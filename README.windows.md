# Claude Context - Windows 설치 가이드

> 🤖 Windows 환경에서 Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 자동화 도구

## 🚀 빠른 시작 (Windows)

### 원클릭 설치

**PowerShell** (관리자 권한 없이 실행 가능):
```powershell
Invoke-Expression (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1").Content
```

### 수동 설치

```powershell
git clone https://github.com/physics91/claude-context.git
cd claude-context
.\install\install.ps1
```

## 📋 Windows 요구사항

- **PowerShell 5.0+** (Windows 10/11에 기본 설치됨)
- **Claude Code v1.0.48+**
- **Git for Windows** ([다운로드](https://git-scm.com/download/win))
- (선택) **Visual Studio Code** - 더 나은 스크립트 편집을 위해

## 🎯 Windows 특화 기능

### PowerShell 네이티브 지원
- Windows PowerShell과 PowerShell Core (7+) 모두 지원
- 실행 정책 우회를 통한 간편한 설치
- Windows 경로 구조 자동 처리

### Git Bash 호환성
- Git Bash에서도 Linux/macOS 스크립트 실행 가능
- 대화 기록 관리자는 Git Bash 환경에서 실행

### Windows 디렉토리 구조
```
%USERPROFILE%\.claude\
├── hooks\
│   ├── claude-context\          # 메인 설치 디렉토리
│   ├── claude_context_injector.ps1
│   └── claude_context_precompact.ps1
├── history\                     # 대화 기록 (History 모드 이상)
├── summaries\                   # 자동 요약 파일
└── CLAUDE.md                    # 전역 컨텍스트 파일
```

## 📖 Windows 사용법

### 1. CLAUDE.md 파일 생성

**PowerShell로 전역 설정 생성:**
```powershell
# 전역 설정 생성
New-Item -ItemType File -Path "$env:USERPROFILE\.claude\CLAUDE.md" -Force
Add-Content -Path "$env:USERPROFILE\.claude\CLAUDE.md" -Value "# 전역 규칙"
Add-Content -Path "$env:USERPROFILE\.claude\CLAUDE.md" -Value "- 한국어로 대화하세요"
Add-Content -Path "$env:USERPROFILE\.claude\CLAUDE.md" -Value "- 상세한 설명을 제공하세요"
```

**프로젝트별 설정:**
```powershell
# 현재 디렉토리에 프로젝트별 설정
New-Item -ItemType File -Path ".\CLAUDE.md" -Force
Add-Content -Path ".\CLAUDE.md" -Value "# 이 프로젝트 전용 규칙"
Add-Content -Path ".\CLAUDE.md" -Value "- TypeScript 사용"
Add-Content -Path ".\CLAUDE.md" -Value "- React 18 기준 코드 작성"
```

### 2. 모드 설정

```powershell
# 대화형 모드 설정
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\install\configure_hooks.ps1"
```

**사용 가능한 모드:**
- `Basic` - CLAUDE.md 주입만
- `History` - 대화 기록 관리 추가  
- `OAuth` - 자동 요약 (Claude Code 인증) ⭐️ **추천**
- `Auto` - 자동 요약 (Claude CLI 필요)
- `Advanced` - 자동 요약 (Gemini CLI 필요)

### 3. Claude Code 재시작

설정 완료 후 Claude Code를 재시작하면 적용됩니다.

## 🔧 Windows 고급 설정

### 환경 변수 설정

**자동 설정 (권장):**
설치 시 생성된 PowerShell 설정 파일을 사용:
```powershell
# PowerShell 프로필에 추가 ($PROFILE)
. "$env:USERPROFILE\.claude\hooks\claude-context\config.ps1"
```

**수동 설정:**
```powershell
# 기본 Claude Context 환경 변수
$env:CLAUDE_CONTEXT_MODE = "history"  # basic, history, oauth, auto, advanced
$env:CLAUDE_ENABLE_CACHE = "true"
$env:CLAUDE_INJECT_PROBABILITY = "1.0"

# 디렉토리 설정
$env:CLAUDE_HOME = "$env:USERPROFILE\.claude"
$env:CLAUDE_HISTORY_DIR = "$env:USERPROFILE\.claude\history"
$env:CLAUDE_SUMMARY_DIR = "$env:USERPROFILE\.claude\summaries"
$env:CLAUDE_CACHE_DIR = "$env:LOCALAPPDATA\claude-context"

# 고급 설정
$env:CLAUDE_MD_INJECT_PROBABILITY = "0.8"  # 주입 확률 조정 (0.0 ~ 1.0)
$env:CLAUDE_DEBUG = "true"                 # 디버그 모드 활성화
```

### 대화 기록 관리 (Git Bash)

Windows에서는 Git Bash를 통해 대화 기록 관리자를 사용합니다:

```bash
# Git Bash에서 실행
MANAGER="$USERPROFILE/.claude/hooks/claude-context/src/monitor/claude_history_manager.sh"

# 세션 목록
$MANAGER list

# 대화 검색
$MANAGER search "검색어"

# 내보내기
$MANAGER export <session_id> markdown output.md
```

### PowerShell에서 직접 관리

```powershell
# 대화 기록 목록
Get-ChildItem "$env:USERPROFILE\.claude\history" | Sort-Object LastWriteTime -Descending

# 최신 대화 보기
Get-Content (Get-ChildItem "$env:USERPROFILE\.claude\history" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

# 대화 검색
Get-ChildItem "$env:USERPROFILE\.claude\history" | ForEach-Object {
    if ((Get-Content $_.FullName) -match "검색어") {
        Write-Host $_.Name
    }
}
```

## 🔍 Windows 문제 해결

### 실행 정책 오류

```powershell
# 임시로 실행 정책 우회
PowerShell -ExecutionPolicy Bypass -File "script.ps1"

# 또는 현재 사용자만 허용
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 권한 문제

```powershell
# 관리자 권한으로 PowerShell 실행
Start-Process PowerShell -Verb RunAs

# 파일 권한 확인
Get-Acl "$env:USERPROFILE\.claude" | Format-List
```

### Claude 설정 확인

```powershell
# settings.json 내용 확인
$settings = Get-Content "$env:USERPROFILE\.claude\settings.json" | ConvertFrom-Json
$settings.hooks | ConvertTo-Json -Depth 5

# hooks 설정 유무 확인
if ($settings.hooks) {
    Write-Host "✓ hooks 설정이 있습니다" -ForegroundColor Green
} else {
    Write-Host "✗ hooks 설정이 없습니다" -ForegroundColor Red
}
```

### 로그 확인

```powershell
# Claude 로그 파일 찾기
Get-ChildItem "$env:TEMP" -Filter "claude_*.log" | Sort-Object LastWriteTime -Descending

# 최신 로그 내용 보기
Get-Content (Get-ChildItem "$env:TEMP" -Filter "claude_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName -Tail 20
```

## 🗑️ 제거 (Windows)

```powershell
# 제거 스크립트 실행
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\install\uninstall.ps1"

# 강제 제거 (확인 없이)
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\install\uninstall.ps1" -Force
```

**수동 정리가 필요한 경우:**

```powershell
# 모든 관련 파일 제거
Remove-Item -Recurse -Force "$env:USERPROFILE\.claude\hooks\claude-context"
Remove-Item -Force "$env:USERPROFILE\.claude\hooks\claude_context_*.ps1"

# Claude 설정에서 hooks 제거
$settings = Get-Content "$env:USERPROFILE\.claude\settings.json" | ConvertFrom-Json
$settings.PSObject.Properties.Remove('hooks')
$settings | ConvertTo-Json -Depth 10 | Set-Content "$env:USERPROFILE\.claude\settings.json"
```

## 💡 Windows 팁

### 1. PowerShell 프로필 활용
```powershell
# 프로필 생성
if (!(Test-Path $PROFILE)) { New-Item -Type File -Path $PROFILE -Force }

# Claude Context 관련 함수 추가
notepad $PROFILE
```

### 2. VS Code 통합
```powershell
# VS Code에서 PowerShell 스크립트 편집
code "$env:USERPROFILE\.claude\CLAUDE.md"
code "$env:USERPROFILE\.claude\hooks\claude-context\config.sh"
```

### 3. 바로가기 생성
```powershell
# 모드 설정 바로가기
$shortcut = "$env:USERPROFILE\Desktop\Claude Context 설정.lnk"
$target = "PowerShell.exe"
$arguments = "-ExecutionPolicy Bypass -File `"$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1`""

$shell = New-Object -ComObject WScript.Shell
$link = $shell.CreateShortcut($shortcut)
$link.TargetPath = $target
$link.Arguments = $arguments
$link.Save()
```

## 🤝 기여하기

Windows 환경 개선에 도움을 주세요:

1. Windows 특화 버그 리포트
2. PowerShell 스크립트 최적화
3. Windows 사용자 가이드 개선
4. Git Bash 호환성 테스트

## 📞 지원

- **GitHub Issues**: [리포트 작성](https://github.com/physics91/claude-context/issues)
- **Windows 전용 태그**: `windows`, `powershell` 태그 사용
- **문서**: [메인 README](./README.md)

---

**Windows 사용자를 위한 특별 제작** ❤️