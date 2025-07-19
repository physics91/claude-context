# Claude Context Windows Test Script - Simple Version
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
        Write-Success "$Description 존재"
        $script:PassedTests++
    } else {
        Write-Failure "$Description 없음"
        $script:FailedTests++
    }
}

function Test-PowerShellSyntax {
    param([string]$FilePath, [string]$Description)
    
    $script:TotalTests++
    
    if (-not (Test-Path $FilePath)) {
        Write-Failure "$Description - 파일 없음"
        $script:FailedTests++
        return
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Success "$Description 구문 정상"
        $script:PassedTests++
    } catch {
        Write-Failure "$Description 구문 오류"
        $script:FailedTests++
    }
}

# Main test execution
Write-Header "Claude Context Windows 테스트"

# 1. Core script files
Write-Section "1. 핵심 스크립트 파일 확인"

Test-FileExists "core\injector.sh" "core\injector.sh"
Test-FileExists "core\precompact.sh" "core\precompact.sh"
Test-FileExists "claude_context_injector.sh" "claude_context_injector.sh"
Test-FileExists "claude_context_precompact.sh" "claude_context_precompact.sh"

# 2. PowerShell scripts
Write-Section "2. PowerShell 스크립트 파일 확인"

Test-FileExists "install\install.ps1" "install\install.ps1"
Test-FileExists "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-FileExists "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-FileExists "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-FileExists "install\uninstall.ps1" "install\uninstall.ps1"

# 3. PowerShell syntax check
Write-Section "3. PowerShell 구문 검사"

Test-PowerShellSyntax "install\install.ps1" "install\install.ps1"
Test-PowerShellSyntax "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-PowerShellSyntax "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-PowerShellSyntax "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-PowerShellSyntax "install\uninstall.ps1" "install\uninstall.ps1"

# 4. Additional files
Write-Section "4. 추가 파일 확인"

Test-FileExists "config.sh" "config.sh"
Test-FileExists "uninstall.sh" "uninstall.sh"
Test-FileExists "utils\common_functions.sh" "utils\common_functions.sh"

# 5. Git Bash availability
Write-Section "5. Git Bash 확인"

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
$script:TotalTests++

if (Test-Path $GitBashPath) {
    Write-Success "Git Bash 사용 가능"
    $script:PassedTests++
    
    # Test bash script syntax
    Write-Host ""
    Write-Host "Bash 스크립트 구문 검사:" -ForegroundColor Cyan
    
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
                    Write-Success "$script 구문 정상"
                    $script:PassedTests++
                } else {
                    Write-Failure "$script 구문 오류"
                    $script:FailedTests++
                }
            } catch {
                Write-Failure "$script 구문 검사 실패"
                $script:FailedTests++
            }
        } else {
            Write-Failure "$script 파일 없음"
            $script:FailedTests++
        }
    }
} else {
    Write-Warning "Git Bash 없음 (C:\Program Files\Git\bin\bash.exe)"
    $script:FailedTests++
}

# Results summary
Write-Header "테스트 결과"

Write-Host "총 테스트: $TotalTests"
Write-Host "성공: " -NoNewline
Write-Host "$PassedTests" -ForegroundColor Green
Write-Host "실패: " -NoNewline  
Write-Host "$FailedTests" -ForegroundColor Red

if ($TotalTests -gt 0) {
    $coverage = [math]::Round(($PassedTests / $TotalTests) * 100)
    Write-Host "커버리지: " -NoNewline
    Write-Host "$coverage%" -ForegroundColor Green
}

Write-Host ""

if ($FailedTests -eq 0) {
    Write-Host "🎉 모든 테스트 통과!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ 일부 테스트 실패" -ForegroundColor Red
    exit 1
}
