# Claude Context Installation Script - Windows PowerShell
# Installs to ~/.claude/hooks/claude-context/ directory

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("PreToolUse", "UserPromptSubmit")]
    [string]$HookType = "UserPromptSubmit",
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall = $false
)

# Stop on errors
$ErrorActionPreference = "Stop"

# Set UTF-8 encoding for better Unicode support
try {
    # Set console encodings for better Unicode support
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
    $OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    
    # Set PowerShell's default file encoding
    $PSDefaultParameterValues['*:Encoding'] = 'utf8'
} catch {
    Write-Warning "Could not set UTF-8 encoding, some Unicode characters may not display correctly"
}

# Import common functions
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CommonFunctionsPath = Join-Path -Path $ScriptDir -ChildPath "common_functions.ps1"

if (Test-Path -Path $CommonFunctionsPath) {
    . $CommonFunctionsPath
} else {
    Write-Error "Common functions module not found: $CommonFunctionsPath"
    exit 1
}

# Color output function
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}


# Generate common environment variables with WSL paths
function Get-CommonEnvironmentVariables {
    param(
        [string]$UserProfileBashPath,
        [string]$LocalAppDataBashPath
    )
    
    $envVars = @()
    $envVars += "CLAUDE_CONFIG_FILE='$UserProfileBashPath/.claude/hooks/claude-context/config.sh'"
    $envVars += "CLAUDE_HOME='$UserProfileBashPath/.claude'"
    $envVars += "CLAUDE_HOOKS_DIR='$UserProfileBashPath/.claude/hooks'"
    $envVars += "CLAUDE_HISTORY_DIR='$UserProfileBashPath/.claude/history'"
    $envVars += "CLAUDE_SUMMARY_DIR='$UserProfileBashPath/.claude/summaries'"
    $envVars += "CLAUDE_CACHE_DIR='$LocalAppDataBashPath/claude-context'"
    $envVars += "CLAUDE_LOG_DIR='$UserProfileBashPath/.claude/logs'"
    
    return $envVars
}

# Get timeout values for installation (uses common module function)
function Get-InstallationTimeoutValues {
    $timeouts = @{
        PreCompact = Get-TimeoutValue -EnvVarName "CLAUDE_PRECOMPACT_TIMEOUT" -DefaultValue 5000
        UserPromptSubmit = Get-TimeoutValue -EnvVarName "CLAUDE_USER_PROMPT_TIMEOUT" -DefaultValue 30000
        Injector = Get-TimeoutValue -EnvVarName "CLAUDE_INJECTOR_TIMEOUT" -DefaultValue 10000
    }
    
    return $timeouts
}

# Comprehensive error logging function for troubleshooting
function Write-ErrorLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [Parameter(Mandatory=$false)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        [Parameter(Mandatory=$false)]
        [string]$Component = "General"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logDir = Join-Path -Path $env:USERPROFILE -ChildPath ".claude\logs"
    
    # Ensure log directory exists
    if (-not (Test-Path $logDir)) {
        try {
            $null = New-Item -ItemType Directory -Path $logDir -Force
        }
        catch {
            Write-Warning "Could not create log directory: $logDir"
            return
        }
    }
    
    $logFile = Join-Path -Path $logDir -ChildPath "claude-context-install.log"
    
    try {
        $logEntry = "[$timestamp] [$Component] $Message"
        
        if ($ErrorRecord) {
            $logEntry += "`n  Exception: $($ErrorRecord.Exception.Message)"
            $logEntry += "`n  ScriptStackTrace: $($ErrorRecord.ScriptStackTrace)"
            if ($ErrorRecord.InvocationInfo) {
                $logEntry += "`n  Location: $($ErrorRecord.InvocationInfo.ScriptName):$($ErrorRecord.InvocationInfo.ScriptLineNumber)"
            }
        }
        
        # Use UTF-8 without BOM for better compatibility
        [System.IO.File]::AppendAllText($logFile, "$logEntry`n", [System.Text.UTF8Encoding]::new($false))
        Write-ColoredOutput "Error logged to: $logFile" "Yellow"
    }
    catch {
        Write-Warning "Could not write to log file: $logFile"
    }
}

# Generate wrapper script content with proper error handling and path conversion
function New-WrapperScript {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("injector", "precompact", "user_prompt")]
        [string]$ScriptType,
        [Parameter(Mandatory=$true)]
        [string]$ScriptName
    )
    
    try {
        # Convert paths using helper functions
        $userProfileBashPath = ConvertTo-WSLPath -WindowsPath $env:USERPROFILE
        $localAppDataBashPath = ConvertTo-WSLPath -WindowsPath $env:LOCALAPPDATA
        
        # Get environment variables using enhanced validation
        $envResult = Get-SafeEnvironmentVariables -AllowedVars @(
            'INPUT_MESSAGE', 'CLAUDE_SESSION_ID', 'CLAUDE_CONTEXT_MODE',
            'CLAUDE_ENABLE_CACHE', 'CLAUDE_INJECT_PROBABILITY'
        ) -ValidatePaths
        
        if (-not $envResult.ValidationPassed) {
            Write-Warning "Some environment variables had validation issues"
            if ($envResult.MissingVariables.Count -gt 0) {
                Write-Verbose "Missing variables: $($envResult.MissingVariables -join ', ')"
            }
        }
        
        $safeEnvVars = @()
        foreach ($key in $envResult.Variables.Keys) {
            $safeEnvVars += "$key='$($envResult.Variables[$key])'"
        }
        $commonEnvVars = Get-CommonEnvironmentVariables -UserProfileBashPath $userProfileBashPath -LocalAppDataBashPath $localAppDataBashPath
        
        # Combine all environment variables
        $allEnvVars = $safeEnvVars + $commonEnvVars
        
        # Set script path based on type
        $scriptPath = switch ($ScriptType) {
            "injector" { "$userProfileBashPath/.claude/hooks/claude-context/src/core/injector.sh" }
            "precompact" { "$userProfileBashPath/.claude/hooks/claude-context/src/core/precompact.sh" }
            "user_prompt" { "$userProfileBashPath/.claude/hooks/claude-context/src/core/injector.sh user_prompt_submit" }
        }
        
        # Generate wrapper content
        $wrapperContent = @"
# Claude Context $ScriptName Wrapper for Windows (Enhanced)
try {
    `$bashExe = Get-Command bash -ErrorAction Stop

    # Environment variable setting (PowerShell -> Bash)
    `$env:CLAUDE_HOME = "`$env:USERPROFILE\.claude"

    # Collect all environment variables
    `$envVars = @()
$($allEnvVars | ForEach-Object { "    `$envVars += `"$_`"" } | Out-String)
    `$envString = `$envVars -join ' '

    # Process arguments (PowerShell args -> bash)
    `$bashArgs = if (`$args) {
        (`$args | ForEach-Object { 
            # Escape single quotes for bash safety
            `$escaped = `$_ -replace "'", "'\'''"
            "'`$escaped'"
        }) -join ' '
    } else {
        ''
    }

    # Execute bash with environment variables and error handling
    `$scriptPath = '$scriptPath'
    `$command = "`$envString '`$scriptPath' `$bashArgs"
    
    `$result = & bash -c `$command
    `$exitCode = `$LASTEXITCODE
    
    if (`$exitCode -ne 0) {
        Write-Warning "Script execution failed with exit code: `$exitCode"
        # Log error for troubleshooting
        if (`$env:CLAUDE_DEBUG -eq "true") {
            Write-Host "Command executed: `$command" -ForegroundColor Yellow
            Write-Host "Exit code: `$exitCode" -ForegroundColor Red
        }
    }
    
    exit `$exitCode
} catch {
    `$errorMsg = "Failed to execute Claude Context $ScriptName`: `$(`$_.Exception.Message)"
    Write-Error `$errorMsg
    
    # Try to log the error if logging is available
    try {
        `$logDir = Join-Path -Path `$env:USERPROFILE -ChildPath ".claude\logs"
        if (Test-Path `$logDir) {
            `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            `$logEntry = "[`$timestamp] [Wrapper-$ScriptType] `$errorMsg"
            Add-Content -Path (Join-Path -Path `$logDir -ChildPath "claude-context-install.log") -Value `$logEntry -Encoding UTF8
        }
    } catch {
        # Silently ignore logging errors
    }
    
    if (`$_.Exception.Message -like "*bash*not*found*") {
        Write-Host "bash not found. Please install Git for Windows." -ForegroundColor Red
        Write-Host "Download from: https://git-scm.com/download/win" -ForegroundColor Yellow
    }
    
    exit 1
}
"@
        
        return $wrapperContent
    }
    catch {
        Write-ErrorLog -Message "Failed to generate wrapper script for $ScriptType" -ErrorRecord $_ -Component "WrapperGeneration"
        throw "Failed to generate wrapper script: $_"
    }
}

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$INSTALL_BASE = Join-Path -Path $env:USERPROFILE -ChildPath ".claude\hooks"
$INSTALL_DIR = Join-Path -Path $INSTALL_BASE -ChildPath "claude-context"
$CONFIG_FILE = Join-Path -Path $INSTALL_BASE -ChildPath "claude-context.conf"

# Print header
function Print-Header {
    Write-ColoredOutput "===============================================" "Blue"
    Write-ColoredOutput "     Claude Context Installation (Windows)   " "Blue"
    Write-ColoredOutput "===============================================" "Blue"
    Write-Host ""
}

# Mode selection
function Select-Mode {
    if ($Mode) {
        return $Mode
    }
    
    Write-ColoredOutput "Please select installation mode:" "Blue"
    Write-Host ""
    Write-Host "1) Basic    - CLAUDE.md injection only (simplest)"
    Write-Host "2) History  - Add conversation history management"
    Write-Host "3) OAuth    - Auto summary with Claude Code auth (recommended)"
    Write-Host "4) Auto     - Auto summary with Claude CLI"
    Write-Host "5) Advanced - Auto summary with Gemini CLI"
    Write-Host ""
    
    do {
        $choice = Read-Host "Choose [1-5] (default: 3)"
        if ([string]::IsNullOrEmpty($choice)) {
            $choice = "3"
        }
    } while ($choice -notmatch "^[1-5]$")
    
    switch ($choice) {
        "1" { return "basic" }
        "2" { return "history" }
        "3" { return "oauth" }
        "4" { return "auto" }
        "5" { return "advanced" }
        default { 
            Write-ColoredOutput "Invalid choice. Using default (oauth)." "Red"
            return "oauth"
        }
    }
}

# Check dependencies
function Test-Dependencies {
    param([string]$SelectedMode)
    
    $missing = @()
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-ColoredOutput "PowerShell 5.0 or higher is required." "Red"
        exit 1
    }
    
    # Check Git
    try {
        git --version | Out-Null
    } catch {
        $missing += "git"
    }
    
    if ($missing.Count -gt 0) {
        Write-ColoredOutput "Missing tools: $($missing -join ', ')" "Red"
        Write-Host "Please install and try again."
        exit 1
    }
}

# Create backup
function New-Backup {
    if (Test-Path $INSTALL_DIR) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "$INSTALL_DIR.backup.$timestamp"
        Write-Host "Backing up existing installation..."
        Copy-Item -Recurse $INSTALL_DIR $backupDir
        Write-ColoredOutput "Backup completed: $backupDir" "Green"
    }
}

# Install files
function Install-Files {
    param([string]$Mode)
    Write-Host "Installing files..."
    
    try {
        # Create claude-context directories
        $dirs = @(
            (Join-Path -Path $INSTALL_DIR -ChildPath "src\core"),
            (Join-Path -Path $INSTALL_DIR -ChildPath "src\utils"),
            (Join-Path -Path $INSTALL_DIR -ChildPath "docs"),
            (Join-Path -Path $INSTALL_DIR -ChildPath "config")
        )

        # Add monitor directory only for specific modes
        if ($Mode -eq "history" -or $Mode -eq "oauth" -or $Mode -eq "auto" -or $Mode -eq "advanced") {
            $dirs += (Join-Path -Path $INSTALL_DIR -ChildPath "src\monitor")
        }
        
        Write-Host "Creating installation directories..."
        foreach ($dir in $dirs) {
            try {
                $null = New-Item -ItemType Directory -Path $dir -Force
                Write-Verbose "Created directory: $dir"
            }
            catch {
                Write-ErrorLog -Message "Failed to create directory: $dir" -ErrorRecord $_ -Component "DirectoryCreation"
                throw "Directory creation failed: $dir"
            }
        }
    }
    catch {
        Write-ErrorLog -Message "Critical error during directory creation" -ErrorRecord $_ -Component "Install"
        throw
    }
    
    # Check required directories
    $requiredDirs = @("core", "utils")
    $missingCount = 0
    
    foreach ($dir in $requiredDirs) {
        $sourcePath = Join-Path -Path $PROJECT_ROOT -ChildPath $dir
        if (-not (Test-Path $sourcePath)) {
            Write-ColoredOutput "Error: Required directory '$dir' not found" "Red"
            $missingCount++
        }
    }
    
    if ($missingCount -gt 0) {
        Write-ColoredOutput "Required files are missing." "Red"
        Write-Host "Project root: $PROJECT_ROOT"
        Get-ChildItem $PROJECT_ROOT
        exit 1
    }
    
    # Copy core files
    Copy-Item -Recurse -Path (Join-Path -Path $PROJECT_ROOT -ChildPath "core") -Destination (Join-Path -Path $INSTALL_DIR -ChildPath "src") -Force
    Copy-Item -Recurse -Path (Join-Path -Path $PROJECT_ROOT -ChildPath "utils") -Destination (Join-Path -Path $INSTALL_DIR -ChildPath "src") -Force
    
    # Copy monitor directory only for specific modes
    if ($Mode -eq "history" -or $Mode -eq "oauth" -or $Mode -eq "auto" -or $Mode -eq "advanced") {
        if (Test-Path (Join-Path -Path $PROJECT_ROOT -ChildPath "monitor")) {
            Copy-Item -Recurse -Path (Join-Path -Path $PROJECT_ROOT -ChildPath "monitor") -Destination (Join-Path -Path $INSTALL_DIR -ChildPath "src") -Force
        }
    }
    
    # Copy only essential documentation
    if (Test-Path (Join-Path -Path $PROJECT_ROOT -ChildPath "docs")) {
        $docsDir = Join-Path -Path $INSTALL_DIR -ChildPath "docs"
        $null = New-Item -ItemType Directory -Path $docsDir -Force
        
        # Copy only essential docs
        $essentialDocs = @("INSTALL.md", "LICENSE", "PROJECT_CONTEXT.md")
        foreach ($doc in $essentialDocs) {
            $sourcePath = Join-Path -Path (Join-Path -Path $PROJECT_ROOT -ChildPath "docs") -ChildPath $doc
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $docsDir -Force
            }
        }
    }
    
    # Copy main documentation files
    $mainDocs = @("README.md", "README.en.md", "README.windows.md")
    foreach ($doc in $mainDocs) {
        $sourcePath = Join-Path -Path $PROJECT_ROOT -ChildPath $doc
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination $INSTALL_DIR -Force
        }
    }
    if (Test-Path (Join-Path -Path $PROJECT_ROOT -ChildPath "config.sh")) {
        Copy-Item -Path (Join-Path -Path $PROJECT_ROOT -ChildPath "config.sh") -Destination $INSTALL_DIR -Force
    }
    
    # Create Windows wrapper scripts using helper function
    $injectorWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_injector.ps1"
    $userPromptWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_user_prompt_injector.ps1"
    $precompactWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_precompact.ps1"
    
    try {
        Write-Host "Generating wrapper scripts with enhanced error handling..."
        
        # Generate injector wrapper
        $injectorContent = New-WrapperScript -ScriptType "injector" -ScriptName "Injector"
        Set-Content -Path $injectorWrapperPath -Value $injectorContent -Encoding UTF8
        Write-ColoredOutput "Created: $injectorWrapperPath" "Green"
        
        # Generate precompact wrapper
        $precompactContent = New-WrapperScript -ScriptType "precompact" -ScriptName "PreCompact"
        Set-Content -Path $precompactWrapperPath -Value $precompactContent -Encoding UTF8
        Write-ColoredOutput "Created: $precompactWrapperPath" "Green"
        
        # Generate user prompt wrapper
        $userPromptContent = New-WrapperScript -ScriptType "user_prompt" -ScriptName "User Prompt Injector"
        Set-Content -Path $userPromptWrapperPath -Value $userPromptContent -Encoding UTF8
        Write-ColoredOutput "Created: $userPromptWrapperPath" "Green"
    }
    catch {
        Write-ErrorLog -Message "Failed to create wrapper scripts" -ErrorRecord $_ -Component "WrapperCreation"
        throw "Wrapper script creation failed: $_"
    }
    
    Write-ColoredOutput "File installation completed" "Green"
}

# Create configuration
function New-Config {
    param([string]$SelectedMode)
    
    Write-Host "Creating configuration files..."
    
    try {
        # Create claude-context.conf
        $configContent = @"
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$($INSTALL_DIR.Replace('\', '/'))"
CLAUDE_CONTEXT_MODE="$SelectedMode"
"@
        Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
        Write-ColoredOutput "Created main config: $CONFIG_FILE" "Green"
    }
    catch {
        Write-ErrorLog -Message "Failed to create main configuration file" -ErrorRecord $_ -Component "ConfigCreation"
        throw "Configuration file creation failed: $CONFIG_FILE"
    }
    
    # Create config.sh with WSL-style paths using helper functions
    $configShPath = Join-Path -Path $INSTALL_DIR -ChildPath "config.sh"

    try {
        # Convert paths using helper function
        $userProfileBashPath = ConvertTo-WSLPath -WindowsPath $env:USERPROFILE
        $localAppDataBashPath = ConvertTo-WSLPath -WindowsPath $env:LOCALAPPDATA

        $configShContent = @"
#!/usr/bin/env bash
# Claude Context Configuration - Windows Compatible with WSL paths

CLAUDE_CONTEXT_MODE="$SelectedMode"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_INJECT_PROBABILITY="1.0"
CLAUDE_HOME="$userProfileBashPath/.claude"
CLAUDE_HOOKS_DIR="$userProfileBashPath/.claude/hooks"
CLAUDE_HISTORY_DIR="`${CLAUDE_HOME}/history"
CLAUDE_SUMMARY_DIR="`${CLAUDE_HOME}/summaries"
CLAUDE_CACHE_DIR="$localAppDataBashPath/claude-context"
CLAUDE_LOG_DIR="`${CLAUDE_HOME}/logs"
CLAUDE_LOCK_TIMEOUT="5"
CLAUDE_CACHE_MAX_AGE="3600"

export CLAUDE_CONTEXT_MODE
export CLAUDE_ENABLE_CACHE
export CLAUDE_INJECT_PROBABILITY
export CLAUDE_HOME
export CLAUDE_HOOKS_DIR
export CLAUDE_HISTORY_DIR
export CLAUDE_SUMMARY_DIR
export CLAUDE_CACHE_DIR
export CLAUDE_LOG_DIR
export CLAUDE_LOCK_TIMEOUT
export CLAUDE_CACHE_MAX_AGE
"@
        Set-Content -Path $configShPath -Value $configShContent -Encoding UTF8
        Write-ColoredOutput "Created bash config: $configShPath" "Green"
    }
    catch {
        Write-ErrorLog -Message "Failed to create bash configuration file" -ErrorRecord $_ -Component "ConfigCreation"
        throw "Bash configuration file creation failed: $configShPath"
    }

    # Create config.ps1 for PowerShell environment
    $configPs1Path = Join-Path -Path $INSTALL_DIR -ChildPath "config.ps1"
    
    try {
        $configPs1Content = @"
# Claude Context Configuration - PowerShell
# 이 파일은 PowerShell 환경에서 Claude Context 환경 변수를 설정합니다.

# 기본 설정
`$env:CLAUDE_CONTEXT_MODE = "$SelectedMode"
`$env:CLAUDE_ENABLE_CACHE = "true"
`$env:CLAUDE_INJECT_PROBABILITY = "1.0"

# 디렉토리 설정
`$env:CLAUDE_HOME = "`$env:USERPROFILE\.claude"
`$env:CLAUDE_HOOKS_DIR = "`$env:USERPROFILE\.claude\hooks"
`$env:CLAUDE_HISTORY_DIR = "`$env:USERPROFILE\.claude\history"
`$env:CLAUDE_SUMMARY_DIR = "`$env:USERPROFILE\.claude\summaries"
`$env:CLAUDE_CACHE_DIR = "`$env:LOCALAPPDATA\claude-context"
`$env:CLAUDE_LOG_DIR = "`$env:USERPROFILE\.claude\logs"

# 고급 설정
`$env:CLAUDE_LOCK_TIMEOUT = "5"
`$env:CLAUDE_CACHE_MAX_AGE = "3600"

# 사용자 정의 설정 (필요시 수정)
# `$env:CLAUDE_MD_INJECT_PROBABILITY = "0.8"  # 주입 확률 조정
# `$env:CLAUDE_DEBUG = "true"                 # 디버그 모드

Write-Verbose "Claude Context PowerShell configuration loaded (Mode: $SelectedMode)"
"@
        Set-Content -Path $configPs1Path -Value $configPs1Content -Encoding UTF8
        Write-ColoredOutput "Created PowerShell config: $configPs1Path" "Green"
    }
    catch {
        Write-ErrorLog -Message "Failed to create PowerShell configuration file" -ErrorRecord $_ -Component "ConfigCreation"
        throw "PowerShell configuration file creation failed: $configPs1Path"
    }

    Write-ColoredOutput "Configuration files created (bash + PowerShell)" "Green"
}

# Update Claude configuration
function Update-ClaudeConfig {
    param([string]$UseHookType)
    
    $claudeConfig = Join-Path -Path $env:USERPROFILE -ChildPath ".claude\settings.json"

    if (-not (Test-Path $claudeConfig)) {
        Write-ColoredOutput "Claude settings file not found. Creating default settings..." "Yellow"

        # Create .claude directory if it doesn't exist
        $claudeDir = Join-Path -Path $env:USERPROFILE -ChildPath ".claude"
        $null = New-Item -ItemType Directory -Path $claudeDir -Force

        # Create default settings.json
        $defaultSettings = @{
            hooks = @{}
        }

        $defaultSettings | ConvertTo-Json -Depth 10 | Set-Content -Path $claudeConfig -Encoding UTF8
        Write-ColoredOutput "Default Claude settings created: $claudeConfig" "Green"
    }
    
    Write-Host "Updating Claude configuration (Hook: $UseHookType)..."
    
    # Create backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    try {
        Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
        Write-ColoredOutput "Configuration backup created: $claudeConfig.backup.$timestamp" "Green"
    }
    catch {
        Write-ErrorLog -Message "Failed to create backup of Claude configuration" -ErrorRecord $_ -Component "ConfigBackup"
        Write-Warning "Could not create configuration backup, continuing anyway..."
    }
    
    # Get configurable timeout values
    try {
        $timeouts = Get-InstallationTimeoutValues
        Write-Host "Using timeout values: PreCompact=$($timeouts.PreCompact)ms, UserPromptSubmit=$($timeouts.UserPromptSubmit)ms"
    }
    catch {
        Write-ErrorLog -Message "Failed to get timeout values, using defaults" -ErrorRecord $_ -Component "TimeoutConfig"
        $timeouts = @{
            PreCompact = 5000
            UserPromptSubmit = 30000
            Injector = 10000
        }
    }
    
    # Update JSON configuration
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        $injectorPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_injector.ps1"
        $userPromptPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_user_prompt_injector.ps1"
        $precompactPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_precompact.ps1"
        
        # Create hooks based on HookType with configurable timeouts
        $hooksConfig = @{
            PreCompact = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command" 
                            command = "powershell -ExecutionPolicy Bypass -File `"$precompactPath`""
                            timeout = $timeouts.PreCompact
                        }
                    )
                }
            )
        }
        
        # Always use UserPromptSubmit hook
        $hooksConfig["UserPromptSubmit"] = @(
            @{
                matcher = ""
                hooks = @(
                    @{
                        type = "command"
                        command = "powershell -ExecutionPolicy Bypass -File `"$userPromptPath`""
                        timeout = $timeouts.UserPromptSubmit
                    }
                )
            }
        )
        
        $config | Add-Member -NotePropertyName "hooks" -NotePropertyValue $hooksConfig -Force
        
        # Convert to JSON with proper formatting and no BOM
        $jsonContent = $config | ConvertTo-Json -Depth 10
        # Remove BOM and save with UTF8 without BOM
        [System.IO.File]::WriteAllText($claudeConfig, $jsonContent, [System.Text.UTF8Encoding]::new($false))
        Write-ColoredOutput "Claude configuration updated with configurable timeouts" "Green"
    }
    catch {
        $errorMsg = "Error updating Claude configuration: $_"
        Write-ColoredOutput $errorMsg "Red"
        Write-ErrorLog -Message $errorMsg -ErrorRecord $_ -Component "ConfigUpdate"
        throw "Failed to update Claude configuration"
    }
}

# Create directories
function New-Directories {
    param([string]$SelectedMode)
    
    # Basic directories
    $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude") -Force
    $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:LOCALAPPDATA -ChildPath "claude-context") -Force

    # History/OAuth/Auto/Advanced mode directories
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\history") -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\summaries") -Force
    }
}

# Show usage information
function Show-Usage {
    param([string]$SelectedMode)
    
    Write-Host ""
    Write-ColoredOutput "Installation completed!" "Green"
    Write-Host ""
    Write-ColoredOutput "Installation location: $INSTALL_DIR" "Blue"
    Write-ColoredOutput "Mode: $($SelectedMode.ToUpper())" "Blue"
    Write-ColoredOutput "Hook Type: $HookType" "Blue"
    Write-Host ""
    Write-ColoredOutput "Configuration:" "Blue"
    Write-Host "- Enhanced error handling and logging enabled"
    Write-Host "- Configurable timeouts via environment variables:"
    Write-Host "  * CLAUDE_PRECOMPACT_TIMEOUT (default: 5000ms)"
    Write-Host "  * CLAUDE_USER_PROMPT_TIMEOUT (default: 30000ms)"
    Write-Host "  * CLAUDE_INJECTOR_TIMEOUT (default: 10000ms)"
    Write-Host "- Logs are saved to: $env:USERPROFILE\.claude\logs\"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Create CLAUDE.md files:"
    Write-Host "   - Global: $env:USERPROFILE\.claude\CLAUDE.md"
    Write-Host "   - Project-specific: <project-root>\CLAUDE.md"
    Write-Host ""
    Write-Host "2. Optional: Set custom timeout values if needed"
    Write-Host "   Example: `$env:CLAUDE_USER_PROMPT_TIMEOUT = 45000"
    Write-Host ""
    Write-Host "3. Enable debug mode for troubleshooting (optional):"
    Write-Host "   `$env:CLAUDE_DEBUG = `"true`""
    Write-Host ""
    Write-Host "4. Restart Claude Code"
    Write-Host ""
}

# Main execution
function Main {
    Print-Header
    
    if ($Uninstall) {
        Write-Host "For uninstall, please use uninstall.ps1"
        return
    }
    
    # Select mode
    $selectedMode = Select-Mode
    Write-Host ""
    Write-ColoredOutput "Selected mode: $selectedMode" "Blue"
    Write-Host ""
    
    # Check dependencies
    Test-Dependencies $selectedMode
    
    # Create backup
    New-Backup
    
    # Install
    Install-Files -Mode $selectedMode
    New-Config $selectedMode
    New-Directories $selectedMode
    Update-ClaudeConfig -UseHookType $HookType
    
    # Show completion message
    Show-Usage $selectedMode
}

# Run script
Main