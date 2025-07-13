#!/usr/bin/env bash
# 공통 유틸리티 함수 라이브러리

# 색상 정의
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# 로깅 함수
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# 프로젝트 루트 찾기
find_project_root() {
    local dir="${1:-$(pwd)}"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/CLAUDE.md" ]] || [[ -d "$dir/.git" ]] || 
           [[ -f "$dir/package.json" ]] || [[ -f "$dir/Cargo.toml" ]] ||
           [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/go.mod" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    echo ""
}

# JSON 안전 이스케이프
json_escape() {
    local text="$1"
    printf '%s' "$text" | jq -Rs .
}

# 파일 존재 및 읽기 가능 확인
check_file_readable() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    if [[ ! -r "$file" ]]; then
        return 1
    fi
    return 0
}

# 디렉토리 생성 (에러 무시)
ensure_dir() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || true
}

# 파일 락 관리
acquire_lock() {
    local lockfile="$1"
    local timeout="${2:-5}"
    local elapsed=0
    
    while ! mkdir "$lockfile" 2>/dev/null; do
        if [[ $elapsed -ge $timeout ]]; then
            return 1
        fi
        sleep 0.1
        elapsed=$((elapsed + 1))
    done
    return 0
}

release_lock() {
    local lockfile="$1"
    rmdir "$lockfile" 2>/dev/null || true
}

# 플랫폼 감지
detect_platform() {
    case "$(uname -s)" in
        Darwin*) echo "macos" ;;
        Linux*)  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

# 명령어 존재 확인
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 안전한 임시 파일 생성
create_temp_file() {
    local prefix="${1:-claude}"
    mktemp "${TMPDIR:-/tmp}/${prefix}.XXXXXX"
}

# 안전한 임시 디렉토리 생성
create_temp_dir() {
    local prefix="${1:-claude}"
    mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX"
}