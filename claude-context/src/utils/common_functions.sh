#!/usr/bin/env bash
# Claude Context - 공통 함수 라이브러리
# 모든 스크립트에서 공유하는 함수들

# --- 로깅 함수 ---
log_info() {
    local message="$1"
    local component="${2:-Common}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$component] INFO: $message" >&2
}

log_error() {
    local message="$1"
    local component="${2:-Common}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$component] ERROR: $message" >&2
}

log_debug() {
    local message="$1"
    local component="${2:-Common}"
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$component] DEBUG: $message" >&2
    fi
}

# --- 파일 시스템 유틸리티 ---
ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir" 2>/dev/null || {
            log_error "Failed to create directory: $dir"
            return 1
        }
    fi
}

file_exists() {
    [[ -f "$1" ]]
}

directory_exists() {
    [[ -d "$1" ]]
}

# --- CLAUDE.md 파일 관리 ---
find_claude_md_files() {
    local claude_files=()
    
    # 1. 전역 CLAUDE.md
    local global_file="${HOME}/.claude/CLAUDE.md"
    if file_exists "$global_file"; then
        claude_files+=("$global_file")
    fi
    
    # 2. 프로젝트별 CLAUDE.md 찾기
    local current_dir="$PWD"
    while [[ "$current_dir" != "/" ]]; do
        # 다양한 패턴 확인
        for pattern in "CLAUDE.md" ".claude/CLAUDE.md" ".claude.md"; do
            local test_path="$current_dir/$pattern"
            if file_exists "$test_path"; then
                claude_files+=("$test_path")
                echo "${claude_files[@]}"
                return 0
            fi
        done
        current_dir="$(dirname "$current_dir")"
    done
    
    echo "${claude_files[@]}"
}

get_merged_claude_content() {
    local claude_files
    claude_files=($(find_claude_md_files))
    local merged_content=""
    
    for file in "${claude_files[@]}"; do
        if [[ -n "$merged_content" ]]; then
            merged_content+="\n\n"
        fi
        
        if [[ "$file" == "${HOME}/.claude/CLAUDE.md" ]]; then
            merged_content+="# Global CLAUDE.md Instructions\n\n"
        else
            merged_content+="# Project-specific CLAUDE.md Instructions (from: $file)\n\n"
        fi
        
        merged_content+="$(cat "$file")"
    done
    
    echo -n "$merged_content"
}

# --- 캐싱 유틸리티 ---
get_cache_dir() {
    local cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/claude-context"
    ensure_directory "$cache_dir"
    echo "$cache_dir"
}

generate_content_hash() {
    local content="$1"
    echo -n "$content" | sha256sum | cut -d' ' -f1
}

is_cache_valid() {
    local cache_file="$1"
    local max_age="${2:-3600}"  # 기본 1시간
    
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    
    local file_age
    if [[ "$OSTYPE" == "darwin"* ]]; then
        file_age=$(($(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0)))
    else
        file_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
    fi
    
    [[ $file_age -lt $max_age ]]
}

# --- 파일 락 유틸리티 ---
acquire_lock() {
    local lock_file="$1"
    local timeout="${2:-5}"
    local count=0
    
    while [[ $count -lt $timeout ]]; do
        if mkdir "$lock_file" 2>/dev/null; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    
    log_error "Failed to acquire lock: $lock_file"
    return 1
}

release_lock() {
    local lock_file="$1"
    rm -rf "$lock_file" 2>/dev/null || true
}

# --- 환경 변수 및 설정 ---
load_config() {
    # 설정 파일 우선순위
    local config_locations=(
        "${CLAUDE_CONFIG_FILE:-}"  # 환경변수로 지정된 경로
        "${HOME}/.claude/hooks/claude-context/config.sh"  # claude-context 디렉토리
        "${HOME}/.claude/hooks/config.sh"  # hooks 루트
    )
    
    local config_file=""
    for location in "${config_locations[@]}"; do
        if [[ -n "$location" ]] && file_exists "$location"; then
            config_file="$location"
            break
        fi
    done
    
    if [[ -n "$config_file" ]]; then
        source "$config_file"
        log_debug "Loaded config from: $config_file"
    else
        # 기본값 설정
        export CLAUDE_CONTEXT_MODE="${CLAUDE_CONTEXT_MODE:-basic}"
        export CLAUDE_INJECT_PROBABILITY="${CLAUDE_INJECT_PROBABILITY:-1.0}"
        export CLAUDE_ENABLE_CACHE="${CLAUDE_ENABLE_CACHE:-true}"
        export CLAUDE_HOME="${CLAUDE_HOME:-${HOME}/.claude}"
        export CLAUDE_HOOKS_DIR="${CLAUDE_HOOKS_DIR:-${CLAUDE_HOME}/hooks}"
        export CLAUDE_HISTORY_DIR="${CLAUDE_HISTORY_DIR:-${CLAUDE_HOME}/history}"
        export CLAUDE_SUMMARY_DIR="${CLAUDE_SUMMARY_DIR:-${CLAUDE_HOME}/summaries}"
        export CLAUDE_CACHE_DIR="${CLAUDE_CACHE_DIR:-${XDG_CACHE_HOME:-${HOME}/.cache}/claude-context}"
        export CLAUDE_LOG_DIR="${CLAUDE_LOG_DIR:-${TMPDIR:-/tmp}}"
        export CLAUDE_CACHE_MAX_AGE="${CLAUDE_CACHE_MAX_AGE:-3600}"
        export CLAUDE_LOCK_TIMEOUT="${CLAUDE_LOCK_TIMEOUT:-5}"
        log_debug "Using default configuration"
    fi
}

get_mode() {
    echo "${CLAUDE_CONTEXT_MODE:-basic}"
}

is_mode_enabled() {
    local required_mode="$1"
    local current_mode="$(get_mode)"
    
    case "$required_mode" in
        "basic")
            return 0  # 항상 활성화
            ;;
        "history")
            [[ "$current_mode" == "history" || "$current_mode" == "advanced" ]]
            ;;
        "advanced")
            [[ "$current_mode" == "advanced" ]]
            ;;
        *)
            return 1
            ;;
    esac
}

# --- 확률 체크 ---
should_inject() {
    local probability="${CLAUDE_INJECT_PROBABILITY:-1.0}"
    
    # 확률이 1.0이면 항상 true
    if [[ "$probability" == "1.0" || "$probability" == "1" ]]; then
        return 0
    fi
    
    # 확률이 0이면 항상 false
    if [[ "$probability" == "0.0" || "$probability" == "0" ]]; then
        return 1
    fi
    
    # 확률 계산
    local random=$((RANDOM % 100))
    local threshold=$(awk "BEGIN {printf \"%.0f\", $probability * 100}")
    
    [[ $random -lt $threshold ]]
}

# --- 중복 체크 ---
is_already_injected() {
    local content="$1"
    local marker="${2:-CLAUDE_MD_INJECTED}"
    
    echo "$content" | grep -q "<!-- $marker -->" 2>/dev/null
}

add_injection_marker() {
    local content="$1"
    local marker="${2:-CLAUDE_MD_INJECTED}"
    
    echo -e "$content\n<!-- $marker -->"
}

# --- 시스템 유틸리티 ---
get_timestamp() {
    date +%s
}

get_iso_timestamp() {
    date -Iseconds
}

# --- JSON 유틸리티 ---
json_escape() {
    local text="$1"
    jq -n --arg text "$text" '$text'
}

# --- 압축 유틸리티 ---
compress_content() {
    local content="$1"
    echo -n "$content" | gzip -c | base64 -w 0
}

decompress_content() {
    local compressed="$1"
    echo -n "$compressed" | base64 -d | gzip -d
}