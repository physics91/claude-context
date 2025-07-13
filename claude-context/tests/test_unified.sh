#!/usr/bin/env bash
set -euo pipefail

# 통합 구조 테스트
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 테스트 환경 설정
TEST_DIR="${TMPDIR:-/tmp}/test_unified_$$"
export HOME="$TEST_DIR"
export CLAUDE_HOME="$TEST_DIR/.claude"
export CLAUDE_HOOKS_DIR="$CLAUDE_HOME/hooks"
export CLAUDE_HISTORY_DIR="$CLAUDE_HOME/history"
export CLAUDE_SUMMARY_DIR="$CLAUDE_HOME/summaries"
export CLAUDE_CACHE_DIR="$TEST_DIR/.cache/claude-context"
export CLAUDE_CONFIG_FILE="$TEST_DIR/config.sh"
export CLAUDE_LOG_DIR="$TEST_DIR/logs"

# 기본 환경 변수 설정 (config 파일이 로드되기 전에 필요)
export CLAUDE_CONTEXT_MODE="basic"
export CLAUDE_ENABLE_CACHE="true"

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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
    mkdir -p "$TEST_DIR"/{.claude,.cache/claude-context}
    mkdir -p "$CLAUDE_HISTORY_DIR" "$CLAUDE_SUMMARY_DIR"
    
    # 테스트용 CLAUDE.md 생성
    echo "# Test Global Context" > "$CLAUDE_HOME/CLAUDE.md"
    
    # 통합 스크립트 복사
    cp -r "$PROJECT_ROOT/src" "$TEST_DIR/"
    find "$TEST_DIR/src" -name "*.sh" -type f -exec chmod +x {} \;
    
    # common_functions.sh 파일 확인 및 CLAUDE_LOG_DIR 기본값 설정
    if [[ -f "$TEST_DIR/src/utils/common_functions.sh" ]]; then
        # CLAUDE_LOG_DIR 기본값 추가
        export CLAUDE_LOG_DIR="$TEST_DIR/logs"
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

# 테스트 시작
echo -e "${BLUE}=== 통합 구조 테스트 ===${NC}"
echo

setup

# 1. Basic 모드 테스트
echo "1. Basic 모드 테스트"
cat > "$CLAUDE_CONFIG_FILE" << EOF
CLAUDE_CONTEXT_MODE="basic"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_LOG_DIR="$TEST_DIR/logs"
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

# 로그 디렉토리 생성
mkdir -p "$TEST_DIR/logs"

OUTPUT=$("$TEST_DIR/src/core/injector.sh" 2>&1) || EXIT_CODE=$?
if [[ ${EXIT_CODE:-0} -ne 0 ]]; then
    echo "Injector error: $OUTPUT"
fi
test_case "Basic 모드 실행" "${EXIT_CODE:-0}"
test_case "CLAUDE.md 주입" "$(echo "$OUTPUT" | grep -q "Test Global Context" && echo 0 || echo 1)"

# 2. History 모드 테스트
echo -e "\n2. History 모드 테스트"
cat > "$CLAUDE_CONFIG_FILE" << EOF
CLAUDE_CONTEXT_MODE="history"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_HISTORY_DIR="$CLAUDE_HISTORY_DIR"
CLAUDE_SUMMARY_DIR="$CLAUDE_SUMMARY_DIR"
CLAUDE_LOG_DIR="$TEST_DIR/logs"
CLAUDE_LOCK_TIMEOUT="5"
CLAUDE_CACHE_MAX_AGE="3600"
CLAUDE_INJECT_PROBABILITY="1.0"
export CLAUDE_CONTEXT_MODE
export CLAUDE_ENABLE_CACHE
export CLAUDE_HISTORY_DIR
export CLAUDE_SUMMARY_DIR
export CLAUDE_LOG_DIR
export CLAUDE_LOCK_TIMEOUT
export CLAUDE_CACHE_MAX_AGE
export CLAUDE_INJECT_PROBABILITY
EOF

export CLAUDE_SESSION_ID="test_session_$(date +%s)"
export INPUT_MESSAGE="테스트 메시지"

OUTPUT=$("$TEST_DIR/src/core/injector.sh" 2>&1) || EXIT_CODE=$?
test_case "History 모드 실행" "${EXIT_CODE:-0}"

SESSION_FILE="$CLAUDE_HISTORY_DIR/session_${CLAUDE_SESSION_ID}.jsonl"
test_case "세션 파일 생성" "$(test -f "$SESSION_FILE" && echo 0 || echo 1)"

# 3. PreCompact 테스트
echo -e "\n3. PreCompact 테스트"
OUTPUT=$("$TEST_DIR/src/core/precompact.sh" 2>&1) || EXIT_CODE=$?
test_case "PreCompact 실행" "${EXIT_CODE:-0}"
test_case "PreCompact CLAUDE.md 주입" "$(echo "$OUTPUT" | grep -q "Test Global Context" && echo 0 || echo 1)"

# 4. 캐싱 테스트
echo -e "\n4. 캐싱 테스트"
OUTPUT1=$("$TEST_DIR/src/core/injector.sh" 2>&1)
OUTPUT2=$("$TEST_DIR/src/core/injector.sh" 2>&1)
test_case "캐싱 동작" "$(ls "$CLAUDE_CACHE_DIR"/*.cache 2>/dev/null | wc -l | grep -q '^[1-9]' && echo 0 || echo 1)"

# 5. 공통 함수 테스트
echo -e "\n5. 공통 함수 테스트"
source "$TEST_DIR/src/utils/common_functions.sh"
load_config  # config 재로드
test_case "find_claude_md_files 함수" "$(find_claude_md_files | grep -q "CLAUDE.md" && echo 0 || echo 1)"
test_case "get_mode 함수" "$([ "$(get_mode)" == "history" ] && echo 0 || echo 1)"
test_case "is_mode_enabled 함수" "$(is_mode_enabled "history" && echo 0 || echo 1)"

# 6. 프로젝트별 CLAUDE.md 테스트
echo -e "\n6. 프로젝트별 CLAUDE.md 테스트"
mkdir -p "$TEST_DIR/project"
echo "# Project Context" > "$TEST_DIR/project/CLAUDE.md"
cd "$TEST_DIR/project"

OUTPUT=$("$TEST_DIR/src/core/injector.sh" 2>/dev/null)
test_case "프로젝트 CLAUDE.md 감지" "$(echo "$OUTPUT" | grep -q "Project Context" && echo 0 || echo 1)"

# 결과 요약
echo
echo -e "${BLUE}=== 테스트 결과 ===${NC}"
echo "총 테스트: $TOTAL_TESTS"
echo -e "성공: ${GREEN}$PASSED_TESTS${NC}"
echo -e "실패: ${RED}$((TOTAL_TESTS - PASSED_TESTS))${NC}"

teardown

if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
    echo -e "\n${GREEN}모든 테스트 통과!${NC}"
    exit 0
else
    echo -e "\n${RED}일부 테스트 실패${NC}"
    exit 1
fi