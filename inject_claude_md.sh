#!/usr/bin/env bash
set -euo pipefail

# 모든 로그는 stderr로 리다이렉트
exec 2>>"${TMPDIR:-/tmp}/inject_claude_md.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2; }

# 필수 명령어 확인
for cmd in jq gzip zcat sha256sum; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "ERROR: Required command '$cmd' not found"
    exit 0  # 훅 실패가 아닌 조용한 종료
  fi
done

# 동적 경로 탐색 함수
find_project_root() {
  # 1. Git 프로젝트 루트 시도
  if git_root=$(git rev-parse --show-toplevel 2>/dev/null); then
    echo "$git_root"
    return
  fi
  
  # 2. 현재 디렉토리부터 상위로 탐색
  local dir="$PWD"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/CLAUDE.md" ]]; then
      echo "$dir"
      return
    fi
    dir=$(dirname "$dir")
  done
  
  # 3. 기본값: 현재 디렉토리
  echo "$PWD"
}

# CLAUDE.md 경로 결정
PROJECT_ROOT=$(find_project_root)
CLAUDE_MD="$PROJECT_ROOT/CLAUDE.md"
log "PROJECT_ROOT: $PROJECT_ROOT"
log "CLAUDE_MD: $CLAUDE_MD"

# 파일 존재 확인
if [[ ! -f "$CLAUDE_MD" ]]; then
  log "CLAUDE.md not found at $CLAUDE_MD"
  exit 0
fi

# 캐시 디렉토리
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
if ! mkdir -p "$CACHE_DIR" 2>/dev/null; then
  log "ERROR: Cannot create cache directory $CACHE_DIR"
  exit 0
fi

# 해시 계산
HASH=$(sha256sum "$CLAUDE_MD" | cut -d' ' -f1)
PROJECT_HASH=$(echo -n "$PROJECT_ROOT" | sha256sum | cut -c1-8)
CACHE_FILE="$CACHE_DIR/${PROJECT_HASH}-${HASH}"
log "HASH: $HASH"
log "CACHE_FILE: $CACHE_FILE"

# 캐시 생성 (필요시)
if [[ ! -f "$CACHE_FILE" ]]; then
  log "Creating cache file"
  # 요약 및 압축
  if ! grep -E '^[[:space:]]*(-|#|##)' "$CLAUDE_MD" | head -n 400 | gzip -9 > "$CACHE_FILE"; then
    log "ERROR: Failed to create cache file"
    rm -f "$CACHE_FILE"
    exit 0
  fi
fi

# PreToolUse 페이로드 읽기
PAYLOAD=$(cat)
if [[ -z "$PAYLOAD" ]]; then
  log "ERROR: Failed to read payload or payload is empty"
  exit 0
fi

# Transcript 경로 추출
TRANSCRIPT=$(jq -r '.transcript_path' <<<"$PAYLOAD" 2>/dev/null || echo "")
if [[ -z "$TRANSCRIPT" ]]; then
  log "ERROR: Cannot extract transcript_path from payload"
  exit 0
fi
log "TRANSCRIPT: $TRANSCRIPT"

# 중복 확인
if [[ -f "$TRANSCRIPT" ]] && grep -Fq "<!--claude-md-hash:$HASH-->" "$TRANSCRIPT" 2>/dev/null; then
  log "CLAUDE.md already injected (hash: $HASH)"
  exit 0
fi

# 압축 해제
if ! CONTENT=$(zcat "$CACHE_FILE"); then
  log "ERROR: Failed to decompress cache file: $CACHE_FILE"
  exit 0
fi

# 시스템 메시지 출력 (stdout은 JSON만)
MARKER="<!--claude-md-hash:$HASH-->"
JSON_OUTPUT=$(jq -n --arg content "$CONTENT" \
                    --arg marker "$MARKER" \
                    --arg path "$CLAUDE_MD" \
                    '{
                      prepend_system: ($content + "\n" + $marker),
                      metadata: {
                        source_path: $path,
                        hash: $marker
                      }
                    }')

if [[ $? -ne 0 ]]; then
  log "ERROR: Failed to generate JSON output"
  exit 0
fi
echo "$JSON_OUTPUT"

# 반드시 성공 코드로 종료
exit 0