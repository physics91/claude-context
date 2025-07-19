# Claude Context Windows Test Script - Final Version
# PowerShell version with bash-like output formatting

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ""
Write-Host "=== Claude Context Windows 테스트 스위트 ===" -ForegroundColor Blue
Write-Host ""

# Test counters
$TotalTests = 0
$PassedTests = 0
$FailedTests = 0

# Helper functions
function Test-FileAndReport {
    param([string]$FilePath, [string]$Description)
    
    $script:TotalTests++
    
    if (Test-Path $FilePath) {
        Write-Host "  ✓ $Description 존재" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "  ✗ $Description 없음" -ForegroundColor Red
        $script:FailedTests++
    }
}

function Test-PSScriptSyntax {
    param([string]$FilePath, [string]$Description)
    
    $script:TotalTests++
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "  ✗ $Description - 파일 없음" -ForegroundColor Red
        $script:FailedTests++
        return
    }
    
    try {
        $content = Get-Content $FilePath -Raw
        $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
        Write-Host "  ✓ $Description 구문 정상" -ForegroundColor Green
        $script:PassedTests++
    } catch {
        Write-Host "  ✗ $Description 구문 오류" -ForegroundColor Red
        $script:FailedTests++
    }
}

# 1. Core script files
Write-Host ""
Write-Host "1. 핵심 스크립트 파일" -ForegroundColor Yellow

Test-FileAndReport "core\injector.sh" "core\injector.sh"
Test-FileAndReport "core\precompact.sh" "core\precompact.sh"
Test-FileAndReport "claude_context_injector.sh" "claude_context_injector.sh"
Test-FileAndReport "claude_context_precompact.sh" "claude_context_precompact.sh"

# 2. PowerShell scripts
Write-Host ""
Write-Host "2. PowerShell 스크립트" -ForegroundColor Yellow

Test-FileAndReport "install\install.ps1" "install\install.ps1"
Test-FileAndReport "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-FileAndReport "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-FileAndReport "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-FileAndReport "install\uninstall.ps1" "install\uninstall.ps1"

# 3. PowerShell syntax check
Write-Host ""
Write-Host "3. PowerShell 구문 검사" -ForegroundColor Yellow

Test-PSScriptSyntax "install\install.ps1" "install\install.ps1"
Test-PSScriptSyntax "install\configure_hooks.ps1" "install\configure_hooks.ps1"
Test-PSScriptSyntax "install\one-line-install.ps1" "install\one-line-install.ps1"
Test-PSScriptSyntax "install\claude_context_native.ps1" "install\claude_context_native.ps1"
Test-PSScriptSyntax "install\uninstall.ps1" "install\uninstall.ps1"

# 4. Additional files
Write-Host ""
Write-Host "4. 추가 파일" -ForegroundColor Yellow

Test-FileAndReport "config.sh" "config.sh"
Test-FileAndReport "uninstall.sh" "uninstall.sh"
Test-FileAndReport "utils\common_functions.sh" "utils\common_functions.sh"

# 5. Git Bash check
Write-Host ""
Write-Host "5. Git Bash 확인" -ForegroundColor Yellow

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
$script:TotalTests++

if (Test-Path $GitBashPath) {
    Write-Host "  ✓ Git Bash 사용 가능" -ForegroundColor Green
    $script:PassedTests++
    
    # Test bash script syntax
    Write-Host ""
    Write-Host "Bash 스크립트 구문 검사:" -ForegroundColor Cyan
    
    $BashScripts = @("core/injector.sh", "core/precompact.sh", "config.sh")
    
    foreach ($bashScript in $BashScripts) {
        $script:TotalTests++
        if (Test-Path $bashScript) {
            try {
                $result = & $GitBashPath -c "bash -n '$bashScript'" 2>$null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  ✓ $bashScript 구문 정상" -ForegroundColor Green
                    $script:PassedTests++
                } else {
                    Write-Host "  ✗ $bashScript 구문 오류" -ForegroundColor Red
                    $script:FailedTests++
                }
            } catch {
                Write-Host "  ✗ $bashScript 구문 검사 실패" -ForegroundColor Red
                $script:FailedTests++
            }
        } else {
            Write-Host "  ✗ $bashScript 파일 없음" -ForegroundColor Red
            $script:FailedTests++
        }
    }
} else {
    Write-Host "  ⚠ Git Bash 없음" -ForegroundColor Yellow
    $script:FailedTests++
}

# 6. Basic functionality test
Write-Host ""
Write-Host "6. 기본 기능 테스트" -ForegroundColor Yellow

$script:TotalTests++
try {
    $TestHome = Join-Path $env:TEMP "claude_test_$(Get-Random)"
    $ClaudeHome = Join-Path $TestHome ".claude"
    
    New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
    "# Test CLAUDE.md Content`nThis is a test file." | Out-File -FilePath (Join-Path $ClaudeHome "CLAUDE.md") -Encoding UTF8
    
    if (Test-Path (Join-Path $ClaudeHome "CLAUDE.md")) {
        Write-Host "  ✓ 테스트 환경 생성 성공" -ForegroundColor Green
        $script:PassedTests++
    } else {
        Write-Host "  ✗ 테스트 환경 생성 실패" -ForegroundColor Red
        $script:FailedTests++
    }
    
    # Cleanup
    if (Test-Path $TestHome) {
        Remove-Item $TestHome -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "  ✗ 테스트 환경 설정 오류" -ForegroundColor Red
    $script:FailedTests++
}

# Results summary
Write-Host ""
Write-Host "=== 테스트 결과 ===" -ForegroundColor Blue
Write-Host ""

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
