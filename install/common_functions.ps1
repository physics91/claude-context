# Claude Context - Common PowerShell Functions
# 공통 함수 모듈

# Convert Windows path to Unix-style path with WSL/Git Bash compatibility
function ConvertTo-WSLPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WindowsPath,
        [Parameter(Mandatory=$false)]
        [ValidateSet("WSL", "GitBash", "Auto")]
        [string]$TargetEnvironment = "Auto"
    )
    
    if ([string]::IsNullOrEmpty($WindowsPath)) {
        throw "Path cannot be null or empty"
    }
    
    try {
        # Expand environment variables and normalize path
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($WindowsPath)
        $normalizedPath = [System.IO.Path]::GetFullPath($expandedPath).Replace('\', '/')
        
        # Extract drive letter and path
        if ($normalizedPath -match '^([A-Za-z]):(.*)$') {
            $driveLetter = $matches[1].ToLower()
            $pathPart = $matches[2]
            
            # Determine target environment if Auto
            if ($TargetEnvironment -eq "Auto") {
                $TargetEnvironment = Get-BashEnvironmentType
            }
            
            # Convert based on target environment
            switch ($TargetEnvironment) {
                "WSL" {
                    # WSL format: C:\path -> /mnt/c/path
                    $bashPath = "/mnt/$driveLetter$pathPart"
                }
                "GitBash" {
                    # Git Bash format: C:\path -> /c/path
                    $bashPath = "/$driveLetter$pathPart"
                }
                default {
                    # Default to WSL format for compatibility
                    $bashPath = "/mnt/$driveLetter$pathPart"
                }
            }
            
            # Remove trailing slash except for root
            if ($bashPath.EndsWith('/') -and $bashPath.Length -gt 4) {
                $bashPath = $bashPath.TrimEnd('/')
            }
            
            # Handle spaces in paths by quoting if needed
            if ($bashPath -match '\s') {
                Write-Verbose "Path contains spaces, consider quoting: '$bashPath'"
            }
            
            return $bashPath
        } else {
            throw "Invalid Windows path format: $WindowsPath (expected format: C:\path\to\directory)"
        }
    } catch {
        Write-Error "Failed to convert path '$WindowsPath': $($_.Exception.Message)"
        throw
    }
}

# Convert Unix-style path back to Windows path (supports both WSL and Git Bash formats)
function ConvertTo-WindowsPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$UnixPath
    )
    
    if ([string]::IsNullOrEmpty($UnixPath)) {
        throw "Path cannot be null or empty"
    }
    
    try {
        # WSL format: /mnt/c/path -> C:\path
        if ($UnixPath -match '^/mnt/([a-z])/(.*)$') {
            $driveLetter = $matches[1].ToUpper()
            $pathPart = $matches[2].Replace('/', '\')
            
            return "${driveLetter}:\$pathPart"
        }
        # WSL root: /mnt/c/ -> C:\
        elseif ($UnixPath -match '^/mnt/([a-z])/?$') {
            $driveLetter = $matches[1].ToUpper()
            return "${driveLetter}:\"
        }
        # Git Bash format: /c/path -> C:\path
        elseif ($UnixPath -match '^/([a-z])/(.*)$') {
            $driveLetter = $matches[1].ToUpper()
            $pathPart = $matches[2].Replace('/', '\')
            
            return "${driveLetter}:\$pathPart"
        }
        # Git Bash root: /c/ -> C:\
        elseif ($UnixPath -match '^/([a-z])/?$') {
            $driveLetter = $matches[1].ToUpper()
            return "${driveLetter}:\"
        }
        else {
            throw "Invalid Unix path format: $UnixPath (expected WSL '/mnt/c/path' or Git Bash '/c/path' format)"
        }
    } catch {
        Write-Error "Failed to convert Unix path '$UnixPath': $($_.Exception.Message)"
        throw
    }
}

# Validate path exists (Windows, WSL, or Git Bash format)
function Test-PathExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$PathType = "Any" # File, Directory, Any
    )
    
    $windowsPath = $Path
    
    # If it's a Unix-style path, convert to Windows path
    if ($Path.StartsWith('/mnt/') -or $Path -match '^/[a-z]/') {
        try {
            $windowsPath = ConvertTo-WindowsPath -UnixPath $Path
        } catch {
            Write-Verbose "Failed to convert Unix path '$Path': $($_.Exception.Message)"
            return $false
        }
    }
    
    switch ($PathType) {
        "File" { return Test-Path -Path $windowsPath -PathType Leaf }
        "Directory" { return Test-Path -Path $windowsPath -PathType Container }
        default { return Test-Path -Path $windowsPath }
    }
}

# Safe environment variable extraction with enhanced validation
function Get-SafeEnvironmentVariables {
    param(
        [string[]]$AllowedVars = @(
            'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'TEMP', 'TMP',
            'COMPUTERNAME', 'USERNAME', 'USERDOMAIN', 'LOGONSERVER',
            'PROCESSOR_ARCHITECTURE', 'PROCESSOR_IDENTIFIER',
            'OS', 'PATH', 'PATHEXT'
        ),
        [switch]$RequireAll = $false,
        [switch]$ValidatePaths = $false
    )
    
    $safeVars = @{}
    $missingVars = @()
    $invalidPaths = @()
    
    foreach ($varName in $AllowedVars) {
        $value = [Environment]::GetEnvironmentVariable($varName)
        
        if ([string]::IsNullOrEmpty($value)) {
            $missingVars += $varName
            if ($RequireAll) {
                Write-Warning "Required environment variable '$varName' is missing or empty"
            }
        } else {
            # Validate path existence for path-related variables
            if ($ValidatePaths -and $varName -match 'PROFILE|APPDATA|TEMP|TMP') {
                if (-not (Test-Path -Path $value)) {
                    $invalidPaths += "$varName='$value'"
                    Write-Warning "Environment variable '$varName' points to non-existent path: $value"
                }
            }
            
            # Enhanced input validation
            if ($value.Length -gt 32767) {
                Write-Warning "Environment variable '$varName' exceeds maximum length (32767 chars)"
                continue
            }
            
            # Check for potentially dangerous characters
            if ($value -match '[<>|&;`$]' -and $varName -ne 'PATH') {
                Write-Warning "Environment variable '$varName' contains potentially unsafe characters"
            }
            
            # Normalize Unicode and escape special characters for bash safety
            $normalizedValue = $value.Normalize([System.Text.NormalizationForm]::FormC)
            $escaped = $normalizedValue -replace "'", "'\'''" -replace '"', '\"' -replace '`', '\`'
            
            # Additional validation for Unicode in environment variables
            try {
                # Test if the string can be safely converted to bytes and back
                $bytes = [System.Text.Encoding]::UTF8.GetBytes($escaped)
                $recovered = [System.Text.Encoding]::UTF8.GetString($bytes)
                if ($recovered -ne $escaped) {
                    Write-Warning "Environment variable '$varName' contains characters that may not translate properly to UTF-8"
                }
            } catch {
                Write-Warning "Environment variable '$varName' contains invalid Unicode sequences"
            }
            
            $safeVars[$varName] = $escaped
        }
    }
    
    # Return enhanced result with validation info
    $result = @{
        Variables = $safeVars
        MissingVariables = $missingVars
        InvalidPaths = $invalidPaths
        ValidationPassed = ($missingVars.Count -eq 0 -or -not $RequireAll) -and ($invalidPaths.Count -eq 0 -or -not $ValidatePaths)
    }
    
    return $result
}

# Generate timeout values with enhanced validation
function Get-TimeoutValue {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EnvVarName,
        [Parameter(Mandatory=$true)]
        [int]$DefaultValue,
        [int]$MinValue = 1000,
        [int]$MaxValue = 300000,
        [switch]$ThrowOnInvalid = $false
    )
    
    # Validate input parameters
    if ([string]::IsNullOrWhiteSpace($EnvVarName)) {
        throw "Environment variable name cannot be null or empty"
    }
    
    if ($DefaultValue -lt $MinValue -or $DefaultValue -gt $MaxValue) {
        throw "Default value ($DefaultValue) is outside valid range ($MinValue-$MaxValue)"
    }
    
    # Get environment variable value
    $customValue = [Environment]::GetEnvironmentVariable($EnvVarName)
    
    if ([string]::IsNullOrWhiteSpace($customValue)) {
        Write-Verbose "Environment variable '$EnvVarName' not set, using default: $DefaultValue"
        return $DefaultValue
    }
    
    # Trim whitespace
    $customValue = $customValue.Trim()
    
    # Validate format and convert
    try {
        # Check for non-numeric characters
        if ($customValue -notmatch '^\d+$') {
            throw "Value contains non-numeric characters: '$customValue'"
        }
        
        $numValue = [int]$customValue
        
        # Range validation
        if ($numValue -lt $MinValue) {
            $message = "Timeout value for '$EnvVarName' ($numValue ms) is below minimum ($MinValue ms)"
            if ($ThrowOnInvalid) {
                throw $message
            } else {
                Write-Warning "$message. Using default: $DefaultValue ms"
                return $DefaultValue
            }
        }
        
        if ($numValue -gt $MaxValue) {
            $message = "Timeout value for '$EnvVarName' ($numValue ms) exceeds maximum ($MaxValue ms)"
            if ($ThrowOnInvalid) {
                throw $message
            } else {
                Write-Warning "$message. Using default: $DefaultValue ms"
                return $DefaultValue
            }
        }
        
        Write-Verbose "Using custom timeout for '$EnvVarName': $numValue ms"
        return $numValue
        
    } catch {
        $message = "Invalid timeout format for '$EnvVarName' ('$customValue'): $($_.Exception.Message)"
        if ($ThrowOnInvalid) {
            throw $message
        } else {
            Write-Warning "$message. Using default: $DefaultValue ms"
            return $DefaultValue
        }
    }
}

# Create directory if it doesn't exist
function Ensure-Directory {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path -Path $Path)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Verbose "Created directory: $Path"
        } catch {
            Write-Warning "Failed to create directory '$Path': $($_.Exception.Message)"
            return $false
        }
    }
    return $true
}

# Log message with timestamp and enhanced Unicode support
function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Level = "INFO",
        [string]$LogFile = $null,
        [switch]$Console,
        [System.Text.Encoding]$Encoding = [System.Text.UTF8Encoding]::new($false)
    )
    
    # Ensure console supports UTF-8 output with proper fallback
    if ($Console) {
        try {
            # Set both console encodings for proper Unicode support
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
            [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
            
            # Also set PowerShell's output encoding
            $global:OutputEncoding = [System.Text.UTF8Encoding]::new($false)
        } catch {
            Write-Verbose "Could not set console encoding to UTF-8: $($_.Exception.Message)"
        }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Normalize Unicode strings to ensure consistent representation
    $normalizedMessage = $Message.Normalize([System.Text.NormalizationForm]::FormC)
    $logEntry = "[$timestamp] [$Level] $normalizedMessage"
    
    if ($Console) {
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            default { Write-Host $logEntry }
        }
    }
    
    if ($LogFile) {
        try {
            # Ensure log directory exists
            $logDir = Split-Path -Path $LogFile -Parent
            if ($logDir -and -not (Test-Path -Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            # Use System.IO.File for better Unicode control
            $logEntryWithNewline = $logEntry + [Environment]::NewLine
            [System.IO.File]::AppendAllText($LogFile, $logEntryWithNewline, $Encoding)
            
        } catch {
            Write-Warning "Failed to write to log file '$LogFile': $($_.Exception.Message)"
        }
    }
}

# Detect bash environment type (WSL vs Git Bash)
function Get-BashEnvironmentType {
    try {
        $bashCmd = Get-Command bash -ErrorAction Stop
        $bashPath = $bashCmd.Source.ToLower()
        
        # Check if it's WSL bash
        if ($bashPath -match "wsl|ubuntu|debian|system32") {
            return "WSL"
        }
        # Check if it's Git Bash
        elseif ($bashPath -match "git|mingw|msys") {
            return "GitBash"
        }
        # Try to detect by testing path format
        else {
            try {
                # Test which path format works
                $testResult = & bash -c "if [ -d '/mnt/c' ]; then echo 'WSL'; elif [ -d '/c' ]; then echo 'GitBash'; else echo 'Unknown'; fi" 2>$null
                if ($testResult -eq "WSL") {
                    return "WSL"
                } elseif ($testResult -eq "GitBash") {
                    return "GitBash"
                }
            } catch {
                # If detection fails, default to WSL
                Write-Verbose "Could not detect bash environment, defaulting to WSL"
            }
        }
        
        # Default to WSL for better compatibility
        return "WSL"
    } catch {
        # If bash is not available, default to WSL
        return "WSL"
    }
}

# Check if bash is available with enhanced detection
function Test-BashAvailability {
    try {
        $bashCmd = Get-Command bash -ErrorAction Stop
        $envType = Get-BashEnvironmentType
        
        return @{
            Available = $true
            Path = $bashCmd.Source
            Environment = $envType
            Version = & bash --version 2>$null | Select-Object -First 1
        }
    } catch {
        return @{
            Available = $false
            Path = $null
            Environment = "Unknown"
            Version = $null
            Error = $_.Exception.Message
        }
    }
}

# Validate script arguments with Unicode support
function Test-ScriptArgs {
    param(
        [string[]]$RequiredArgs,
        [hashtable]$ProvidedArgs
    )
    
    $missing = @()
    $unicodeIssues = @()
    
    foreach ($arg in $RequiredArgs) {
        if (-not $ProvidedArgs.ContainsKey($arg) -or [string]::IsNullOrEmpty($ProvidedArgs[$arg])) {
            $missing += $arg
        } else {
            # Check for Unicode normalization issues
            $value = $ProvidedArgs[$arg]
            $normalized = $value.Normalize([System.Text.NormalizationForm]::FormC)
            if ($value -ne $normalized) {
                $unicodeIssues += "$arg (Unicode normalization required)"
                $ProvidedArgs[$arg] = $normalized
            }
        }
    }
    
    return @{
        Valid = ($missing.Count -eq 0)
        MissingArgs = $missing
        UnicodeIssues = $unicodeIssues
        NormalizedArgs = $ProvidedArgs
    }
}

# Test Unicode string safety for bash environments
function Test-UnicodeStringForBash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString,
        [switch]$NormalizeString = $true
    )
    
    $result = @{
        IsValid = $true
        NormalizedString = $InputString
        Issues = @()
    }
    
    try {
        # Normalize Unicode string
        if ($NormalizeString) {
            $result.NormalizedString = $InputString.Normalize([System.Text.NormalizationForm]::FormC)
        }
        
        # Test UTF-8 encoding/decoding
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($result.NormalizedString)
        $recovered = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        if ($recovered -ne $result.NormalizedString) {
            $result.IsValid = $false
            $result.Issues += "String contains characters that cannot be properly encoded in UTF-8"
        }
        
        # Check for control characters that might cause issues in bash
        if ($result.NormalizedString -match '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x9F]') {
            $result.Issues += "String contains control characters that may cause issues in bash"
        }
        
        # Check for potentially problematic Unicode categories
        for ($i = 0; $i -lt $result.NormalizedString.Length; $i++) {
            $char = $result.NormalizedString[$i]
            $category = [System.Char]::GetUnicodeCategory($char)
            
            if ($category -in @([System.Globalization.UnicodeCategory]::Control, 
                              [System.Globalization.UnicodeCategory]::Format,
                              [System.Globalization.UnicodeCategory]::Surrogate)) {
                $result.Issues += "String contains Unicode character in category '$category' at position $i"
            }
        }
        
    } catch {
        $result.IsValid = $false
        $result.Issues += "Unicode validation failed: $($_.Exception.Message)"
    }
    
    return $result
}

# Export functions for module usage (only when loaded as module)
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') {
    # Running as script - functions are automatically available
} else {
    # Running as module - export functions
    Export-ModuleMember -Function @(
        'ConvertTo-WSLPath',
        'ConvertTo-WindowsPath', 
        'Test-PathExists',
        'Get-SafeEnvironmentVariables',
        'Get-TimeoutValue',
        'Ensure-Directory',
        'Write-Log',
        'Get-BashEnvironmentType',
        'Test-BashAvailability',
        'Test-ScriptArgs',
        'Test-UnicodeStringForBash'
    )
}