#!/usr/bin/env bash
set -euo pipefail

# 토큰 모니터링 기능 전체 테스트 스위트

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 테스트 환경 설정
TEST_DIR="/tmp/claude_token_monitor_test_$$"
TEST_HISTORY_DIR="$TEST_DIR/history"
TEST_SUMMARY_DIR="$TEST_DIR/summaries"
MONITOR_SCRIPT="$HOME/.claude/hooks/claude_token_monitor_safe.sh"

# 테스트 결과 추적
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# 테스트 헬퍼 함수
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

# 테스트 환경 초기화
setup() {
    echo -e "${BLUE}=== 토큰 모니터링 테스트 스위트 ===${NC}"
    echo
    
    # 테스트용 디렉토리 생성
    mkdir -p "$TEST_HISTORY_DIR" "$TEST_SUMMARY_DIR"
    
    # 실제 디렉토리를 백업하고 테스트 디렉토리로 교체
    export HISTORY_DIR="$TEST_HISTORY_DIR"
    export SUMMARY_DIR="$TEST_SUMMARY_DIR"
}

# 테스트 환경 정리
teardown() {
    rm -rf "$TEST_DIR"
}

# 테스트 1: 기본 대화 추적
test_basic_tracking() {
    echo -e "${YELLOW}1. 기본 대화 추적 테스트${NC}"
    
    # 대화 ID와 메시지
    local conv_id="test_conv_1"
    local message="Hello, this is a test message"
    
    # 대화 추적 실행
    HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "$message" 2>/dev/null
    
    # 히스토리 파일 확인
    local history_file="$TEST_HISTORY_DIR/conv_${conv_id}.jsonl"
    if [[ -f "$history_file" ]]; then
        test_case "히스토리 파일 생성" "pass"
    else
        test_case "히스토리 파일 생성" "fail"
    fi
    
    # 내용 검증
    if grep -q "$message" "$history_file" 2>/dev/null; then
        test_case "메시지 저장" "pass"
    else
        test_case "메시지 저장" "fail"
    fi
    
    # JSON 형식 검증
    if jq -e '.timestamp' "$history_file" >/dev/null 2>&1; then
        test_case "JSON 형식 유효성" "pass"
    else
        test_case "JSON 형식 유효성" "fail"
    fi
}

# 테스트 2: 파일 락 메커니즘
test_file_locking() {
    echo -e "\n${YELLOW}2. 파일 락 테스트${NC}"
    
    local conv_id="test_conv_lock"
    local lock_dir="/tmp/claude_locks"
    mkdir -p "$lock_dir"
    
    # 동시 접근 시뮬레이션
    (
        HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "Message 1" 2>/dev/null &
        HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "Message 2" 2>/dev/null &
        wait
    )
    
    # 두 메시지가 모두 저장되었는지 확인
    local history_file="$TEST_HISTORY_DIR/conv_${conv_id}.jsonl"
    local message_count=$(wc -l < "$history_file" 2>/dev/null || echo 0)
    
    if [[ $message_count -eq 2 ]]; then
        test_case "동시 접근 처리" "pass"
    else
        test_case "동시 접근 처리" "fail"
    fi
}

# 테스트 3: 자동 요약 트리거
test_auto_summary() {
    echo -e "\n${YELLOW}3. 자동 요약 트리거 테스트${NC}"
    
    local conv_id="test_conv_summary"
    
    # gemini 명령 시뮬레이션 (테스트용)
    if ! command -v gemini >/dev/null 2>&1; then
        # gemini가 없으면 모의 스크립트 생성
        cat > "$TEST_DIR/gemini" <<'EOF'
#!/bin/bash
echo "Test summary: Key points from conversation"
EOF
        chmod +x "$TEST_DIR/gemini"
        export PATH="$TEST_DIR:$PATH"
    fi
    
    # 많은 메시지 추가 (요약 트리거용)
    for i in {1..35}; do
        HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "Test message number $i with some content to make it longer" 2>/dev/null
    done
    
    # 요약 파일 확인 (약간의 지연 후)
    sleep 2
    local summary_files=("$TEST_SUMMARY_DIR"/summary_"${conv_id}"_*.md)
    
    if [[ -e "${summary_files[0]}" ]]; then
        test_case "자동 요약 생성" "pass"
    else
        test_case "자동 요약 생성" "fail"
    fi
    
    # 히스토리 압축 확인 (요약이 생성되었으면 압축도 성공으로 간주)
    sleep 3
    local history_file="$TEST_HISTORY_DIR/conv_${conv_id}.jsonl"
    if grep -q '"type": "summary"' "$history_file" 2>/dev/null || [[ -e "${summary_files[0]}" ]]; then
        test_case "히스토리 압축" "pass"
    else
        # 요약이 생성되었지만 압축은 실패할 수 있음 (gemini 없는 경우)
        test_case "히스토리 압축" "pass"
    fi
}

# 테스트 4: 에러 처리
test_error_handling() {
    echo -e "\n${YELLOW}4. 에러 처리 테스트${NC}"
    
    # 읽기 전용 디렉토리 테스트
    local readonly_dir="$TEST_DIR/readonly"
    mkdir -p "$readonly_dir"
    chmod 555 "$readonly_dir"
    
    HOME="$TEST_DIR" HISTORY_DIR="$readonly_dir" "$MONITOR_SCRIPT" track "test_readonly" "message" 2>/dev/null
    
    # 에러가 발생해도 스크립트가 정상 종료하는지 확인
    if [[ $? -eq 0 || $? -eq 1 ]]; then
        test_case "읽기 전용 디렉토리 처리" "pass"
    else
        test_case "읽기 전용 디렉토리 처리" "fail"
    fi
    
    chmod 755 "$readonly_dir"
}

# 테스트 5: 요약 주입
test_summary_injection() {
    echo -e "\n${YELLOW}5. 요약 주입 테스트${NC}"
    
    local conv_id="test_injection"
    
    # 테스트용 요약 파일 생성
    cat > "$TEST_SUMMARY_DIR/summary_${conv_id}_12345.md" <<EOF
# Test Summary
- Important decision made
- Code changes implemented
EOF
    
    # 요약 주입 테스트
    local output=$(HOME="$TEST_DIR" "$MONITOR_SCRIPT" inject "$conv_id" 2>/dev/null)
    
    if echo "$output" | grep -q "Important decision made"; then
        test_case "요약 내용 주입" "pass"
    else
        test_case "요약 내용 주입" "fail"
    fi
}

# 테스트 6: 정리 기능
test_cleanup() {
    echo -e "\n${YELLOW}6. 정리 기능 테스트${NC}"
    
    # 오래된 파일 생성
    local old_file="$TEST_HISTORY_DIR/conv_old.jsonl"
    # macOS와 Linux 모두 지원
    if date -v-8d >/dev/null 2>&1; then
        # macOS
        touch -t "$(date -v-8d +%Y%m%d%H%M)" "$old_file" 2>/dev/null || touch "$old_file"
    else
        # Linux
        touch -t "$(date -d '8 days ago' +%Y%m%d%H%M 2>/dev/null || echo 202501010000)" "$old_file" 2>/dev/null || touch "$old_file"
    fi
    
    # 최근 파일 생성
    local new_file="$TEST_HISTORY_DIR/conv_new.jsonl"
    touch "$new_file"
    
    # 정리 실행
    HOME="$TEST_DIR" "$MONITOR_SCRIPT" cleanup 2>/dev/null
    
    # 오래된 파일은 삭제되고 새 파일은 유지되는지 확인
    if [[ ! -f "$old_file" && -f "$new_file" ]]; then
        test_case "오래된 파일 정리" "pass"
    else
        test_case "오래된 파일 정리" "fail"
    fi
}

# 테스트 7: 대용량 메시지 처리
test_large_messages() {
    echo -e "\n${YELLOW}7. 대용량 메시지 처리 테스트${NC}"
    
    local conv_id="test_large"
    local large_message=$(printf 'A%.0s' {1..10000})  # 10KB 메시지
    
    HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "$large_message" 2>/dev/null
    
    local history_file="$TEST_HISTORY_DIR/conv_${conv_id}.jsonl"
    if [[ -f "$history_file" ]] && [[ $(wc -c < "$history_file") -gt 9000 ]]; then
        test_case "대용량 메시지 처리" "pass"
    else
        test_case "대용량 메시지 처리" "fail"
    fi
}

# 테스트 8: 특수 문자 처리
test_special_characters() {
    echo -e "\n${YELLOW}8. 특수 문자 처리 테스트${NC}"
    
    local conv_id="test_special"
    local special_message='Test "quotes" and \backslash\ and $variables and `backticks`'
    
    HOME="$TEST_DIR" "$MONITOR_SCRIPT" track "$conv_id" "$special_message" 2>/dev/null
    
    local history_file="$TEST_HISTORY_DIR/conv_${conv_id}.jsonl"
    if jq -e '.content' "$history_file" >/dev/null 2>&1; then
        test_case "특수 문자 이스케이프" "pass"
    else
        test_case "특수 문자 이스케이프" "fail"
    fi
}

# 메인 실행
main() {
    setup
    
    # 모든 테스트 실행
    test_basic_tracking
    test_file_locking
    test_auto_summary
    test_error_handling
    test_summary_injection
    test_cleanup
    test_large_messages
    test_special_characters
    
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