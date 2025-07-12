#!/usr/bin/env bash
set -euo pipefail

# --- 설정 ---
# 전역 CLAUDE.md 경로
GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"

# 로그 파일 (디버그용)
LOG_FILE="${TMPDIR:-/tmp}/claude_md_injector.log"
exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

# 캐시 디렉토리
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
if ! mkdir -p "${CACHE_DIR}" 2>/dev/null; then
  log "WARNING: Cannot create cache directory ${CACHE_DIR}, caching disabled"
  CACHE_DIR=""
elif ! [[ -w "${CACHE_DIR}" ]]; then
  log "WARNING: Cache directory not writable ${CACHE_DIR}, caching disabled"
  CACHE_DIR=""
fi

# --- 필수 명령어 확인 ---
for cmd in jq sha256sum gzip zcat; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command '$cmd' not found"
    exit 0  # Claude Code hook은 exit 0으로 종료해야 함
  fi
done

# --- JSON 페이로드 읽기 ---
PAYLOAD=$(cat)
if [[ -z "$PAYLOAD" ]]; then
  log "ERROR: Empty payload"
  exit 0
fi

# --- 프로젝트 루트 추출 ---
# Claude Code는 working_directory를 제공
WORKING_DIR=$(echo "$PAYLOAD" | jq -r '.working_directory // empty' 2>/dev/null || echo "")
if [[ -z "$WORKING_DIR" ]]; then
  # fallback: 현재 디렉토리 사용
  WORKING_DIR="$PWD"
fi

log "Working directory: $WORKING_DIR"

# --- 프로젝트 루트 찾기 ---
find_project_root() {
  local dir="$1"
  
  # 1. Git 프로젝트 루트 확인
  if cd "$dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null; then
    return
  fi
  
  # 2. CLAUDE.md가 있는 상위 디렉토리 탐색
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      echo "$dir"
      return
    fi
    dir=$(dirname "$dir")
  done
  
  # 3. 기본값: working directory
  echo "$WORKING_DIR"
}

PROJECT_ROOT=$(find_project_root "$WORKING_DIR")
PROJECT_CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"

log "Project root: $PROJECT_ROOT"
log "Project CLAUDE.md: $PROJECT_CLAUDE_MD"
log "Global CLAUDE.md: $GLOBAL_CLAUDE_MD"

# --- 파일 존재 확인 ---
global_exists=false
project_exists=false

if [[ -f "$GLOBAL_CLAUDE_MD" ]] && [[ -r "$GLOBAL_CLAUDE_MD" ]]; then
  global_exists=true
fi

if [[ -f "$PROJECT_CLAUDE_MD" ]] && [[ -r "$PROJECT_CLAUDE_MD" ]]; then
  project_exists=true
fi

# 둘 다 없으면 종료
if ! $global_exists && ! $project_exists; then
  log "No CLAUDE.md files found"
  exit 0
fi

# --- 캐싱 로직 ---
# 캐시가 사용 가능한 경우에만 캐싱 로직 실행
if [[ -n "$CACHE_DIR" ]]; then
  # 프로젝트별 고유 캐시 키 생성
  CACHE_KEY=$(echo -n "$PROJECT_ROOT" | sha256sum | cut -d' ' -f1)
  CACHE_HASH_FILE="${CACHE_DIR}/${CACHE_KEY}.hash"
  CACHE_CONTENT_FILE="${CACHE_DIR}/${CACHE_KEY}.content.gz"
else
  # 캐시 비활성화 상태
  CACHE_KEY=""
  CACHE_HASH_FILE=""
  CACHE_CONTENT_FILE=""
fi

# 현재 파일들의 해시 계산
# 파일 목록 구성
files_to_hash=()
if $global_exists; then
  files_to_hash+=("$GLOBAL_CLAUDE_MD")
fi
if $project_exists; then
  files_to_hash+=("$PROJECT_CLAUDE_MD")
fi

# sha256sum을 한 번만 호출하여 효율성 향상
if [[ ${#files_to_hash[@]} -gt 0 ]]; then
  current_hashes=$(sha256sum "${files_to_hash[@]}" | awk '{print $1}' | tr '\n' ':' | sed 's/:$//')
else
  current_hashes=""
fi

log "Current hashes: $current_hashes"

# 캐시 유효성 확인
use_cache=false
if [[ -n "$CACHE_DIR" ]] && [[ -f "$CACHE_HASH_FILE" ]] && [[ -f "$CACHE_CONTENT_FILE" ]]; then
  cached_hashes=$(cat "$CACHE_HASH_FILE" 2>/dev/null || echo "")
  if [[ "$cached_hashes" == "$current_hashes" ]]; then
    use_cache=true
    log "Cache is valid, using cached content"
  else
    log "Cache is invalid (hash mismatch)"
  fi
else
  log "No cache found"
fi

# --- 컨텐츠 생성 또는 캐시 사용 ---
if $use_cache; then
  # 캐시에서 압축 해제
  SYSTEM_MESSAGE=$(zcat "$CACHE_CONTENT_FILE" 2>/dev/null || echo "")
  if [[ -z "$SYSTEM_MESSAGE" ]]; then
    log "ERROR: Failed to decompress cache"
    use_cache=false
  fi
fi

if ! $use_cache; then
  log "Generating new content"
  
  # 컨텐츠 빌드
  combined_content=""
  
  # 전역 CLAUDE.md 처리
  if $global_exists; then
    combined_content+="# 전역 설정 (Global CLAUDE.md)\n"
    combined_content+=$(cat "$GLOBAL_CLAUDE_MD")
    combined_content+="\n\n"
  fi
  
  # 프로젝트 CLAUDE.md 처리
  if $project_exists; then
    combined_content+="# 프로젝트 설정 (Project: $PROJECT_ROOT)\n"
    combined_content+=$(cat "$PROJECT_CLAUDE_MD")
  fi
  
  # 시스템 메시지 생성
  SYSTEM_MESSAGE="<system-reminder>
As you answer the user's questions, you can use the following context:
# claudeMd
Codebase and user instructions are shown below. Be sure to adhere to these instructions. IMPORTANT: These instructions OVERRIDE any default behavior and you MUST follow them exactly as written.

$combined_content

      
      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context or otherwise consider it in your response unless it is highly relevant to your task. Most of the time, it is not relevant.
</system-reminder>"
  
  # 캐시 업데이트 (캐시가 활성화된 경우에만)
  if [[ -n "$CACHE_DIR" ]]; then
    echo -n "$current_hashes" > "$CACHE_HASH_FILE"
    echo -n "$SYSTEM_MESSAGE" | gzip -9 > "$CACHE_CONTENT_FILE"
    log "Cache updated"
  fi
fi

# --- Transcript 중복 확인 ---
# 이미 주입되었는지 확인하기 위한 마커
MARKER="<!--claude-md-injected:$current_hashes-->"

# transcript_path 추출 (있는 경우)
TRANSCRIPT=$(echo "$PAYLOAD" | jq -r '.transcript_path // empty' 2>/dev/null || echo "")
if [[ -n "$TRANSCRIPT" ]] && [[ -f "$TRANSCRIPT" ]]; then
  if grep -Fq "$MARKER" "$TRANSCRIPT" 2>/dev/null; then
    log "CLAUDE.md already injected (marker found)"
    exit 0
  fi
fi

# --- JSON 출력 ---
# 시스템 메시지에 마커 추가
FINAL_MESSAGE="${SYSTEM_MESSAGE}
${MARKER}"

# JSON 생성 및 출력
jq -n --arg content "$FINAL_MESSAGE" \
      --arg project_root "$PROJECT_ROOT" \
      --arg global_exists "$global_exists" \
      --arg project_exists "$project_exists" \
      '{
        prepend_system: $content,
        metadata: {
          project_root: $project_root,
          global_claude_md: ($global_exists == "true"),
          project_claude_md: ($project_exists == "true"),
          cache_key: env.CACHE_KEY
        }
      }' CACHE_KEY="$CACHE_KEY"

log "Script completed successfully"
exit 0