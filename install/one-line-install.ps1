# Claude Context 원클릭 설치 스크립트 (Windows PowerShell)
# 
# 보안 권장 사용법 (2단계):
# 1. Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "one-line-install.ps1"
# 2. Get-Content .\one-line-install.ps1 # 내용 확인 후
# 3. PowerShell -ExecutionPolicy Bypass -File .\one-line-install.ps1
#
# 빠른 설치 (위험): Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1").Content

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null
)

# 오류 시 중단
$ErrorActionPreference = "Stop"

# 설정
$GITHUB_USER = "physics91"
$GITHUB_REPO = "claude-context"
$GITHUB_BRANCH = "main"

# 색상 정의
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

Write-ColoredOutput "╔════════════════════════════════════════╗" "Blue"
Write-ColoredOutput "║     Claude Context v1.0.0 설치         ║" "Blue"
Write-ColoredOutput "║            (Windows)                   ║" "Blue"
Write-ColoredOutput "╚════════════════════════════════════════╝" "Blue"
Write-Host ""

# PowerShell 버전 확인
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-ColoredOutput "Error: PowerShell 5.0 이상이 필요합니다." "Red"
    Write-Host "현재 버전: $($PSVersionTable.PSVersion)"
    exit 1
}

# 임시 디렉토리 생성 - 성능 최적화
$tempDir = Join-Path $env:TEMP "claude-context-install-$(Get-Random)"
$null = New-Item -ItemType Directory -Path $tempDir -Force

try {
    Set-Location $tempDir
    
    # Git 설치 확인
    try {
        git --version | Out-Null
    } catch {
        Write-ColoredOutput "Error: Git이 설치되어 있지 않습니다." "Red"
        Write-Host "먼저 Git을 설치해주세요:"
        Write-Host "  - Git for Windows: https://git-scm.com/download/win"
        Write-Host "  - 또는 winget install Git.Git"
        exit 1
    }
    
    # 저장소 클론
    Write-Host "저장소를 다운로드하는 중..."
    try {
        git clone --depth 1 --branch $GITHUB_BRANCH "https://github.com/$GITHUB_USER/$GITHUB_REPO.git" 2>$null | Out-Null
        Write-ColoredOutput "✓ 다운로드 완료" "Green"
    } catch {
        Write-ColoredOutput "Error: 저장소 다운로드에 실패했습니다." "Red"
        Write-Host "네트워크 연결을 확인하고 다시 시도해주세요."
        exit 1
    }
    
    # 설치 스크립트 실행
    Set-Location $GITHUB_REPO
    
    $installScript = $null
    if (Test-Path "install.ps1") {
        $installScript = ".\install.ps1"
    } elseif (Test-Path "install\install.ps1") {
        $installScript = ".\install\install.ps1"
    } else {
        Write-ColoredOutput "Error: PowerShell 설치 스크립트를 찾을 수 없습니다." "Red"
        Write-Host "Bash 스크립트를 사용하려면 Git Bash에서 실행해주세요."
        exit 1
    }
    
    Write-Host ""
    if ($Mode) {
        & $installScript -Mode $Mode
    } else {
        & $installScript
    }
    
} finally {
    # 임시 디렉토리 정리
    try {
        Set-Location $env:USERPROFILE
        Remove-Item -Recurse -Force $tempDir -ErrorAction SilentlyContinue
    } catch {
        # 정리 실패해도 무시
    }
}

Write-Host ""
Write-ColoredOutput "🎉 Claude Context가 성공적으로 설치되었습니다!" "Green"
Write-Host ""
Write-ColoredOutput "다음 단계:" "Blue"
Write-Host "1. $env:USERPROFILE\.claude\CLAUDE.md 파일을 생성하여 전역 컨텍스트를 설정하세요"
Write-Host "   예시:"
Write-Host "   New-Item -ItemType File -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Force"
Write-Host "   Add-Content -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Value '# 기본 규칙'"
Write-Host "   Add-Content -Path '$env:USERPROFILE\.claude\CLAUDE.md' -Value '- 한국어로 대화하세요'"
Write-Host ""
Write-Host "2. Claude Code를 재시작하세요"
Write-Host ""
Write-ColoredOutput "고급 기능 설정:" "Blue"
Write-Host "PowerShell -ExecutionPolicy Bypass -File '$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1'"
Write-Host ""
Write-Host "자세한 사용법: https://github.com/$GITHUB_USER/$GITHUB_REPO"
Write-Host "문제 발생 시: https://github.com/$GITHUB_USER/$GITHUB_REPO/issues"