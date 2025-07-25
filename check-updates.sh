#!/usr/bin/env bash
# Claude Context 업데이트 확인 스크립트
# 업데이트 가능 여부만 확인하는 간단한 도구

set -euo pipefail

# 스크립트 위치 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# utils/update_functions.sh 로드
if [[ -f "$SCRIPT_DIR/utils/update_functions.sh" ]]; then
    source "$SCRIPT_DIR/utils/update_functions.sh"
else
    echo "Error: update_functions.sh를 찾을 수 없습니다."
    exit 1
fi

# 설치 여부 확인
INSTALL_DIR="${HOME}/.claude/hooks/claude-context"
if [[ ! -d "$INSTALL_DIR" ]]; then
    echo -e "${RED}Claude Context가 설치되어 있지 않습니다.${NC}"
    echo "설치 방법:"
    echo "curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-install.sh | bash"
    exit 1
fi

# 업데이트 정보 표시
get_update_info

# 종료 코드: 0=업데이트 가능, 1=최신 버전, 2=오류
exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo
    echo -e "${BLUE}업데이트 방법:${NC}"
    echo "curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash"
fi

exit $exit_code