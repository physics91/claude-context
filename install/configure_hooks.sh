#!/usr/bin/env bash
set -euo pipefail

# Claude Context 설정 변경 스크립트 - 깔끔한 구조 버전

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 설정
INSTALL_BASE="${HOME}/.claude/hooks"
INSTALL_DIR="${INSTALL_BASE}/claude-context"
CONFIG_FILE="${INSTALL_DIR}/config.sh"
CLAUDE_CONFIG="${HOME}/.claude/settings.json"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Claude Context 설정 변경              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo

# 설치 확인
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}Error: Claude Context가 설치되어 있지 않습니다.${NC}"
    echo "먼저 설치를 진행해주세요."
    exit 1
fi

# 현재 설정 확인
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo -e "${BLUE}현재 모드: ${CLAUDE_CONTEXT_MODE:-unknown}${NC}"
    echo
fi

# 모드 선택
echo "설정할 모드를 선택하세요:"
echo
echo "1) Basic   - CLAUDE.md 주입만"
echo "2) History - 대화 기록 관리 (Gemini 불필요)"
echo "3) Advanced - 토큰 모니터링 포함 (Gemini 필요)"
echo
read -p "선택 [1-3]: " choice

case $choice in
    1) MODE="basic" ;;
    2) MODE="history" ;;
    3) MODE="advanced" ;;
    *)
        echo -e "${RED}잘못된 선택입니다.${NC}"
        exit 1
        ;;
esac

# config.sh 업데이트
if [[ -f "${INSTALL_DIR}/config/config.sh.template" ]]; then
    sed "s/{{MODE}}/$MODE/g" "${INSTALL_DIR}/config/config.sh.template" > "$CONFIG_FILE"
else
    # 기존 config.sh의 MODE만 변경
    if [[ -f "$CONFIG_FILE" ]]; then
        sed -i.bak "s/^CLAUDE_CONTEXT_MODE=.*/CLAUDE_CONTEXT_MODE=\"$MODE\"/" "$CONFIG_FILE"
    else
        echo -e "${RED}Error: 설정 파일을 찾을 수 없습니다.${NC}"
        exit 1
    fi
fi

# 디렉토리 생성 (필요한 경우)
if [[ "$MODE" == "history" || "$MODE" == "advanced" ]]; then
    mkdir -p "${HOME}/.claude/history"
    mkdir -p "${HOME}/.claude/summaries"
fi

echo
echo -e "${GREEN}✓ 설정이 변경되었습니다!${NC}"
echo -e "${BLUE}새로운 모드: $MODE${NC}"
echo

case $MODE in
    basic)
        echo "기본 기능만 활성화되었습니다."
        echo "- CLAUDE.md 파일 자동 주입"
        echo "- 대화 압축 시 컨텍스트 보호"
        ;;
    history)
        echo "대화 기록 관리가 활성화되었습니다."
        echo "- 모든 대화 자동 추적"
        echo "- 간단한 내장 요약 기능"
        echo
        echo "사용법:"
        echo "  $INSTALL_DIR/src/monitor/claude_history_manager.sh --help"
        ;;
    advanced)
        echo "고급 기능이 활성화되었습니다."
        echo "- 대화 기록 관리"
        echo "- 토큰 모니터링 (Gemini 필요)"
        echo
        echo "Gemini가 설치되어 있는지 확인하세요:"
        echo "  command -v gemini"
        ;;
esac

echo
echo -e "${GREEN}Claude Code를 재시작하면 변경사항이 적용됩니다.${NC}"