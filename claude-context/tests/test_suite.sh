#!/usr/bin/env bash
set -euo pipefail

# Claude Context 테스트 스위트
# 모든 모드와 컴포넌트를 테스트합니다

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 테스트 결과
TOTAL=0
PASSED=0
FAILED=0

# 테스트 헬퍼 함수
run_test() {
    local name="$1"
    local test_script="$2"
    
    echo -e "\n${BLUE}테스트: $name${NC}"
    TOTAL=$((TOTAL + 1))
    
    if bash "$test_script" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ 성공${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ 실패${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# 헤더 출력
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Context 테스트 스위트       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# 환경 확인
echo -e "\n${YELLOW}환경 확인...${NC}"
for cmd in jq sha256sum; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd"
    else
        echo -e "${RED}✗${NC} $cmd (필요함)"
    fi
done

# 개별 테스트 실행
echo -e "\n${YELLOW}테스트 실행...${NC}"

# 1. 통합 구조 테스트
if [[ -f "$SCRIPT_DIR/test_unified.sh" ]]; then
    run_test "통합 구조" "$SCRIPT_DIR/test_unified.sh"
fi

# 2. History Manager 테스트
if [[ -f "$SCRIPT_DIR/test_history_manager.sh" ]]; then
    run_test "History Manager" "$SCRIPT_DIR/test_history_manager.sh"
fi

# 3. 통합 대화 기록 테스트
if [[ -f "$SCRIPT_DIR/test_integrated_history.sh" ]]; then
    run_test "통합 대화 기록" "$SCRIPT_DIR/test_integrated_history.sh"
fi

# 4. 기본 기능 테스트
echo -e "\n${BLUE}테스트: 기본 기능${NC}"
TOTAL=$((TOTAL + 1))

# 임시 환경 설정
export CLAUDE_CONTEXT_MODE="basic"
export HOME="/tmp/test_home_$$"
mkdir -p "$HOME/.claude"
echo "# Test Content" > "$HOME/.claude/CLAUDE.md"

# 기본 injector 테스트
if OUTPUT=$("$PROJECT_ROOT/src/core/injector.sh" 2>/dev/null) && \
   echo "$OUTPUT" | grep -q "Test Content"; then
    echo -e "${GREEN}✓ 성공${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}✗ 실패${NC}"
    FAILED=$((FAILED + 1))
fi

# 정리
rm -rf "$HOME"
unset HOME

# 결과 요약
echo -e "\n${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}테스트 결과${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo "총 테스트: $TOTAL"
echo -e "성공: ${GREEN}$PASSED${NC}"
echo -e "실패: ${RED}$FAILED${NC}"

# 커버리지 계산
if [[ $TOTAL -gt 0 ]]; then
    COVERAGE=$(awk "BEGIN {printf \"%.0f\", ($PASSED/$TOTAL)*100}")
    echo -e "커버리지: ${GREEN}${COVERAGE}%${NC}"
fi

echo

# 종료 코드
if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 모든 테스트 통과!${NC}"
    exit 0
else
    echo -e "${RED}❌ 일부 테스트 실패${NC}"
    exit 1
fi