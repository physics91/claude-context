# Claude Context Windows Test Script
# PowerShell version with bash-like output formatting

param(
    [switch]$Verbose = $false
)

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

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Cyan
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
    Write-Host "${Title}:" -ForegroundColor Yellow
}

# Test counters
$script:TotalTests = 0
$script:PassedTests = 0
$script:FailedTests = 0

function Test-Item {
    param(
        [string]$Name,
        [scriptblock]$TestBlock
    )
    
    $script:TotalTests++
    
    try {
        $result = & $TestBlock
        if ($result) {
            Write-Success $Name
            $script:PassedTests++
        } else {
            Write-Failure $Name
            $script:FailedTests++
        }
    } catch {
        Write-Failure "$Name - Error: $($_.Exception.Message)"
        $script:FailedTests++
        if ($Verbose) {
            Write-Host "    Details: $($_.Exception)" -ForegroundColor DarkRed
        }
    }
}

# Main test execution
Write-Header "Claude Context Windows 테스트"

# 1. File existence tests
Write-Section "1. 스크립트 파일 확인"

$CoreScripts = @(
    "core\injector.sh",
    "core\precompact.sh", 
    "claude_context_injector.sh",
    "claude_context_precompact.sh"
)

foreach ($script in $CoreScripts) {
    Test-Item "$script 존재" {
        Test-Path $script
    }
}

# 2. PowerShell scripts
Write-Section "2. PowerShell 스크립트 확인"

$PowerShellScripts = @(
    "install\install.ps1",
    "install\configure_hooks.ps1", 
    "install\one-line-install.ps1",
    "install\claude_context_native.ps1",
    "install\uninstall.ps1"
)

foreach ($script in $PowerShellScripts) {
    Test-Item "$script 존재" {
        Test-Path $script
    }
}

# 3. PowerShell syntax check
Write-Section "3. PowerShell 구문 검사"

foreach ($script in $PowerShellScripts) {
    if (Test-Path $script) {
        Test-Item "$script 구문 정상" {
            try {
                $content = Get-Content $script -Raw
                $null = [System.Management.Automation.PSParser]::Tokenize($content, [ref]$null)
                return $true
            } catch {
                return $false
            }
        }
    }
}

# 4. Bash script syntax (if Git Bash available)
Write-Section "4. Bash 스크립트 구문 검사"

$GitBashPath = "C:\Program Files\Git\bin\bash.exe"
if (Test-Path $GitBashPath) {
    Write-Info "Git Bash 발견 - bash 스크립트 검사 중..."
    
    $BashScripts = @(
        "core/injector.sh",
        "core/precompact.sh",
        "install/install.sh",
        "install/configure_hooks.sh"
    )
    
    foreach ($script in $BashScripts) {
        if (Test-Path $script) {
            Test-Item "$script 구문 정상" {
                $result = & $GitBashPath -c "bash -n '$script'" 2>$null
                return $LASTEXITCODE -eq 0
            }
        }
    }
} else {
    Write-Warning "Git Bash를 찾을 수 없음 - bash 스크립트 검사 건너뜀"
}

# 5. Basic functionality test
Write-Section "5. 기본 기능 테스트"

if (Test-Path $GitBashPath) {
    # Create test environment
    $TestHome = Join-Path $env:TEMP "claude_test_$(Get-Random)"
    $ClaudeHome = Join-Path $TestHome ".claude"
    
    Test-Item "테스트 환경 생성" {
        New-Item -ItemType Directory -Path $ClaudeHome -Force | Out-Null
        "# Test CLAUDE.md Content`nThis is a test file for Claude Context." | Out-File -FilePath (Join-Path $ClaudeHome "CLAUDE.md") -Encoding UTF8
        return Test-Path (Join-Path $ClaudeHome "CLAUDE.md")
    }
    
    Test-Item "Injector 기능 테스트" {
        $env:HOME = $TestHome
        $env:CLAUDE_CONTEXT_MODE = "basic"
        
        try {
            $currentDir = (Get-Location).Path.Replace('\', '/')
            $output = & $GitBashPath -c "cd '$currentDir'; bash core/injector.sh" 2>$null
            $result = $output -match "Test CLAUDE.md Content"
            return $result
        } finally {
            Remove-Variable -Name "HOME" -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name "CLAUDE_CONTEXT_MODE" -Scope Global -ErrorAction SilentlyContinue
        }
    }
    
    # Cleanup
    if (Test-Path $TestHome) {
        Remove-Item $TestHome -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Warning "Git Bash 없음 - 기능 테스트 건너뜀"
}

# 6. Configuration file test
Write-Section "6. 설정 파일 테스트"

Test-Item "config.sh 존재" {
    Test-Path "config.sh"
}

if (Test-Path "config.sh" -and (Test-Path $GitBashPath)) {
    Test-Item "config.sh 구문 정상" {
        $result = & $GitBashPath -c "bash -n config.sh" 2>$null
        return $LASTEXITCODE -eq 0
    }
}

# Results summary
Write-Header "테스트 결과"

Write-Host "총 테스트: $script:TotalTests"
Write-Host "성공: " -NoNewline
Write-Host "$script:PassedTests" -ForegroundColor Green
Write-Host "실패: " -NoNewline  
Write-Host "$script:FailedTests" -ForegroundColor Red

if ($script:TotalTests -gt 0) {
    $coverage = [math]::Round(($script:PassedTests / $script:TotalTests) * 100)
    Write-Host "커버리지: " -NoNewline
    Write-Host "$coverage%" -ForegroundColor Green
}

Write-Host ""

if ($script:FailedTests -eq 0) {
    Write-Host "🎉 모든 테스트 통과!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ 일부 테스트 실패" -ForegroundColor Red
    exit 1
}
