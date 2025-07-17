# Claude Context Installation Script - Windows PowerShell
# Installs to ~/.claude/hooks/claude-context/ directory

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null,
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall = $false
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

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$INSTALL_BASE = Join-Path $env:USERPROFILE ".claude\hooks"
$INSTALL_DIR = Join-Path $INSTALL_BASE "claude-context"
$CONFIG_FILE = Join-Path $INSTALL_BASE "claude-context.conf"

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
    Write-Host "Installing files..."
    
    # Create claude-context directories
    $dirs = @(
        (Join-Path $INSTALL_DIR "src\core"),
        (Join-Path $INSTALL_DIR "src\monitor"), 
        (Join-Path $INSTALL_DIR "src\utils"),
        (Join-Path $INSTALL_DIR "tests"),
        (Join-Path $INSTALL_DIR "docs"),
        (Join-Path $INSTALL_DIR "examples"),
        (Join-Path $INSTALL_DIR "config")
    )
    
    foreach ($dir in $dirs) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    
    # Check required directories
    $requiredDirs = @("core", "monitor", "utils")
    $missingCount = 0
    
    foreach ($dir in $requiredDirs) {
        $sourcePath = Join-Path $PROJECT_ROOT $dir
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
    
    # Copy files
    Copy-Item -Recurse (Join-Path $PROJECT_ROOT "core") (Join-Path $INSTALL_DIR "src") -Force
    Copy-Item -Recurse (Join-Path $PROJECT_ROOT "monitor") (Join-Path $INSTALL_DIR "src") -Force
    Copy-Item -Recurse (Join-Path $PROJECT_ROOT "utils") (Join-Path $INSTALL_DIR "src") -Force
    
    # Copy optional directories
    if (Test-Path (Join-Path $PROJECT_ROOT "tests")) {
        Copy-Item -Recurse (Join-Path $PROJECT_ROOT "tests") $INSTALL_DIR -Force
    }
    if (Test-Path (Join-Path $PROJECT_ROOT "docs")) {
        Copy-Item -Recurse (Join-Path $PROJECT_ROOT "docs") $INSTALL_DIR -Force
    }
    
    # Copy documentation files
    if (Test-Path (Join-Path $PROJECT_ROOT "README.md")) {
        Copy-Item (Join-Path $PROJECT_ROOT "README.md") $INSTALL_DIR -Force
    }
    if (Test-Path (Join-Path $PROJECT_ROOT "config.sh")) {
        Copy-Item (Join-Path $PROJECT_ROOT "config.sh") $INSTALL_DIR -Force
    }
    
    # Create Windows wrapper scripts
    $injectorWrapperPath = Join-Path $INSTALL_BASE "claude_context_injector.ps1"
    $precompactWrapperPath = Join-Path $INSTALL_BASE "claude_context_precompact.ps1"
    
    # injector wrapper
    $injectorContent = @"
# Claude Context Injector Wrapper for Windows
try {
    `$bashExe = Get-Command bash -ErrorAction Stop
    `$scriptPath = "`$env:USERPROFILE/.claude/hooks/claude-context/src/core/injector.sh"
    & bash -c "`$scriptPath `$args"
} catch {
    Write-Error "bash not found. Please install Git for Windows."
    exit 1
}
"@
    
    # precompact wrapper
    $precompactContent = @"
# Claude Context PreCompact Wrapper for Windows
try {
    `$bashExe = Get-Command bash -ErrorAction Stop
    `$scriptPath = "`$env:USERPROFILE/.claude/hooks/claude-context/src/core/precompact.sh"
    & bash -c "`$scriptPath `$args"
} catch {
    Write-Error "bash not found. Please install Git for Windows."
    exit 1
}
"@
    
    Set-Content -Path $injectorWrapperPath -Value $injectorContent -Encoding UTF8
    Set-Content -Path $precompactWrapperPath -Value $precompactContent -Encoding UTF8
    
    Write-ColoredOutput "File installation completed" "Green"
}

# Create configuration
function New-Config {
    param([string]$SelectedMode)
    
    Write-Host "Creating configuration files..."
    
    # Create claude-context.conf
    $configContent = @"
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$($INSTALL_DIR.Replace('\', '/'))"
CLAUDE_CONTEXT_MODE="$SelectedMode"
"@
    Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
    
    # Create config.sh
    $configShPath = Join-Path $INSTALL_DIR "config.sh"
    $configShContent = @"
#!/usr/bin/env bash
# Claude Context Configuration - Windows Compatible

CLAUDE_CONTEXT_MODE="$SelectedMode"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_INJECT_PROBABILITY="1.0"
CLAUDE_HOME="`${USERPROFILE}/.claude"
CLAUDE_HOOKS_DIR="`${USERPROFILE}/.claude/hooks"
CLAUDE_HISTORY_DIR="`${CLAUDE_HOME}/history"
CLAUDE_SUMMARY_DIR="`${CLAUDE_HOME}/summaries"
CLAUDE_CACHE_DIR="`${LOCALAPPDATA}/claude-context"
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
    
    Write-ColoredOutput "Configuration files created" "Green"
}

# Update Claude configuration
function Update-ClaudeConfig {
    $claudeConfig = Join-Path $env:USERPROFILE ".claude\settings.json"
    
    if (-not (Test-Path $claudeConfig)) {
        Write-ColoredOutput "Claude settings file not found." "Yellow"
        Write-Host "Please run Claude Code once and try again."
        return
    }
    
    Write-Host "Updating Claude configuration..."
    
    # Create backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
    
    # Update JSON configuration
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        $injectorPath = Join-Path $INSTALL_BASE "claude_context_injector.ps1"
        $precompactPath = Join-Path $INSTALL_BASE "claude_context_precompact.ps1"
        
        $config | Add-Member -NotePropertyName "hooks" -NotePropertyValue @{
            PreToolUse = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command"
                            command = "powershell -ExecutionPolicy Bypass -File `"$injectorPath`""
                            timeout = 30000
                        }
                    )
                }
            )
            PreCompact = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command" 
                            command = "powershell -ExecutionPolicy Bypass -File `"$precompactPath`""
                            timeout = 1000
                        }
                    )
                }
            )
        } -Force
        
        # Convert to JSON with proper formatting and no BOM
        $jsonContent = $config | ConvertTo-Json -Depth 10
        # Remove BOM and save with UTF8 without BOM
        [System.IO.File]::WriteAllText($claudeConfig, $jsonContent, [System.Text.UTF8Encoding]::new($false))
        Write-ColoredOutput "Claude configuration updated" "Green"
    }
    catch {
        Write-ColoredOutput "Error updating Claude configuration: $_" "Red"
    }
}

# Create directories
function New-Directories {
    param([string]$SelectedMode)
    
    # Basic directories
    $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude") -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "claude-context") -Force
    
    # History/OAuth/Auto/Advanced mode directories
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\history") -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\summaries") -Force
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
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "1. Create CLAUDE.md files:"
    Write-Host "   - Global: $env:USERPROFILE\.claude\CLAUDE.md"
    Write-Host "   - Project-specific: <project-root>\CLAUDE.md"
    Write-Host ""
    Write-Host "2. Restart Claude Code"
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
    Install-Files
    New-Config $selectedMode
    New-Directories $selectedMode
    Update-ClaudeConfig
    
    # Show completion message
    Show-Usage $selectedMode
}

# Run script
Main