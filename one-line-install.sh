#!/usr/bin/env bash
# 한 줄 설치를 위한 래퍼 스크립트
# 사용법: curl -sSL https://example.com/install | bash

set -euo pipefail

# GitHub 저장소 정보
GITHUB_USER="physics91"
GITHUB_REPO="claude-context"
GITHUB_BRANCH="main"

# 임시 디렉토리 생성
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}CLAUDE.md Hook 설치를 시작합니다...${NC}"
echo

# 필요한 파일들 다운로드
cd "$TEMP_DIR"
BASE_URL="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH"

# 스크립트 목록
SCRIPTS=(
    "install.sh"
    "claude_md_injector.sh"
    "claude_md_monitor.sh"
    "test_claude_md_hook.sh"
)

echo "스크립트 다운로드 중..."
for script in "${SCRIPTS[@]}"; do
    if curl -sSL "$BASE_URL/$script" -o "$script"; then
        echo "  ✓ $script"
    else
        echo "  ✗ $script (실패)"
        exit 1
    fi
done

# 실행 권한 부여
chmod +x *.sh

# install.sh 실행
echo
./install.sh

echo
echo -e "${GREEN}설치가 완료되었습니다!${NC}"
echo "문제가 있으면 https://github.com/$GITHUB_USER/$GITHUB_REPO/issues 에 보고해주세요."