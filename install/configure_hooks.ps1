# Claude Context Hook 설정 스크립트 (Windows PowerShell)
# Claude Context 모드를 변경할 수 있는 대화형 스크립트

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null
)

# 오류 시 중단
$ErrorActionPreference = "Stop"

# 색상 정의
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 설정 - Join-Path 사용으로 안전한 경로 조합
$INSTALL_BASE = Join-Path $env:USERPROFILE ".claude\hooks"
$INSTALL_DIR = Join-Path $INSTALL_BASE "claude-context"
$CONFIG_FILE = Join-Path $INSTALL_BASE "claude-context.conf"

# 헤더 출력
function Print-Header {
    Write-ColoredOutput "╔════════════════════════════════════════╗" "Blue"
    Write-ColoredOutput "║     Claude Context 모드 설정           ║" "Blue"
    Write-ColoredOutput "╚════════════════════════════════════════╝" "Blue"
    Write-Host ""
}

# 현재 모드 확인
function Get-CurrentMode {
    if (Test-Path $CONFIG_FILE) {
        $content = Get-Content $CONFIG_FILE
        $modeLine = $content | Where-Object { $_ -match "CLAUDE_CONTEXT_MODE=" }
        if ($modeLine) {
            return $modeLine -replace 'CLAUDE_CONTEXT_MODE="?([^"]*)"?', '$1'
        }
    }
    return "알 수 없음"
}

# 모드 선택
function Select-Mode {
    if ($Mode) {
        return $Mode
    }
    
    $currentMode = Get-CurrentMode
    Write-ColoredOutput "현재 모드: $currentMode" "Yellow"
    Write-Host ""
    
    Write-ColoredOutput "새로운 모드를 선택하세요:" "Blue"
    Write-Host ""
    Write-Host "1) Basic    - CLAUDE.md 주입만 (가장 간단)"
    Write-Host "2) History  - 대화 기록 관리 추가"
    Write-Host "3) OAuth    - 자동 요약 포함 (Claude Code 인증 사용) ⭐️"
    Write-Host "4) Auto     - 자동 요약 포함 (Claude CLI 필요)"
    Write-Host "5) Advanced - 자동 요약 포함 (Gemini CLI 필요)"
    Write-Host ""
    
    do {
        $choice = Read-Host "선택 [1-5] (기본값: 3)"
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
            Write-ColoredOutput "잘못된 선택입니다. 기본값(oauth)으로 진행합니다." "Red"
            return "oauth"
        }
    }
}

# 설정 업데이트
function Update-Config {
    param([string]$SelectedMode)
    
    Write-Host "설정을 업데이트하는 중..."
    
    # claude-context.conf 업데이트
    if (Test-Path $CONFIG_FILE) {
        $content = Get-Content $CONFIG_FILE
        $newContent = $content | ForEach-Object {
            if ($_ -match "CLAUDE_CONTEXT_MODE=") {
                "CLAUDE_CONTEXT_MODE=`"$SelectedMode`""
            } else {
                $_
            }
        }
        Set-Content -Path $CONFIG_FILE -Value $newContent -Encoding UTF8
    } else {
        $configContent = @"
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$($INSTALL_DIR.Replace('\', '/'))"
CLAUDE_CONTEXT_MODE="$SelectedMode"
"@
        Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
    }
    
    # config.sh 업데이트
    $configShPath = "$INSTALL_DIR\config.sh"
    if (Test-Path $configShPath) {
        $content = Get-Content $configShPath
        $newContent = $content | ForEach-Object {
            if ($_ -match "CLAUDE_CONTEXT_MODE=") {
                "CLAUDE_CONTEXT_MODE=`"$SelectedMode`""
            } else {
                $_
            }
        }
        Set-Content -Path $configShPath -Value $newContent -Encoding UTF8
    }
    
    Write-ColoredOutput "✓ 설정 업데이트 완료" "Green"
}

# 디렉토리 생성
function New-Directories {
    param([string]$SelectedMode)
    
    # 기본 디렉토리 - Out-Null 대신 $null 할당
    $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude") -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "claude-context") -Force
    
    # History/OAuth/Auto/Advanced 모드 디렉토리
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        Write-Host "대화 기록 관리용 디렉토리를 생성하는 중..."
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\history") -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\summaries") -Force
        Write-ColoredOutput "✓ 디렉토리 생성 완료" "Green"
    }
}

# 상태 확인
function Test-Installation {
    $errors = @()
    
    if (-not (Test-Path $INSTALL_DIR)) {
        $errors += "Claude Context가 설치되어 있지 않습니다."
    }
    
    if (-not (Test-Path "$env:USERPROFILE\.claude\settings.json")) {
        $errors += "Claude Code 설정 파일을 찾을 수 없습니다."
    }
    
    return $errors
}

# 사용법 출력
function Show-Usage {
    param([string]$SelectedMode)
    
    Write-Host ""
    Write-ColoredOutput "✅ 모드 변경이 완료되었습니다!" "Green"
    Write-Host ""
    Write-ColoredOutput "현재 모드: $($SelectedMode.ToUpper())" "Blue"
    Write-Host ""
    
    switch ($SelectedMode) {
        "basic" {
            Write-Host "CLAUDE.md 파일 주입만 활성화됩니다."
        }
        "history" {
            Write-Host "대화 기록 관리 기능이 활성화됩니다."
            Write-Host ""
            Write-Host "대화 기록 관리:"
            Write-Host "  $INSTALL_DIR\src\monitor\claude_history_manager.sh --help"
        }
        "oauth" {
            Write-Host "자동 요약 기능이 활성화됩니다. (Claude Code OAuth 사용)"
            Write-Host "Claude Code의 인증 정보를 자동으로 사용합니다."
            Write-Host ""
            if (-not (Test-Path "$env:USERPROFILE\.claude\.credentials.json")) {
                Write-ColoredOutput "⚠️  Claude Code에 먼저 로그인해주세요." "Yellow"
            }
        }
        "auto" {
            Write-Host "자동 요약 기능이 활성화됩니다. (Claude CLI 사용)"
            Write-Host ""
            try {
                claude --version | Out-Null
                Write-ColoredOutput "✓ Claude CLI가 설치되어 있습니다." "Green"
            } catch {
                Write-ColoredOutput "⚠️  Claude CLI를 설치해주세요." "Yellow"
            }
        }
        "advanced" {
            Write-Host "고급 자동 요약 기능이 활성화됩니다. (Gemini 사용)"
            Write-Host ""
            try {
                gemini --version | Out-Null
                Write-ColoredOutput "✓ Gemini CLI가 설치되어 있습니다." "Green"
            } catch {
                Write-ColoredOutput "⚠️  Gemini CLI를 설치해주세요." "Yellow"
                Write-Host "설정: `$env:GEMINI_API_KEY = '<your-api-key>'"
            }
        }
    }
    
    Write-Host ""
    Write-Host "다음 단계:"
    Write-Host "1. Claude Code를 재시작하세요"
    Write-Host "2. CLAUDE.md 파일을 생성하거나 업데이트하세요"
    Write-Host ""
    Write-Host "문제 해결:"
    Write-Host "  $INSTALL_DIR\README.md"
}

# 메인 실행
function Main {
    Print-Header
    
    # 설치 상태 확인
    $errors = Test-Installation
    if ($errors.Count -gt 0) {
        Write-ColoredOutput "설치 상태 확인 중 오류가 발견되었습니다:" "Red"
        foreach ($error in $errors) {
            Write-Host "  - $error"
        }
        Write-Host ""
        Write-Host "먼저 install.ps1을 실행하여 Claude Context를 설치해주세요."
        exit 1
    }
    
    # 모드 선택
    $selectedMode = Select-Mode
    Write-Host ""
    Write-ColoredOutput "선택한 모드: $selectedMode" "Blue"
    Write-Host ""
    
    # 설정 업데이트
    Update-Config $selectedMode
    New-Directories $selectedMode
    
    # 완료 메시지
    Show-Usage $selectedMode
}

# 스크립트 실행
Main