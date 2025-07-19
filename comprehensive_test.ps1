# Claude Context Comprehensive Test Suite
# Tests all scripts in the project systematically

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Color functions
function Write-Success { param([string]$Message) Write-Host "  ✓ $Message" -ForegroundColor Green }
function Write-Failure { param([string]$Message) Write-Host "  ✗ $Message" -ForegroundColor Red }
function Write-Warning { param([string]$Message) Write-Host "  ⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param([string]$Message) Write-Host "  ℹ $Message" -ForegroundColor Cyan }
function Write-Header { param([string]$Title) Write-Host ""; Write-Host "=== $Title ===" -ForegroundColor Blue; Write-Host "" }
function Write-Section { param([string]$Title) Write-Host ""; Write-Host "$Title" -ForegroundColor Yellow }

# Test counters
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0
$script:WarningTests = 0

function Add-TestResult {
    param([string]$Status, [string]$Message)
    $script:TotalTests++
    switch ($Status) {
        "Pass" { Write-Success $Message; $script:PassedTests++ }
        "Fail" { Write-Failure $Message; $script:FailedTests++ }
        "Warning" { Write-Warning $Message; $script:WarningTests++ }
    }
}

# Find all script files
function Get-AllScripts {
    $scripts = @{
        "Bash" = @()
        "PowerShell" = @()
        "Other" = @()
    }
    
    # Find bash scripts
    $bashFiles = Get-ChildItem -Recurse -Include "*.sh" | Where-Object { $_.Name -notlike ".*" }
    foreach ($file in $bashFiles) {
        $scripts["Bash"] += $file.FullName.Replace($PWD.Path + "\", "")
    }
    
    # Find PowerShell scripts
    $psFiles = Get-ChildItem -Recurse -Include "*.ps1" | Where-Object { $_.Name -notlike ".*" -and $_.Name -notlike "test_*" -and $_.Name -notlike "comprehensive_test.ps1" }
    foreach ($file in $psFiles) {
        $scripts["PowerShell"] += $file.FullName.Replace($PWD.Path + "\", "")
    }
    
    return $scripts
}

# Test bash script syntax
function Test-BashSyntax {
    param([string]$ScriptPath)
    
    $GitBashPath = "C:\Program Files\Git\bin\bash.exe"
    if (-not (Test-Path $GitBashPath)) {
        Add-TestResult "Warning" "$ScriptPath - Git Bash not found"
        return
    }
    
    try {
        $result = & $GitBashPath -c "bash -n '$ScriptPath'" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Pass" "$ScriptPath syntax OK"
        } else {
            Add-TestResult "Fail" "$ScriptPath syntax error"
        }
    } catch {
        Add-TestResult "Fail" "$ScriptPath syntax check failed"
    }
}

# Test PowerShell script syntax
function Test-PowerShellSyntax {
    param([string]$ScriptPath)
    
    try {
        $content = Get-Content $ScriptPath -Raw -ErrorAction Stop
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Add-TestResult "Pass" "$ScriptPath syntax OK"
    } catch {
        Add-TestResult "Fail" "$ScriptPath syntax error: $($_.Exception.Message)"
    }
}

# Test file permissions and executability
function Test-FilePermissions {
    param([string]$ScriptPath)
    
    if (Test-Path $ScriptPath) {
        Add-TestResult "Pass" "$ScriptPath exists"
        
        # Check if file is readable
        try {
            $content = Get-Content $ScriptPath -TotalCount 1 -ErrorAction Stop
            Add-TestResult "Pass" "$ScriptPath readable"
        } catch {
            Add-TestResult "Fail" "$ScriptPath not readable"
        }
    } else {
        Add-TestResult "Fail" "$ScriptPath missing"
    }
}

# Test script dependencies
function Test-Dependencies {
    param([string]$ScriptPath)
    
    if (-not (Test-Path $ScriptPath)) { return }
    
    $content = Get-Content $ScriptPath -Raw
    
    # Check for common dependencies
    $dependencies = @{
        "jq" = "jq"
        "curl" = "curl"
        "git" = "git"
        "sha256sum" = "sha256sum"
    }
    
    foreach ($dep in $dependencies.Keys) {
        if ($content -match $dep) {
            try {
                $null = Get-Command $dependencies[$dep] -ErrorAction Stop
                Add-TestResult "Pass" "$ScriptPath dependency '$dep' available"
            } catch {
                Add-TestResult "Warning" "$ScriptPath dependency '$dep' not found"
            }
        }
    }
}

# Main test execution
Write-Header "Claude Context Comprehensive Test Suite"

# Get all scripts
$allScripts = Get-AllScripts

Write-Section "1. Script Discovery"
Write-Info "Found $($allScripts['Bash'].Count) Bash scripts"
Write-Info "Found $($allScripts['PowerShell'].Count) PowerShell scripts"

# Test 1: File existence and permissions
Write-Section "2. File Existence and Permissions"

foreach ($script in $allScripts['Bash']) {
    Test-FilePermissions $script
}

foreach ($script in $allScripts['PowerShell']) {
    Test-FilePermissions $script
}

# Test 2: Syntax checking
Write-Section "3. Syntax Checking"

Write-Host "Bash Scripts:" -ForegroundColor Cyan
foreach ($script in $allScripts['Bash']) {
    Test-BashSyntax $script
}

Write-Host "PowerShell Scripts:" -ForegroundColor Cyan
foreach ($script in $allScripts['PowerShell']) {
    Test-PowerShellSyntax $script
}

# Test 3: Dependency checking
Write-Section "4. Dependency Checking"

foreach ($script in $allScripts['Bash']) {
    Test-Dependencies $script
}

foreach ($script in $allScripts['PowerShell']) {
    Test-Dependencies $script
}

# Test 4: Core functionality tests
Write-Section "5. Core Functionality Tests"

# Test core injector
if (Test-Path "core\injector.sh") {
    $GitBashPath = "C:\Program Files\Git\bin\bash.exe"
    if (Test-Path $GitBashPath) {
        try {
            # Create test environment
            $TestHome = Join-Path $env:TEMP "claude_comprehensive_test_$(Get-Random)"
            $ClaudeHome = Join-Path $TestHome ".claude"
            New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
            "# Test Content for Comprehensive Test" | Out-File -FilePath (Join-Path $ClaudeHome "CLAUDE.md") -Encoding UTF8
            
            # Set environment variables
            $env:HOME = $TestHome
            $env:CLAUDE_CONTEXT_MODE = "basic"
            
            # Test injector
            $output = & $GitBashPath -c "cd '$PWD'; bash core/injector.sh" 2>$null
            if ($output -and $output -match "Test Content") {
                Add-TestResult "Pass" "Core injector functional test"
            } else {
                Add-TestResult "Fail" "Core injector functional test"
            }
            
            # Cleanup
            Remove-Item $TestHome -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item Env:HOME -ErrorAction SilentlyContinue
            Remove-Item Env:CLAUDE_CONTEXT_MODE -ErrorAction SilentlyContinue
            
        } catch {
            Add-TestResult "Fail" "Core injector test error: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "Warning" "Core injector test skipped - Git Bash not available"
    }
}

# Test core precompact
if (Test-Path "core\precompact.sh") {
    $GitBashPath = "C:\Program Files\Git\bin\bash.exe"
    if (Test-Path $GitBashPath) {
        try {
            $output = & $GitBashPath -c "cd '$PWD'; bash core/precompact.sh" 2>$null
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult "Pass" "Core precompact functional test"
            } else {
                Add-TestResult "Fail" "Core precompact functional test"
            }
        } catch {
            Add-TestResult "Fail" "Core precompact test error: $($_.Exception.Message)"
        }
    } else {
        Add-TestResult "Warning" "Core precompact test skipped - Git Bash not available"
    }
}

# Test 5: Integration tests
Write-Section "6. Integration Tests"

# Test main wrapper scripts
$mainScripts = @("claude_context_injector.sh", "claude_context_precompact.sh")
foreach ($script in $mainScripts) {
    if (Test-Path $script) {
        $GitBashPath = "C:\Program Files\Git\bin\bash.exe"
        if (Test-Path $GitBashPath) {
            try {
                $output = & $GitBashPath -c "cd '$PWD'; bash $script --help" 2>$null
                if ($LASTEXITCODE -eq 0 -or $output) {
                    Add-TestResult "Pass" "$script integration test"
                } else {
                    Add-TestResult "Warning" "$script integration test - no help output"
                }
            } catch {
                Add-TestResult "Warning" "$script integration test error"
            }
        }
    }
}

# Results summary
Write-Header "Test Results Summary"

Write-Host "Total Tests: $script:TotalTests"
Write-Host "Passed: " -NoNewline; Write-Host "$script:PassedTests" -ForegroundColor Green
Write-Host "Failed: " -NoNewline; Write-Host "$script:FailedTests" -ForegroundColor Red
Write-Host "Warnings: " -NoNewline; Write-Host "$script:WarningTests" -ForegroundColor Yellow

if ($script:TotalTests -gt 0) {
    $successRate = [math]::Round((($script:PassedTests + $script:WarningTests) / $script:TotalTests) * 100)
    $passRate = [math]::Round(($script:PassedTests / $script:TotalTests) * 100)
    Write-Host "Success Rate: " -NoNewline; Write-Host "$successRate%" -ForegroundColor Green
    Write-Host "Pass Rate: " -NoNewline; Write-Host "$passRate%" -ForegroundColor Green
}

Write-Host ""

if ($script:FailedTests -eq 0) {
    Write-Host "🎉 All critical tests passed!" -ForegroundColor Green
    if ($script:WarningTests -gt 0) {
        Write-Host "⚠️ Some warnings detected - check dependency requirements" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "❌ Some tests failed - review the results above" -ForegroundColor Red
    exit 1
}
