#!/usr/bin/env bash
set -euo pipefail

# Enhanced PreCompact Hook - CLAUDE.md 재주입 + 자동 요약 통합
# 대화 압축 시점에 이전 요약과 함께 컨텍스트 유지

# --- 설정 ---
GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
SUMMARY_DIR="${HOME}/.claude/summaries"
LOG_FILE="${TMPDIR:-/tmp}/claude_enhanced_precompact.log"
TOKEN_MONITOR="${HOME}/.claude/hooks/claude_token_monitor.sh"

exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [EnhancedPreCompact] $*" >&2; }

# --- 필수 명령어 확인 ---
for cmd in jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command '$cmd' not found"
    exit 0
  fi
done

# --- JSON 페이로드 읽기 ---
PAYLOAD=$(cat)
if [[ -z "$PAYLOAD" ]]; then
  log "ERROR: Empty payload"
  exit 0
fi

# --- 작업 디렉토리 및 대화 ID 추출 ---
WORKING_DIR=$(echo "$PAYLOAD" | jq -r '.working_directory // empty' 2>/dev/null || echo "")
CONVERSATION_ID=$(echo "$PAYLOAD" | jq -r '.conversation_id // empty' 2>/dev/null || echo "default")
if [[ -z "$WORKING_DIR" ]]; then
  WORKING_DIR="$PWD"
fi

log "Enhanced PreCompact triggered. Working dir: $WORKING_DIR, Conv ID: $CONVERSATION_ID"

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
  log "Found project CLAUDE.md: $PROJECT_CLAUDE_MD"
fi

# --- CLAUDE.md 컨텐츠 준비 ---
COMBINED_CONTENT=""

# 전역 CLAUDE.md
if [[ -f "$GLOBAL_CLAUDE_MD" ]]; then
  log "Reading global CLAUDE.md"
  GLOBAL_CONTENT=$(<"$GLOBAL_CLAUDE_MD")
  if [[ -n "$GLOBAL_CONTENT" ]]; then
    COMBINED_CONTENT="# Global Context (from ~/.claude/CLAUDE.md)

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

# Project Context (from $PROJECT_ROOT/CLAUDE.md)

$PROJECT_CONTENT"
    else
      COMBINED_CONTENT="# Project Context (from $PROJECT_ROOT/CLAUDE.md)

$PROJECT_CONTENT"
    fi
  fi
fi

# --- 이전 대화 요약 추가 ---
if [[ -x "$TOKEN_MONITOR" ]]; then
  log "Checking for conversation summaries..."
  SUMMARIES=$("$TOKEN_MONITOR" inject "$CONVERSATION_ID" 2>/dev/null || echo "")
  if [[ -n "$SUMMARIES" ]]; then
    log "Found previous summaries"
    COMBINED_CONTENT="$COMBINED_CONTENT

# Previous Conversation Context

$SUMMARIES"
  fi
fi

# --- 컨텐츠가 있으면 메시지 추가 ---
if [[ -n "$COMBINED_CONTENT" ]]; then
  log "Injecting enhanced context before compaction"
  
  # 압축 전 중요 컨텍스트 리마인더 메시지 생성
  REMINDER_MESSAGE="<system-reminder>
IMPORTANT: The conversation is about to be compacted. Here are the critical context, instructions, and conversation history that must be preserved:

$COMBINED_CONTENT

Key points to remember after compaction:
1. Continue following all instructions from CLAUDE.md files
2. Maintain awareness of previously discussed topics and decisions
3. Reference the summaries when relevant to current tasks

Please ensure these instructions and context continue to guide your responses after compaction.
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
  
  log "Enhanced PreCompact injection successful"
else
  log "No content found to inject"
  echo '{}'
fi