#!/usr/bin/env bash
set -euo pipefail

# 통합 테스트 - 대화 기록 관리 통합 버전
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INJECTOR="$PROJECT_ROOT/src/core/injector.sh"
HISTORY_MANAGER="$PROJECT_ROOT/src/monitor/claude_history_manager.sh"

# 테스트 환경 설정
TEST_DIR="${TMPDIR:-/tmp}/test_integrated_$$"
export HOME="$TEST_DIR"
export CLAUDE_HOME="$TEST_DIR/.claude"
export CLAUDE_HISTORY_DIR="$TEST_DIR/history"
export CLAUDE_SUMMARY_DIR="$TEST_DIR/summaries"
export CLAUDE_CACHE_DIR="$TEST_DIR/.cache/claude-context"
export CLAUDE_LOG_DIR="$TEST_DIR/logs"
export CLAUDE_CONFIG_FILE="$TEST_DIR/config.sh"
export CLAUDE_SESSION_ID="test_session_$(date +%s)"

# 하위 호환성
export HISTORY_DIR="$CLAUDE_HISTORY_DIR"
export SUMMARY_DIR="$CLAUDE_SUMMARY_DIR"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 테스트 결과 추적
TOTAL_TESTS=0
PASSED_TESTS=0

test_case() {
    local name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "0" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $name"
    fi
}

# 설정
setup() {
    mkdir -p "$TEST_DIR"/{.claude,.cache/claude-context} "$HISTORY_DIR" "$SUMMARY_DIR" "$CLAUDE_LOG_DIR"
    
    # 통합 스크립트 복사
    cp -r "$PROJECT_ROOT/src" "$TEST_DIR/"
    find "$TEST_DIR/src" -name "*.sh" -type f -exec chmod +x {} \;
    
    # 테스트용 CLAUDE.md 생성
    echo "# Test Global Context" > "$TEST_DIR/.claude/CLAUDE.md"
    
    # history 모드 설정
    cat > "$CLAUDE_CONFIG_FILE" << EOF
CLAUDE_CONTEXT_MODE="history"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_LOG_DIR="$CLAUDE_LOG_DIR"
CLAUDE_LOCK_TIMEOUT="5"
CLAUDE_CACHE_MAX_AGE="3600"
CLAUDE_INJECT_PROBABILITY="1.0"
export CLAUDE_CONTEXT_MODE
export CLAUDE_ENABLE_CACHE
export CLAUDE_LOG_DIR
export CLAUDE_LOCK_TIMEOUT
export CLAUDE_CACHE_MAX_AGE
export CLAUDE_INJECT_PROBABILITY
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

echo "=== 통합 테스트: 대화 기록 관리 ==="
echo

setup

# 1. 세션 자동 생성 테스트
echo "1. 세션 자동 생성 테스트"
OUTPUT=$("$TEST_DIR/src/core/injector.sh" 2>&1) || EXIT_CODE=$?
test_case "Injector 실행" "${EXIT_CODE:-0}"

SESSION_FILE="$HISTORY_DIR/session_${CLAUDE_SESSION_ID}.jsonl"
test_case "세션 파일 자동 생성" "$(test -f "$SESSION_FILE" && echo 0 || echo 1)"

# 2. 메시지 추적 테스트
echo -e "\n2. 메시지 추적 테스트"
export INPUT_MESSAGE="테스트 사용자 메시지입니다"
"$TEST_DIR/src/core/injector.sh" >/dev/null 2>&1 || true

# 메시지가 기록되었는지 확인
TRACKED=$(grep -q "테스트 사용자 메시지" "$SESSION_FILE" 2>/dev/null && echo 0 || echo 1)
test_case "사용자 메시지 자동 추적" "$TRACKED"

# 3. CLAUDE.md 내용 주입 테스트
echo -e "\n3. CLAUDE.md 내용 주입 테스트"
OUTPUT=$("$TEST_DIR/src/core/injector.sh" 2>&1)
test_case "CLAUDE.md 내용 포함" "$(echo "$OUTPUT" | grep -q "Test Global Context" && echo 0 || echo 1)"

# 4. PreCompact 모드 테스트
echo -e "\n4. PreCompact 모드 테스트"
OLD_SESSION_ID="$CLAUDE_SESSION_ID"

# 몇 개의 메시지 추가
for i in {1..5}; do
    "$HISTORY_MANAGER" add "$CLAUDE_SESSION_ID" user "메시지 $i" >/dev/null 2>&1
done

# PreCompact 실행
OUTPUT=$("$INJECTOR" precompact 2>/dev/null)
test_case "PreCompact 실행" "$?"

# 새 세션 ID는 스크립트 내부에서만 변경되므로 이 테스트는 건너뜀
# test_case "새 세션 ID 생성" "$([ "$CLAUDE_SESSION_ID" != "$OLD_SESSION_ID" ] && echo 0 || echo 1)"

# 5. 세션 정보 표시 테스트
echo -e "\n5. 세션 정보 표시 테스트"
OUTPUT=$("$INJECTOR" 2>/dev/null)
test_case "세션 정보 포함" "$(echo "$OUTPUT" | grep -q "Current Session Info" && echo 0 || echo 1)"

# 6. 대화 검색 기능 테스트
echo -e "\n6. 대화 검색 기능 테스트"
SEARCH_RESULT=$("$HISTORY_MANAGER" search "메시지" 2>/dev/null)
test_case "검색 기능 작동" "$?"
test_case "검색 결과 존재" "$(echo "$SEARCH_RESULT" | grep -q "Session" && echo 0 || echo 1)"

# 7. 세션 목록 테스트
echo -e "\n7. 세션 목록 테스트"
LIST_OUTPUT=$("$HISTORY_MANAGER" list simple 2>/dev/null)
test_case "세션 목록 조회" "$?"

# 8. 프로젝트별 CLAUDE.md 테스트
echo -e "\n8. 프로젝트별 CLAUDE.md 테스트"
mkdir -p "$TEST_DIR/project"
echo "# Project Specific Context" > "$TEST_DIR/project/CLAUDE.md"
cd "$TEST_DIR/project"

OUTPUT=$("$INJECTOR" 2>/dev/null)
test_case "프로젝트 CLAUDE.md 포함" "$(echo "$OUTPUT" | grep -q "Project Specific Context" && echo 0 || echo 1)"

# 결과 요약
echo
echo "=== 테스트 결과 ==="
echo "총 테스트: $TOTAL_TESTS"
echo -e "성공: ${GREEN}$PASSED_TESTS${NC}"
echo -e "실패: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"

teardown

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}모든 통합 테스트 통과!${NC}"
    exit 0
else
    echo -e "\n${RED}일부 테스트 실패${NC}"
    exit 1
fi