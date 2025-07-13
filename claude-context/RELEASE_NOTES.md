# Claude Context v1.0.0 릴리즈 노트

## 🎉 정식 릴리즈

Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 **Claude Context**의 첫 정식 버전을 발표합니다!

## 🚀 주요 기능

### 핵심 기능
- **자동 컨텍스트 주입**: CLAUDE.md 파일의 내용을 Claude가 항상 인지
- **대화 압축 보호**: PreCompact hook으로 긴 대화에서도 컨텍스트 유지
- **전역/프로젝트별 설정**: 유연한 컨텍스트 관리
- **스마트 캐싱**: SHA256 해시 기반 캐싱으로 빠른 성능

### 고급 기능
- **토큰 효율성 모니터링**: 자동 대화 요약으로 토큰 절약
- **Gemini 통합**: 지능적인 요약 생성
- **대화 기록 관리**: 이전 대화 참조 가능

## 📦 설치

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

## 🔧 사용법

1. **전역 설정**: `~/.claude/CLAUDE.md` 생성
2. **프로젝트 설정**: `프로젝트루트/CLAUDE.md` 생성
3. Claude Code 재시작

## 💡 예시

### 전역 CLAUDE.md
```markdown
# 기본 규칙
- 항상 테스트를 먼저 작성하세요
- 한국어로 대화하세요
```

### 프로젝트 CLAUDE.md
```markdown
# 프로젝트 규칙
- TypeScript 사용
- React 18 기준
- Tailwind CSS 사용
```

## 🧪 품질 보증
- 100% 테스트 커버리지
- 크로스 플랫폼 지원 (macOS, Linux)
- 에러 복구 메커니즘
- 동시성 처리

## 🤝 기여자
- @physics91 - 프로젝트 리드
- Claude & Gemini - AI 페어 프로그래밍

## 📝 라이선스
MIT License

---

문제 발생 시 [이슈](https://github.com/physics91/claude-context/issues)를 등록해주세요!