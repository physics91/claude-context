#!/usr/bin/env bash
set -euo pipefail

# Claude Context 커버리지 테스트
# 모든 시나리오에서 CLAUDE.md가 제대로 로드되는지 확인

# 색상 정의
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Claude Context 커버리지 테스트 ===${NC}"
echo

# 1. 현재 설정 확인
echo -e "${YELLOW}1. 현재 설정 상태${NC}"
SETTINGS_FILE="$HOME/.claude/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    echo -e "${GREEN}✓ 설정 파일 존재${NC}"
    
    # PreToolUse hook 확인
    if jq -e '.hooks["PreToolUse"]' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PreToolUse hook 설정됨${NC}"
    else
        echo -e "${RED}✗ PreToolUse hook 없음${NC}"
    fi
    
    # PreCompact hook 확인
    if jq -e '.hooks["PreCompact"]' "$SETTINGS_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PreCompact hook 설정됨${NC}"
    else
        echo -e "${RED}✗ PreCompact hook 없음${NC}"
    fi
else
    echo -e "${RED}✗ 설정 파일 없음${NC}"
fi

echo

# 2. CLAUDE.md 파일 확인
echo -e "${YELLOW}2. CLAUDE.md 파일 확인${NC}"
GLOBAL_CLAUDE="$HOME/.claude/CLAUDE.md"

if [[ -f "$GLOBAL_CLAUDE" ]]; then
    echo -e "${GREEN}✓ 전역 CLAUDE.md 존재${NC}"
    
    # 대화 시작 규칙 확인
    if grep -q "대화 시작 규칙" "$GLOBAL_CLAUDE" 2>/dev/null; then
        echo -e "${GREEN}✓ 대화 시작 규칙 포함됨${NC}"
        echo "  첫 대화에서도 도구를 사용하여 컨텍스트 로드 보장"
    else
        echo -e "${YELLOW}! 대화 시작 규칙 없음${NC}"
        echo "  첫 대화에서 도구를 사용하지 않으면 컨텍스트 미로드 가능"
    fi
else
    echo -e "${YELLOW}! 전역 CLAUDE.md 없음${NC}"
fi

echo

# 3. 커버리지 시나리오 테스트
echo -e "${YELLOW}3. 커버리지 시나리오${NC}"
echo
echo "✅ 커버되는 상황:"
echo "  1. 도구를 사용하는 모든 대화 (PreToolUse hook)"
echo "  2. 대화가 길어져서 압축될 때 (PreCompact hook)"
echo "  3. 대화 시작 규칙이 있고 첫 대화에서 프로젝트 파일을 읽을 때"
echo
echo "⚠️  커버되지 않는 상황:"
echo "  1. 도구를 전혀 사용하지 않는 짧은 대화"
echo "  2. 대화 시작 규칙이 없고 첫 질문이 일반적인 질문일 때"
echo

# 4. 로그 분석
echo -e "${YELLOW}4. 최근 Hook 실행 로그${NC}"
LOG_DIR="${TMPDIR:-/tmp}"
INJECTOR_LOG="$LOG_DIR/claude_md_injector.log"
PRECOMPACT_LOG="$LOG_DIR/claude_md_precompact.log"

if [[ -f "$INJECTOR_LOG" ]]; then
    echo "PreToolUse 최근 실행:"
    tail -n 3 "$INJECTOR_LOG" | sed 's/^/  /'
else
    echo "PreToolUse 로그 없음"
fi

echo

if [[ -f "$PRECOMPACT_LOG" ]]; then
    echo "PreCompact 최근 실행:"
    tail -n 3 "$PRECOMPACT_LOG" | sed 's/^/  /'
else
    echo "PreCompact 로그 없음 (아직 대화 압축이 발생하지 않음)"
fi

echo

# 5. 권장사항
echo -e "${YELLOW}5. 권장사항${NC}"
echo
echo "완벽한 커버리지를 위해:"
echo "1. 전역 CLAUDE.md에 대화 시작 규칙 추가 (완료: $(grep -q "대화 시작 규칙" "$GLOBAL_CLAUDE" 2>/dev/null && echo "✓" || echo "✗"))"
echo "2. 프로젝트별 CLAUDE.md에도 프로젝트 특화 시작 규칙 추가"
echo "3. Claude Code 재시작 후 테스트"
echo
echo -e "${BLUE}팁:${NC} 'cat ~/.claude/CLAUDE.md' 명령으로 현재 설정을 확인하세요."