#!/usr/bin/env bash
set -euo pipefail

# PreCompact Hook - 대화 압축 전 CLAUDE.md 재주입
# 이 스크립트는 Claude가 대화를 압축하기 직전에 실행되어
# CLAUDE.md의 내용을 다시 주입합니다.

# --- 설정 ---
GLOBAL_CLAUDE_MD="${HOME}/.claude/CLAUDE.md"
LOG_FILE="${TMPDIR:-/tmp}/claude_md_precompact.log"
exec 2>>"${LOG_FILE}"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PreCompact] $*" >&2; }

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

# --- 작업 디렉토리 추출 ---
WORKING_DIR=$(echo "$PAYLOAD" | jq -r '.working_directory // empty' 2>/dev/null || echo "")
if [[ -z "$WORKING_DIR" ]]; then
  WORKING_DIR="$PWD"
fi

log "PreCompact hook triggered. Working directory: $WORKING_DIR"

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

# --- 컨텐츠가 있으면 메시지 추가 ---
if [[ -n "$COMBINED_CONTENT" ]]; then
  log "Injecting CLAUDE.md content before compaction"
  
  # 압축 전 중요 컨텍스트 리마인더 메시지 생성
  REMINDER_MESSAGE="<system-reminder>
IMPORTANT: The conversation is about to be compacted. Here are the critical context and instructions that must be preserved:

$COMBINED_CONTENT

Please ensure these instructions continue to guide your responses after compaction.
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
  
  log "PreCompact injection successful"
else
  log "No CLAUDE.md content found to inject"
  echo '{}'
fi