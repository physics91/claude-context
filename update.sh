#!/usr/bin/env bash
# Claude Context 업데이트 스크립트
# 로컬에서 설치된 경우에 사용하는 업데이트 도구

set -euo pipefail

# 스크립트 위치 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# utils/update_functions.sh 로드
if [[ -f "$SCRIPT_DIR/utils/update_functions.sh" ]]; then
    source "$SCRIPT_DIR/utils/update_functions.sh"
else
    echo "Error: update_functions.sh를 찾을 수 없습니다."
    echo "이 스크립트는 Claude Context 프로젝트 루트에서 실행해야 합니다."
    exit 1
fi

# 옵션 파싱
FORCE_UPDATE=false
CHECK_ONLY=false
SHOW_INFO=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE_UPDATE=true
            shift
            ;;
        --check|-c)
            CHECK_ONLY=true
            shift
            ;;
        --info|-i)
            SHOW_INFO=true
            shift
            ;;
        --help|-h)
            echo "Claude Context 업데이트 도구"
            echo
            echo "사용법: $0 [옵션]"
            echo
            echo "옵션:"
            echo "  --force, -f      강제 업데이트 (버전 확인 생략)"
            echo "  --check, -c      업데이트 확인만 수행 (실제 업데이트 안 함)"
            echo "  --info, -i       현재 및 최신 버전 정보 표시"
            echo "  --help, -h       이 도움말 표시"
            echo
            echo "예시:"
            echo "  $0               # 일반 업데이트"
            echo "  $0 --check       # 업데이트 가능 여부만 확인"
            echo "  $0 --force       # 강제 업데이트"
            echo "  $0 --info        # 버전 정보 확인"
            exit 0
            ;;
        *)
            echo "알 수 없는 옵션: $1"
            echo "도움말: $0 --help"
            exit 1
            ;;
    esac
done

# 메인 실행
main() {
    # 정보 표시 모드
    if [[ "$SHOW_INFO" == "true" ]]; then
        get_update_info
        return $?
    fi
    
    # 확인 모드
    if [[ "$CHECK_ONLY" == "true" ]]; then
        if is_update_available; then
            echo -e "${GREEN}업데이트가 가능합니다.${NC}"
            return 0
        else
            echo -e "${BLUE}업데이트가 필요하지 않습니다.${NC}"
            return 1
        fi
    fi
    
    # 업데이트 수행
    perform_update "$FORCE_UPDATE"
}

# 스크립트 실행
main "$@"