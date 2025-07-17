#!/usr/bin/env bash
set -euo pipefail

echo "Claude Context를 제거합니다..."

# Claude 설정에서 hooks 제거
CLAUDE_CONFIG="${HOME}/.claude/settings.json"
if [[ -f "$CLAUDE_CONFIG" ]]; then
    jq 'del(.hooks)' "$CLAUDE_CONFIG" > "${CLAUDE_CONFIG}.tmp"
    mv "${CLAUDE_CONFIG}.tmp" "$CLAUDE_CONFIG"
fi

# 설치 디렉토리 제거
rm -rf "${HOME}/.claude/hooks/claude-context"
rm -f "${HOME}/.claude/hooks/claude_context_"*.sh
rm -f "${HOME}/.claude/hooks/claude_user_prompt_"*.sh

echo "✓ 제거가 완료되었습니다."
echo "데이터 디렉토리는 보존됩니다:"
echo "- ~/.claude/history"
echo "- ~/.claude/summaries"
