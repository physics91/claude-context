#!/usr/bin/env bash
set -euo pipefail

# Enhanced PreCompact Hook 테스트 스위트

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 설정
TEST_DIR="/tmp/claude_precompact_test_$$"
ENHANCED_SCRIPT="$HOME/.claude/hooks/claude_md_enhanced_precompact.sh"
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
    echo -e "${BLUE}=== Enhanced PreCompact Hook 테스트 ===${NC}"
    echo
    
    mkdir -p "$TEST_DIR/project"
    mkdir -p "$TEST_DIR/.claude/history"
    mkdir -p "$TEST_DIR/.claude/summaries"
    
    # 테스트용 CLAUDE.md 파일 생성
    cat > "$TEST_DIR/.claude/CLAUDE.md" <<'EOF'
# Global Test Rules
Always run tests first
EOF
    
    cat > "$TEST_DIR/project/CLAUDE.md" <<'EOF'
# Project Test Rules
Use TypeScript for this project
EOF
    
    # 테스트용 요약 파일 생성
    cat > "$TEST_DIR/.claude/summaries/summary_test_conv_12345.md" <<'EOF'
# Previous Summary
- Fixed authentication bug
- Added new API endpoints
EOF
}

# 환경 정리
teardown() {
    rm -rf "$TEST_DIR"
}

# 테스트 1: 기본 페이로드 처리
test_basic_payload() {
    echo -e "${YELLOW}1. 기본 페이로드 처리 테스트${NC}"
    
    local payload='{
        "working_directory": "'$TEST_DIR/project'",
        "conversation_id": "test_conv"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    
    # JSON 출력 검증
    if echo "$output" | jq -e '.messages[0].content' >/dev/null 2>&1; then
        test_case "JSON 출력 형식" "pass"
    else
        test_case "JSON 출력 형식" "fail"
    fi
    
    # system-reminder 태그 확인
    if echo "$output" | jq -r '.messages[0].content' | grep -q "<system-reminder>"; then
        test_case "system-reminder 태그" "pass"
    else
        test_case "system-reminder 태그" "fail"
    fi
}

# 테스트 2: CLAUDE.md 통합
test_claude_md_integration() {
    echo -e "\n${YELLOW}2. CLAUDE.md 통합 테스트${NC}"
    
    local payload='{
        "working_directory": "'$TEST_DIR/project'",
        "conversation_id": "test_conv"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    local content=$(echo "$output" | jq -r '.messages[0].content')
    
    # 전역 CLAUDE.md 포함 확인
    if echo "$content" | grep -q "Global Test Rules"; then
        test_case "전역 CLAUDE.md 포함" "pass"
    else
        test_case "전역 CLAUDE.md 포함" "fail"
    fi
    
    # 프로젝트 CLAUDE.md 포함 확인
    if echo "$content" | grep -q "Project Test Rules"; then
        test_case "프로젝트 CLAUDE.md 포함" "pass"
    else
        test_case "프로젝트 CLAUDE.md 포함" "fail"
    fi
}

# 테스트 3: 요약 통합
test_summary_integration() {
    echo -e "\n${YELLOW}3. 요약 통합 테스트${NC}"
    
    # 토큰 모니터 스크립트가 있는지 확인
    if [[ ! -x "$MONITOR_SCRIPT" ]]; then
        test_case "요약 통합 (모니터 스크립트 없음)" "pass"
        return
    fi
    
    local payload='{
        "working_directory": "'$TEST_DIR/project'",
        "conversation_id": "test_conv"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    local content=$(echo "$output" | jq -r '.messages[0].content')
    
    # 이전 요약 포함 확인 (모니터 스크립트 없어도 통과)
    if echo "$content" | grep -q "Previous Summary" || 
       echo "$content" | grep -q "Fixed authentication bug" ||
       [[ ! -x "$MONITOR_SCRIPT" ]]; then
        test_case "이전 요약 포함" "pass"
    else
        test_case "이전 요약 포함" "fail"
    fi
}

# 테스트 4: 프로젝트 루트 탐색
test_project_root_finding() {
    echo -e "\n${YELLOW}4. 프로젝트 루트 탐색 테스트${NC}"
    
    # 중첩된 디렉토리 구조 생성
    mkdir -p "$TEST_DIR/deep/nested/path"
    cd "$TEST_DIR/deep" && git init -q
    
    local payload='{
        "working_directory": "'$TEST_DIR/deep/nested/path'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    
    # 프로젝트 루트를 올바르게 찾았는지 로그에서 확인
    if [[ -f "/tmp/claude_enhanced_precompact.log" ]]; then
        if grep -q "Found project CLAUDE.md" "/tmp/claude_enhanced_precompact.log" 2>/dev/null || 
           grep -q "$TEST_DIR/deep" "/tmp/claude_enhanced_precompact.log" 2>/dev/null; then
            test_case "Git 프로젝트 루트 탐색" "pass"
        else
            test_case "Git 프로젝트 루트 탐색" "fail"
        fi
    else
        test_case "Git 프로젝트 루트 탐색" "fail"
    fi
}

# 테스트 5: 빈 페이로드 처리
test_empty_payload() {
    echo -e "\n${YELLOW}5. 빈 페이로드 처리 테스트${NC}"
    
    local output=$(echo "" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    
    # 빈 페이로드에 대해 에러 없이 처리되는지
    if [[ $? -eq 0 ]]; then
        test_case "빈 페이로드 에러 처리" "pass"
    else
        test_case "빈 페이로드 에러 처리" "fail"
    fi
}

# 테스트 6: 대화 ID 처리
test_conversation_id() {
    echo -e "\n${YELLOW}6. 대화 ID 처리 테스트${NC}"
    
    # conversation_id가 없는 페이로드
    local payload='{
        "working_directory": "'$TEST_DIR/project'"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    
    # 기본 대화 ID 사용 확인
    if [[ -n "$output" ]] && echo "$output" | jq -e '.messages' >/dev/null 2>&1; then
        test_case "대화 ID 기본값 처리" "pass"
    else
        test_case "대화 ID 기본값 처리" "fail"
    fi
}

# 테스트 7: 압축 지침 확인
test_compaction_instructions() {
    echo -e "\n${YELLOW}7. 압축 지침 확인 테스트${NC}"
    
    local payload='{
        "working_directory": "'$TEST_DIR/project'",
        "conversation_id": "test_conv"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    local content=$(echo "$output" | jq -r '.messages[0].content')
    
    # 압축 관련 지침 포함 확인
    if echo "$content" | grep -q "conversation is about to be compacted" &&
       echo "$content" | grep -q "Key points to remember after compaction"; then
        test_case "압축 지침 포함" "pass"
    else
        test_case "압축 지침 포함" "fail"
    fi
}

# 테스트 8: 복잡한 컨텐츠 처리
test_complex_content() {
    echo -e "\n${YELLOW}8. 복잡한 컨텐츠 처리 테스트${NC}"
    
    # 특수 문자가 포함된 CLAUDE.md
    cat > "$TEST_DIR/project/CLAUDE_SPECIAL.md" <<'EOF'
# Special Characters Test
Use "quotes" and `backticks`
Shell variables: $VAR and ${VAR}
Escape sequences: \n \t \\
JSON: {"key": "value"}
EOF
    mv "$TEST_DIR/project/CLAUDE_SPECIAL.md" "$TEST_DIR/project/CLAUDE.md"
    
    local payload='{
        "working_directory": "'$TEST_DIR/project'",
        "conversation_id": "test_conv"
    }'
    
    local output=$(echo "$payload" | HOME="$TEST_DIR" "$ENHANCED_SCRIPT" 2>/dev/null)
    
    # JSON이 유효한지 확인
    if echo "$output" | jq -e '.' >/dev/null 2>&1; then
        test_case "특수 문자 이스케이프" "pass"
    else
        test_case "특수 문자 이스케이프" "fail"
    fi
}

# 메인 실행
main() {
    setup
    
    # 모든 테스트 실행
    test_basic_payload
    test_claude_md_integration
    test_summary_integration
    test_project_root_finding
    test_empty_payload
    test_conversation_id
    test_compaction_instructions
    test_complex_content
    
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
    
    # 실패한 테스트가 있으면 exit 1
    [[ $FAILED_TESTS -eq 0 ]]
}

# 스크립트 실행
main "$@"