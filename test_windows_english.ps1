# Claude Context Windows Test Script
# PowerShell version with bash-like output formatting

# Color functions for consistent output
function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Blue
    Write-Host ""
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "$Title" -ForegroundColor Yellow
}

# Test counters
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

function Test-FileExists {
    param([string]$FilePath, [string]$Description)
    
    $script:TotalTests++
    
    if (Test-Path $FilePath) {
        Write-Success "$Description exists"
        $script:PassedTests++
    } else {
        Write-Failure "$Description missing"
        $script:FailedTests++
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath, [string]$Description)
    
    $script:TotalTests++
    
    if (-not (Test-Path $FilePath)) {
        Write-Failure "$Description - file not found"
        $script:FailedTests++
        return
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Success "$Description syntax OK"
        $script:PassedTests++
    } catch {
        Write-Failure "$Description syntax error"
        $script:FailedTests++
    }
}

# Main test execution
Write-Header "Claude Context Windows Test Suite"

# 1. Core script files
Write-Section "1. Core Script Files"

Test-FileExists "core\injector.sh" "core\injector.sh"
Test-FileExists "core\precompact.sh" "core\precompact.sh"
Test-FileExists "claude_context_injector.sh" "claude_context_injector.sh"
Test-FileExists "claude_context_precompact.sh" "claude_context_precompact.sh"

# 2. PowerShell scripts
Write-Section "2. PowerShell Scripts"

Test-FileExists "install\install.ps1" "install\install.ps1"
Test-FileExists "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-FileExists "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-FileExists "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-FileExists "install\uninstall.ps1" "install\uninstall.ps1"

# 3. PowerShell syntax check
Write-Section "3. PowerShell Syntax Check"

Test-PowerShellSyntax "install\install.ps1" "install\install.ps1"
Test-PowerShellSyntax "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-PowerShellSyntax "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-PowerShellSyntax "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-PowerShellSyntax "install\uninstall.ps1" "install\uninstall.ps1"

# 4. Additional files
Write-Section "4. Additional Files"

Test-FileExists "config.sh" "config.sh"
Test-FileExists "uninstall.sh" "uninstall.sh"
Test-FileExists "utils\common_functions.sh" "utils\common_functions.sh"

# 5. Git Bash availability
Write-Section "5. Git Bash Check"

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
$script:TotalTests++

if (Test-Path $GitBashPath) {
    Write-Success "Git Bash available"
    $script:PassedTests++
    
    # Test bash script syntax
    Write-Host ""
    Write-Host "Bash Script Syntax Check:" -ForegroundColor Cyan
    
    $BashScripts = @(
        "core/injector.sh",
        "core/precompact.sh",
        "config.sh"
    )
    
    foreach ($script in $BashScripts) {
        $script:TotalTests++
        if (Test-Path $script) {
            try {
                $result = & $GitBashPath -c "bash -n '$script'" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$script syntax OK"
                    $script:PassedTests++
                } else {
                    Write-Failure "$script syntax error"
                    $script:FailedTests++
                }
            } catch {
                Write-Failure "$script syntax check failed"
                $script:FailedTests++
            }
        } else {
            Write-Failure "$script file not found"
            $script:FailedTests++
        }
    }
} else {
    Write-Warning "Git Bash not found"
    $script:FailedTests++
}

# 6. Basic functionality test
Write-Section "6. Basic Functionality Test"

if (Test-Path $GitBashPath) {
    $TestHome = Join-Path $env:TEMP "claude_test_$(Get-Random)"
    $ClaudeHome = Join-Path $TestHome ".claude"
    
    $script:TotalTests++
    try {
        New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
        "# Test CLAUDE.md Content`nThis is a test file." | Out-File -FilePath (Join-Path $ClaudeHome "CLAUDE.md") -Encoding UTF8
        
        if (Test-Path (Join-Path $ClaudeHome "CLAUDE.md")) {
            Write-Success "Test environment created"
            $script:PassedTests++
        } else {
            Write-Failure "Test environment creation failed"
            $script:FailedTests++
        }
    } catch {
        Write-Failure "Test environment setup error"
        $script:FailedTests++
    } finally {
        if (Test-Path $TestHome) {
            Remove-Item $TestHome -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Warning "Skipping functionality test - Git Bash not available"
}

# Results summary
Write-Header "Test Results"

Write-Host "Total Tests: $TotalTests"
Write-Host "Passed: " -NoNewline
Write-Host "$PassedTests" -ForegroundColor Green
Write-Host "Failed: " -NoNewline  
Write-Host "$FailedTests" -ForegroundColor Red

if ($TotalTests -gt 0) {
    $coverage = [math]::Round(($PassedTests / $TotalTests) * 100)
    Write-Host "Coverage: " -NoNewline
    Write-Host "$coverage%" -ForegroundColor Green
}

Write-Host ""

if ($FailedTests -eq 0) {
    Write-Host "🎉 All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Some tests failed" -ForegroundColor Red
    exit 1
}
