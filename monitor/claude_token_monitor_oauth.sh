#!/usr/bin/env bash
# Claude Context - Token Monitor (OAuth 기반 버전)
# Claude Code의 OAuth 토큰을 사용한 자동 요약 기능

# --- 설정 ---
CLAUDE_HOME="${HOME}/.claude"
HISTORY_DIR="${CLAUDE_HOME}/history"
SUMMARY_DIR="${CLAUDE_HOME}/summaries"
LOG_FILE="${CLAUDE_HOME}/logs/claude_injector.log"
CREDENTIALS_FILE="${CLAUDE_HOME}/.credentials.json"

# 요약 트리거 임계값
MESSAGE_THRESHOLD=20       # 메시지 수
TOKEN_THRESHOLD=50000      # 토큰 수 (추정)

# Claude API 설정
CLAUDE_API_URL="https://api.anthropic.com/v1/messages"
CLAUDE_MODEL="claude-3-haiku-20240307"  # 비용 효율적인 모델
ANTHROPIC_VERSION="2023-06-01"

# --- 공통 함수 불러오기 ---
source "${CLAUDE_HOME}/hooks/utils/common_functions.sh" 2>/dev/null || {
    echo "ERROR: common_functions.sh not found" >&2
    exit 1
}

# --- OAuth 토큰 가져오기 ---
get_access_token() {
    if [[ ! -f "$CREDENTIALS_FILE" ]]; then
        log "ERROR: Credentials file not found: $CREDENTIALS_FILE"
        return 1
    fi
    
    local access_token=$(jq -r '.claudeAiOauth.accessToken' "$CREDENTIALS_FILE" 2>/dev/null)
    
    if [[ -z "$access_token" ]] || [[ "$access_token" == "null" ]]; then
        log "ERROR: Could not retrieve accessToken from $CREDENTIALS_FILE"
        return 1
    fi
    
    # 토큰 만료 확인
    local expires_at=$(jq -r '.claudeAiOauth.expiresAt' "$CREDENTIALS_FILE" 2>/dev/null)
    local current_time=$(date +%s)000  # 밀리초 단위로 변환
    
    if [[ -n "$expires_at" ]] && [[ "$expires_at" != "null" ]]; then
        if [[ $current_time -gt $expires_at ]]; then
            log "WARNING: Access token has expired (expired at: $expires_at)"
            echo -e "${YELLOW}경고: OAuth 토큰이 만료되었습니다.${NC}" >&2
            echo "Claude Code를 한 번 실행하여 토큰을 갱신해주세요." >&2
            return 1
        fi
    fi
    
    echo "$access_token"
}

# --- Claude API 호출 함수 ---
call_claude_api() {
    local prompt="$1"
    local access_token="$2"
    
    local request_body=$(cat <<EOF
{
    "model": "$CLAUDE_MODEL",
    "max_tokens": 1024,
    "messages": [
        {
            "role": "user",
            "content": "$prompt"
        }
    ]
}
EOF
)
    
    local response=$(curl -s "$CLAUDE_API_URL" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: $ANTHROPIC_VERSION" \
        -H "Authorization: Bearer $access_token" \
        -d "$request_body" 2>/dev/null)
    
    # 에러 체크
    local error_msg=$(echo "$response" | jq -r '.error.message' 2>/dev/null)
    if [[ -n "$error_msg" ]] && [[ "$error_msg" != "null" ]]; then
        log "ERROR: Claude API error: $error_msg"
        return 1
    fi
    
    # 결과 텍스트 추출
    local result_text=$(echo "$response" | jq -r '.content[0].text' 2>/dev/null)
    if [[ -z "$result_text" ]] || [[ "$result_text" == "null" ]]; then
        log "ERROR: Failed to extract text from API response"
        return 1
    fi
    
    echo "$result_text"
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
    
    # jq 사용 가능 여부 체크
    if ! command -v jq >/dev/null 2>&1; then
        log "WARNING: jq not found, skipping auto-summary"
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

# --- OAuth 기반 자동 요약 ---
trigger_summary() {
    local conversation_id="$1"
    local history_file="$2"
    local summary_file="${SUMMARY_DIR}/summary_${conversation_id}_$(date +%s).md"
    local temp_file=$(mktemp)
    local backup_file="${history_file}.backup"
    
    # OAuth 토큰 가져오기
    local access_token=$(get_access_token)
    if [[ -z "$access_token" ]]; then
        log "ERROR: Failed to get access token"
        return 1
    fi
    
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
    
    # 프롬프트 생성 (JSON 특수 문자 이스케이프)
    local conversation_content=$(jq -r '.content' < "$temp_file" 2>/dev/null | head -c 10000 | jq -Rs .)
    local summary_prompt="다음 대화를 핵심만 추출해 요약하세요:
- 해결된 문제와 솔루션
- 중요 결정사항
- 진행중인 작업
- 코드 변경사항 (파일명과 주요 변경점만)
최대 500단어 이내로 작성하세요.

대화 내용:
$conversation_content"
    
    log "Calling Claude API for summary..."
    local summary_text=$(call_claude_api "$summary_prompt" "$access_token")
    
    if [[ -n "$summary_text" ]]; then
        echo "$summary_text" > "$summary_file"
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
        log "ERROR: Failed to create summary with Claude API"
    fi
    
    rm -f "$temp_file"
    return 0
}

# --- 실행 ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    conversation_id="${1:-unknown}"
    monitor_tokens "$conversation_id"
fi