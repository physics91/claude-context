#!/usr/bin/env bash
set -euo pipefail

# CLAUDE.md Hook 자동 설치/제거 스크립트
# 사용법: 
#   설치: curl -sSL https://raw.githubusercontent.com/.../install.sh | bash
#   제거: ~/.claude/hooks/install.sh --uninstall

# --- 설정 변수 ---
INSTALL_DIR="$HOME/.claude/hooks"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude/md_cache"
LOG_DIR="${TMPDIR:-/tmp}"

# 스크립트 파일 목록
SCRIPTS=(
    "claude_md_injector.sh"
    "claude_md_monitor.sh"
    "test_claude_md_hook.sh"
)

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

# 패키지 매니저 감지
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v brew &>/dev/null; then
        echo "brew"
    elif command -v apk &>/dev/null; then
        echo "apk"
    else
        echo "unknown"
    fi
}

# OS별 패키지 이름 매핑
get_package_name() {
    local tool=$1
    local pkg_manager=$2
    
    case "$tool" in
        "sha256sum")
            case "$pkg_manager" in
                "apt"|"yum"|"dnf") echo "coreutils" ;;
                "brew") echo "coreutils" ;;
                "apk") echo "coreutils" ;;
            esac
            ;;
        "zcat")
            case "$pkg_manager" in
                "apt"|"yum"|"dnf") echo "gzip" ;;
                "brew") echo "gzip" ;;
                "apk") echo "gzip" ;;
            esac
            ;;
        *)
            echo "$tool"
            ;;
    esac
}

# 의존성 자동 설치
install_dependencies() {
    local missing_tools=("$@")
    local pkg_manager=$(detect_package_manager)
    
    if [[ "$pkg_manager" == "unknown" ]]; then
        error "패키지 매니저를 찾을 수 없습니다. 수동으로 설치해주세요: ${missing_tools[*]}"
    fi
    
    # 설치할 패키지 목록 생성 (중복 제거)
    local packages=()
    for tool in "${missing_tools[@]}"; do
        local pkg=$(get_package_name "$tool" "$pkg_manager")
        if [[ ! " ${packages[@]} " =~ " ${pkg} " ]]; then
            packages+=("$pkg")
        fi
    done
    
    info "다음 패키지를 설치합니다: ${packages[*]}"
    echo -n "계속하시겠습니까? (y/N): "
    read -r response
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        error "설치가 취소되었습니다."
    fi
    
    # sudo 확인
    local sudo_cmd=""
    if [[ $EUID -ne 0 ]] && command -v sudo &>/dev/null; then
        sudo_cmd="sudo"
    fi
    
    # 패키지 설치
    case "$pkg_manager" in
        "apt")
            $sudo_cmd apt-get update && $sudo_cmd apt-get install -y "${packages[@]}"
            ;;
        "yum")
            $sudo_cmd yum install -y "${packages[@]}"
            ;;
        "dnf")
            $sudo_cmd dnf install -y "${packages[@]}"
            ;;
        "brew")
            brew install "${packages[@]}"
            ;;
        "apk")
            $sudo_cmd apk add "${packages[@]}"
            ;;
    esac
    
    if [[ $? -ne 0 ]]; then
        error "패키지 설치에 실패했습니다."
    fi
}

# 의존성 확인
check_dependencies() {
    local missing_deps=()
    
    for cmd in jq sha256sum gzip zcat; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        warning "다음 도구가 설치되어 있지 않습니다: ${missing_deps[*]}"
        
        # 자동 설치 제안
        echo -n "자동으로 설치하시겠습니까? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            install_dependencies "${missing_deps[@]}"
            
            # 재확인
            missing_deps=()
            for cmd in jq sha256sum gzip zcat; do
                if ! command -v "$cmd" &>/dev/null; then
                    missing_deps+=("$cmd")
                fi
            done
            
            if [[ ${#missing_deps[@]} -gt 0 ]]; then
                error "일부 도구가 여전히 설치되지 않았습니다: ${missing_deps[*]}"
            else
                success "모든 필수 도구가 설치되었습니다!"
            fi
        else
            error "필수 도구가 설치되어 있지 않습니다. 수동으로 설치해주세요."
        fi
    fi
}

# Claude Code 설정 파일 찾기
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

# 현재 스크립트가 실행 중인 위치 확인
get_script_dir() {
    if [[ -f "$0" ]]; then
        dirname "$(readlink -f "$0")"
    else
        # pipe로 실행된 경우 현재 디렉토리 사용
        pwd
    fi
}

# Claude Code 버전 확인
check_claude_version() {
    # Claude 설정 파일 존재 여부로 간접 확인
    local settings_file=$(find_claude_settings)
    if [[ ! -f "$settings_file" ]]; then
        warning "Claude Code가 설치되어 있지 않거나 설정 파일을 찾을 수 없습니다."
        warning "Claude Code v1.0.38 이상이 필요합니다. (hooks 기능 지원)"
        echo -n "계속하시겠습니까? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            error "설치가 취소되었습니다."
        fi
    fi
}

# --- 설치 함수 ---
do_install() {
    info "CLAUDE.md Hook 설치를 시작합니다..."
    
    # Claude Code 버전 확인
    check_claude_version
    
    # 의존성 확인
    check_dependencies
    
    # 디렉토리 생성
    info "디렉토리 생성 중..."
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$CACHE_DIR"
    
    # 스크립트 복사 또는 다운로드
    local script_dir=$(get_script_dir)
    info "훅 스크립트 설치 중..."
    
    # 로컬에 스크립트가 있는지 확인
    local installed_count=0
    for script in "${SCRIPTS[@]}"; do
        if [[ -f "$script_dir/$script" ]]; then
            # 로컬 파일 복사
            cp "$script_dir/$script" "$INSTALL_DIR/"
            ((installed_count++))
        elif [[ -f "$INSTALL_DIR/$script" ]]; then
            # 이미 설치됨
            ((installed_count++))
        fi
    done
    
    if [[ $installed_count -eq 0 ]]; then
        error "필요한 스크립트 파일을 찾을 수 없습니다."
    fi
    
    # install.sh 자신도 복사
    if [[ -f "$0" ]] && [[ "$0" != "$INSTALL_DIR/install.sh" ]]; then
        cp "$0" "$INSTALL_DIR/install.sh"
    fi
    
    # 실행 권한 부여
    info "실행 권한 설정 중..."
    chmod +x "$INSTALL_DIR"/*.sh
    
    # Claude 설정 파일 업데이트
    info "Claude 설정 업데이트 중..."
    local settings_file=$(find_claude_settings)
    local hook_path="$INSTALL_DIR/claude_md_injector.sh"
    
    # 기존 설정 백업
    cp "$settings_file" "${settings_file}.backup"
    
    # hooks 설정 추가/업데이트
    local temp_file=$(mktemp)
    if jq --arg hook "$hook_path" '
        .hooks = (.hooks // {}) |
        .hooks["pre-tool-use"] = [
            {
                "command": $hook,
                "timeout": 1000
            }
        ]
    ' "$settings_file" > "$temp_file"; then
        mv "$temp_file" "$settings_file"
        success "설정이 업데이트되었습니다."
    else
        rm -f "$temp_file"
        error "설정 업데이트에 실패했습니다."
    fi
    
    # 설치 정보 저장
    cat > "$INSTALL_DIR/.install_info" <<EOF
{
    "version": "1.0.0",
    "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "install_dir": "$INSTALL_DIR",
    "cache_dir": "$CACHE_DIR"
}
EOF
    
    success "설치가 완료되었습니다!"
    echo
    info "설치 위치: $INSTALL_DIR"
    info "캐시 위치: $CACHE_DIR"
    info "로그 위치: $LOG_DIR/claude_md_injector.log"
    echo
    info "다음 명령으로 상태를 확인할 수 있습니다:"
    echo "  $INSTALL_DIR/claude_md_monitor.sh"
    echo
    info "제거하려면 다음 명령을 실행하세요:"
    echo "  $INSTALL_DIR/install.sh --uninstall"
}

# --- 제거 함수 ---
do_uninstall() {
    info "CLAUDE.md Hook 제거를 시작합니다..."
    
    # 설정 파일에서 hook 제거
    local settings_file=$(find_claude_settings)
    if [[ -f "$settings_file" ]]; then
        info "Claude 설정에서 hook 제거 중..."
        local temp_file=$(mktemp)
        if jq 'del(.hooks["pre-tool-use"])' "$settings_file" > "$temp_file"; then
            mv "$temp_file" "$settings_file"
            success "설정이 정리되었습니다."
        else
            rm -f "$temp_file"
            warning "설정 정리에 실패했습니다."
        fi
    fi
    
    # 캐시 삭제 확인
    if [[ -d "$CACHE_DIR" ]]; then
        echo -n "캐시 디렉토리도 삭제하시겠습니까? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -rf "$CACHE_DIR"
            info "캐시가 삭제되었습니다."
        fi
    fi
    
    # 로그 파일 삭제 확인
    local log_file="$LOG_DIR/claude_md_injector.log"
    if [[ -f "$log_file" ]]; then
        echo -n "로그 파일도 삭제하시겠습니까? (y/N): "
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            rm -f "$log_file"
            info "로그가 삭제되었습니다."
        fi
    fi
    
    # 설치 디렉토리 삭제
    if [[ -d "$INSTALL_DIR" ]]; then
        info "설치 디렉토리 삭제 중..."
        rm -rf "$INSTALL_DIR"
    fi
    
    success "제거가 완료되었습니다!"
}

# --- 업데이트 확인 함수 ---
check_update() {
    info "업데이트 확인 중..."
    # TODO: GitHub API를 사용하여 최신 버전 확인
    warning "자동 업데이트는 아직 구현되지 않았습니다."
    info "최신 버전을 설치하려면 다시 설치 명령을 실행하세요."
}

# --- 메인 로직 ---
main() {
    case "${1:-}" in
        --uninstall|-u)
            do_uninstall
            ;;
        --update)
            check_update
            ;;
        --help|-h)
            echo "CLAUDE.md Hook 설치 스크립트"
            echo "사용법:"
            echo "  $0              # 설치"
            echo "  $0 --uninstall  # 제거"
            echo "  $0 --update     # 업데이트 확인"
            echo "  $0 --help       # 도움말"
            ;;
        "")
            do_install
            ;;
        *)
            error "알 수 없는 옵션: $1\n'$0 --help'로 사용법을 확인하세요."
            ;;
    esac
}

main "$@"