#!/usr/bin/env bash
# Claude Context 원클릭 설치 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash
# 
# 환경 변수로 옵션 설정 가능:
# CLAUDE_CONTEXT_MODE=history CLAUDE_CONTEXT_HOOK_TYPE=UserPromptSubmit curl -sSL ... | bash

set -euo pipefail

# 설정
GITHUB_USER="physics91"
GITHUB_REPO="claude-context"
GITHUB_BRANCH="main"

# 기본값
MODE="${CLAUDE_CONTEXT_MODE:-oauth}"
HOOK_TYPE="${CLAUDE_CONTEXT_HOOK_TYPE:-PreToolUse}"

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Context v1.0.0 설치         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

cd "$TEMP_DIR"

# Git 설치 확인
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git이 설치되어 있지 않습니다.${NC}"
    echo "먼저 Git을 설치해주세요:"
    echo "  - macOS: brew install git"
    echo "  - Ubuntu/Debian: sudo apt install git"
    echo "  - RHEL/CentOS: sudo yum install git"
    exit 1
fi

# jq 설치 확인
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Warning: jq가 설치되어 있지 않습니다.${NC}"
    echo "설치를 계속하지만, jq 설치를 권장합니다:"
    echo "  - macOS: brew install jq"
    echo "  - Ubuntu/Debian: sudo apt install jq"
    echo "  - RHEL/CentOS: sudo yum install jq"
    echo
fi

# 저장소 클론
echo "저장소를 다운로드하는 중..."
if ! git clone --depth 1 --branch "$GITHUB_BRANCH" "https://github.com/$GITHUB_USER/$GITHUB_REPO.git" >/dev/null 2>&1; then
    echo -e "${RED}Error: 저장소 다운로드에 실패했습니다.${NC}"
    echo "네트워크 연결을 확인하고 다시 시도해주세요."
    exit 1
fi

echo -e "${GREEN}✓ 다운로드 완료${NC}"

# 설치 스크립트 실행
cd "$GITHUB_REPO"
if [[ -f install.sh ]]; then
    chmod +x install.sh
    echo
    ./install.sh --mode "$MODE" --hook-type "$HOOK_TYPE"
elif [[ -f install/install.sh ]]; then
    chmod +x install/install.sh
    echo
    ./install/install.sh --mode "$MODE" --hook-type "$HOOK_TYPE"
else
    echo -e "${RED}Error: 설치 스크립트를 찾을 수 없습니다.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}🎉 Claude Context가 성공적으로 설치되었습니다!${NC}"
echo
echo -e "${BLUE}다음 단계:${NC}"
echo "1. ~/.claude/CLAUDE.md 파일을 생성하여 전역 컨텍스트를 설정하세요"
echo "   예시:"
echo "   echo '# 기본 규칙' > ~/.claude/CLAUDE.md"
echo "   echo '- 한국어로 대화하세요' >> ~/.claude/CLAUDE.md"
echo
echo "2. Claude Code를 재시작하세요"
echo
echo -e "${BLUE}고급 기능 (토큰 모니터링):${NC}"
echo "~/.claude/hooks/install/update_hooks_config_enhanced.sh"
echo
echo "자세한 사용법: https://github.com/$GITHUB_USER/$GITHUB_REPO"
echo "문제 발생 시: https://github.com/$GITHUB_USER/$GITHUB_REPO/issues"