# 프로젝트 컨텍스트 예제

이 파일은 CLAUDE.md의 예제입니다. 프로젝트 루트나 ~/.claude/ 디렉토리에 이런 형식으로 작성하세요.

## 🎯 프로젝트 개요

Next.js 기반 전자상거래 플랫폼 개발

## 📋 코딩 규칙

### TypeScript
- strict 모드 활성화
- any 타입 사용 금지
- 인터페이스는 I 접두사 사용 (예: IUser)

### React
- 함수형 컴포넌트만 사용
- hooks 적극 활용
- prop-types 대신 TypeScript 인터페이스 사용

### 스타일
- Tailwind CSS 사용
- 커스텀 CSS는 module.css 파일로
- 색상은 theme 변수만 사용

## 🏗️ 프로젝트 구조

```
src/
  components/   # 재사용 가능한 컴포넌트
  pages/        # Next.js 페이지
  hooks/        # 커스텀 훅
  utils/        # 유틸리티 함수
  services/     # API 호출 로직
  types/        # TypeScript 타입 정의
```

## 🔧 주요 기술 스택

- Next.js 14
- TypeScript 5
- Tailwind CSS 3
- Zustand (상태 관리)
- React Query (서버 상태)
- Prisma (ORM)

## 📝 커밋 컨벤션

```
feat: 새로운 기능 추가
fix: 버그 수정
docs: 문서 수정
style: 코드 포맷팅
refactor: 코드 리팩토링
test: 테스트 코드
chore: 빌드 업무 수정
```

## ⚠️ 주의사항

1. 환경 변수는 절대 커밋하지 않기
2. 모든 API 키는 .env.local에 저장
3. 배포 전 반드시 lint와 test 실행
4. PR 전에 코드 리뷰 요청

## 🚀 자주 사용하는 명령어

```bash
# 개발 서버 실행
npm run dev

# 타입 체크
npm run type-check

# 린트 실행
npm run lint

# 테스트 실행
npm run test

# 빌드
npm run build
```