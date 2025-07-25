# Claude Context 설치 가이드

Claude Context는 Claude Code가 항상 프로젝트의 컨텍스트를 인식하도록 하는 자동화 도구입니다.

## 🚀 원클릭 설치 (추천)

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

**Windows (PowerShell):**
```powershell
# 권장: 스크립트 다운로드 후 실행
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.ps1" -OutFile "install.ps1"
PowerShell -ExecutionPolicy Bypass -File .\install.ps1
```

## 📦 수동 설치

1. 저장소 클론:
```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
```

2. 설치 스크립트 실행:
```bash
# Linux/macOS
./install/install.sh

# Windows
.\install\install.ps1
```

## 🔧 필수 요구사항

### Claude Code
- **권장 버전: v1.0.54+** (PreCompact hook 지원)
- **최소 버전: v1.0.48** (PreToolUse hook 지원)
- v1.0.38에서 hooks 기능 추가
- v1.0.41에서 hook_event_name, timeout 설정 등 개선
- v1.0.48에서 PreCompact hook 추가 (대화 압축 시 컨텍스트 보호)
- v1.0.54에서 UserPromptSubmit hook 추가 (더 안정적인 컨텍스트 주입)
- 버전 확인: Help → About Claude Code

### 시스템 도구

**Linux/macOS:**
다음 명령어들이 필요합니다 (설치 스크립트가 자동으로 확인):
- `jq` - JSON 처리
- `sha256sum` - 파일 해시 계산
- `gzip`, `zcat` - 압축 처리

Ubuntu/Debian:
```bash
sudo apt install jq coreutils gzip
```

macOS:
```bash
brew install jq coreutils
```

**Windows:**
- PowerShell 5.0+ (Windows 10/11에 기본 포함)
- Git for Windows (bash 환경 제공)

Git for Windows 설치:
```powershell
# Chocolatey 사용
choco install git

# Scoop 사용
scoop install git

# 또는 공식 웹사이트에서 다운로드
# https://git-scm.com/download/win
```

## 🎯 주요 기능

- ✅ 전역 및 프로젝트별 CLAUDE.md 자동 인식
- ✅ 효율적인 캐싱으로 빠른 성능
- ✅ 파일 변경 시 자동 감지 및 업데이트
- ✅ 다양한 OS 지원 (Linux, macOS, WSL)

## 📝 사용법

### CLAUDE.md 파일 생성

1. **전역 설정** (`~/.claude/CLAUDE.md`):
```markdown
## 기본 개발 지침
- 코드는 명확하고 간결하게
- 주석은 필요한 곳에만
- 테스트 코드 작성 필수
```

2. **프로젝트별 설정** (`프로젝트루트/CLAUDE.md`):
```markdown
## 프로젝트 규칙
- TypeScript 사용
- ESLint 규칙 준수
- 커밋 메시지는 conventional commits 형식
```

### 모니터링

설치 후 다음 명령으로 상태를 확인할 수 있습니다:

```bash
~/.claude/hooks/claude_md_monitor.sh
```

주요 기능:
- 로그 분석
- 캐시 상태 확인
- 실시간 모니터링
- 프로젝트별 테스트

## 🔄 업데이트

### 원클릭 업데이트

**Linux/macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash
```

**Windows (PowerShell):**
```powershell
iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
```

### 업데이트 옵션

**강제 업데이트:**
```bash
# Linux/macOS
CLAUDE_UPDATE_FORCE=true curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash

# Windows
$env:CLAUDE_UPDATE_FORCE = "true"; iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
```

자세한 업데이트 가이드는 [UPDATE.md](./UPDATE.md)를 참조하세요.

## 🗑️ 제거

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 문제 해결

### 설치가 안 될 때

1. 필수 명령어 확인:
```bash
command -v jq sha256sum gzip zcat
```

2. Claude 설정 파일 위치 확인:
```bash
ls ~/.claude/settings.json
```

### Hook이 작동하지 않을 때

1. 로그 확인:
```bash
tail -f /tmp/claude_md_injector.log
```

2. 수동 테스트:
```bash
~/.claude/hooks/test_claude_md_hook.sh
```

## 📊 성능

- 첫 실행: ~100ms
- 캐시 히트: ~10ms
- 메모리 사용: < 10MB
- 캐시 크기: 프로젝트당 ~5KB

## 🤝 기여하기

버그 리포트나 기능 제안은 GitHub Issues를 이용해주세요.

## 📄 라이선스

MIT License