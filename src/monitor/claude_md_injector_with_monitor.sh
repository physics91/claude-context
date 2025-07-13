#!/usr/bin/env bash
set -euo pipefail

# Enhanced PostToolUse Hook - CLAUDE.md 주입 + 대화 추적
# 도구 사용 후 CLAUDE.md 내용 주입 및 토큰 모니터링

# --- 설정 ---
GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
TOKEN_MONITOR="${HOME}/.claude/hooks/claude_token_monitor.sh"
LOG_FILE="${TMPDIR:-/tmp}/claude_md_injector_monitor.log"
INJECT_PROBABILITY=${CLAUDE_MD_INJECT_PROBABILITY:-1.0}

exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [InjectorMonitor] $*" >&2; }

# --- 필수 명령어 확인 ---
for cmd in jq awk; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command '$cmd' not found"
    exit 0
  fi
done

# --- JSON 페이로드 읽기 ---
PAYLOAD=$(cat)
if [[ -z "$PAYLOAD" ]]; then
  log "ERROR: Empty payload"
  echo '{}'
  exit 0
fi

# --- 도구 이름 및 정보 추출 ---
TOOL_NAME=$(echo "$PAYLOAD" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
CONVERSATION_ID=$(echo "$PAYLOAD" | jq -r '.conversation_id // empty' 2>/dev/null || echo "default")
WORKING_DIR=$(echo "$PAYLOAD" | jq -r '.working_directory // empty' 2>/dev/null || echo "$PWD")

log "Tool used: $TOOL_NAME, Conv ID: $CONVERSATION_ID"

# --- 대화 내용 추적 (토큰 모니터링) ---
if [[ -x "$TOKEN_MONITOR" ]]; then
  # 도구 사용 정보를 간단히 기록
  TOOL_USAGE="Tool used: $TOOL_NAME"
  "$TOKEN_MONITOR" track "$CONVERSATION_ID" "$TOOL_USAGE" 2>/dev/null || true
fi

# --- 확률적 주입 확인 ---
if ! awk -v prob="$INJECT_PROBABILITY" 'BEGIN{srand(); exit (rand() > prob)}'; then
  log "Skipping injection (probability check failed)"
  echo '{}'
  exit 0
fi

log "PostToolUse triggered. Tool: $TOOL_NAME, Working directory: $WORKING_DIR"

# --- 프로젝트 루트 찾기 ---
find_project_root() {
  local dir="$1"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.git" ]] || [[ -f "$dir/package.json" ]] || [[ -f "$dir/Cargo.toml" ]]; then
      echo "$dir"
      return 0
    fi
    dir=$(dirname "$dir")
  done
  echo ""
}

PROJECT_ROOT=$(find_project_root "$WORKING_DIR")
PROJECT_CLAUDE_MD=""
if [[ -n "$PROJECT_ROOT" ]] && [[ -f "$PROJECT_ROOT/CLAUDE.md" ]]; then
  PROJECT_CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
  log "Found project CLAUDE.md at: $PROJECT_CLAUDE_MD"
fi

# --- CLAUDE.md 컨텐츠 준비 ---
COMBINED_CONTENT=""

# 전역 CLAUDE.md
if [[ -f "$GLOBAL_CLAUDE_MD" ]]; then
  log "Reading global CLAUDE.md"
  GLOBAL_CONTENT=$(<"$GLOBAL_CLAUDE_MD")
  if [[ -n "$GLOBAL_CONTENT" ]]; then
    COMBINED_CONTENT="Contents of ${GLOBAL_CLAUDE_MD} (user's private global instructions for all projects):

$GLOBAL_CONTENT"
  fi
fi

# 프로젝트별 CLAUDE.md
if [[ -n "$PROJECT_CLAUDE_MD" ]]; then
  log "Reading project CLAUDE.md"
  PROJECT_CONTENT=$(<"$PROJECT_CLAUDE_MD")
  if [[ -n "$PROJECT_CONTENT" ]]; then
    if [[ -n "$COMBINED_CONTENT" ]]; then
      COMBINED_CONTENT="$COMBINED_CONTENT

Contents of ${PROJECT_CLAUDE_MD} (user's project-specific instructions):

$PROJECT_CONTENT"
    else
      COMBINED_CONTENT="Contents of ${PROJECT_CLAUDE_MD} (user's project-specific instructions):

$PROJECT_CONTENT"
    fi
  fi
fi

# --- 중요한 타이밍에 요약 확인 ---
# Read, Write, MultiEdit 등 주요 작업 후 요약 필요성 체크
case "$TOOL_NAME" in
  "Read"|"Write"|"MultiEdit"|"Bash")
    if [[ -x "$TOKEN_MONITOR" ]]; then
      log "Checking if summary needed after $TOOL_NAME"
      # 백그라운드에서 체크 (응답 지연 방지)
      ("$TOKEN_MONITOR" track "$CONVERSATION_ID" "Major operation: $TOOL_NAME" 2>/dev/null || true) &
    fi
    ;;
esac

# --- 컨텐츠가 있으면 메시지 추가 ---
if [[ -n "$COMBINED_CONTENT" ]]; then
  log "Injecting CLAUDE.md content with monitoring"
  
  # 시스템 리마인더 생성
  REMINDER_MESSAGE="<system-reminder>
As you answer the user's questions, you can use the following context:
# claudeMd
Codebase and user instructions are shown below. Be sure to adhere to these instructions. IMPORTANT: These instructions OVERRIDE any default behavior and you MUST follow them exactly as written.

$COMBINED_CONTENT
      
      IMPORTANT: this context may or may not be relevant to your tasks. You should not respond to this context or otherwise consider it in your response unless it is highly relevant to your task. Most of the time, it is not relevant.
</system-reminder>"
  
  # JSON 응답 생성
  jq -n \
    --arg content "$REMINDER_MESSAGE" \
    '{
      "messages": [
        {
          "role": "system",
          "content": $content
        }
      ]
    }'
  
  log "Injection with monitoring successful"
else
  log "No CLAUDE.md content found"
  echo '{}'
fi