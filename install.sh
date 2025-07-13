#!/usr/bin/env bash
set -euo pipefail

# Claude Context - 통합 설치 스크립트
# 새로운 디렉토리 구조를 지원하는 업데이트된 버전

# --- 설정 변수 ---
INSTALL_DIR="$HOME/.claude/hooks"
SRC_DIR="$INSTALL_DIR/src"
CORE_DIR="$SRC_DIR/core"
MONITOR_DIR="$SRC_DIR/monitor"
UTILS_DIR="$SRC_DIR/utils"
INSTALL_SCRIPTS_DIR="$INSTALL_DIR/install"
TEST_DIR="$INSTALL_DIR/tests"
DOC_DIR="$INSTALL_DIR/docs"

# 추가 디렉토리
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
LOG_DIR="${TMPDIR:-/tmp}"
HISTORY_DIR="$HOME/.claude/history"
SUMMARY_DIR="$HOME/.claude/summaries"

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- 도우미 함수 ---
info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }

# 의존성 확인
check_dependencies() {
    local missing_deps=()
    
    for cmd in jq sha256sum gzip zcat; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error "필수 도구가 설치되어 있지 않습니다: ${missing_deps[*]}"
    fi
}

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
    
    # 설정 파일이 없으면 기본 위치에 생성
    local default_path="$HOME/.claude/settings.json"
    mkdir -p "$(dirname "$default_path")"
    echo '{}' > "$default_path"
    info "Claude 설정 파일을 생성했습니다: $default_path"
    echo "$default_path"
}

# --- 설치 함수 ---
do_install() {
    info "Claude Context 설치를 시작합니다..."
    
    # 의존성 확인
    check_dependencies
    
    # 디렉토리 구조 생성
    info "디렉토리 구조 생성 중..."
    mkdir -p "$CORE_DIR" "$MONITOR_DIR" "$UTILS_DIR" "$INSTALL_SCRIPTS_DIR" "$TEST_DIR" "$DOC_DIR"
    mkdir -p "$CACHE_DIR" "$HISTORY_DIR" "$SUMMARY_DIR"
    
    # 현재 위치 확인
    local current_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 설치 모드 결정 (원클릭 vs 로컬)
    if [[ -f "$current_dir/src/core/claude_md_injector.sh" ]]; then
        info "로컬 설치 모드 감지됨"
        
        # 파일 복사
        cp -r "$current_dir"/* "$INSTALL_DIR/" 2>/dev/null || true
        
    elif [[ -f "$INSTALL_DIR/src/core/claude_md_injector.sh" ]]; then
        info "이미 설치된 파일 사용"
    else
        # GitHub에서 다운로드
        info "GitHub에서 파일 다운로드 중..."
        
        # 임시 디렉토리 생성
        local temp_dir=$(mktemp -d)
        cd "$temp_dir"
        
        # 저장소 클론
        if ! git clone https://github.com/physics91/claude-context.git .; then
            error "저장소 다운로드 실패"
        fi
        
        # 파일 복사
        cp -r ./* "$INSTALL_DIR/" 2>/dev/null || true
        
        # 임시 디렉토리 정리
        cd - >/dev/null
        rm -rf "$temp_dir"
    fi
    
    # 실행 권한 부여
    info "실행 권한 설정 중..."
    find "$INSTALL_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    
    # Claude 설정 업데이트
    info "Claude 설정 업데이트 중..."
    local settings_file=$(find_claude_settings)
    
    # 기존 설정 백업
    cp "$settings_file" "${settings_file}.backup.$(date +%s)"
    
    # 기본 hooks 설정
    local temp_file=$(mktemp)
    jq --arg pretool "$CORE_DIR/claude_md_injector.sh" \
       --arg precompact "$CORE_DIR/claude_md_precompact.sh" '
        .hooks = (.hooks // {}) |
        .hooks["PreToolUse"] = [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": $pretool,
                        "timeout": 30000
                    }
                ]
            }
        ] |
        .hooks["PreCompact"] = [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": $precompact,
                        "timeout": 1000
                    }
                ]
            }
        ]
    ' "$settings_file" > "$temp_file" && mv "$temp_file" "$settings_file"
    
    success "설치가 완료되었습니다!"
    echo
    info "다음 단계:"
    echo "1. ~/.claude/CLAUDE.md 파일을 생성하여 전역 컨텍스트를 설정하세요"
    echo "2. 프로젝트 루트에 CLAUDE.md 파일을 생성하여 프로젝트별 컨텍스트를 설정하세요"
    echo "3. Claude Code를 재시작하세요"
    echo
    info "고급 기능 (토큰 모니터링)을 사용하려면:"
    echo "  $INSTALL_SCRIPTS_DIR/update_hooks_config_enhanced.sh"
    echo
    info "제거하려면:"
    echo "  $0 --uninstall"
}

# --- 제거 함수 ---
do_uninstall() {
    info "Claude Context 제거를 시작합니다..."
    
    # 설정 파일에서 hook 제거
    local settings_file=$(find_claude_settings)
    if [[ -f "$settings_file" ]]; then
        info "Claude 설정에서 hook 제거 중..."
        local temp_file=$(mktemp)
        jq 'del(.hooks["PreToolUse"]) | del(.hooks["PreCompact"])' "$settings_file" > "$temp_file" && \
            mv "$temp_file" "$settings_file"
    fi
    
    # 디렉토리 삭제 확인
    if [[ -d "$INSTALL_DIR" ]]; then
        echo -n "설치 디렉토리를 완전히 삭제하시겠습니까? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$INSTALL_DIR"
            info "설치 디렉토리가 삭제되었습니다."
        fi
    fi
    
    # 데이터 디렉토리 삭제 확인
    echo -n "캐시 및 기록 데이터도 삭제하시겠습니까? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        rm -rf "$CACHE_DIR" "$HISTORY_DIR" "$SUMMARY_DIR"
        info "데이터가 삭제되었습니다."
    fi
    
    success "제거가 완료되었습니다!"
}

# --- 메인 로직 ---
main() {
    case "${1:-}" in
        --uninstall|-u)
            do_uninstall
            ;;
        --help|-h)
            echo "Claude Context 설치 스크립트"
            echo "사용법:"
            echo "  $0              # 설치"
            echo "  $0 --uninstall  # 제거"
            echo "  $0 --help       # 도움말"
            ;;
        "")
            do_install
            ;;
        *)
            error "알 수 없는 옵션: $1"
            ;;
    esac
}

main "$@"