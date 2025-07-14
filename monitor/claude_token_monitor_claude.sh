#!/usr/bin/env bash
# Claude Context - Token Monitor (Claude 기반 버전)
# Claude CLI를 사용한 자동 요약 기능

# --- 설정 ---
CLAUDE_HOME="${HOME}/.claude"
HISTORY_DIR="${CLAUDE_HOME}/history"
SUMMARY_DIR="${CLAUDE_HOME}/summaries"
LOG_FILE="${CLAUDE_HOME}/logs/claude_injector.log"

# 요약 트리거 임계값
MESSAGE_THRESHOLD=20       # 메시지 수
TOKEN_THRESHOLD=50000      # 토큰 수 (추정)

# --- 공통 함수 불러오기 ---
source "${CLAUDE_HOME}/hooks/utils/common_functions.sh" 2>/dev/null || {
    echo "ERROR: common_functions.sh not found" >&2
    exit 1
}

# --- 메인 모니터링 ---
monitor_tokens() {
    local conversation_id="$1"
    local history_file="${HISTORY_DIR}/history_${conversation_id}.jsonl"
    
    # 파일 존재 확인
    if [[ ! -f "$history_file" ]]; then
        log "No history file found for conversation $conversation_id"
        return 0
    fi
    
    # 잠금 설정
    local lockfile="${history_file}.lock"
    if ! acquire_lock "$lockfile"; then
        log "ERROR: Failed to acquire lock for monitoring"
        return 1
    fi
    
    trap "release_lock '$lockfile'" EXIT
    
    # 메시지 수 계산
    local message_count=$(wc -l < "$history_file" 2>/dev/null || echo 0)
    log "Conversation $conversation_id: $message_count messages"
    
    # claude CLI 사용 가능 여부 체크
    if ! command -v claude >/dev/null 2>&1; then
        log "WARNING: claude CLI not found, skipping auto-summary"
        release_lock "$lockfile"
        return 0
    fi
    
    # 토큰 수 추정
    local estimated_tokens=$(( $(wc -c < "$history_file" 2>/dev/null || echo 0) / 4 ))
    
    # 요약 필요 여부 확인
    if [[ $message_count -gt $MESSAGE_THRESHOLD ]] || [[ $estimated_tokens -gt $TOKEN_THRESHOLD ]]; then
        log "Triggering auto-summary for conversation $conversation_id"
        # 백그라운드에서 요약 실행 (블로킹 방지)
        (
            trigger_summary "$conversation_id" "$history_file" &
        )
    fi
    
    release_lock "$lockfile"
    trap - EXIT
    return 0
}

# --- Claude CLI를 사용한 자동 요약 ---
trigger_summary() {
    local conversation_id="$1"
    local history_file="$2"
    local summary_file="${SUMMARY_DIR}/summary_${conversation_id}_$(date +%s).md"
    local temp_file=$(mktemp)
    local backup_file="${history_file}.backup"
    
    # 원본 백업
    cp "$history_file" "$backup_file" 2>/dev/null || {
        log "ERROR: Failed to backup history"
        return 1
    }
    
    # 요약할 메시지 범위 결정
    local total_messages=$(wc -l < "$history_file")
    local messages_to_summarize=$((total_messages - 10))
    
    if [[ $messages_to_summarize -lt 20 ]]; then
        log "Not enough messages to summarize yet"
        rm -f "$temp_file"
        return 0
    fi
    
    # 요약 대상 추출
    head -n "$messages_to_summarize" "$history_file" > "$temp_file"
    
    # Claude CLI를 사용한 요약
    local summary_prompt="다음 대화를 핵심만 추출해 요약하세요:
- 해결된 문제와 솔루션
- 중요 결정사항
- 진행중인 작업
- 코드 변경사항 (파일명과 주요 변경점만)
최대 500단어 이내로 작성하세요.

대화 내용:
$(jq -r '.content' < "$temp_file" 2>/dev/null | head -c 10000)"
    
    log "Calling claude for summary..."
    if echo "$summary_prompt" | claude --no-conversation > "$summary_file" 2>/dev/null; then
        log "Summary created: $summary_file"
        
        # 안전한 히스토리 업데이트
        {
            echo "# Auto-summary $(date '+%Y-%m-%d %H:%M:%S')" > "$history_file.new"
            echo "Summary: $summary_file" >> "$history_file.new"
            echo "---" >> "$history_file.new"
            tail -n 10 "$history_file" >> "$history_file.new"
            
            # 원자적 교체
            mv "$history_file.new" "$history_file"
            log "History compacted for conversation $conversation_id"
        } || {
            log "ERROR: Failed to update history"
            cp "$backup_file" "$history_file" 2>/dev/null
        }
    else
        log "ERROR: Failed to create summary with claude"
    fi
    
    rm -f "$temp_file"
    return 0
}

# --- 실행 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    conversation_id="${1:-unknown}"
    monitor_tokens "$conversation_id"
fi