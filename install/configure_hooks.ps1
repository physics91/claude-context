# Claude Context Hook Configuration Script (Windows PowerShell)
# Interactive script to change Claude Context mode

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("PreToolUse", "UserPromptSubmit")]
    [string]$HookType = "UserPromptSubmit"
)

# Stop on errors
$ErrorActionPreference = "Stop"

# Color output function
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Configuration - using Join-Path for safe path combination
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$INSTALL_BASE = Join-Path -Path $env:USERPROFILE -ChildPath ".claude\hooks"
$INSTALL_DIR = Join-Path -Path $INSTALL_BASE -ChildPath "claude-context"
$CONFIG_FILE = Join-Path -Path $INSTALL_BASE -ChildPath "claude-context.conf"

# Print header
function Print-Header {
    Write-ColoredOutput "===============================================" "Blue"
    Write-ColoredOutput "     Claude Context Mode Configuration       " "Blue"
    Write-ColoredOutput "===============================================" "Blue"
    Write-Host ""
}

# Get current mode
function Get-CurrentMode {
    if (Test-Path $CONFIG_FILE) {
        $content = Get-Content $CONFIG_FILE
        $modeLine = $content | Where-Object { $_ -match "CLAUDE_CONTEXT_MODE=" }
        if ($modeLine) {
            return $modeLine -replace 'CLAUDE_CONTEXT_MODE="?([^"]*)"?', '$1'
        }
    }
    return "Unknown"
}

# Mode selection
function Select-Mode {
    if ($Mode) {
        return $Mode
    }
    
    $currentMode = Get-CurrentMode
    Write-ColoredOutput "Current mode: $currentMode" "Yellow"
    Write-Host ""
    
    Write-ColoredOutput "Please select new mode:" "Blue"
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

# Update configuration
function Update-Config {
    param([string]$SelectedMode)
    
    Write-Host "Updating configuration..."
    
    # Update claude-context.conf
    if (Test-Path $CONFIG_FILE) {
        $content = Get-Content $CONFIG_FILE
        $newContent = $content | ForEach-Object {
            if ($_ -match "CLAUDE_CONTEXT_MODE=") {
                "CLAUDE_CONTEXT_MODE=`"$SelectedMode`""
            } else {
                $_
            }
        }
        Set-Content -Path $CONFIG_FILE -Value $newContent -Encoding UTF8
    } else {
        $configContent = @"
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$($INSTALL_DIR.Replace('\', '/'))"
CLAUDE_CONTEXT_MODE="$SelectedMode"
"@
        Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
    }
    
    # Update config.sh
    $configShPath = Join-Path -Path $INSTALL_DIR -ChildPath "config.sh"
    if (Test-Path $configShPath) {
        $content = Get-Content $configShPath
        $newContent = $content | ForEach-Object {
            if ($_ -match "CLAUDE_CONTEXT_MODE=") {
                "CLAUDE_CONTEXT_MODE=`"$SelectedMode`""
            } else {
                $_
            }
        }
        Set-Content -Path $configShPath -Value $newContent -Encoding UTF8
    }
    
    Write-ColoredOutput "Configuration update completed" "Green"
}

# Create directories - Out-Null replacement with $null assignment
function New-Directories {
    param([string]$SelectedMode)
    
    # Basic directories
    $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude") -Force
    $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:LOCALAPPDATA -ChildPath "claude-context") -Force
    
    # History/OAuth/Auto/Advanced mode directories
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        Write-Host "Creating conversation history management directories..."
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\history") -Force
        $null = New-Item -ItemType Directory -Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\summaries") -Force
        Write-ColoredOutput "Directory creation completed" "Green"
    }
}

# Check installation status
function Test-Installation {
    $errors = @()
    
    if (-not (Test-Path $INSTALL_DIR)) {
        $errors += "Claude Context is not installed."
    }
    
    # Note: settings.json will be created automatically if needed, so we don't treat this as an error
    # if (-not (Test-Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\settings.json"))) {
    #     $errors += "Claude Code settings file not found."
    # }
    
    return $errors
}

# Show usage information
function Show-Usage {
    param([string]$SelectedMode)
    
    Write-Host ""
    Write-ColoredOutput "Mode change completed!" "Green"
    Write-Host ""
    Write-ColoredOutput "Current mode: $($SelectedMode.ToUpper())" "Blue"
    Write-Host ""
    
    switch ($SelectedMode) {
        "basic" {
            Write-Host "CLAUDE.md file injection only is enabled."
        }
        "history" {
            Write-Host "Conversation history management is enabled."
            Write-Host ""
            Write-Host "Conversation history management:"
            Write-Host "  $INSTALL_DIR\src\monitor\claude_history_manager.sh --help"
        }
        "oauth" {
            Write-Host "Auto summary feature is enabled. (Using Claude Code OAuth)"
            Write-Host "Claude Code authentication information is used automatically."
            Write-Host ""
            if (-not (Test-Path (Join-Path -Path $env:USERPROFILE -ChildPath ".claude\.credentials.json"))) {
                Write-ColoredOutput "Please log in to Claude Code first." "Yellow"
            }
        }
        "auto" {
            Write-Host "Auto summary feature is enabled. (Using Claude CLI)"
            Write-Host ""
            try {
                claude --version | Out-Null
                Write-ColoredOutput "Claude CLI is installed." "Green"
            } catch {
                Write-ColoredOutput "Please install Claude CLI." "Yellow"
            }
        }
        "advanced" {
            Write-Host "Advanced auto summary feature is enabled. (Using Gemini)"
            Write-Host ""
            try {
                gemini --version | Out-Null
                Write-ColoredOutput "Gemini CLI is installed." "Green"
            } catch {
                Write-ColoredOutput "Please install Gemini CLI." "Yellow"
                Write-Host "Setup: `$env:GEMINI_API_KEY = '<your-api-key>'"
            }
        }
    }
    
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Restart Claude Code"
    Write-Host "2. Create or update CLAUDE.md files"
    Write-Host ""
    Write-Host "Troubleshooting:"
    Write-Host "  $INSTALL_DIR\README.md"
}

# Hook type selection - Always use UserPromptSubmit
function Select-HookType {
    # Always return UserPromptSubmit
    return "UserPromptSubmit"
}

# Update hooks in Claude settings
function Update-Hooks {
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
    
    Write-Host "Updating hooks to use $UseHookType..."
    
    # Run install script with hook type parameter
    $installScript = Join-Path $SCRIPT_DIR "install.ps1"
    & powershell -ExecutionPolicy Bypass -File $installScript -HookType $UseHookType -Mode (Get-CurrentMode)
}

# Get current mode from config
function Get-CurrentMode {
    $configFile = Join-Path $INSTALL_BASE "claude-context.conf"
    if (Test-Path $configFile) {
        $content = Get-Content $configFile | Where-Object { $_ -match 'CLAUDE_CONTEXT_MODE="(.+)"' }
        if ($Matches) {
            return $Matches[1]
        }
    }
    return "basic"
}

# Main execution
function Main {
    Print-Header
    
    # Check installation status
    $errors = Test-Installation
    if ($errors.Count -gt 0) {
        Write-ColoredOutput "Installation status check found errors:" "Red"
        foreach ($error in $errors) {
            Write-Host "  - $error"
        }
        Write-Host ""
        Write-Host "Please run install.ps1 first to install Claude Context."
        exit 1
    }
    
    # If only changing hook type
    if ($HookType -and -not $Mode) {
        Update-Hooks $HookType
        Write-ColoredOutput "Hook type updated to: $HookType" "Green"
        return
    }
    
    # Select mode if needed
    $selectedMode = if ($Mode) { $Mode } else { Select-Mode }
    Write-Host ""
    Write-ColoredOutput "Selected mode: $selectedMode" "Blue"
    Write-Host ""
    
    # Always use UserPromptSubmit hook type
    $selectedHookType = "UserPromptSubmit"
    
    # Update configuration
    Update-Config $selectedMode
    New-Directories $selectedMode
    Update-Hooks $selectedHookType
    
    # Show completion message
    Show-Usage $selectedMode
}

# Run script
Main