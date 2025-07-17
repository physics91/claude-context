#!/usr/bin/env bash
set -euo pipefail

# Claude Context 설정 변경 스크립트 - 깔끔한 구조 버전

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 기본값
MODE=""
HOOK_TYPE=""

# 옵션 처리
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode)
            MODE="$2"
            shift 2
            ;;
        --hook-type)
            HOOK_TYPE="$2"
            shift 2
            ;;
        --help)
            echo "사용법: $0 [옵션]"
            echo "옵션:"
            echo "  --mode <mode>        설정 모드 (basic|history|oauth|auto|advanced)"
            echo "  --hook-type <type>   Hook 타입 (PreToolUse|UserPromptSubmit)"
            echo "  --help               도움말 표시"
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            echo "도움말: $0 --help"
            exit 1
            ;;
    esac
done

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
read -p "선택 [1-3] (기본값: 2): " choice

# 기본값 처리
choice=${choice:-2}

case $choice in
    1) MODE="basic" ;;
    2) MODE="history" ;;
    3) MODE="advanced" ;;
    *)
        echo -e "${YELLOW}잘못된 선택입니다. 기본값(history)으로 진행합니다.${NC}"
        MODE="history"
        ;;
esac

# config.sh 업데이트
if [[ -f "${INSTALL_DIR}/config/config.sh.template" ]]; then
    sed "s/{{MODE}}/$MODE/g" "${INSTALL_DIR}/config/config.sh.template" > "$CONFIG_FILE"
else
    # 기존 config.sh의 MODE만 변경
    if [[ -f "$CONFIG_FILE" ]]; then
        # macOS와 Linux 호환성을 위한 sed 처리
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^CLAUDE_CONTEXT_MODE=.*/CLAUDE_CONTEXT_MODE=\"$MODE\"/" "$CONFIG_FILE"
        else
            sed -i "s/^CLAUDE_CONTEXT_MODE=.*/CLAUDE_CONTEXT_MODE=\"$MODE\"/" "$CONFIG_FILE"
        fi
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

# Hook 타입 변경이 필요한 경우
if [[ -n "$HOOK_TYPE" ]]; then
    echo
    echo -e "${BLUE}Hook 타입을 변경하는 중...${NC}"
    
    # install.sh 스크립트 실행하여 hook 타입만 변경
    if [[ -f "$INSTALL_DIR/install.sh" ]]; then
        "$INSTALL_DIR/install.sh" --mode "$MODE" --hook-type "$HOOK_TYPE"
    else
        # 또는 현재 디렉토리의 install.sh 사용
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "$SCRIPT_DIR/install.sh" --mode "$MODE" --hook-type "$HOOK_TYPE"
    fi
    
    echo -e "${GREEN}✓ Hook 타입이 $HOOK_TYPE(으)로 변경되었습니다!${NC}"
fi