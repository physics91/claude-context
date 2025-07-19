# Claude Context One-Line Installation Script (Windows PowerShell)
# 
# Secure recommended usage (2-step):
# 1. Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "one-line-install.ps1"
# 2. Get-Content .\one-line-install.ps1 # Review content
# 3. PowerShell -ExecutionPolicy Bypass -File .\one-line-install.ps1
#
# Quick install (use with caution): Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1").Content

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null
)

# Stop on errors
$ErrorActionPreference = "Stop"

# Configuration
$GITHUB_USER = "physics91"
$GITHUB_REPO = "claude-context"
$GITHUB_BRANCH = "main"

# Color output function
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColoredOutput "===============================================" "Blue"
Write-ColoredOutput "     Claude Context v1.0.0 Installation     " "Blue"
Write-ColoredOutput "              (Windows)                     " "Blue"
Write-ColoredOutput "===============================================" "Blue"
Write-Host ""

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-ColoredOutput "Error: PowerShell 5.0 or higher is required." "Red"
    Write-Host "Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Create temporary directory - performance optimization
$tempDir = Join-Path $env:TEMP "claude-context-install-$(Get-Random)"
$null = New-Item -ItemType Directory -Path $tempDir -Force

try {
    Set-Location $tempDir
    
    # Check Git installation
    try {
        git --version | Out-Null
    } catch {
        Write-ColoredOutput "Error: Git is not installed." "Red"
        Write-Host "Please install Git first:"
        Write-Host "  - Git for Windows: https://git-scm.com/download/win"
        Write-Host "  - Or: winget install Git.Git"
        exit 1
    }
    
    # Clone repository
    Write-Host "Downloading repository..."
    try {
        git clone --depth 1 --branch $GITHUB_BRANCH "https://github.com/$GITHUB_USER/$GITHUB_REPO.git" 2>$null | Out-Null
        Write-ColoredOutput "Download completed" "Green"
    } catch {
        Write-ColoredOutput "Error: Repository download failed." "Red"
        Write-Host "Please check your network connection and try again."
        exit 1
    }
    
    # Run installation script
    Set-Location $GITHUB_REPO
    
    $installScript = $null
    if (Test-Path "install.ps1") {
        $installScript = ".\install.ps1"
    } elseif (Test-Path "install\install.ps1") {
        $installScript = ".\install\install.ps1"
    } else {
        Write-ColoredOutput "Error: PowerShell installation script not found." "Red"
        Write-Host "Please use Git Bash to run the bash script instead."
        exit 1
    }
    
    Write-Host ""
    if ($Mode) {
        & $installScript -Mode $Mode
    } else {
        & $installScript
    }
    
} finally {
    # Clean up temporary directory
    try {
        Set-Location $env:USERPROFILE
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup failures
    }
}

Write-Host ""
Write-ColoredOutput "Claude Context has been successfully installed!" "Green"
Write-Host ""
Write-ColoredOutput "Next steps:" "Blue"
Write-Host "1. Create $env:USERPROFILE\.claude\CLAUDE.md file to set global context"
Write-Host "   Example:"
Write-Host "   New-Item -ItemType File -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Force"
Write-Host "   Add-Content -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Value '# Basic Rules'"
Write-Host "   Add-Content -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Value '- Please communicate in Korean'"
Write-Host ""
Write-Host "2. Restart Claude Code"
Write-Host ""
Write-ColoredOutput "Advanced features setup:" "Blue"
Write-Host "PowerShell -ExecutionPolicy Bypass -File '$env:USERPROFILE\.claude\hooks\claude-context\install\configure_hooks.ps1'"
Write-Host ""
Write-Host "Documentation: https://github.com/$GITHUB_USER/$GITHUB_REPO"
Write-Host "Issues: https://github.com/$GITHUB_USER/$GITHUB_REPO/issues"