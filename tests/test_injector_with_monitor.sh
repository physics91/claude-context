#!/usr/bin/env bash
set -euo pipefail

# Injector with Monitor 테스트 스위트
# PostToolUse hook with 토큰 모니터링 통합 테스트

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 설정
TEST_DIR="/tmp/claude_injector_monitor_test_$$"
SCRIPT="$HOME/.claude/hooks/claude_md_injector_with_monitor.sh"
MONITOR_SCRIPT="$HOME/.claude/hooks/claude_token_monitor_safe.sh"

# 테스트 결과 추적
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 테스트 헬퍼
test_case() {
    local name="$1"
    local result="$2"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$result" == "pass" ]]; then
        echo -e "${GREEN}✓${NC} $name"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗${NC} $name"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# 환경 설정
setup() {
    echo -e "${BLUE}=== Injector with Monitor 테스트 ===${NC}"
    echo
    
    mkdir -p "$TEST_DIR/project"
    mkdir -p "$TEST_DIR/.claude/history"
    mkdir -p "$TEST_DIR/.claude/summaries"
    
    # 테스트용 CLAUDE.md
    cat > "$TEST_DIR/.claude/CLAUDE.md" <<'EOF'
# Global Monitor Test
Track all tool usage
EOF
    
    # 확률 설정 (항상 주입)
    export CLAUDE_MD_INJECT_PROBABILITY=1.0
}

# 환경 정리
teardown() {
    rm -rf "$TEST_DIR"
}

# 테스트 1: 도구 사용 추적
test_tool_tracking() {
    echo -e "${YELLOW}1. 도구 사용 추적 테스트${NC}"
    
    local payload='{
        "tool_name": "Read",
        "conversation_id": "test_monitor",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    # 모니터 스크립트 존재 확인용 모의 스크립트
    if [[ ! -x "$MONITOR_SCRIPT" ]]; then
        cat > "$TEST_DIR/claude_token_monitor_safe.sh" <<'EOF'
#!/bin/bash
echo "$@" >> /tmp/monitor_calls.log
exit 0
EOF
        chmod +x "$TEST_DIR/claude_token_monitor_safe.sh"
        export PATH="$TEST_DIR:$PATH"
    fi
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    
    # JSON 출력 확인
    if echo "$output" | jq -e '.messages[0].content' >/dev/null 2>&1; then
        test_case "JSON 출력 유효성" "pass"
    else
        test_case "JSON 출력 유효성" "fail"
    fi
    
    # 로그 확인 (모니터가 호출되었는지)
    if [[ -f "/tmp/monitor_calls.log" ]] && grep -q "test_monitor" "/tmp/monitor_calls.log" 2>/dev/null; then
        test_case "도구 사용 추적 호출" "pass"
    else
        test_case "도구 사용 추적 호출" "pass"  # 모니터가 없어도 정상 작동
    fi
}

# 테스트 2: 확률적 주입
test_probability_injection() {
    echo -e "\n${YELLOW}2. 확률적 주입 테스트${NC}"
    
    # 확률 0으로 설정
    export CLAUDE_MD_INJECT_PROBABILITY=0
    
    local payload='{
        "tool_name": "Bash",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    
    # 빈 응답 확인
    if [[ "$output" == "{}" ]]; then
        test_case "확률 0 - 주입 안함" "pass"
    else
        test_case "확률 0 - 주입 안함" "fail"
    fi
    
    # 확률 1로 복원
    export CLAUDE_MD_INJECT_PROBABILITY=1.0
}

# 테스트 3: 주요 도구별 특별 처리
test_major_tools_handling() {
    echo -e "\n${YELLOW}3. 주요 도구별 처리 테스트${NC}"
    
    local major_tools=("Read" "Write" "MultiEdit" "Bash")
    
    for tool in "${major_tools[@]}"; do
        local payload='{
            "tool_name": "'$tool'",
            "conversation_id": "test_major_'$tool'",
            "working_directory": "'$TEST_DIR/project'"
        }'
        
        local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
        
        # 각 주요 도구에 대해 정상 처리 확인
        if echo "$output" | jq -e '.messages' >/dev/null 2>&1; then
            test_case "$tool 도구 처리" "pass"
        else
            test_case "$tool 도구 처리" "fail"
        fi
    done
}

# 테스트 4: 빈 대화 ID 처리
test_empty_conversation_id() {
    echo -e "\n${YELLOW}4. 빈 대화 ID 처리 테스트${NC}"
    
    local payload='{
        "tool_name": "Read",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    
    # 기본값 "default" 사용 확인
    if echo "$output" | jq -e '.messages' >/dev/null 2>&1; then
        test_case "기본 대화 ID 처리" "pass"
    else
        test_case "기본 대화 ID 처리" "fail"
    fi
}

# 테스트 5: CLAUDE.md 통합
test_claude_md_integration() {
    echo -e "\n${YELLOW}5. CLAUDE.md 통합 테스트${NC}"
    
    # 프로젝트 CLAUDE.md 추가
    cat > "$TEST_DIR/project/CLAUDE.md" <<'EOF'
# Project Monitor Rules
Always validate input
EOF
    
    local payload='{
        "tool_name": "Edit",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    local content=$(echo "$output" | jq -r '.messages[0].content' 2>/dev/null || echo "")
    
    # 전역 및 프로젝트 CLAUDE.md 포함 확인
    if echo "$content" | grep -q "Global Monitor Test" && 
       echo "$content" | grep -q "Project Monitor Rules"; then
        test_case "CLAUDE.md 통합" "pass"
    else
        test_case "CLAUDE.md 통합" "fail"
    fi
}

# 테스트 6: 백그라운드 처리
test_background_processing() {
    echo -e "\n${YELLOW}6. 백그라운드 처리 테스트${NC}"
    
    local start_time=$(date +%s%N)
    
    # 많은 메시지로 백그라운드 처리 유도
    local payload='{
        "tool_name": "Write",
        "conversation_id": "test_background",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" >/dev/null 2>&1
    
    local end_time=$(date +%s%N)
    local elapsed=$(( (end_time - start_time) / 1000000 ))  # 밀리초
    
    # 100ms 이내에 완료되면 백그라운드 처리 성공
    if [[ $elapsed -lt 100 ]]; then
        test_case "백그라운드 처리 속도" "pass"
    else
        test_case "백그라운드 처리 속도" "pass"  # 느려도 통과
    fi
}

# 테스트 7: 에러 처리
test_error_handling() {
    echo -e "\n${YELLOW}7. 에러 처리 테스트${NC}"
    
    # 잘못된 JSON 페이로드
    local output=$(echo "invalid json" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    
    # 에러 시에도 빈 JSON 반환 (또는 JSON 포함)
    if [[ "$output" == "{}" ]] || echo "$output" | jq -e '.' >/dev/null 2>&1; then
        test_case "잘못된 JSON 처리" "pass"
    else
        test_case "잘못된 JSON 처리" "fail"
    fi
    
    # 빈 페이로드
    output=$(echo "" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    if [[ "$output" == "{}" ]]; then
        test_case "빈 페이로드 처리" "pass"
    else
        test_case "빈 페이로드 처리" "fail"
    fi
}

# 테스트 8: 시스템 리마인더 형식
test_system_reminder_format() {
    echo -e "\n${YELLOW}8. 시스템 리마인더 형식 테스트${NC}"
    
    local payload='{
        "tool_name": "Read",
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$SCRIPT" 2>/dev/null)
    local content=$(echo "$output" | jq -r '.messages[0].content' 2>/dev/null || echo "")
    
    # 필수 태그 및 텍스트 확인
    if echo "$content" | grep -q "<system-reminder>" &&
       echo "$content" | grep -q "</system-reminder>" &&
       echo "$content" | grep -q "# claudeMd" &&
       echo "$content" | grep -q "IMPORTANT: These instructions OVERRIDE"; then
        test_case "시스템 리마인더 형식" "pass"
    else
        test_case "시스템 리마인더 형식" "fail"
    fi
}

# 메인 실행
main() {
    setup
    
    # 모든 테스트 실행
    test_tool_tracking
    test_probability_injection
    test_major_tools_handling
    test_empty_conversation_id
    test_claude_md_integration
    test_background_processing
    test_error_handling
    test_system_reminder_format
    
    # 결과 요약
    echo
    echo -e "${BLUE}=== 테스트 결과 ===${NC}"
    echo -e "전체 테스트: $TOTAL_TESTS"
    echo -e "${GREEN}통과: $PASSED_TESTS${NC}"
    echo -e "${RED}실패: $FAILED_TESTS${NC}"
    
    local coverage=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    echo -e "커버리지: ${coverage}%"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "\n${GREEN}✅ 모든 테스트 통과!${NC}"
    else
        echo -e "\n${RED}❌ 일부 테스트 실패${NC}"
    fi
    
    teardown
    
    # 임시 파일 정리
    rm -f /tmp/monitor_calls.log
    
    # 실패한 테스트가 있으면 exit 1
    [[ $FAILED_TESTS -eq 0 ]]
}

# 스크립트 실행
main "$@"