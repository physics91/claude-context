# Claude Context

> 🤖 Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 자동화 도구

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## 🚀 빠른 시작

### 설치

```bash
# 1. 저장소 클론 (private repo)
git clone https://github.com/physics91/claude-context.git
cd claude-context

# 2. 설치 실행
./install.sh
```

### 한 줄 설치 (공개 후)

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install.sh | bash
```

## 🎯 주요 기능

- ✅ **자동 컨텍스트 주입**: Claude Code가 도구를 사용할 때마다 CLAUDE.md 내용 자동 전달
- ✅ **대화 압축 보호**: PreCompact hook으로 긴 대화에서도 컨텍스트 유지
- ✅ **전역/프로젝트별 설정**: 기본 설정과 프로젝트별 설정 모두 지원
- ✅ **스마트 캐싱**: SHA256 해시 기반 변경 감지 및 gzip 압축 캐싱
- ✅ **즉시 반영**: 파일 수정 시 다음 실행부터 자동 적용
- ✅ **경량 & 빠른 성능**: 캐시 히트 시 ~10ms
- 🆕 **토큰 효율성 모니터링**: 긴 대화 자동 요약으로 토큰 절약 (선택사항)

## 📋 요구사항

- Claude Code (Claude Desktop App) **v1.0.41 이상**
  - v1.0.38에서 hooks 첫 도입, v1.0.41에서 안정화
  - PreCompact hook 지원을 위해 v1.0.41 이상 권장
  - 버전 확인: Claude Code 메뉴 → About
- Bash shell
- 기본 Unix 도구: `jq`, `sha256sum`, `gzip`, `zcat`
  - 설치 스크립트가 자동으로 설치 제안
  - 또는 수동 설치: `sudo apt install jq coreutils gzip`

## 📖 사용법

### 1. CLAUDE.md 파일 생성

**전역 설정** (`~/.claude/CLAUDE.md`):
```markdown
# 기본 개발 지침
- 코드는 명확하고 간결하게 작성
- 의미 있는 변수명 사용
- 주석은 필요한 곳에만
```

**프로젝트별 설정** (`프로젝트루트/CLAUDE.md`):
```markdown
# 프로젝트 규칙
- TypeScript 4.9+ 사용
- ESLint airbnb 규칙 준수
- 모든 함수에 JSDoc 작성
```

### 2. 모니터링

```bash
# 대화형 모니터 실행
~/.claude/hooks/claude_md_monitor.sh

# 로그 분석
~/.claude/hooks/claude_md_monitor.sh log

# 캐시 상태 확인
~/.claude/hooks/claude_md_monitor.sh cache
```

## 🔧 고급 설정

### 첫 대화 커버리지 보장

Claude가 도구를 사용하지 않는 대화에서도 CLAUDE.md를 인식하도록 하려면, CLAUDE.md 파일 상단에 다음과 같은 대화 시작 규칙을 추가하세요:

```markdown
## 🚀 대화 시작 규칙
새로운 대화 시작 시 반드시:
1. Read 도구로 README.md 또는 package.json 읽기
2. 없다면 LS 도구로 디렉토리 구조 확인
```

이렇게 하면 첫 대화부터 도구를 사용하게 되어 PreToolUse hook이 실행됩니다.

### Hook 타입

설치 시 두 가지 hook이 자동으로 설정됩니다:

1. **PreToolUse**: 도구 사용 전 CLAUDE.md 주입
2. **PreCompact**: 대화 압축 전 CLAUDE.md 재주입 (긴 대화 대응)

### 선택적 섹션 (향후 지원 예정)

```markdown
## @always
항상 포함되는 내용

## @python
Python 파일 작업 시에만

## @test
테스트 작성 시에만
```

## 🆕 토큰 효율성 모니터링 (선택사항)

긴 대화나 반복적인 토론으로 토큰을 빠르게 소비하는 경우를 위한 자동 요약 기능:

### 설정 방법

```bash
# 설정 업데이트 스크립트 실행
~/.claude/hooks/update_hooks_config_enhanced.sh

# 옵션 2 선택: "토큰 모니터링 포함"
```

### 기능

- **자동 대화 추적**: 모든 도구 사용 기록
- **스마트 요약**: 30개 메시지 또는 5000토큰 초과 시 자동 요약
- **Gemini 통합**: 효율적인 요약 생성 (gemini 명령 필요)
- **이전 컨텍스트 보존**: 요약된 내용도 PreCompact 시 자동 주입

### 데이터 위치

- 대화 기록: `~/.claude/history/`
- 요약 파일: `~/.claude/summaries/`
- 정리 명령: `~/.claude/hooks/claude_token_monitor_safe.sh cleanup`

### 주의사항

- `gemini` 명령이 없으면 요약 기능 제한
- 파일 시스템에 추가 I/O 발생
- 베타 기능으로 안정성 테스트 중

## 🗑️ 제거

```bash
~/.claude/hooks/install.sh --uninstall
```

## 📊 성능

- 첫 실행: ~100ms (파일 읽기 + 압축)
- 캐시 히트: ~10ms
- 캐시 크기: 프로젝트당 ~5KB
- 메모리 사용: < 10MB

## 🤝 기여하기

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📝 라이선스

MIT License - 자유롭게 사용하세요!

## 🙏 감사의 말

이 프로젝트는 Claude와 Gemini의 도움으로 만들어졌습니다.