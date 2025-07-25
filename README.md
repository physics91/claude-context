# Claude Context

<div align="center">

[English](./README.en.md) | [中文](./README.zh.md) | [日본語](./README.ja.md) | **한국어**

</div>

> 🤖 Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 자동화 도구

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 📋 요구사항

- **Claude Code v1.0.54+** (PreCompact hook 지원)
- **OS별 요구사항:**
  - Linux/macOS: Bash, `jq`, `sha256sum`, `gzip`
  - Windows: PowerShell 5.0+, Git for Windows

## 🚀 설치

### 원클릭 설치

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

### 수동 설치

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh  # Linux/macOS
.\install\install.ps1  # Windows
```

## 🔧 설정

### 1. CLAUDE.md 파일 생성

**전역 설정** (`~/.claude/CLAUDE.md`):
```markdown
# 모든 프로젝트에 적용되는 규칙
- 한국어로 대화하세요
- 테스트 코드를 먼저 작성하세요
```

**프로젝트별 설정** (`프로젝트루트/CLAUDE.md`):
```markdown
# 이 프로젝트 전용 규칙
- TypeScript 사용
- React 18 기준
```

### 2. Claude Code 재시작

설정이 자동으로 적용됩니다.

## 💡 작동 원리

### Hook 시스템
Claude Code의 Hook 시스템을 활용하여 자동으로 컨텍스트를 주입합니다:

1. **PreToolUse/UserPromptSubmit Hook**: Claude가 도구를 사용하거나 프롬프트를 받을 때 CLAUDE.md 주입
2. **PreCompact Hook**: 대화가 길어져 압축될 때 컨텍스트 보호
3. **스마트 캐싱**: 동일한 파일은 캐시를 사용하여 성능 최적화 (~10ms)

### 우선순위
1. 프로젝트별 CLAUDE.md (현재 작업 디렉토리)
2. 전역 CLAUDE.md (~/.claude/)
3. 두 파일이 모두 있으면 자동 병합

## 🎯 고급 기능

### 모드 변경
```bash
# Linux/macOS
~/.claude/hooks/install/configure_hooks.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\install\configure_hooks.ps1"
```

**사용 가능한 모드:**
- **Basic**: CLAUDE.md 주입만 (기본값)
- **History**: 대화 기록 자동 저장
- **OAuth**: Claude Code 인증으로 자동 요약 ⭐
- **Advanced**: Gemini CLI로 토큰 모니터링

### Hook 타입 선택
```bash
# 설치 시 Hook 타입 지정
./install/install.sh --hook-type UserPromptSubmit  # 또는 PreToolUse
```

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

**강제 업데이트 (버전 확인 생략):**
```bash
# Linux/macOS
CLAUDE_UPDATE_FORCE=true curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash

# Windows
$env:CLAUDE_UPDATE_FORCE = "true"; iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
```

**백업 보관 개수 설정:**
```bash
# Linux/macOS (기본값: 5개)
CLAUDE_UPDATE_BACKUP_KEEP=10 curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash

# Windows
$env:CLAUDE_UPDATE_BACKUP_KEEP = "10"; iex (irm https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.ps1)
```

### 주요 기능
- ✅ **자동 백업**: 업데이트 전 기존 버전 자동 백업
- ✅ **설정 보존**: 사용자 설정 및 CLAUDE.md 파일 유지
- ✅ **실패 시 롤백**: 오류 발생 시 자동으로 이전 버전 복원
- ✅ **버전 관리**: Semantic Versioning 지원
- ✅ **크로스 플랫폼**: Windows/Linux/macOS 지원

자세한 업데이트 가이드는 [UPDATE.md](./docs/UPDATE.md)를 참조하세요.

## 🗑️ 제거

```bash
# Linux/macOS
~/.claude/hooks/claude-context/uninstall.sh

# Windows
PowerShell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.claude\hooks\claude-context\uninstall.ps1"
```

## 🔍 문제 해결

### Claude가 CLAUDE.md를 인식하지 못할 때
1. Claude Code 재시작
2. 설정 확인: `~/.claude/settings.json`의 hooks 섹션
3. 로그 확인: `/tmp/claude_*.log` (Linux/macOS) 또는 `%TEMP%\claude_*.log` (Windows)

### 자세한 문서
- [설치 가이드](./docs/installation.md)
- [고급 설정](./docs/advanced.md)
- [문제 해결](./docs/troubleshooting.md)

## 📝 라이선스

MIT License