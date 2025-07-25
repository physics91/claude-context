## Agent Workflow Routine (최중요)

### 워크플로우 구조
작업을 수행할 때 다음 순서로 에이전트를 활용합니다:

**Project Manager** → **Developer** → **Reviewer** → **Tester**

### 에이전트 역할 정의
1. **Project Manager**: 작업 계획 및 요구사항 분석
2. **Developer**: 실제 코드 작성 및 구현
3. **Reviewer**: 코드 품질 검토 및 개선사항 제안
4. **Tester**: 테스트 작성 및 실행, 품질 검증

### 순환 피드백 메커니즘
- **Reviewer** 단계에서 기준 미달 시 → **Developer**로 재순환
- **Tester** 단계에서 테스트 실패 시 → **Developer**로 재순환
- 모든 기준을 만족할 때까지 순환 반복

### 사용 예시
```
사용자 요청 → Project Manager (계획) → Developer (구현) → Reviewer (검토)
                                            ↗                      ↓
                                    문제 발견 시 재작업        기준 만족 시
                                            ↖                      ↓
                                      Developer ← Tester (테스트)
```

## Project Overview
Claude Context는 Claude Code가 항상 프로젝트 맥락을 기억하도록 하는 자동화 도구입니다.

### 핵심 기능
- CLAUDE.md 파일 자동 주입으로 컨텍스트 유지
- 토큰 효율성을 위한 대화 모니터링 및 자동 요약
- 크로스 플랫폼 지원 (Linux/macOS/Windows)
- Hook 시스템을 통한 원활한 통합

### 프로젝트 목표
1. 100% 테스트 커버리지 달성
2. 사용자 친화적인 설치 및 설정 프로세스
3. 플랫폼 간 일관된 동작 보장
4. 성능 최적화 및 안정성 확보

## Development Guidelines

### 코딩 스타일
- **언어**: 주로 Bash (Linux/macOS), PowerShell (Windows)
- **테스트**: 모든 기능에 대해 테스트 코드 작성 필수
- **문서화**: 모든 스크립트에 헤더 주석 및 함수 설명 필수
- **플랫폼 호환성**: Windows와 Unix 시스템 모두 고려

### 파일 구조 규칙
- `core/`: 핵심 훅 스크립트
- `install/`: 설치 관련 스크립트
- `utils/`: 공통 유틸리티 함수
- `tests/`: 테스트 파일들
- `docs/`: 문서 파일들

### 커밋 메시지 컨벤션
- `feat:` 새로운 기능 추가
- `fix:` 버그 수정
- `refactor:` 코드 리팩토링
- `test:` 테스트 추가/수정
- `docs:` 문서 수정
- `cleanup:` 코드 정리

### 테스트 전략
1. 단위 테스트: 개별 함수/모듈 테스트
2. 통합 테스트: 전체 워크플로우 테스트
3. 플랫폼 테스트: Windows/Linux/macOS 동작 검증
4. 성능 테스트: 토큰 사용량 및 응답 시간 측정

## 우선순위 작업 가이드

### High Priority
1. **보안 및 안정성**: 스크립트 실행 권한, 입력 검증
2. **크로스 플랫폼 호환성**: 모든 OS에서 동일한 동작
3. **에러 처리**: 명확한 에러 메시지 및 복구 방안
4. **성능 최적화**: 캐싱, 백그라운드 처리

### Medium Priority
1. **사용자 경험**: 설치 프로세스 개선, 진단 도구
2. **문서화**: 사용자 가이드, API 문서
3. **모니터링**: 토큰 사용량, 성능 지표

### Low Priority
1. **UI/UX 개선**: 로그 형식, 진행 표시
2. **추가 기능**: 고급 설정 옵션

## 문제 해결 가이드

### 일반적인 문제들

#### 1. 경로 관련 오류
**증상:** "파일을 찾을 수 없음" 또는 경로 오류로 스크립트 실행 실패
**원인:** Windows 경로 변환 문제
**해결방법:**
- Git for Windows가 bash 지원과 함께 설치되었는지 확인
- 경로에 특수 문자가 포함되지 않았는지 확인
- WSL 스타일 경로 변환 확인: `C:\Users\...` → `/mnt/c/Users/...`

#### 2. 훅 실행 실패
**증상:** 훅이 실행되지 않거나 타임아웃 발생
**원인:** PowerShell 실행 정책 또는 타임아웃 설정 문제
**해결방법:**
```powershell
# 실행 정책 확인
Get-ExecutionPolicy
# 스크립트 실행 허용 설정
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### 3. 환경 변수 문제
**증상:** 컨텍스트가 제대로 주입되지 않음
**원인:** 환경 변수 누락 또는 잘못된 설정
**해결방법:**
- 환경 변수가 올바르게 설정되었는지 확인
- CLAUDE.md 파일들이 예상 위치에 존재하는지 확인
- 디버그 모드 활성화: `$env:CLAUDE_DEBUG = "true"`

#### 4. 문자 인코딩 문제
**증상:** 텍스트 깨짐 또는 파싱 오류
**원인:** 파일 인코딩 불일치
**해결방법:**
- 모든 파일이 UTF-8 인코딩을 사용하는지 확인
- 줄 바꿈이 Unix 형식(LF)인지 확인 (CRLF 아님)

### 디버그 모드
상세 로깅을 위해 다음을 설정:
```powershell
$env:CLAUDE_DEBUG = "true"
```

### 로그 파일
설치 및 실행 로그 확인 위치:
- 설치: `%USERPROFILE%\.claude\logs\claude-context-install.log`
- 런타임: `%USERPROFILE%\.claude\logs\`

### 설정 파일
주요 설정 파일 위치:
- PowerShell 설정: `%USERPROFILE%\.claude\hooks\claude-context\config.ps1`
- Bash 설정: `%USERPROFILE%\.claude\hooks\claude-context\config.sh`
- Claude 설정: `%USERPROFILE%\.claude\settings.json`

### 타임아웃 설정
환경 변수로 타임아웃 값 커스터마이징:
- `CLAUDE_PRECOMPACT_TIMEOUT` (기본값: 5000ms)
- `CLAUDE_USER_PROMPT_TIMEOUT` (기본값: 30000ms)
- `CLAUDE_INJECTOR_TIMEOUT` (기본값: 10000ms)

## 성능 최적화 가이드

### 캐싱 전략
- CLAUDE.md 파일 내용 캐싱으로 반복 읽기 최소화
- 해시 기반 변경 감지로 불필요한 처리 방지
- 메모리 기반 캐시와 디스크 기반 캐시 조합 활용

### 토큰 효율성
- 대화 길이 모니터링 및 자동 요약
- 중복 컨텍스트 제거
- 압축 및 최적화된 텍스트 형식 사용

### 백그라운드 처리
- 비동기 로그 기록
- 지연 로딩으로 초기 실행 시간 단축
- 병렬 처리로 다중 파일 처리 최적화
