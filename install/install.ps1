# Claude Context Installation Script - Windows PowerShell
# Installs to ~/.claude/hooks/claude-context/ directory

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("PreToolUse", "UserPromptSubmit")]
    [string]$HookType = "PreToolUse",
    
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
    
    foreach ($dir in $dirs) {
        $null = New-Item -ItemType Directory -Path $dir -Force
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
    
    # Create Windows wrapper scripts
    $injectorWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_injector.ps1"
    $userPromptWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_user_prompt_injector.ps1"
    $precompactWrapperPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_precompact.ps1"
    
    # injector wrapper
    $injectorContent = @"
# Claude Context Injector Wrapper for Windows (Enhanced)
try {
    `$bashExe = Get-Command bash -ErrorAction Stop

    # Windows 경로를 Git Bash 호환 경로로 변환
    `$userProfile = `$env:USERPROFILE -replace '\\\\', '/' -replace '^([A-Z]):', '/`$1'
    `$scriptPath = "`$userProfile/.claude/hooks/claude-context/src/core/injector.sh"

    # 환경 변수 설정 (PowerShell -> Bash)
    `$env:CLAUDE_HOME = "`$env:USERPROFILE\.claude"
    `$env:HOME = `$env:USERPROFILE

    # Claude Hook 환경 변수들 수집
    `$envVars = @()
    if (`$env:INPUT_MESSAGE) { `$envVars += "INPUT_MESSAGE='`$(`$env:INPUT_MESSAGE -replace "'", "'\''")'" }
    if (`$env:CLAUDE_SESSION_ID) { `$envVars += "CLAUDE_SESSION_ID='`$(`$env:CLAUDE_SESSION_ID)'" }
    if (`$env:CLAUDE_CONTEXT_MODE) { `$envVars += "CLAUDE_CONTEXT_MODE='`$(`$env:CLAUDE_CONTEXT_MODE)'" }
    if (`$env:CLAUDE_ENABLE_CACHE) { `$envVars += "CLAUDE_ENABLE_CACHE='`$(`$env:CLAUDE_ENABLE_CACHE)'" }
    if (`$env:CLAUDE_INJECT_PROBABILITY) { `$envVars += "CLAUDE_INJECT_PROBABILITY='`$(`$env:CLAUDE_INJECT_PROBABILITY)'" }

    # 기본 환경 변수 추가
    `$envVars += "CLAUDE_HOME='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude'"
    `$envVars += "CLAUDE_HOOKS_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/hooks'"
    `$envVars += "CLAUDE_HISTORY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/history'"
    `$envVars += "CLAUDE_SUMMARY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/summaries'"
    `$envVars += "CLAUDE_CACHE_DIR='`$(`$env:LOCALAPPDATA -replace '\\\\', '/')/claude-context'"
    `$envVars += "CLAUDE_LOG_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/logs'"

    `$envString = `$envVars -join ' '

    # 인수 처리 (PowerShell args -> bash)
    `$bashArgs = if (`$args) {
        (`$args | ForEach-Object { "'`$(`$_ -replace "'", "'\''")'" }) -join ' '
    } else {
        ''
    }

    # bash 실행 (환경 변수와 함께)
    `$command = "`$envString '`$scriptPath' `$bashArgs"
    & bash -c `$command
} catch {
    Write-Error "bash not found. Please install Git for Windows."
    exit 1
}
"@
    
    # precompact wrapper
    $precompactContent = @"
# Claude Context PreCompact Wrapper for Windows (Enhanced)
try {
    `$bashExe = Get-Command bash -ErrorAction Stop

    # Windows 경로를 Git Bash 호환 경로로 변환
    `$userProfile = `$env:USERPROFILE -replace '\\\\', '/' -replace '^([A-Z]):', '/`$1'
    `$scriptPath = "`$userProfile/.claude/hooks/claude-context/src/core/precompact.sh"

    # 환경 변수 설정 (PowerShell -> Bash)
    `$env:CLAUDE_HOME = "`$env:USERPROFILE\.claude"
    `$env:HOME = `$env:USERPROFILE

    # Claude Hook 환경 변수들 수집
    `$envVars = @()
    if (`$env:INPUT_MESSAGE) { `$envVars += "INPUT_MESSAGE='`$(`$env:INPUT_MESSAGE -replace "'", "'\''")'" }
    if (`$env:CLAUDE_SESSION_ID) { `$envVars += "CLAUDE_SESSION_ID='`$(`$env:CLAUDE_SESSION_ID)'" }
    if (`$env:CLAUDE_CONTEXT_MODE) { `$envVars += "CLAUDE_CONTEXT_MODE='`$(`$env:CLAUDE_CONTEXT_MODE)'" }
    if (`$env:CLAUDE_ENABLE_CACHE) { `$envVars += "CLAUDE_ENABLE_CACHE='`$(`$env:CLAUDE_ENABLE_CACHE)'" }
    if (`$env:CLAUDE_INJECT_PROBABILITY) { `$envVars += "CLAUDE_INJECT_PROBABILITY='`$(`$env:CLAUDE_INJECT_PROBABILITY)'" }

    # 기본 환경 변수 추가
    `$envVars += "CLAUDE_HOME='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude'"
    `$envVars += "CLAUDE_HOOKS_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/hooks'"
    `$envVars += "CLAUDE_HISTORY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/history'"
    `$envVars += "CLAUDE_SUMMARY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/summaries'"
    `$envVars += "CLAUDE_CACHE_DIR='`$(`$env:LOCALAPPDATA -replace '\\\\', '/')/claude-context'"
    `$envVars += "CLAUDE_LOG_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/logs'"

    `$envString = `$envVars -join ' '

    # 인수 처리 (PowerShell args -> bash)
    `$bashArgs = if (`$args) {
        (`$args | ForEach-Object { "'`$(`$_ -replace "'", "'\''")'" }) -join ' '
    } else {
        ''
    }

    # bash 실행 (환경 변수와 함께)
    `$command = "`$envString '`$scriptPath' `$bashArgs"
    & bash -c `$command
} catch {
    Write-Error "bash not found. Please install Git for Windows."
    exit 1
}
"@
    
    # user prompt wrapper
    $userPromptContent = @"
# Claude Context User Prompt Injector Wrapper for Windows (Enhanced)
try {
    `$bashExe = Get-Command bash -ErrorAction Stop

    # Windows 경로를 Git Bash 호환 경로로 변환
    `$userProfile = `$env:USERPROFILE -replace '\\\\', '/' -replace '^([A-Z]):', '/`$1'
    `$scriptPath = "`$userProfile/.claude/hooks/claude-context/src/core/user_prompt_injector.sh"

    # 환경 변수 설정 (PowerShell -> Bash)
    `$env:CLAUDE_HOME = "`$env:USERPROFILE\.claude"
    `$env:HOME = `$env:USERPROFILE

    # Claude Hook 환경 변수들 수집
    `$envVars = @()
    if (`$env:INPUT_MESSAGE) { `$envVars += "INPUT_MESSAGE='`$(`$env:INPUT_MESSAGE -replace "'", "'\''")'" }
    if (`$env:CLAUDE_SESSION_ID) { `$envVars += "CLAUDE_SESSION_ID='`$(`$env:CLAUDE_SESSION_ID)'" }
    if (`$env:CLAUDE_CONTEXT_MODE) { `$envVars += "CLAUDE_CONTEXT_MODE='`$(`$env:CLAUDE_CONTEXT_MODE)'" }
    if (`$env:CLAUDE_ENABLE_CACHE) { `$envVars += "CLAUDE_ENABLE_CACHE='`$(`$env:CLAUDE_ENABLE_CACHE)'" }
    if (`$env:CLAUDE_INJECT_PROBABILITY) { `$envVars += "CLAUDE_INJECT_PROBABILITY='`$(`$env:CLAUDE_INJECT_PROBABILITY)'" }

    # 기본 환경 변수 추가
    `$envVars += "CLAUDE_HOME='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude'"
    `$envVars += "CLAUDE_HOOKS_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/hooks'"
    `$envVars += "CLAUDE_HISTORY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/history'"
    `$envVars += "CLAUDE_SUMMARY_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/summaries'"
    `$envVars += "CLAUDE_CACHE_DIR='`$(`$env:LOCALAPPDATA -replace '\\\\', '/')/claude-context'"
    `$envVars += "CLAUDE_LOG_DIR='`$(`$env:USERPROFILE -replace '\\\\', '/')/.claude/logs'"

    `$envString = `$envVars -join ' '

    # 인수 처리 (PowerShell args -> bash)
    `$bashArgs = if (`$args) {
        (`$args | ForEach-Object { "'`$(`$_ -replace "'", "'\''")'" }) -join ' '
    } else {
        ''
    }

    # bash 실행 (환경 변수와 함께)
    `$command = "`$envString '`$scriptPath' `$bashArgs"
    & bash -c `$command
} catch {
    Write-Error "bash not found. Please install Git for Windows."
    exit 1
}
"@
    
    Set-Content -Path $injectorWrapperPath -Value $injectorContent -Encoding UTF8
    Set-Content -Path $userPromptWrapperPath -Value $userPromptContent -Encoding UTF8
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
    $configShPath = Join-Path -Path $INSTALL_DIR -ChildPath "config.sh"
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

    # Create config.ps1 for PowerShell environment
    $configPs1Path = Join-Path -Path $INSTALL_DIR -ChildPath "config.ps1"
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
    Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
    
    # Update JSON configuration
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        $injectorPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_injector.ps1"
        $userPromptPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_user_prompt_injector.ps1"
        $precompactPath = Join-Path -Path $INSTALL_BASE -ChildPath "claude_context_precompact.ps1"
        
        # Create hooks based on HookType
        $hooksConfig = @{
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
        }
        
        if ($UseHookType -eq "UserPromptSubmit") {
            $hooksConfig["UserPromptSubmit"] = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command"
                            command = "powershell -ExecutionPolicy Bypass -File `"$userPromptPath`""
                            timeout = 5000
                        }
                    )
                }
            )
        } else {
            # Default to PreToolUse
            $hooksConfig["PreToolUse"] = @(
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
        }
        
        $config | Add-Member -NotePropertyName "hooks" -NotePropertyValue $hooksConfig -Force
        
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
    Install-Files -Mode $selectedMode
    New-Config $selectedMode
    New-Directories $selectedMode
    Update-ClaudeConfig -UseHookType $HookType
    
    # Show completion message
    Show-Usage $selectedMode
}

# Run script
Main