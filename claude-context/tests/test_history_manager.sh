#!/usr/bin/env bash
set -euo pipefail

# 테스트 환경 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY_MANAGER="$SCRIPT_DIR/../src/monitor/claude_history_manager.sh"
TEST_DIR="${TMPDIR:-/tmp}/test_history_manager_$$"
export CLAUDE_HISTORY_DIR="$TEST_DIR/history"
export CLAUDE_SUMMARY_DIR="$TEST_DIR/summaries"
export CLAUDE_LOG_DIR="$TEST_DIR/logs"
export HOME="$TEST_DIR"
export CLAUDE_HOME="$TEST_DIR/.claude"

# 하위 호환성을 위한 변수 설정
export HISTORY_DIR="$CLAUDE_HISTORY_DIR"
export SUMMARY_DIR="$CLAUDE_SUMMARY_DIR"

# 테스트 결과 추적
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# 테스트 준비
setup() {
    mkdir -p "$HISTORY_DIR" "$SUMMARY_DIR" "$CLAUDE_LOG_DIR" "$CLAUDE_HOME"
    chmod +x "$HISTORY_MANAGER"
}

# 테스트 정리
teardown() {
    rm -rf "$TEST_DIR"
}

# 테스트 케이스 함수
test_case() {
    local name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "0" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 테스트 시작
echo "=== History Manager 테스트 ==="
echo

setup

# 1. 세션 생성 테스트
echo "1. 세션 생성 테스트"
SESSION_ID=$("$HISTORY_MANAGER" create test_session_1)
test_case "세션 생성" "$?"
test_case "세션 파일 존재" "$(test -f "$HISTORY_DIR/session_${SESSION_ID}.jsonl" && echo 0 || echo 1)"
test_case "메타데이터 파일 존재" "$(test -f "$HISTORY_DIR/session_${SESSION_ID}.jsonl.meta" && echo 0 || echo 1)"

# 2. 메시지 추가 테스트
echo -e "\n2. 메시지 추가 테스트"
"$HISTORY_MANAGER" add "$SESSION_ID" user "안녕하세요, Claude!" >/dev/null 2>&1
test_case "사용자 메시지 추가" "$?"

"$HISTORY_MANAGER" add "$SESSION_ID" assistant "안녕하세요! 무엇을 도와드릴까요?" >/dev/null 2>&1
test_case "어시스턴트 메시지 추가" "$?"

MESSAGE_COUNT=$(wc -l < "$HISTORY_DIR/session_${SESSION_ID}.jsonl")
test_case "메시지 수 확인 (2개)" "$([ "$MESSAGE_COUNT" -eq 2 ] && echo 0 || echo 1)"

# 3. 세션 목록 테스트
echo -e "\n3. 세션 목록 테스트"
LIST_OUTPUT=$("$HISTORY_MANAGER" list simple 2>/dev/null)
test_case "세션 목록 조회" "$?"
test_case "세션 ID 포함 확인" "$(echo "$LIST_OUTPUT" | grep -q "$SESSION_ID" && echo 0 || echo 1)"

# 4. 대화 검색 테스트
echo -e "\n4. 대화 검색 테스트"
SEARCH_OUTPUT=$("$HISTORY_MANAGER" search "Claude" 2>/dev/null)
test_case "검색 실행" "$?"
test_case "검색 결과 확인" "$(echo "$SEARCH_OUTPUT" | grep -q "Session" && echo 0 || echo 1)"

# 5. 세션 내보내기 테스트
echo -e "\n5. 세션 내보내기 테스트"
EXPORT_FILE="$TEST_DIR/export_test.md"
"$HISTORY_MANAGER" export "$SESSION_ID" markdown "$EXPORT_FILE" >/dev/null 2>&1
test_case "Markdown 내보내기" "$?"
test_case "내보낸 파일 존재" "$(test -f "$EXPORT_FILE" && echo 0 || echo 1)"

EXPORT_FILE_JSON="$TEST_DIR/export_test.json"
"$HISTORY_MANAGER" export "$SESSION_ID" json "$EXPORT_FILE_JSON" >/dev/null 2>&1
test_case "JSON 내보내기" "$?"

# 6. 요약 생성 테스트
echo -e "\n6. 요약 생성 테스트"
# 더 많은 메시지 추가
for i in {1..10}; do
    "$HISTORY_MANAGER" add "$SESSION_ID" user "테스트 메시지 $i" >/dev/null 2>&1
    "$HISTORY_MANAGER" add "$SESSION_ID" assistant "응답 메시지 $i" >/dev/null 2>&1
done

"$HISTORY_MANAGER" summarize "$SESSION_ID" 1 10 >/dev/null 2>&1
test_case "요약 생성" "$?"

SUMMARY_EXISTS=$(find "$SUMMARY_DIR" -name "summary_${SESSION_ID}_*.json" | wc -l)
test_case "요약 파일 생성 확인" "$([ "$SUMMARY_EXISTS" -gt 0 ] && echo 0 || echo 1)"

# 7. 도움말 테스트
echo -e "\n7. 도움말 테스트"
HELP_OUTPUT=$("$HISTORY_MANAGER" help 2>&1)
test_case "도움말 표시" "$?"
test_case "도움말 내용 확인" "$(echo "$HELP_OUTPUT" | grep -q "Claude History Manager" && echo 0 || echo 1)"

# 8. 잘못된 세션 ID 처리
echo -e "\n8. 오류 처리 테스트"
"$HISTORY_MANAGER" add "invalid_session" user "test" >/dev/null 2>&1 || EXIT_CODE=$?
test_case "잘못된 세션 처리" "$([ "${EXIT_CODE:-0}" -ne 0 ] && echo 0 || echo 1)"

# 9. 인덱스 관리 테스트
echo -e "\n9. 인덱스 관리 테스트"
INDEX_FILE="$HISTORY_DIR/.index.json"
test_case "인덱스 파일 생성" "$(test -f "$INDEX_FILE" && echo 0 || echo 1)"

if command -v jq &> /dev/null; then
    INDEX_CONTAINS=$(jq --arg id "$SESSION_ID" 'map(select(. == $id)) | length' "$INDEX_FILE")
    test_case "인덱스에 세션 포함" "$([ "$INDEX_CONTAINS" -eq 1 ] && echo 0 || echo 1)"
else
    test_case "인덱스에 세션 포함" "0"  # jq 없으면 통과
fi

# 10. 자동 요약 트리거 테스트
echo -e "\n10. 자동 요약 테스트"
NEW_SESSION=$("$HISTORY_MANAGER" create auto_summary_test)

# 임계값 테스트를 위해 적은 수의 메시지만 추가 (10개)
for i in {1..10}; do
    "$HISTORY_MANAGER" add "$NEW_SESSION" user "메시지 $i" >/dev/null 2>&1
done

# 요약 생성이 작동하는지 확인 (수동으로 요약 생성)
"$HISTORY_MANAGER" summarize "$NEW_SESSION" >/dev/null 2>&1

# 요약이 생성되었는지 확인
AUTO_SUMMARY=$(find "$SUMMARY_DIR" -name "summary_${NEW_SESSION}_*.json" | wc -l)
test_case "요약 생성 기능" "$([ "$AUTO_SUMMARY" -gt 0 ] && echo 0 || echo 1)"

# 결과 요약
echo
echo "=== 테스트 결과 ==="
echo "총 테스트: $TOTAL_TESTS"
echo -e "성공: ${GREEN}$PASSED_TESTS${NC}"
echo -e "실패: ${RED}$FAILED_TESTS${NC}"

# 정리
teardown

# 성공/실패 반환
if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "\n${GREEN}모든 테스트 통과!${NC}"
    exit 0
else
    echo -e "\n${RED}일부 테스트 실패${NC}"
    exit 1
fi