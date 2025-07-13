#!/usr/bin/env bash
set -euo pipefail

# Claude 대화 기록 관리 시스템
# gemini 의존성 없이 독립적으로 작동

# --- 설정 ---
HISTORY_DIR="${HISTORY_DIR:-${HOME}/.claude/history}"
SUMMARY_DIR="${SUMMARY_DIR:-${HOME}/.claude/summaries}"
INDEX_FILE="${HISTORY_DIR}/.index.json"
LOG_FILE="${TMPDIR:-/tmp}/claude_history_manager.log"

# 대화 기록 설정
MAX_HISTORY_SIZE=10000  # 대화당 최대 메시지 수
SUMMARY_THRESHOLD=50    # 요약 트리거 메시지 수
ARCHIVE_DAYS=30         # 보관 기간

# 디렉토리 생성
mkdir -p "$HISTORY_DIR" "$SUMMARY_DIR" 2>/dev/null || true

exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [HistoryManager] $*" >&2; }

# --- 대화 세션 관리 ---
create_session() {
    local session_id="${1:-$(date +%s)}"
    local session_file="$HISTORY_DIR/session_${session_id}.jsonl"
    local metadata="{
        \"session_id\": \"$session_id\",
        \"created_at\": \"$(date -Iseconds)\",
        \"project\": \"${PWD}\",
        \"message_count\": 0
    }"
    
    echo "$metadata" > "${session_file}.meta"
    touch "$session_file"
    
    # 인덱스 업데이트
    update_index "add" "$session_id"
    
    echo "$session_id"
}

# --- 메시지 추가 ---
add_message() {
    local session_id="$1"
    local role="$2"  # user, assistant, system
    local content="$3"
    local session_file="$HISTORY_DIR/session_${session_id}.jsonl"
    
    if [[ ! -f "$session_file" ]]; then
        log "Session not found: $session_id"
        return 1
    fi
    
    # 메시지 생성
    local message=$(jq -c -n \
        --arg role "$role" \
        --arg content "$content" \
        --arg timestamp "$(date -Iseconds)" \
        '{
            role: $role,
            content: $content,
            timestamp: $timestamp
        }')
    
    # 파일에 추가
    echo "$message" >> "$session_file"
    
    # 메타데이터 업데이트
    local count=$(wc -l < "$session_file")
    jq --arg count "$count" '.message_count = ($count | tonumber)' \
        "${session_file}.meta" > "${session_file}.meta.tmp" && \
        mv "${session_file}.meta.tmp" "${session_file}.meta"
    
    # 자동 요약 체크
    if [[ $((count % SUMMARY_THRESHOLD)) -eq 0 ]]; then
        log "Auto-summarizing session $session_id (message count: $count)"
        summarize_session "$session_id" "$((count - SUMMARY_THRESHOLD + 1))" "$count"
    fi
}

# --- 간단한 내장 요약 기능 ---
summarize_session() {
    local session_id="$1"
    local start_line="${2:-1}"
    local end_line="${3:-}"
    local session_file="$HISTORY_DIR/session_${session_id}.jsonl"
    local summary_file="$SUMMARY_DIR/summary_${session_id}_$(date +%s).json"
    
    if [[ ! -f "$session_file" ]]; then
        return 1
    fi
    
    # 메시지 추출
    local messages
    if [[ -n "$end_line" ]]; then
        messages=$(sed -n "${start_line},${end_line}p" "$session_file")
    else
        messages=$(tail -n "+$start_line" "$session_file")
    fi
    
    # 간단한 통계 기반 요약
    local user_count=$(echo "$messages" | jq -s '[.[] | select(.role == "user")] | length')
    local assistant_count=$(echo "$messages" | jq -s '[.[] | select(.role == "assistant")] | length')
    
    # 주요 키워드 추출 (간단한 빈도 분석)
    local keywords=$(echo "$messages" | \
        jq -r '.content' | \
        tr '[:upper:]' '[:lower:]' | \
        grep -oE '\b[a-z]{4,}\b' | \
        sort | uniq -c | sort -nr | head -10 | \
        awk '{print $2}' | jq -R . | jq -s .)
    
    # 첫 번째와 마지막 메시지
    local first_msg=$(echo "$messages" | head -1 | jq -r '.content' | head -c 100)
    local last_msg=$(echo "$messages" | tail -1 | jq -r '.content' | head -c 100)
    
    # 요약 생성
    jq -n \
        --arg session_id "$session_id" \
        --arg start "$start_line" \
        --arg end "${end_line:-end}" \
        --arg timestamp "$(date -Iseconds)" \
        --argjson user_count "$user_count" \
        --argjson assistant_count "$assistant_count" \
        --argjson keywords "$keywords" \
        --arg first_msg "$first_msg..." \
        --arg last_msg "$last_msg..." \
        '{
            session_id: $session_id,
            range: {start: $start, end: $end},
            timestamp: $timestamp,
            statistics: {
                user_messages: $user_count,
                assistant_messages: $assistant_count,
                total_messages: ($user_count + $assistant_count)
            },
            keywords: $keywords,
            preview: {
                first: $first_msg,
                last: $last_msg
            }
        }' > "$summary_file"
    
    log "Summary created: $summary_file"
    
    # 원본 메시지 압축 (선택적)
    if [[ "${COMPRESS_HISTORY:-false}" == "true" ]]; then
        local temp_file=$(mktemp)
        echo "$messages" | gzip > "${summary_file}.gz"
        sed -i "${start_line},${end_line}d" "$session_file"
        echo "{\"type\": \"summary_ref\", \"file\": \"$summary_file\", \"compressed\": \"${summary_file}.gz\"}" >> "$session_file"
    fi
}

# --- 대화 검색 ---
search_history() {
    local query="$1"
    local results=()
    
    # 모든 세션 파일 검색
    for session_file in "$HISTORY_DIR"/session_*.jsonl; do
        [[ -f "$session_file" ]] || continue
        
        local session_id=$(basename "$session_file" .jsonl | cut -d_ -f2)
        local matches=$(grep -i "$query" "$session_file" 2>/dev/null | head -5)
        
        if [[ -n "$matches" ]]; then
            results+=("Session $session_id:")
            while IFS= read -r line; do
                local preview=$(echo "$line" | jq -r '.content' | head -c 80)
                results+=("  $preview...")
            done <<< "$matches"
            results+=("")
        fi
    done
    
    if [[ ${#results[@]} -eq 0 ]]; then
        echo "No matches found for: $query"
    else
        printf '%s\n' "${results[@]}"
    fi
}

# --- 세션 목록 ---
list_sessions() {
    local format="${1:-simple}"  # simple, detailed, json
    
    case "$format" in
        simple)
            for meta_file in "$HISTORY_DIR"/session_*.jsonl.meta; do
                [[ -f "$meta_file" ]] || continue
                local session_id=$(basename "$meta_file" | sed 's/^session_//' | sed 's/\.jsonl\.meta$//')
                local created=$(jq -r '.created_at' "$meta_file")
                local count=$(jq -r '.message_count' "$meta_file")
                echo "[$session_id] $created - $count messages"
            done
            ;;
        detailed)
            for meta_file in "$HISTORY_DIR"/session_*.jsonl.meta; do
                [[ -f "$meta_file" ]] || continue
                echo "---"
                jq . "$meta_file"
            done
            ;;
        json)
            local sessions=()
            for meta_file in "$HISTORY_DIR"/session_*.jsonl.meta; do
                [[ -f "$meta_file" ]] || continue
                sessions+=("$(cat "$meta_file")")
            done
            printf '%s\n' "${sessions[@]}" | jq -s .
            ;;
    esac
}

# --- 세션 내보내기 ---
export_session() {
    local session_id="$1"
    local output_format="${2:-markdown}"  # markdown, json, txt
    local output_file="${3:-session_${session_id}_export.${output_format}}"
    local session_file="$HISTORY_DIR/session_${session_id}.jsonl"
    
    if [[ ! -f "$session_file" ]]; then
        echo "Session not found: $session_id"
        return 1
    fi
    
    case "$output_format" in
        markdown)
            {
                echo "# Claude Session Export - $session_id"
                echo
                jq -r '.created_at' "${session_file}.meta" | xargs -I{} echo "Created: {}"
                echo
                
                while IFS= read -r line; do
                    local role=$(echo "$line" | jq -r '.role')
                    local content=$(echo "$line" | jq -r '.content')
                    local timestamp=$(echo "$line" | jq -r '.timestamp')
                    
                    case "$role" in
                        user)
                            echo "## 👤 User [$timestamp]"
                            ;;
                        assistant)
                            echo "## 🤖 Assistant [$timestamp]"
                            ;;
                        system)
                            echo "## 📋 System [$timestamp]"
                            ;;
                    esac
                    echo
                    echo "$content"
                    echo
                done < "$session_file"
            } > "$output_file"
            ;;
        json)
            jq -s . "$session_file" > "$output_file"
            ;;
        txt)
            jq -r '"[\(.role)] \(.content)\n"' "$session_file" > "$output_file"
            ;;
    esac
    
    echo "Exported to: $output_file"
}

# --- 인덱스 관리 ---
update_index() {
    local action="$1"  # add, remove
    local session_id="$2"
    
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo "[]" > "$INDEX_FILE"
    fi
    
    case "$action" in
        add)
            jq --arg id "$session_id" '. + [$id] | unique' "$INDEX_FILE" > "$INDEX_FILE.tmp"
            ;;
        remove)
            jq --arg id "$session_id" 'map(select(. != $id))' "$INDEX_FILE" > "$INDEX_FILE.tmp"
            ;;
    esac
    
    mv "$INDEX_FILE.tmp" "$INDEX_FILE"
}

# --- 정리 기능 ---
cleanup_old_sessions() {
    local days="${1:-$ARCHIVE_DAYS}"
    local count=0
    
    find "$HISTORY_DIR" -name "session_*.jsonl" -mtime "+$days" | while read -r file; do
        local session_id=$(basename "$file" .jsonl | cut -d_ -f2)
        
        # 아카이브 생성
        tar -czf "$HISTORY_DIR/archive_${session_id}.tar.gz" \
            "$file" "${file}.meta" 2>/dev/null || true
        
        # 원본 삭제
        rm -f "$file" "${file}.meta"
        update_index "remove" "$session_id"
        
        ((count++))
    done
    
    log "Archived $count old sessions"
}

# --- 메인 실행 ---
main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        create)
            create_session "$@"
            ;;
        add)
            add_message "$@"
            ;;
        search)
            search_history "$@"
            ;;
        list)
            list_sessions "$@"
            ;;
        export)
            export_session "$@"
            ;;
        summarize)
            summarize_session "$@"
            ;;
        cleanup)
            cleanup_old_sessions "$@"
            ;;
        help|--help|-h)
            cat << EOF
Claude History Manager - 대화 기록 관리 도구

사용법:
  $0 create [session_id]           - 새 세션 생성
  $0 add <session_id> <role> <msg> - 메시지 추가
  $0 search <query>                - 대화 검색
  $0 list [format]                 - 세션 목록 (simple/detailed/json)
  $0 export <session_id> [format]  - 세션 내보내기 (markdown/json/txt)
  $0 summarize <session_id> [start] [end] - 세션 요약
  $0 cleanup [days]                - 오래된 세션 정리

예시:
  $0 create                        # 새 세션 시작
  $0 add 1234567890 user "안녕하세요"
  $0 search "프로젝트"
  $0 export 1234567890 markdown
EOF
            ;;
        *)
            echo "Unknown command: $command"
            echo "Use '$0 help' for usage"
            exit 1
            ;;
    esac
}

# 직접 실행 시에만 메인 함수 호출
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi