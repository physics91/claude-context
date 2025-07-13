#!/usr/bin/env bash
set -euo pipefail

# 안전성이 강화된 토큰 모니터링 시스템
# 사이드 이펙트를 최소화하고 에러 복구 강화

# --- 설정 ---
HISTORY_DIR="${HISTORY_DIR:-${HOME}/.claude/history}"
SUMMARY_DIR="${SUMMARY_DIR:-${HOME}/.claude/summaries}"
LOG_FILE="${TMPDIR:-/tmp}/claude_token_monitor.log"
TOKEN_THRESHOLD=5000
MESSAGE_THRESHOLD=30
LOCK_DIR="${TMPDIR:-/tmp}/claude_locks"

# 디렉토리 생성
mkdir -p "$HISTORY_DIR" "$SUMMARY_DIR" "$LOCK_DIR" 2>/dev/null || true

exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SafeTokenMonitor] $*" >&2; }

# --- 파일 락 메커니즘 ---
acquire_lock() {
    local lockfile="$1"
    local timeout=5
    local elapsed=0
    
    while ! mkdir "$lockfile" 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            log "WARNING: Lock timeout for $lockfile"
            return 1
        fi
        sleep 0.1
        elapsed=$((elapsed + 1))
    done
    return 0
}

release_lock() {
    local lockfile="$1"
    rmdir "$lockfile" 2>/dev/null || true
}

# --- 안전한 대화 기록 추적 ---
track_conversation() {
    local conversation_id="${1:-default}"
    local message_content="$2"
    local history_file="${HISTORY_DIR}/conv_${conversation_id}.jsonl"
    local lockfile="${LOCK_DIR}/${conversation_id}.lock"
    
    # 락 획득 시도
    if ! acquire_lock "$lockfile"; then
        log "Failed to acquire lock for $conversation_id"
        return 1
    fi
    
    # 트랩 설정으로 락 해제 보장
    trap "release_lock '$lockfile'" EXIT
    
    # 안전한 파일 쓰기
    {
        echo "{\"timestamp\": \"$(date -Iseconds)\", \"content\": $(jq -R . <<< "$message_content")}"
    } >> "$history_file" || {
        log "ERROR: Failed to write to history file"
        release_lock "$lockfile"
        return 1
    }
    
    # 메시지 수 확인
    local message_count=$(wc -l < "$history_file" 2>/dev/null || echo 0)
    log "Conversation $conversation_id: $message_count messages"
    
    # gemini 사용 가능 여부 체크
    if ! command -v gemini >/dev/null 2>&1; then
        log "WARNING: gemini not found, skipping auto-summary"
        release_lock "$lockfile"
        return 0
    fi
    
    # 토큰 수 추정
    local estimated_tokens=$(( $(wc -c < "$history_file" 2>/dev/null || echo 0) / 4 ))
    
    # 요약 필요 여부 확인 (조건 완화)
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

# --- 안전한 자동 요약 ---
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
    
    # Gemini 요약 (에러 처리 강화)
    local summary_prompt="다음 대화를 핵심만 추출해 요약하세요:
- 해결된 문제와 솔루션
- 중요 결정사항
- 진행중인 작업
- 코드 변경사항 (파일명과 주요 변경점만)
최대 500단어 이내로 작성하세요.

대화 내용:
$(jq -r '.content' < "$temp_file" 2>/dev/null | head -c 10000)"
    
    log "Calling gemini for summary..."
    if gemini -p "$summary_prompt" > "$summary_file" 2>/dev/null; then
        log "Summary created: $summary_file"
        
        # 안전한 히스토리 업데이트
        {
            echo "{\"type\": \"summary\", \"file\": \"$summary_file\", \"range\": \"1-$messages_to_summarize\"}"
            tail -n 10 "$history_file"
        } > "$temp_file" && mv "$temp_file" "$history_file" || {
            log "ERROR: Failed to update history, restoring backup"
            mv "$backup_file" "$history_file"
            rm -f "$temp_file" "$summary_file"
            return 1
        }
        
        log "History compacted with summary reference"
        rm -f "$backup_file"
    else
        log "ERROR: Failed to create summary, keeping original history"
        rm -f "$temp_file" "$summary_file" "$backup_file"
        return 1
    fi
}

# --- 요약 주입 (읽기 전용) ---
inject_summaries() {
    local conversation_id="${1:-default}"
    local output=""
    
    # 관련 요약 파일들 찾기 (최근 3개만)
    local summaries=($(ls -t "${SUMMARY_DIR}"/summary_"${conversation_id}"_*.md 2>/dev/null | head -3))
    
    if [[ ${#summaries[@]} -gt 0 ]]; then
        output="## 이전 대화 요약\n\n"
        for summary in "${summaries[@]}"; do
            if [[ -f "$summary" ]] && [[ -r "$summary" ]]; then
                output+="### $(basename "$summary" .md)\n\n"
                output+="$(cat "$summary" 2>/dev/null || echo "[요약 읽기 실패]")\n\n"
            fi
        done
    fi
    
    echo -e "$output"
}

# --- 메인 실행 ---
case "${1:-}" in
    "track")
        track_conversation "${2:-default}" "${3:-}"
        ;;
    "inject")
        inject_summaries "${2:-default}"
        ;;
    "cleanup")
        # 오래된 파일 정리 (안전하게)
        find "$HISTORY_DIR" -name "*.jsonl" -mtime +7 -type f -delete 2>/dev/null || true
        find "$SUMMARY_DIR" -name "*.md" -mtime +30 -type f -delete 2>/dev/null || true
        find "$LOCK_DIR" -type d -mmin +60 -delete 2>/dev/null || true
        log "Cleanup completed"
        ;;
    *)
        echo "Usage: $0 {track|inject|cleanup} [args...]"
        exit 1
        ;;
esac