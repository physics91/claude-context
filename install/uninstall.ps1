# Claude Context Uninstall Script (Windows PowerShell)

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
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
$INSTALL_BASE = Join-Path $env:USERPROFILE ".claude\hooks"
$INSTALL_DIR = Join-Path $INSTALL_BASE "claude-context"
$CONFIG_FILE = Join-Path $INSTALL_BASE "claude-context.conf"

# Print header
function Print-Header {
    Write-ColoredOutput "===============================================" "Red"
    Write-ColoredOutput "     Claude Context Uninstall               " "Red"
    Write-ColoredOutput "===============================================" "Red"
    Write-Host ""
}

# Confirm uninstallation
function Confirm-Uninstall {
    if ($Force) {
        return $true
    }
    
    Write-ColoredOutput "The following items will be removed:" "Yellow"
    Write-Host ""
    
    if (Test-Path $INSTALL_DIR) {
        Write-Host "  - Installation directory: $INSTALL_DIR"
    }
    
    if (Test-Path $CONFIG_FILE) {
        Write-Host "  - Configuration file: $CONFIG_FILE"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_context_injector.ps1")) {
        Write-Host "  - Injector script: $(Join-Path $INSTALL_BASE 'claude_context_injector.ps1')"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_user_prompt_injector.ps1")) {
        Write-Host "  - User Prompt Injector script: $(Join-Path $INSTALL_BASE 'claude_user_prompt_injector.ps1')"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_context_precompact.ps1")) {
        Write-Host "  - PreCompact script: $(Join-Path $INSTALL_BASE 'claude_context_precompact.ps1')"
    }
    
    Write-Host "  - Remove hooks from Claude Code settings"
    Write-Host ""
    
    Write-ColoredOutput "Conversation history and summary files will be preserved." "Yellow"
    Write-Host "   (To remove: Remove-Item -Recurse '$env:USERPROFILE\.claude\history')"
    Write-Host ""
    
    $confirm = Read-Host "Do you want to continue? [y/N]"
    return $confirm -match "^[Yy]$"
}

# Remove Claude hooks
function Remove-ClaudeHooks {
    $claudeConfig = Join-Path $env:USERPROFILE ".claude\settings.json"
    
    if (-not (Test-Path $claudeConfig)) {
        Write-ColoredOutput "Claude settings file not found." "Yellow"
        return
    }
    
    Write-Host "Removing hooks from Claude settings..."
    
    # Create backup
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
    
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        # Remove hooks property - safe processing
        if ($config.PSObject.Properties['hooks']) {
            $config.PSObject.Properties.Remove('hooks')
            # Convert to JSON with proper formatting and no BOM
            $jsonContent = $config | ConvertTo-Json -Depth 10
            # Remove BOM and save with UTF8 without BOM
            [System.IO.File]::WriteAllText($claudeConfig, $jsonContent, [System.Text.UTF8Encoding]::new($false))
            Write-ColoredOutput "Hooks removal from Claude settings completed" "Green"
        } else {
            Write-ColoredOutput "Hooks settings are already removed." "Yellow"
        }
    }
    catch {
        Write-ColoredOutput "Error updating Claude settings: $_" "Red"
        Write-Host "You may need to manually remove hooks settings."
    }
}

# Remove files and directories
function Remove-Files {
    $removedItems = @()
    
    # Remove installation directory
    if (Test-Path $INSTALL_DIR) {
        try {
            Remove-Item -Recurse -Force $INSTALL_DIR
            $removedItems += "Installation directory"
            Write-ColoredOutput "Installation directory removal completed" "Green"
        }
        catch {
            Write-ColoredOutput "Installation directory removal failed: $_" "Red"
        }
    }
    
    # Remove configuration file
    if (Test-Path $CONFIG_FILE) {
        try {
            Remove-Item -Force $CONFIG_FILE
            $removedItems += "Configuration file"
            Write-ColoredOutput "Configuration file removal completed" "Green"
        }
        catch {
            Write-ColoredOutput "Configuration file removal failed: $_" "Red"
        }
    }
    
    # Remove wrapper scripts
    $wrapperScripts = @(
        (Join-Path $INSTALL_BASE "claude_context_injector.ps1"),
        (Join-Path $INSTALL_BASE "claude_user_prompt_injector.ps1"),
        (Join-Path $INSTALL_BASE "claude_context_precompact.ps1")
    )
    
    foreach ($script in $wrapperScripts) {
        if (Test-Path $script) {
            try {
                Remove-Item -Force $script
                $removedItems += "Wrapper script"
                Write-ColoredOutput "$(Split-Path -Leaf $script) removal completed" "Green"
            }
            catch {
                Write-ColoredOutput "$(Split-Path -Leaf $script) removal failed: $_" "Red"
            }
        }
    }
    
    return $removedItems
}

# Check cleanup
function Test-Cleanup {
    $remaining = @()
    
    if (Test-Path $INSTALL_DIR) {
        $remaining += "Installation directory"
    }
    
    if (Test-Path $CONFIG_FILE) {
        $remaining += "Configuration file"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_context_injector.ps1")) {
        $remaining += "Injector script"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_user_prompt_injector.ps1")) {
        $remaining += "User Prompt Injector script"
    }
    
    if (Test-Path (Join-Path $INSTALL_BASE "claude_context_precompact.ps1")) {
        $remaining += "PreCompact script"
    }
    
    # Check Claude settings
    $claudeConfig = Join-Path $env:USERPROFILE ".claude\settings.json"
    if (Test-Path $claudeConfig) {
        try {
            $config = Get-Content $claudeConfig | ConvertFrom-Json
            if ($config.PSObject.Properties['hooks']) {
                $remaining += "Claude settings hooks"
            }
        }
        catch {
            # Ignore JSON parsing failures
        }
    }
    
    return $remaining
}

# Show completion message
function Show-CompletionMessage {
    param([array]$RemovedItems, [array]$RemainingItems)
    
    Write-Host ""
    if ($RemovedItems.Count -gt 0) {
        Write-ColoredOutput "The following items have been removed:" "Green"
        foreach ($item in $RemovedItems) {
            Write-Host "  ✓ $item"
        }
        Write-Host ""
    }
    
    if ($RemainingItems.Count -gt 0) {
        Write-ColoredOutput "The following items remain:" "Yellow"
        foreach ($item in $RemainingItems) {
            Write-Host "  - $item"
        }
        Write-Host ""
        Write-Host "Manual removal may be required."
        Write-Host ""
    }
    
    Write-ColoredOutput "Conversation history and summary files:" "Blue"
    Write-Host "  - Location: $env:USERPROFILE\.claude\history"
    Write-Host "  - Location: $env:USERPROFILE\.claude\summaries"
    Write-Host "  - Manual removal: Remove-Item -Recurse '$env:USERPROFILE\.claude\history'"
    Write-Host ""
    
    Write-ColoredOutput "Next steps:" "Blue"
    Write-Host "1. Restart Claude Code"
    Write-Host "2. Check Claude Code settings if needed"
    Write-Host ""
    
    if ($RemainingItems.Count -eq 0) {
        Write-ColoredOutput "Claude Context uninstallation completed!" "Green"
    } else {
        Write-ColoredOutput "Some items require manual removal." "Yellow"
    }
}

# Main execution
function Main {
    Print-Header
    
    # Check installation
    if (-not (Test-Path $INSTALL_DIR) -and -not (Test-Path $CONFIG_FILE)) {
        Write-ColoredOutput "Claude Context is not installed." "Yellow"
        exit 0
    }
    
    # Confirm uninstallation
    if (-not (Confirm-Uninstall)) {
        Write-ColoredOutput "Uninstallation cancelled." "Yellow"
        exit 0
    }
    
    Write-Host ""
    Write-Host "Starting uninstallation..."
    Write-Host ""
    
    # Remove Claude hooks
    Remove-ClaudeHooks
    
    # Remove files
    $removedItems = Remove-Files
    
    # Check cleanup
    $remainingItems = Test-Cleanup
    
    # Show completion message
    Show-CompletionMessage $removedItems $remainingItems
}

# Run script
Main