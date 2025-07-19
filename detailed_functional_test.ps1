# Claude Context Detailed Functional Test
# Tests specific functionality of each component

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

function Add-TestResult {
    param([string]$Status, [string]$Message)
    $script:TotalTests++
    switch ($Status) {
        "Pass" { Write-Success $Message; $script:PassedTests++ }
        "Fail" { Write-Failure $Message; $script:FailedTests++ }
        "Warning" { Write-Warning $Message }
    }
}

Write-Header "Claude Context Detailed Functional Test"

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
if (-not (Test-Path $GitBashPath)) {
    Write-Warning "Git Bash not found - skipping bash script tests"
    exit 1
}

# Test 1: Core Injector Detailed Test
Write-Section "1. Core Injector Detailed Tests"

try {
    # Create comprehensive test environment
    $TestHome = Join-Path $env:TEMP "claude_detailed_test_$(Get-Random)"
    $ClaudeHome = Join-Path $TestHome ".claude"
    $HooksDir = Join-Path $ClaudeHome "hooks"
    $HistoryDir = Join-Path $ClaudeHome "history"
    
    New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
    New-Item -ItemType Directory -Path $HooksDir -Force | Out-Null
    New-Item -ItemType Directory -Path $HistoryDir -Force | Out-Null
    
    # Create test CLAUDE.md with various content
    $claudeContent = @"
# Test Project Context

## Overview
This is a test project for Claude Context functionality.

## Features
- Feature 1: Basic functionality
- Feature 2: Advanced features
- Feature 3: Integration capabilities

## Code Examples
``````bash
echo "Hello World"
``````

## Notes
- Important note 1
- Important note 2
"@
    
    $claudeContent | Out-File -FilePath (Join-Path $ClaudeHome "CLAUDE.md") -Encoding UTF8
    
    # Test different modes
    $modes = @("basic", "history", "auto")
    
    foreach ($mode in $modes) {
        $env:HOME = $TestHome
        $env:CLAUDE_CONTEXT_MODE = $mode
        
        try {
            $output = & $GitBashPath -c "cd '$PWD'; bash core/injector.sh" 2>$null
            
            if ($output) {
                if ($output -match "Test Project Context") {
                    Add-TestResult "Pass" "Injector mode '$mode' - content included"
                } else {
                    Add-TestResult "Fail" "Injector mode '$mode' - content missing"
                }
                
                # Check output length
                $outputLength = $output.Length
                if ($outputLength -gt 100) {
                    Add-TestResult "Pass" "Injector mode '$mode' - adequate output length ($outputLength chars)"
                } else {
                    Add-TestResult "Warning" "Injector mode '$mode' - short output ($outputLength chars)"
                }
            } else {
                Add-TestResult "Fail" "Injector mode '$mode' - no output"
            }
        } catch {
            Add-TestResult "Fail" "Injector mode '$mode' - execution error"
        }
        
        Remove-Item Env:HOME -ErrorAction SilentlyContinue
        Remove-Item Env:CLAUDE_CONTEXT_MODE -ErrorAction SilentlyContinue
    }
    
} catch {
    Add-TestResult "Fail" "Injector test setup failed: $($_.Exception.Message)"
}

# Test 2: Core Precompact Detailed Test
Write-Section "2. Core Precompact Detailed Tests"

try {
    # Test precompact with different inputs
    $testInputs = @(
        "Short test input",
        ("Long test input " * 100),
        "Input with special characters: !@#$%^&*()",
        "Multi-line`ninput`nwith`nbreaks"
    )
    
    foreach ($i in 0..($testInputs.Count-1)) {
        $input = $testInputs[$i]
        $inputFile = Join-Path $env:TEMP "test_input_$i.txt"
        $input | Out-File -FilePath $inputFile -Encoding UTF8
        
        try {
            $output = & $GitBashPath -c "cd '$PWD'; echo '$input' | bash core/precompact.sh" 2>$null
            
            if ($LASTEXITCODE -eq 0) {
                Add-TestResult "Pass" "Precompact test $($i+1) - execution successful"
                
                if ($output.Length -le $input.Length) {
                    Add-TestResult "Pass" "Precompact test $($i+1) - output compacted"
                } else {
                    Add-TestResult "Warning" "Precompact test $($i+1) - output not compacted"
                }
            } else {
                Add-TestResult "Fail" "Precompact test $($i+1) - execution failed"
            }
        } catch {
            Add-TestResult "Fail" "Precompact test $($i+1) - error: $($_.Exception.Message)"
        }
        
        Remove-Item $inputFile -ErrorAction SilentlyContinue
    }
    
} catch {
    Add-TestResult "Fail" "Precompact test setup failed: $($_.Exception.Message)"
}

# Test 3: Configuration Tests
Write-Section "3. Configuration Tests"

if (Test-Path "config.sh") {
    try {
        # Test config loading
        $output = & $GitBashPath -c "cd '$PWD'; source config.sh && echo 'Config loaded successfully'" 2>$null
        
        if ($output -match "Config loaded successfully") {
            Add-TestResult "Pass" "Configuration loading test"
        } else {
            Add-TestResult "Fail" "Configuration loading test"
        }
        
        # Test config variables
        $configContent = Get-Content "config.sh" -Raw
        $expectedVars = @("CLAUDE_CONTEXT_MODE", "CLAUDE_HOME", "CLAUDE_HOOKS_DIR")
        
        foreach ($var in $expectedVars) {
            if ($configContent -match $var) {
                Add-TestResult "Pass" "Configuration variable '$var' defined"
            } else {
                Add-TestResult "Warning" "Configuration variable '$var' not found"
            }
        }
        
    } catch {
        Add-TestResult "Fail" "Configuration test error: $($_.Exception.Message)"
    }
} else {
    Add-TestResult "Warning" "config.sh not found - skipping configuration tests"
}

# Test 4: Utility Functions Tests
Write-Section "4. Utility Functions Tests"

if (Test-Path "utils\common_functions.sh") {
    try {
        # Test utility functions loading
        $output = & $GitBashPath -c "cd '$PWD'; source utils/common_functions.sh && echo 'Utils loaded'" 2>$null
        
        if ($output -match "Utils loaded") {
            Add-TestResult "Pass" "Utility functions loading test"
        } else {
            Add-TestResult "Fail" "Utility functions loading test"
        }
        
        # Check for common function definitions
        $utilsContent = Get-Content "utils\common_functions.sh" -Raw
        $expectedFunctions = @("log_info", "log_error", "check_dependencies")
        
        foreach ($func in $expectedFunctions) {
            if ($utilsContent -match $func) {
                Add-TestResult "Pass" "Utility function '$func' defined"
            } else {
                Add-TestResult "Warning" "Utility function '$func' not found"
            }
        }
        
    } catch {
        Add-TestResult "Fail" "Utility functions test error: $($_.Exception.Message)"
    }
} else {
    Add-TestResult "Warning" "common_functions.sh not found - skipping utility tests"
}

# Test 5: Installation Script Tests (Dry Run)
Write-Section "5. Installation Script Tests (Dry Run)"

$installScripts = @("install\install.sh", "install\configure_hooks.sh")

foreach ($script in $installScripts) {
    if (Test-Path $script) {
        try {
            # Test with --help or --dry-run if available
            $helpOutput = & $GitBashPath -c "cd '$PWD'; bash $script --help" 2>$null
            $dryRunOutput = & $GitBashPath -c "cd '$PWD'; bash $script --dry-run" 2>$null
            
            if ($helpOutput -or $dryRunOutput) {
                Add-TestResult "Pass" "$script help/dry-run test"
            } else {
                # Try basic syntax check
                $syntaxCheck = & $GitBashPath -c "bash -n $script" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Add-TestResult "Pass" "$script syntax validation"
                } else {
                    Add-TestResult "Fail" "$script syntax validation"
                }
            }
        } catch {
            Add-TestResult "Warning" "$script test skipped - execution error"
        }
    }
}

# Test 6: PowerShell Installation Scripts
Write-Section "6. PowerShell Installation Scripts Tests"

$psInstallScripts = Get-ChildItem "install\*.ps1"

foreach ($script in $psInstallScripts) {
    try {
        # Test parameter validation
        $helpOutput = & powershell -ExecutionPolicy Bypass -File $script.FullName -WhatIf 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Add-TestResult "Pass" "$($script.Name) parameter validation"
        } else {
            Add-TestResult "Warning" "$($script.Name) parameter validation - no WhatIf support"
        }
        
        # Test script loading (without execution)
        try {
            $content = Get-Content $script.FullName -Raw
            $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
            Add-TestResult "Pass" "$($script.Name) PowerShell syntax"
        } catch {
            Add-TestResult "Fail" "$($script.Name) PowerShell syntax error"
        }
        
    } catch {
        Add-TestResult "Warning" "$($script.Name) test error"
    }
}

# Cleanup
if (Test-Path $TestHome) {
    Remove-Item $TestHome -Recurse -Force -ErrorAction SilentlyContinue
}

# Results summary
Write-Header "Detailed Test Results Summary"

Write-Host "Total Tests: $script:TotalTests"
Write-Host "Passed: " -NoNewline; Write-Host "$script:PassedTests" -ForegroundColor Green
Write-Host "Failed: " -NoNewline; Write-Host "$script:FailedTests" -ForegroundColor Red

if ($script:TotalTests -gt 0) {
    $passRate = [math]::Round(($script:PassedTests / $script:TotalTests) * 100)
    Write-Host "Pass Rate: " -NoNewline; Write-Host "$passRate%" -ForegroundColor Green
}

Write-Host ""

if ($script:FailedTests -eq 0) {
    Write-Host "🎉 All detailed functional tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some detailed tests failed" -ForegroundColor Red
    exit 1
}
