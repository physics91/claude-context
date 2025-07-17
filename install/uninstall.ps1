# Claude Context 제거 스크립트 (Windows PowerShell)

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
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

# 설정
$INSTALL_BASE = "$env:USERPROFILE\.claude\hooks"
$INSTALL_DIR = "$INSTALL_BASE\claude-context"
$CONFIG_FILE = "$INSTALL_BASE\claude-context.conf"

# 헤더 출력
function Print-Header {
    Write-ColoredOutput "╔════════════════════════════════════════╗" "Red"
    Write-ColoredOutput "║     Claude Context 제거                ║" "Red"
    Write-ColoredOutput "╚════════════════════════════════════════╝" "Red"
    Write-Host ""
}

# 확인 요청
function Confirm-Uninstall {
    if ($Force) {
        return $true
    }
    
    Write-ColoredOutput "다음 항목들이 제거됩니다:" "Yellow"
    Write-Host ""
    
    if (Test-Path $INSTALL_DIR) {
        Write-Host "  - 설치 디렉토리: $INSTALL_DIR"
    }
    
    if (Test-Path $CONFIG_FILE) {
        Write-Host "  - 설정 파일: $CONFIG_FILE"
    }
    
    if (Test-Path "$INSTALL_BASE\claude_context_injector.ps1") {
        Write-Host "  - Injector 스크립트: $INSTALL_BASE\claude_context_injector.ps1"
    }
    
    if (Test-Path "$INSTALL_BASE\claude_context_precompact.ps1") {
        Write-Host "  - PreCompact 스크립트: $INSTALL_BASE\claude_context_precompact.ps1"
    }
    
    Write-Host "  - Claude Code 설정에서 hooks 제거"
    Write-Host ""
    
    Write-ColoredOutput "⚠️  대화 기록과 요약 파일은 보존됩니다." "Yellow"
    Write-Host "   (제거하려면: Remove-Item -Recurse '$env:USERPROFILE\.claude\history')"
    Write-Host ""
    
    $confirm = Read-Host "계속하시겠습니까? [y/N]"
    return $confirm -match "^[Yy]$"
}

# Claude 설정에서 hooks 제거
function Remove-ClaudeHooks {
    $claudeConfig = "$env:USERPROFILE\.claude\settings.json"
    
    if (-not (Test-Path $claudeConfig)) {
        Write-ColoredOutput "Claude 설정 파일을 찾을 수 없습니다." "Yellow"
        return
    }
    
    Write-Host "Claude 설정에서 hooks를 제거하는 중..."
    
    # 백업 생성
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    Copy-Item $claudeConfig "$claudeConfig.backup.$timestamp"
    
    try {
        $config = Get-Content $claudeConfig | ConvertFrom-Json
        
        # hooks 속성 제거 - 안전한 처리
        if ($config.PSObject.Properties['hooks']) {
            $config.PSObject.Properties.Remove('hooks')
            $config | ConvertTo-Json -Depth 10 | Set-Content $claudeConfig -Encoding UTF8
            Write-ColoredOutput "✓ Claude 설정에서 hooks 제거 완료" "Green"
        } else {
            Write-ColoredOutput "hooks 설정이 이미 제거되어 있습니다." "Yellow"
        }
    }
    catch {
        Write-ColoredOutput "Claude 설정 업데이트 중 오류: $_" "Red"
        Write-Host "수동으로 hooks 설정을 제거해야 할 수 있습니다."
    }
}

# 파일 및 디렉토리 제거
function Remove-Files {
    $removedItems = @()
    
    # 설치 디렉토리 제거
    if (Test-Path $INSTALL_DIR) {
        try {
            Remove-Item -Recurse -Force $INSTALL_DIR
            $removedItems += "설치 디렉토리"
            Write-ColoredOutput "✓ 설치 디렉토리 제거 완료" "Green"
        }
        catch {
            Write-ColoredOutput "설치 디렉토리 제거 실패: $_" "Red"
        }
    }
    
    # 설정 파일 제거
    if (Test-Path $CONFIG_FILE) {
        try {
            Remove-Item -Force $CONFIG_FILE
            $removedItems += "설정 파일"
            Write-ColoredOutput "✓ 설정 파일 제거 완료" "Green"
        }
        catch {
            Write-ColoredOutput "설정 파일 제거 실패: $_" "Red"
        }
    }
    
    # wrapper 스크립트 제거
    $wrapperScripts = @(
        "$INSTALL_BASE\claude_context_injector.ps1",
        "$INSTALL_BASE\claude_context_precompact.ps1"
    )
    
    foreach ($script in $wrapperScripts) {
        if (Test-Path $script) {
            try {
                Remove-Item -Force $script
                $removedItems += "Wrapper 스크립트"
                Write-ColoredOutput "✓ $(Split-Path -Leaf $script) 제거 완료" "Green"
            }
            catch {
                Write-ColoredOutput "$(Split-Path -Leaf $script) 제거 실패: $_" "Red"
            }
        }
    }
    
    return $removedItems
}

# 정리 확인
function Test-Cleanup {
    $remaining = @()
    
    if (Test-Path $INSTALL_DIR) {
        $remaining += "설치 디렉토리"
    }
    
    if (Test-Path $CONFIG_FILE) {
        $remaining += "설정 파일"
    }
    
    if (Test-Path "$INSTALL_BASE\claude_context_injector.ps1") {
        $remaining += "Injector 스크립트"
    }
    
    if (Test-Path "$INSTALL_BASE\claude_context_precompact.ps1") {
        $remaining += "PreCompact 스크립트"
    }
    
    # Claude 설정 확인
    $claudeConfig = "$env:USERPROFILE\.claude\settings.json"
    if (Test-Path $claudeConfig) {
        try {
            $config = Get-Content $claudeConfig | ConvertFrom-Json
            if ($config.PSObject.Properties.Name -contains 'hooks') {
                $remaining += "Claude 설정의 hooks"
            }
        }
        catch {
            # JSON 파싱 실패는 무시
        }
    }
    
    return $remaining
}

# 완료 메시지
function Show-CompletionMessage {
    param([array]$RemovedItems, [array]$RemainingItems)
    
    Write-Host ""
    if ($RemovedItems.Count -gt 0) {
        Write-ColoredOutput "🗑️ 다음 항목들이 제거되었습니다:" "Green"
        foreach ($item in $RemovedItems) {
            Write-Host "  ✓ $item"
        }
        Write-Host ""
    }
    
    if ($RemainingItems.Count -gt 0) {
        Write-ColoredOutput "⚠️  다음 항목들이 남아있습니다:" "Yellow"
        foreach ($item in $RemainingItems) {
            Write-Host "  - $item"
        }
        Write-Host ""
        Write-Host "수동으로 제거가 필요할 수 있습니다."
        Write-Host ""
    }
    
    Write-ColoredOutput "대화 기록 및 요약 파일:" "Blue"
    Write-Host "  - 위치: $env:USERPROFILE\.claude\history"
    Write-Host "  - 위치: $env:USERPROFILE\.claude\summaries"
    Write-Host "  - 수동 제거: Remove-Item -Recurse '$env:USERPROFILE\.claude\history'"
    Write-Host ""
    
    Write-ColoredOutput "다음 단계:" "Blue"
    Write-Host "1. Claude Code를 재시작하세요"
    Write-Host "2. 필요시 Claude Code 설정을 확인하세요"
    Write-Host ""
    
    if ($RemainingItems.Count -eq 0) {
        Write-ColoredOutput "✅ Claude Context 제거가 완료되었습니다!" "Green"
    } else {
        Write-ColoredOutput "⚠️  일부 항목의 수동 제거가 필요합니다." "Yellow"
    }
}

# 메인 실행
function Main {
    Print-Header
    
    # 설치 확인
    if (-not (Test-Path $INSTALL_DIR) -and -not (Test-Path $CONFIG_FILE)) {
        Write-ColoredOutput "Claude Context가 설치되어 있지 않습니다." "Yellow"
        exit 0
    }
    
    # 확인 요청
    if (-not (Confirm-Uninstall)) {
        Write-ColoredOutput "제거가 취소되었습니다." "Yellow"
        exit 0
    }
    
    Write-Host ""
    Write-Host "제거를 시작합니다..."
    Write-Host ""
    
    # Claude hooks 제거
    Remove-ClaudeHooks
    
    # 파일 제거
    $removedItems = Remove-Files
    
    # 정리 확인
    $remainingItems = Test-Cleanup
    
    # 완료 메시지
    Show-CompletionMessage $removedItems $remainingItems
}

# 스크립트 실행
Main