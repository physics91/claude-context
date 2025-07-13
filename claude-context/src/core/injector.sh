#!/usr/bin/env bash
set -euo pipefail

# Claude Context - 통합 Injector
# PreToolUse hook으로 CLAUDE.md 내용과 컨텍스트를 주입

# 스크립트 디렉토리 찾기
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 공통 함수 및 설정 로드
source "${SCRIPT_DIR}/../utils/common_functions.sh"
load_config

# 컴포넌트 이름 설정
COMPONENT="Injector"

# --- 초기화 ---
log_debug "Starting injector (mode: $(get_mode))" "$COMPONENT"

# 디렉토리 생성
ensure_directory "$CLAUDE_CACHE_DIR"
ensure_directory "$CLAUDE_LOG_DIR"

# 락 파일 설정
LOCK_FILE="${CLAUDE_LOG_DIR}/claude_injector.lock"

# 로그 파일 리다이렉션
exec 2>>"${CLAUDE_LOG_DIR}/claude_injector.log"

# --- History Manager 초기화 (history/advanced 모드) ---
if is_mode_enabled "history"; then
    HISTORY_MANAGER="${SCRIPT_DIR}/../monitor/claude_history_manager.sh"
    SESSION_ID="${CLAUDE_SESSION_ID:-$(get_timestamp)}"
    export CLAUDE_SESSION_ID="$SESSION_ID"
    
    # 세션 생성 (없으면)
    if [[ -x "$HISTORY_MANAGER" ]] && [[ ! -f "${CLAUDE_HISTORY_DIR}/session_${SESSION_ID}.jsonl" ]]; then
        "$HISTORY_MANAGER" create "$SESSION_ID" 2>/dev/null || true
    fi
fi

# --- Token Monitor 초기화 (advanced 모드) ---
if is_mode_enabled "advanced"; then
    TOKEN_MONITOR="${SCRIPT_DIR}/../monitor/claude_token_monitor_safe.sh"
fi

# --- 대화 기록 추가 함수 ---
track_message() {
    local role="${1:-user}"
    local content="${2:-}"
    
    if is_mode_enabled "history" && [[ -x "$HISTORY_MANAGER" ]] && [[ -n "$content" ]]; then
        HISTORY_DIR="$CLAUDE_HISTORY_DIR" \
        SUMMARY_DIR="$CLAUDE_SUMMARY_DIR" \
        "$HISTORY_MANAGER" add "$SESSION_ID" "$role" "$content" 2>/dev/null || true
    fi
    
    if is_mode_enabled "advanced" && [[ -x "$TOKEN_MONITOR" ]] && [[ -n "$content" ]]; then
        "$TOKEN_MONITOR" track "$SESSION_ID" "$content" 2>/dev/null || true
    fi
}

# --- CLAUDE.md 컨텐츠 생성 ---
build_claude_content() {
    local content=""
    
    # 1. CLAUDE.md 파일들 병합
    local claude_md_content=$(get_merged_claude_content)
    if [[ -n "$claude_md_content" ]]; then
        content+="$claude_md_content\n\n"
    fi
    
    # 2. History 모드: 세션 정보 추가
    if is_mode_enabled "history" && [[ -x "$HISTORY_MANAGER" ]]; then
        local session_info=$(
            HISTORY_DIR="$CLAUDE_HISTORY_DIR" \
            SUMMARY_DIR="$CLAUDE_SUMMARY_DIR" \
            "$HISTORY_MANAGER" list simple 2>/dev/null | grep "\\[$SESSION_ID\\]" || true
        )
        
        if [[ -n "$session_info" ]]; then
            content+="# Current Session Info\n"
            content+="$session_info\n\n"
            
            # 최근 요약 추가
            local summaries=$(find "$CLAUDE_SUMMARY_DIR" -name "summary_${SESSION_ID}_*.json" 2>/dev/null | sort -r | head -3)
            if [[ -n "$summaries" ]]; then
                content+="## Recent Summaries\n"
                while IFS= read -r summary_file; do
                    if file_exists "$summary_file"; then
                        local preview=$(jq -r '.preview.first' "$summary_file" 2>/dev/null || echo "")
                        if [[ -n "$preview" ]]; then
                            content+="- $preview\n"
                        fi
                    fi
                done <<< "$summaries"
                content+="\n"
            fi
        fi
    fi
    
    # 3. Advanced 모드: 토큰 정보 추가
    if is_mode_enabled "advanced" && [[ -x "$TOKEN_MONITOR" ]]; then
        local token_info=$("$TOKEN_MONITOR" status "$SESSION_ID" 2>/dev/null || true)
        if [[ -n "$token_info" ]]; then
            content+="# Token Usage Info\n"
            content+="$token_info\n\n"
        fi
    fi
    
    echo -n "$content"
}

# --- PreToolUse Hook 핸들러 ---
handle_pretooluse() {
    # 확률 체크
    if ! should_inject; then
        log_debug "Injection skipped (probability check)" "$COMPONENT"
        return 0
    fi
    
    # 락 획득
    if ! acquire_lock "$LOCK_FILE" "$CLAUDE_LOCK_TIMEOUT"; then
        log_error "Failed to acquire lock" "$COMPONENT"
        return 1
    fi
    
    trap 'release_lock "$LOCK_FILE"' EXIT
    
    # 사용자 메시지 추적 (history/advanced 모드)
    local user_message="${INPUT_MESSAGE:-}"
    if [[ -n "$user_message" ]]; then
        track_message "user" "$user_message"
    fi
    
    # CLAUDE 컨텐츠 생성
    local claude_content=$(build_claude_content)
    
    if [[ -z "$claude_content" ]]; then
        log_debug "No content to inject" "$COMPONENT"
        return 0
    fi
    
    # 중복 주입 방지
    if is_already_injected "$claude_content"; then
        log_debug "Content already injected" "$COMPONENT"
        return 0
    fi
    
    # 캐싱 처리
    if [[ "$CLAUDE_ENABLE_CACHE" == "true" ]]; then
        local content_hash=$(generate_content_hash "$claude_content")
        local cache_file="$CLAUDE_CACHE_DIR/${content_hash}.cache"
        
        if is_cache_valid "$cache_file" "$CLAUDE_CACHE_MAX_AGE"; then
            log_debug "Using cached content: $cache_file" "$COMPONENT"
            cat "$cache_file"
            return 0
        fi
        
        # 캐시에 저장
        echo -n "$claude_content" > "$cache_file"
        log_debug "Content cached: $cache_file" "$COMPONENT"
    fi
    
    # 출력
    echo -n "$claude_content"
}

# --- PreCompact Hook 핸들러 ---
handle_precompact() {
    log_debug "Handling PreCompact" "$COMPONENT"
    
    # History/Advanced 모드: 세션 요약 및 새 세션 시작
    if is_mode_enabled "history"; then
        # 현재 세션 요약
        if [[ -x "$HISTORY_MANAGER" ]]; then
            HISTORY_DIR="$CLAUDE_HISTORY_DIR" \
            SUMMARY_DIR="$CLAUDE_SUMMARY_DIR" \
            "$HISTORY_MANAGER" summarize "$SESSION_ID" 2>/dev/null || true
        fi
        
        # Advanced 모드: 토큰 모니터 요약
        if is_mode_enabled "advanced" && [[ -x "$TOKEN_MONITOR" ]]; then
            "$TOKEN_MONITOR" summarize "$SESSION_ID" 2>/dev/null || true
        fi
        
        # 새 세션 ID 생성
        export CLAUDE_SESSION_ID="$(get_timestamp)"
        log_info "New session started: $CLAUDE_SESSION_ID" "$COMPONENT"
    fi
    
    # PreToolUse와 동일한 내용 주입
    handle_pretooluse
}

# --- 메인 실행 ---
main() {
    local hook_type="${1:-pretooluse}"
    
    case "$hook_type" in
        precompact)
            handle_precompact
            ;;
        *)
            handle_pretooluse
            ;;
    esac
}

# 직접 실행 시에만 메인 함수 호출
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi