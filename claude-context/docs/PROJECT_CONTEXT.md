# Claude Context 프로젝트 구조 및 리팩토링 계획

## 프로젝트 개요
Claude Code가 항상 프로젝트 컨텍스트를 기억하도록 하는 자동화 도구입니다.
- CLAUDE.md 파일의 내용을 자동으로 주입
- 토큰 효율성을 위한 대화 모니터링 및 자동 요약
- 100% 테스트 커버리지 달성

## 현재 디렉토리 구조
```
.claude/hooks/
├── 핵심 스크립트 (Core Scripts)
│   ├── claude_md_injector.sh              # 기본 PostToolUse hook
│   ├── claude_md_precompact.sh            # 기본 PreCompact hook
│   ├── claude_md_injector_with_monitor.sh # 토큰 모니터링 통합 버전
│   ├── claude_md_enhanced_precompact.sh   # 요약 통합 PreCompact
│   └── claude_token_monitor_safe.sh       # 토큰 모니터링 시스템
│
├── 설치/설정 (Installation)
│   ├── install.sh                         # 메인 설치 스크립트
│   ├── one-line-install.sh               # 원라인 설치
│   ├── update_hooks_config.sh            # 기본 설정 업데이트
│   └── update_hooks_config_enhanced.sh   # 향상된 설정 (선택적)
│
├── 테스트 (Tests)
│   ├── test_*.sh                         # 개별 컴포넌트 테스트
│   ├── test_all.sh                       # 통합 테스트 스위트
│   └── check_coverage.sh                 # 커버리지 체크
│
├── 문서 (Documentation)
│   ├── README.md                         # 메인 문서
│   ├── INSTALL.md                        # 설치 가이드
│   └── LICENSE                           # MIT 라이선스
│
├── 예제/템플릿 (Examples)
│   ├── examples/
│   └── templates/
│
└── 기타 (Others)
    ├── claude_playground/                # 테스트 환경
    └── 레거시 스크립트들
```

## 정리가 필요한 항목

### 1. 중복/레거시 파일
- `claude_md_monitor.sh` - 사용되지 않음
- `inject_claude_md.sh` - 레거시
- `claude_token_monitor.sh` - safe 버전으로 대체됨

### 2. 디렉토리 구조 개선안
```
.claude/hooks/
├── src/                    # 핵심 스크립트
│   ├── core/              # 메인 hooks
│   ├── monitor/           # 토큰 모니터링
│   └── utils/             # 유틸리티
├── install/               # 설치 관련
├── tests/                 # 테스트
├── docs/                  # 문서
├── examples/              # 예제
└── scripts/               # 헬퍼 스크립트
```

### 3. 문서 업데이트 필요
- README.md - 토큰 모니터링 기능 상세 설명
- INSTALL.md - 새로운 설치 옵션 반영
- CONTRIBUTING.md - 기여 가이드 추가
- ARCHITECTURE.md - 시스템 아키텍처 설명

### 4. 코드 리팩토링 포인트
1. **공통 함수 추출**
   - 프로젝트 루트 찾기
   - JSON 처리
   - 로깅 시스템

2. **설정 중앙화**
   - 환경 변수 통합
   - 기본값 정의

3. **에러 처리 표준화**
   - 일관된 에러 코드
   - 로깅 형식 통일

4. **성능 최적화**
   - 캐시 메커니즘 개선
   - 백그라운드 처리 최적화

## Gemini와 논의할 사항

1. **디렉토리 구조 최적화**
   - 어떤 구조가 가장 직관적인가?
   - 사용자 편의성 vs 개발자 편의성

2. **문서화 전략**
   - 어떤 문서가 우선순위가 높은가?
   - 사용자 가이드 vs 기술 문서

3. **배포 전략**
   - GitHub Actions 통합?
   - 버전 관리 방식?
   - 자동 업데이트 메커니즘?

4. **테스트 전략**
   - CI/CD 파이프라인?
   - 크로스 플랫폼 테스트?

5. **사용자 경험 개선**
   - 설치 프로세스 간소화
   - 에러 메시지 개선
   - 진단 도구 추가?

## 액션 아이템
1. [ ] 레거시 파일 정리
2. [ ] 디렉토리 구조 재구성
3. [ ] 공통 유틸리티 라이브러리 생성
4. [ ] 문서 전면 개편
5. [ ] 배포 자동화 설정

이 내용을 바탕으로 gemini와 상의하여 최적의 구조를 결정하고 실행하겠습니다.