#!/usr/bin/env bash
set -euo pipefail

# Claude Code 설정에 PreCompact hook 추가
# 기존 pre-tool-use hook과 함께 작동

# --- 설정 ---
INSTALL_DIR="$HOME/.claude/hooks"

# --- 도우미 함수 ---
info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

# Claude 설정 파일 찾기
find_claude_settings() {
  local possible_paths=(
    "$HOME/.config/claude/settings.json"
    "$HOME/.claude/settings.json"
    "$HOME/Library/Application Support/Claude/settings.json"
  )
  
  for path in "${possible_paths[@]}"; do
    if [[ -f "$path" ]]; then
      echo "$path"
      return 0
    fi
  done
  
  error "Claude 설정 파일을 찾을 수 없습니다."
}

# 메인 로직
info "Claude Code hooks 설정 업데이트 중..."

SETTINGS_FILE=$(find_claude_settings)
info "설정 파일 위치: $SETTINGS_FILE"

# 백업 생성
cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

# 현재 hooks 설정 확인
info "현재 hooks 설정 확인 중..."

# 업데이트된 설정 생성
TEMP_FILE=$(mktemp)
if jq --arg pretool "$INSTALL_DIR/claude_md_injector.sh" \
     --arg precompact "$INSTALL_DIR/claude_md_precompact.sh" \
     '.hooks = (.hooks // {}) |
      .hooks["pre-tool-use"] = [
        {
          "command": $pretool,
          "timeout": 1000
        }
      ] |
      .hooks["pre-compact"] = [
        {
          "command": $precompact,
          "timeout": 1000
        }
      ]' "$SETTINGS_FILE" > "$TEMP_FILE"; then
  mv "$TEMP_FILE" "$SETTINGS_FILE"
  success "설정이 업데이트되었습니다!"
else
  rm -f "$TEMP_FILE"
  error "설정 업데이트에 실패했습니다."
fi

info "업데이트된 hooks:"
echo "  - pre-tool-use: 도구 사용 전 CLAUDE.md 주입"
echo "  - pre-compact: 대화 압축 전 CLAUDE.md 재주입"
echo
success "모든 설정이 완료되었습니다!"
info "Claude Code를 재시작하면 변경사항이 적용됩니다."