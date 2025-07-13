# Claude Context

> 🤖 Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 자동화 도구

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage: 100%](https://img.shields.io/badge/Coverage-100%25-brightgreen.svg)](./tests)

## 🚀 빠른 시작

### 원클릭 설치

```bash
curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
```

### 수동 설치

```bash
git clone https://github.com/physics91/claude-context.git
cd claude-context
./install/install.sh
```

## 🎯 주요 기능

### 핵심 기능
- ✅ **자동 컨텍스트 주입**: Claude가 도구 사용 시 CLAUDE.md 자동 로드
- ✅ **대화 압축 보호**: 긴 대화에서도 컨텍스트 유지 (PreCompact hook, v1.0.48+)
- ✅ **전역/프로젝트별 설정**: 유연한 컨텍스트 관리
- ✅ **스마트 캐싱**: 빠른 성능 (~10ms)

### 고급 기능 (선택사항)
- 🆕 **대화 기록 관리**: Gemini 없이 독립적으로 작동
- 🆕 **자동 대화 추적**: 모든 대화 자동 저장 및 검색
- 🆕 **토큰 효율성 모니터링**: Gemini 연동으로 지능적 요약

## 📋 요구사항

- **Claude Code v1.0.48+** (PreCompact hook 지원은 v1.0.48부터)
  - v1.0.41 ~ v1.0.47: PreToolUse hook만 지원 (기본 기능은 작동)
- Bash shell
- 기본 Unix 도구: `jq`, `sha256sum`, `gzip`
- (선택) `gemini` CLI - 토큰 모니터링 기능용

## 📖 사용법

### 1. CLAUDE.md 파일 생성

**전역 설정** (`~/.claude/CLAUDE.md`):
```markdown
# 모든 프로젝트에 적용되는 규칙
- 항상 테스트를 먼저 작성하세요
- 한국어로 대화하세요
```

**프로젝트별 설정** (`프로젝트루트/CLAUDE.md`):
```markdown
# 이 프로젝트 전용 규칙
- TypeScript 사용
- React 18 기준 코드 작성
```

### 2. 모드 설정

```bash
# 대화형 설정 (권장)
~/.claude/hooks/install/configure_hooks.sh

# 모드 선택:
# 1) Basic   - CLAUDE.md 주입만
# 2) History - 대화 기록 관리 (Gemini 불필요)
# 3) Advanced - 토큰 모니터링 (Gemini 필요)
```

### 3. Claude Code 재시작

설정 변경 후 Claude Code를 재시작하면 적용됩니다.

## 🔧 고급 설정

### 대화 기록 관리 (Gemini 불필요)

모든 대화를 자동으로 추적하고 관리합니다:

```bash
# 대화 기록 관리자 사용
MANAGER=~/.claude/hooks/src/monitor/claude_history_manager.sh

# 세션 목록 보기
$MANAGER list

# 대화 검색
$MANAGER search "검색어"

# 세션 내보내기 (markdown/json/txt)
$MANAGER export <session_id> markdown output.md
```

### 토큰 모니터링 활성화 (Gemini 필요)

더 지능적인 요약을 원하는 경우:

1. `gemini` CLI 설치
2. 고급 설정 선택:
   ```bash
   ~/.claude/hooks/install/update_hooks_config_enhanced.sh
   ```

### 환경 변수

```bash
# 주입 확률 조정 (0.0 ~ 1.0)
export CLAUDE_MD_INJECT_PROBABILITY=0.5

# 캐시 디렉토리 변경
export XDG_CACHE_HOME=/custom/cache/path
```

## 🗂️ 프로젝트 구조

```
claude-context/
├── src/
│   ├── core/
│   │   ├── injector.sh      # 통합 injector (모든 모드 지원)
│   │   └── precompact.sh    # 통합 precompact hook
│   ├── monitor/
│   │   ├── claude_history_manager.sh  # 대화 기록 관리
│   │   └── claude_token_monitor_safe.sh  # 토큰 모니터링
│   └── utils/
│       └── common_functions.sh  # 공통 함수 라이브러리
├── install/
│   ├── install.sh           # 설치 스크립트
│   ├── configure_hooks.sh   # 모드 설정 스크립트
│   └── one-line-install.sh  # 원클릭 설치
├── tests/                   # 테스트 스위트
├── docs/                    # 상세 문서
├── config.sh.template       # 설정 템플릿
└── MIGRATION_GUIDE.md       # 마이그레이션 가이드
```

## 🧪 테스트

```bash
# 전체 테스트 실행
./tests/test_all.sh

# 개별 컴포넌트 테스트
./tests/test_claude_md_hook.sh
./tests/test_token_monitor.sh
```

## 🗑️ 제거

```bash
~/.claude/hooks/install/install.sh --uninstall
```

## 🤝 기여하기

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing`)
5. Open a Pull Request

## 📊 성능

- 첫 실행: ~100ms
- 캐시 히트: ~10ms
- 메모리 사용: < 10MB

## 🔍 문제 해결

### Claude가 CLAUDE.md를 인식하지 못할 때
1. Claude Code 재시작
2. 설정 확인: `cat ~/.claude/settings.json | jq .hooks`
3. 로그 확인: `tail -f /tmp/claude_*.log`

### 토큰 모니터링이 작동하지 않을 때
1. `gemini` 설치 확인
2. 대화 기록 확인: `ls ~/.claude/history/`
3. 권한 확인: `ls -la ~/.claude/`

## 📝 라이선스

MIT License - 자유롭게 사용하세요!

## 🙏 감사의 말

이 프로젝트는 Claude와 Gemini의 협업으로 만들어졌습니다.