#!/usr/bin/env bash
set -euo pipefail

# PreCompact Hook 테스트 스크립트

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== PreCompact Hook 테스트 ===${NC}"
echo

# 1. 스크립트 존재 확인
echo -e "${YELLOW}1. PreCompact 스크립트 확인${NC}"
if [[ -f "./claude_md_precompact.sh" ]]; then
    echo -e "${GREEN}✓ claude_md_precompact.sh 존재${NC}"
    if [[ -x "./claude_md_precompact.sh" ]]; then
        echo -e "${GREEN}✓ 실행 권한 있음${NC}"
    else
        echo -e "${RED}✗ 실행 권한 없음${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ claude_md_precompact.sh 없음${NC}"
    exit 1
fi
echo

# 2. 테스트 CLAUDE.md 생성
echo -e "${YELLOW}2. 테스트 환경 준비${NC}"
TEST_DIR=$(mktemp -d)
echo "테스트 디렉토리: $TEST_DIR"

# 테스트용 CLAUDE.md 생성
cat > "$TEST_DIR/CLAUDE.md" << 'EOF'
# PreCompact Hook Test

이것은 PreCompact hook 테스트를 위한 CLAUDE.md입니다.

## 테스트 규칙
- 규칙 1: 항상 친절하게
- 규칙 2: 코드는 명확하게
- 규칙 3: 주석은 상세하게
EOF

echo -e "${GREEN}✓ 테스트 CLAUDE.md 생성 완료${NC}"
echo

# 3. PreCompact hook 테스트 실행
echo -e "${YELLOW}3. PreCompact Hook 실행 테스트${NC}"

# 테스트 페이로드 생성
TEST_PAYLOAD=$(cat << EOF
{
  "working_directory": "$TEST_DIR",
  "event": "pre-compact",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
)

echo "테스트 페이로드:"
echo "$TEST_PAYLOAD" | jq .
echo

# Hook 실행
echo -e "${BLUE}Hook 실행 중...${NC}"
HOOK_OUTPUT=$(echo "$TEST_PAYLOAD" | ./claude_md_precompact.sh 2>&1)
HOOK_EXIT_CODE=$?

if [[ $HOOK_EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}✓ Hook 실행 성공 (exit code: $HOOK_EXIT_CODE)${NC}"
else
    echo -e "${RED}✗ Hook 실행 실패 (exit code: $HOOK_EXIT_CODE)${NC}"
    echo "에러 출력:"
    echo "$HOOK_OUTPUT"
    exit 1
fi

# 4. 출력 검증
echo
echo -e "${YELLOW}4. Hook 출력 검증${NC}"

# JSON 유효성 검사
if echo "$HOOK_OUTPUT" | jq . >/dev/null 2>&1; then
    echo -e "${GREEN}✓ 유효한 JSON 출력${NC}"
else
    echo -e "${RED}✗ 잘못된 JSON 형식${NC}"
    echo "출력:"
    echo "$HOOK_OUTPUT"
    exit 1
fi

# 메시지 존재 확인
if echo "$HOOK_OUTPUT" | jq -e '.messages' >/dev/null 2>&1; then
    echo -e "${GREEN}✓ messages 필드 존재${NC}"
    
    # 메시지 내용 확인
    MESSAGE_CONTENT=$(echo "$HOOK_OUTPUT" | jq -r '.messages[0].content')
    if [[ "$MESSAGE_CONTENT" == *"PreCompact Hook Test"* ]]; then
        echo -e "${GREEN}✓ CLAUDE.md 내용이 포함됨${NC}"
    else
        echo -e "${RED}✗ CLAUDE.md 내용이 포함되지 않음${NC}"
    fi
else
    echo -e "${RED}✗ messages 필드 없음${NC}"
fi

# 5. 로그 확인
echo
echo -e "${YELLOW}5. 로그 파일 확인${NC}"
LOG_FILE="${TMPDIR:-/tmp}/claude_md_precompact.log"
if [[ -f "$LOG_FILE" ]]; then
    echo -e "${GREEN}✓ 로그 파일 존재: $LOG_FILE${NC}"
    echo "최근 로그 (마지막 10줄):"
    tail -n 10 "$LOG_FILE" | sed 's/^/  /'
else
    echo -e "${YELLOW}! 로그 파일 없음${NC}"
fi

# 6. 전역 CLAUDE.md 테스트
echo
echo -e "${YELLOW}6. 전역 CLAUDE.md 통합 테스트${NC}"
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    echo -e "${GREEN}✓ 전역 CLAUDE.md 존재${NC}"
    
    # 전역과 프로젝트 CLAUDE.md 모두 있을 때 테스트
    HOOK_OUTPUT2=$(echo "$TEST_PAYLOAD" | ./claude_md_precompact.sh 2>&1)
    if echo "$HOOK_OUTPUT2" | grep -q "Global Context" && echo "$HOOK_OUTPUT2" | grep -q "Project Context"; then
        echo -e "${GREEN}✓ 전역과 프로젝트 CLAUDE.md 모두 포함됨${NC}"
    else
        echo -e "${YELLOW}! 일부 컨텍스트만 포함됨${NC}"
    fi
else
    echo -e "${YELLOW}! 전역 CLAUDE.md 없음 (선택사항)${NC}"
fi

# 7. 설정 확인
echo
echo -e "${YELLOW}7. Claude Code 설정 확인${NC}"
SETTINGS_FILE="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS_FILE" ]]; then
    if jq -e '.hooks["PreCompact"]' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PreCompact hook이 설정됨${NC}"
        jq '.hooks["PreCompact"]' "$SETTINGS_FILE" | sed 's/^/  /'
    else
        echo -e "${RED}✗ PreCompact hook이 설정되지 않음${NC}"
        echo "update_hooks_config.sh를 실행하여 설정을 추가하세요."
    fi
else
    echo -e "${RED}✗ Claude Code 설정 파일 없음${NC}"
fi

# 정리
rm -rf "$TEST_DIR"

echo
echo -e "${BLUE}=== 테스트 완료 ===${NC}"
echo
echo "PreCompact hook은 대화가 길어져서 압축이 필요할 때 자동으로 실행됩니다."
echo "실제 동작을 확인하려면 Claude Code에서 긴 대화를 진행해보세요."