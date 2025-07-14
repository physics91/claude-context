#!/usr/bin/env bash
# Claude Context PreCompact Wrapper

# stderr로 모든 로그 출력
exec 2>&1

# precompact 스크립트 실행 (에러가 발생해도 스크립트는 계속 실행)
"${HOME}/.claude/hooks/claude-context/src/core/precompact.sh" "$@" || true

# 항상 성공 코드 반환
exit 0
