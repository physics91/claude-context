# Claude Context 설치 스크립트 - Windows PowerShell 버전
# ~/.claude/hooks/claude-context/ 디렉토리에 설치

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("basic", "history", "oauth", "auto", "advanced")]
    [string]$Mode = $null,
    
    [Parameter(Mandatory=$false)]
    [switch]$Uninstall = $false
)

# 오류 시 중단
$ErrorActionPreference = "Stop"

# 색상 정의 (Windows PowerShell용)
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# 설정 - Join-Path 사용으로 안전한 경로 조합
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$INSTALL_BASE = Join-Path $env:USERPROFILE ".claude\hooks"
$INSTALL_DIR = Join-Path $INSTALL_BASE "claude-context"
$CONFIG_FILE = Join-Path $INSTALL_BASE "claude-context.conf"

# 헤더 출력
function Print-Header {
    Write-ColoredOutput "╔════════════════════════════════════════╗" "Blue"
    Write-ColoredOutput "║     Claude Context 설치 (Windows)     ║" "Blue"
    Write-ColoredOutput "╚════════════════════════════════════════╝" "Blue"
    Write-Host ""
}

# 모드 선택
function Select-Mode {
    if ($Mode) {
        return $Mode
    }
    
    Write-ColoredOutput "설치 모드를 선택하세요:" "Blue"
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

# 의존성 확인
function Test-Dependencies {
    param([string]$SelectedMode)
    
    $missing = @()
    
    # PowerShell 버전 확인
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-ColoredOutput "PowerShell 5.0 이상이 필요합니다." "Red"
        exit 1
    }
    
    # Git 확인
    try {
        git --version | Out-Null
    } catch {
        $missing += "git"
    }
    
    # OAuth 모드 의존성
    if ($SelectedMode -eq "oauth") {
        $credentialsFile = "$env:USERPROFILE\.claude\.credentials.json"
        if (-not (Test-Path $credentialsFile)) {
            Write-ColoredOutput "경고: Claude Code 인증 파일을 찾을 수 없습니다." "Yellow"
            Write-Host "Claude Code를 먼저 실행하여 로그인해주세요."
            $confirm = Read-Host "계속하시겠습니까? [y/N]"
            if ($confirm -notmatch "^[Yy]$") {
                exit 1
            }
        }
    }
    
    # Auto 모드 의존성
    if ($SelectedMode -eq "auto") {
        try {
            claude --version | Out-Null
        } catch {
            Write-ColoredOutput "경고: 'claude' CLI가 설치되어 있지 않습니다." "Yellow"
            Write-Host "Auto 모드를 사용하려면 Claude CLI가 필요합니다."
            $confirm = Read-Host "계속하시겠습니까? [y/N]"
            if ($confirm -notmatch "^[Yy]$") {
                exit 1
            }
        }
    }
    
    # Advanced 모드 의존성
    if ($SelectedMode -eq "advanced") {
        try {
            gemini --version | Out-Null
        } catch {
            Write-ColoredOutput "경고: 'gemini' CLI가 설치되어 있지 않습니다." "Yellow"
            Write-Host "Advanced 모드를 사용하려면 gemini가 필요합니다."
            $confirm = Read-Host "계속하시겠습니까? [y/N]"
            if ($confirm -notmatch "^[Yy]$") {
                exit 1
            }
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-ColoredOutput "다음 도구가 필요합니다: $($missing -join ', ')" "Red"
        Write-Host "설치 후 다시 시도해주세요."
        exit 1
    }
}

# 백업 생성
function New-Backup {
    if (Test-Path $INSTALL_DIR) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "$INSTALL_DIR.backup.$timestamp"
        Write-Host "기존 설치를 백업합니다..."
        Copy-Item -Recurse $INSTALL_DIR $backupDir
        Write-ColoredOutput "✓ 백업 완료: $backupDir" "Green"
    }
}

# 파일 설치
function Install-Files {
    Write-Host "파일을 설치하는 중..."
    
    # claude-context 디렉토리 생성 - Join-Path 사용
    $dirs = @(
        (Join-Path $INSTALL_DIR "src\core"),
        (Join-Path $INSTALL_DIR "src\monitor"), 
        (Join-Path $INSTALL_DIR "src\utils"),
        (Join-Path $INSTALL_DIR "tests"),
        (Join-Path $INSTALL_DIR "docs"),
        (Join-Path $INSTALL_DIR "examples"),
        (Join-Path $INSTALL_DIR "config")
    )
    
    foreach ($dir in $dirs) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    
    # 필수 디렉토리 확인
    $requiredDirs = @("src\core", "src\monitor", "src\utils")
    $missingCount = 0
    
    foreach ($dir in $requiredDirs) {
        $sourcePath = Join-Path $PROJECT_ROOT $dir.Replace("src\", "")
        if (-not (Test-Path $sourcePath)) {
            Write-ColoredOutput "오류: 필수 디렉토리 '$dir'를 찾을 수 없습니다" "Red"
            $missingCount++
        }
    }
    
    if ($missingCount -gt 0) {
        Write-ColoredOutput "설치에 필요한 파일이 누락되었습니다." "Red"
        Write-Host "프로젝트 루트: $PROJECT_ROOT"
        Get-ChildItem $PROJECT_ROOT
        exit 1
    }
    
    # 파일 복사
    Copy-Item -Recurse "$PROJECT_ROOT\core" "$INSTALL_DIR\src\" -Force
    Copy-Item -Recurse "$PROJECT_ROOT\monitor" "$INSTALL_DIR\src\" -Force
    Copy-Item -Recurse "$PROJECT_ROOT\utils" "$INSTALL_DIR\src\" -Force
    
    # 선택적 디렉토리 복사
    if (Test-Path "$PROJECT_ROOT\tests") {
        Copy-Item -Recurse "$PROJECT_ROOT\tests" $INSTALL_DIR -Force
    }
    if (Test-Path "$PROJECT_ROOT\docs") {
        Copy-Item -Recurse "$PROJECT_ROOT\docs" $INSTALL_DIR -Force
    }
    
    # 문서 파일 복사
    if (Test-Path "$PROJECT_ROOT\README.md") {
        Copy-Item "$PROJECT_ROOT\README.md" $INSTALL_DIR -Force
    }
    if (Test-Path "$PROJECT_ROOT\config.sh") {
        Copy-Item "$PROJECT_ROOT\config.sh" $INSTALL_DIR -Force
    }
    
    # Windows용 wrapper 스크립트 생성 - Git Bash 경로 안정화
    $injectorWrapper = @"
# Claude Context Injector Wrapper for Windows
# Git Bash 경로 탐색
`$GitBashPath = @(
    "`$env:ProgramFiles\Git\bin\bash.exe",
    "`$env:ProgramFiles(x86)\Git\bin\bash.exe",
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
) | Where-Object { Test-Path `$_ } | Select-Object -First 1

if (-not `$GitBashPath) {
    Write-Error "Git Bash를 찾을 수 없습니다. Git for Windows를 설치해주세요."
    exit 1
}

`$scriptPath = "`$env:USERPROFILE/.claude/hooks/claude-context/src/core/injector.sh"
& `$GitBashPath -c "`$scriptPath `$args"
"@
    
    $precompactWrapper = @"
# Claude Context PreCompact Wrapper for Windows
# Git Bash 경로 탐색
`$GitBashPath = @(
    "`$env:ProgramFiles\Git\bin\bash.exe",
    "`$env:ProgramFiles(x86)\Git\bin\bash.exe",
    "C:\Program Files\Git\bin\bash.exe",
    "C:\Program Files (x86)\Git\bin\bash.exe"
) | Where-Object { Test-Path `$_ } | Select-Object -First 1

if (-not `$GitBashPath) {
    Write-Error "Git Bash를 찾을 수 없습니다. Git for Windows를 설치해주세요."
    exit 1
}

`$scriptPath = "`$env:USERPROFILE/.claude/hooks/claude-context/src/core/precompact.sh"
& `$GitBashPath -c "`$scriptPath `$args"
"@
    
    Set-Content -Path "$INSTALL_BASE\claude_context_injector.ps1" -Value $injectorWrapper -Encoding UTF8
    Set-Content -Path "$INSTALL_BASE\claude_context_precompact.ps1" -Value $precompactWrapper -Encoding UTF8
    
    Write-ColoredOutput "✓ 파일 설치 완료" "Green"
}

# 설정 파일 생성
function New-Config {
    param([string]$SelectedMode)
    
    Write-Host "설정 파일을 생성하는 중..."
    
    # claude-context.conf 생성
    $configContent = @"
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$($INSTALL_DIR.Replace('\', '/'))"
CLAUDE_CONTEXT_MODE="$SelectedMode"
"@
    Set-Content -Path $CONFIG_FILE -Value $configContent -Encoding UTF8
    
    # config.sh 생성 (Windows 호환)
    $configShContent = @"
#!/usr/bin/env bash
# Claude Context Configuration - Windows Compatible

CLAUDE_CONTEXT_MODE="$SelectedMode"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_INJECT_PROBABILITY="1.0"
CLAUDE_HOME="`${USERPROFILE}/.claude"
CLAUDE_HOOKS_DIR="`${USERPROFILE}/.claude/hooks"
CLAUDE_HISTORY_DIR="`${CLAUDE_HOME}/history"
CLAUDE_SUMMARY_DIR="`${CLAUDE_HOME}/summaries"
CLAUDE_CACHE_DIR="`${LOCALAPPDATA}/claude-context"
CLAUDE_LOG_DIR="`${CLAUDE_HOME}/logs"
CLAUDE_LOCK_TIMEOUT="5"
CLAUDE_CACHE_MAX_AGE="3600"

export CLAUDE_CONTEXT_MODE
export CLAUDE_ENABLE_CACHE
export CLAUDE_INJECT_PROBABILITY
export CLAUDE_HOME
export CLAUDE_HOOKS_DIR
export CLAUDE_HISTORY_DIR
export CLAUDE_SUMMARY_DIR
export CLAUDE_CACHE_DIR
export CLAUDE_LOG_DIR
export CLAUDE_LOCK_TIMEOUT
export CLAUDE_CACHE_MAX_AGE
"@
    Set-Content -Path "$INSTALL_DIR\config.sh" -Value $configShContent -Encoding UTF8
    
    Write-ColoredOutput "✓ 설정 파일 생성 완료" "Green"
}

# Claude 설정 업데이트
function Update-ClaudeConfig {
    $claudeConfig = "$env:USERPROFILE\.claude\settings.json"
    
    if (-not (Test-Path $claudeConfig)) {
        Write-ColoredOutput "Claude 설정 파일을 찾을 수 없습니다." "Yellow"
        Write-Host "Claude Code를 한 번 실행한 후 다시 시도해주세요."
        return
    }
    
    Write-Host "Claude 설정을 업데이트하는 중..."
    
    # 백업 생성
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
    
    # JSON 설정 업데이트
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        # Windows에서는 PowerShell 스크립트 사용
        $injectorPath = "$INSTALL_BASE\claude_context_injector.ps1".Replace('\', '/')
        $precompactPath = "$INSTALL_BASE\claude_context_precompact.ps1".Replace('\', '/')
        
        $config.hooks = @{
            PreToolUse = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command"
                            command = "powershell -ExecutionPolicy Bypass -File `"$injectorPath`""
                            timeout = 30000
                        }
                    )
                }
            )
            PreCompact = @(
                @{
                    matcher = ""
                    hooks = @(
                        @{
                            type = "command" 
                            command = "powershell -ExecutionPolicy Bypass -File `"$precompactPath`""
                            timeout = 1000
                        }
                    )
                }
            )
        }
        
        $config | ConvertTo-Json -Depth 10 | Set-Content $claudeConfig -Encoding UTF8
        Write-ColoredOutput "✓ Claude 설정 업데이트 완료" "Green"
    }
    catch {
        Write-ColoredOutput "Claude 설정 업데이트 중 오류가 발생했습니다: $_" "Red"
    }
}

# 디렉토리 생성
function New-Directories {
    param([string]$SelectedMode)
    
    # 기본 디렉토리 - Out-Null 대신 $null 할당
    $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude") -Force
    $null = New-Item -ItemType Directory -Path (Join-Path $env:LOCALAPPDATA "claude-context") -Force
    
    # History/OAuth/Auto/Advanced 모드 디렉토리
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\history") -Force
        $null = New-Item -ItemType Directory -Path (Join-Path $env:USERPROFILE ".claude\summaries") -Force
    }
}

# 사용법 출력
function Show-Usage {
    param([string]$SelectedMode)
    
    Write-Host ""
    Write-ColoredOutput "🎉 설치가 완료되었습니다!" "Green"
    Write-Host ""
    Write-ColoredOutput "설치 위치: $INSTALL_DIR" "Blue"
    Write-ColoredOutput "설치된 모드: $($SelectedMode.ToUpper())" "Blue"
    Write-Host ""
    Write-ColoredOutput "⚠️  주의: PreCompact hook은 Claude Code v1.0.48+ 에서만 작동합니다." "Yellow"
    Write-ColoredOutput "   낮은 버전에서는 PreToolUse hook만 사용됩니다." "Yellow"
    Write-Host ""
    Write-Host "다음 단계:"
    Write-Host "1. CLAUDE.md 파일 생성:"
    Write-Host "   - 전역: $env:USERPROFILE\.claude\CLAUDE.md"
    Write-Host "   - 프로젝트별: <프로젝트루트>\CLAUDE.md"
    Write-Host ""
    
    if ($SelectedMode -in @("history", "oauth", "auto", "advanced")) {
        Write-Host "2. 대화 기록 관리:"
        Write-Host "   $INSTALL_DIR\src\monitor\claude_history_manager.sh --help"
        Write-Host ""
    }
    
    switch ($SelectedMode) {
        "oauth" {
            Write-Host "3. 자동 요약 기능 (Claude Code OAuth 사용)"
            Write-Host "   Claude Code의 인증 정보를 자동으로 사용합니다."
            Write-Host "   별도의 API 키가 필요하지 않습니다!"
            Write-Host ""
        }
        "auto" {
            Write-Host "3. 자동 요약 기능 (Claude CLI 사용)"
            Write-Host "   현재 Claude Code 세션에서는 작동하지 않습니다."
            Write-Host "   별도의 Claude CLI 설치가 필요합니다."
            Write-Host ""
        }
        "advanced" {
            Write-Host "3. Gemini API 설정:"
            Write-Host "   `$env:GEMINI_API_KEY = '<your-api-key>'"
            Write-Host ""
        }
    }
    
    Write-Host "4. Claude Code 재시작"
    Write-Host ""
    Write-Host "제거: $INSTALL_DIR\uninstall.ps1"
}

# 제거 기능
function Uninstall-ClaudeContext {
    Write-ColoredOutput "Claude Context를 제거하는 중..." "Yellow"
    
    # 설치 디렉토리 제거
    if (Test-Path $INSTALL_DIR) {
        Remove-Item -Recurse -Force $INSTALL_DIR
        Write-ColoredOutput "✓ 설치 디렉토리 제거 완료" "Green"
    }
    
    # Claude 설정에서 hooks 제거
    $claudeConfig = "$env:USERPROFILE\.claude\settings.json"
    if (Test-Path $claudeConfig) {
        try {
            $config = Get-Content $claudeConfig | ConvertFrom-Json
            $config.PSObject.Properties.Remove('hooks')
            $config | ConvertTo-Json -Depth 10 | Set-Content $claudeConfig -Encoding UTF8
            Write-ColoredOutput "✓ Claude 설정에서 hooks 제거 완료" "Green"
        }
        catch {
            Write-ColoredOutput "Claude 설정 업데이트 중 오류: $_" "Red"
        }
    }
    
    Write-ColoredOutput "🗑️ Claude Context 제거가 완료되었습니다." "Green"
}

# 메인 실행
function Main {
    Print-Header
    
    if ($Uninstall) {
        Uninstall-ClaudeContext
        return
    }
    
    # 모드 선택
    $selectedMode = Select-Mode
    Write-Host ""
    Write-ColoredOutput "선택한 모드: $selectedMode" "Blue"
    Write-Host ""
    
    # 의존성 확인
    Test-Dependencies $selectedMode
    
    # 백업 생성
    New-Backup
    
    # 설치 진행
    Install-Files
    New-Config $selectedMode
    New-Directories $selectedMode
    Update-ClaudeConfig
    
    # 완료 메시지
    Show-Usage $selectedMode
}

# 스크립트 실행
Main