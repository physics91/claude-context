#!/usr/bin/env bash
# Claude Context - 업데이트 함수 라이브러리
# 버전 관리, 백업, 다운로드, 롤백 등 업데이트 관련 함수들

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# GitHub 설정
GITHUB_USER="physics91"
GITHUB_REPO="claude-context"
GITHUB_BRANCH="main"
GITHUB_API_BASE="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO"
GITHUB_RAW_BASE="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO"

# 로그 함수 (common_functions.sh와 일관성 유지)
update_log_info() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPDATE] INFO: $message" >&2
}

update_log_error() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPDATE] ERROR: $message" >&2
}

update_log_debug() {
    local message="$1"
    if [[ "${DEBUG:-false}" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UPDATE] DEBUG: $message" >&2
    fi
}

# --- 버전 관리 함수 ---

# 현재 설치된 버전 가져오기
get_current_version() {
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local version_file="$install_dir/VERSION"
    
    if [[ -f "$version_file" ]]; then
        cat "$version_file" 2>/dev/null | tr -d '\n\r'
    else
        # 레거시 지원: 기존 설치에는 VERSION 파일이 없을 수 있음
        echo "unknown"
    fi
}

# GitHub에서 최신 릴리즈 버전 가져오기
get_latest_version() {
    local api_url="$GITHUB_API_BASE/releases/latest"
    
    update_log_debug "Fetching latest version from: $api_url"
    
    # curl과 jq를 사용하여 최신 릴리즈 정보 가져오기
    if command -v curl &> /dev/null && command -v jq &> /dev/null; then
        local latest_version
        latest_version=$(curl -s "$api_url" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
        
        if [[ -n "$latest_version" && "$latest_version" != "null" ]]; then
            echo "$latest_version" | sed 's/^v//'  # v 접두사 제거
            return 0
        fi
    fi
    
    # 릴리즈가 없거나 API 호출 실패 시 메인 브랜치의 VERSION 파일 확인
    if command -v curl &> /dev/null; then
        local version_url="$GITHUB_RAW_BASE/$GITHUB_BRANCH/VERSION"
        local main_version
        main_version=$(curl -s "$version_url" 2>/dev/null | tr -d '\n\r')
        
        if [[ -n "$main_version" ]]; then
            echo "$main_version"
            return 0
        fi
    fi
    
    # 모든 방법이 실패한 경우
    update_log_error "Failed to fetch latest version from GitHub"
    return 1
}

# 버전 비교 (semantic versioning)
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    # unknown 버전 처리
    if [[ "$version1" == "unknown" ]]; then
        echo "older"
        return 0
    fi
    
    if [[ "$version2" == "unknown" ]]; then
        echo "newer"
        return 0
    fi
    
    # 버전이 동일한 경우
    if [[ "$version1" == "$version2" ]]; then
        echo "same"
        return 0
    fi
    
    # 버전 분리 및 비교
    local v1_parts=(${version1//./ })
    local v2_parts=(${version2//./ })
    
    # 각 파트를 숫자로 변환하여 비교
    for i in {0..2}; do
        local v1_part=${v1_parts[i]:-0}
        local v2_part=${v2_parts[i]:-0}
        
        # 숫자가 아닌 문자 제거 (예: 1.0.0-beta -> 1.0.0)
        v1_part=$(echo "$v1_part" | sed 's/[^0-9].*//')
        v2_part=$(echo "$v2_part" | sed 's/[^0-9].*//')
        
        v1_part=${v1_part:-0}
        v2_part=${v2_part:-0}
        
        if [[ $v1_part -lt $v2_part ]]; then
            echo "older"
            return 0
        elif [[ $v1_part -gt $v2_part ]]; then
            echo "newer"
            return 0
        fi
    done
    
    echo "same"
}

# 업데이트 필요 여부 확인
is_update_available() {
    local current_version
    local latest_version
    local comparison
    
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    if [[ $? -ne 0 ]]; then
        update_log_error "Cannot check for updates: failed to get latest version"
        return 2  # 네트워크 오류 등
    fi
    
    comparison=$(compare_versions "$current_version" "$latest_version")
    
    update_log_debug "Current: $current_version, Latest: $latest_version, Comparison: $comparison"
    
    case "$comparison" in
        "older")
            echo -e "${YELLOW}업데이트 가능: $current_version → $latest_version${NC}"
            return 0  # 업데이트 필요
            ;;
        "newer")
            echo -e "${GREEN}현재 버전이 최신보다 높습니다: $current_version (최신: $latest_version)${NC}"
            return 1  # 업데이트 불필요
            ;;
        "same")
            echo -e "${GREEN}최신 버전입니다: $current_version${NC}"
            return 1  # 업데이트 불필요
            ;;
        *)
            update_log_error "Version comparison failed"
            return 2  # 오류
            ;;
    esac
}

# --- 백업 함수 ---

# 현재 설치 백업
create_backup() {
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local backup_base="${HOME}/.claude/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local current_version=$(get_current_version)
    local backup_dir="$backup_base/claude-context-$current_version-$timestamp"
    
    if [[ ! -d "$install_dir" ]]; then
        update_log_error "No installation found to backup"
        return 1
    fi
    
    echo -e "${BLUE}기존 설치를 백업하는 중...${NC}"
    
    # 백업 디렉토리 생성
    mkdir -p "$backup_base"
    
    # 설치 디렉토리 백업
    if cp -r "$install_dir" "$backup_dir" 2>/dev/null; then
        echo -e "${GREEN}✓ 백업 완료: $backup_dir${NC}"
        echo "$backup_dir"  # 백업 경로 반환
        return 0
    else
        update_log_error "Failed to create backup"
        return 1
    fi
}

# 강화된 롤백 메커니즘
safe_restore_from_backup() {
    local backup_dir="$1"
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local temp_restore_dir="${install_dir}.restore.$$"
    
    if [[ ! -d "$backup_dir" ]]; then
        update_log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    echo -e "${YELLOW}백업에서 안전하게 복원하는 중: $backup_dir${NC}"
    
    # 1단계: 임시 위치에 복원 시도
    if ! cp -r "$backup_dir" "$temp_restore_dir" 2>/dev/null; then
        update_log_error "Failed to copy backup to temporary location"
        return 1
    fi
    
    # 2단계: 기존 설치 제거
    if [[ -d "$install_dir" ]]; then
        if ! rm -rf "$install_dir" 2>/dev/null; then
            update_log_error "Failed to remove current installation"
            rm -rf "$temp_restore_dir" 2>/dev/null
            return 1
        fi
    fi
    
    # 3단계: 임시 위치에서 최종 위치로 이동
    if ! mv "$temp_restore_dir" "$install_dir" 2>/dev/null; then
        update_log_error "Failed to move restored backup to final location"
        # 실패 시 임시 파일 정리
        rm -rf "$temp_restore_dir" 2>/dev/null
        return 1
    fi
    
    # 4단계: 권한 설정 복원
    if ! chmod -R u+rwX,go-rwx "$install_dir" 2>/dev/null; then
        update_log_error "Warning: Failed to set proper permissions on restored installation"
    fi
    
    echo -e "${GREEN}✓ 안전하게 복원 완료${NC}"
    return 0
}

# 빠른 롤백 (비상 상황용)
quick_restore_from_backup() {
    local backup_dir="$1"
    local install_dir="${HOME}/.claude/hooks/claude-context"
    
    if [[ ! -d "$backup_dir" ]]; then
        update_log_error "Backup directory not found: $backup_dir"
        return 1
    fi
    
    echo -e "${YELLOW}빠른 복원 수행 중: $backup_dir${NC}"
    
    # 현재 설치 제거
    [[ -d "$install_dir" ]] && rm -rf "$install_dir" 2>/dev/null
    
    # 백업에서 복원
    if cp -r "$backup_dir" "$install_dir" 2>/dev/null; then
        echo -e "${GREEN}✓ 복원 완료${NC}"
        return 0
    else
        update_log_error "Failed to restore from backup"
        return 1
    fi
}

# 레거시 호환성을 위한 래퍼 함수
restore_from_backup() {
    safe_restore_from_backup "$@"
}

# 오래된 백업 정리
cleanup_old_backups() {
    local backup_base="${HOME}/.claude/backups"
    local max_backups="${1:-5}"  # 기본적으로 최대 5개 백업 유지
    
    if [[ ! -d "$backup_base" ]]; then
        return 0
    fi
    
    update_log_debug "Cleaning up old backups (keeping $max_backups latest)"
    
    # 백업 디렉토리를 시간 순으로 정렬하여 오래된 것 제거
    local backup_count
    backup_count=$(find "$backup_base" -maxdepth 1 -name "claude-context-*" -type d | wc -l)
    
    if [[ $backup_count -gt $max_backups ]]; then
        local excess=$((backup_count - max_backups))
        find "$backup_base" -maxdepth 1 -name "claude-context-*" -type d -print0 | \
            sort -z | head -z -n "$excess" | xargs -0 rm -rf
        echo -e "${GREEN}✓ 오래된 백업 $excess개 정리 완료${NC}"
    fi
}

# --- 다운로드 함수 ---

# Git 저장소 보안 검증
verify_git_security() {
    local repo_dir="$1"
    local expected_user="$GITHUB_USER"
    local expected_repo="$GITHUB_REPO"
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        update_log_error "Not a valid git repository: $repo_dir"
        return 1
    fi
    
    cd "$repo_dir" || return 1
    
    # 원격 저장소 URL 검증
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    if [[ "$remote_url" != "https://github.com/$expected_user/$expected_repo.git" && 
          "$remote_url" != "git@github.com:$expected_user/$expected_repo.git" ]]; then
        update_log_error "Repository URL verification failed: $remote_url"
        return 1
    fi
    
    # 최신 커밋 검증 (GitHub API 사용)
    if command -v curl &> /dev/null; then
        local api_url="$GITHUB_API_BASE/commits/$GITHUB_BRANCH"
        local expected_sha
        expected_sha=$(curl -s "$api_url" 2>/dev/null | 
                      grep '"sha"' | head -n1 | 
                      sed 's/.*"sha": "\([^"]*\)".*/\1/' || echo "")
        
        if [[ -n "$expected_sha" ]]; then
            local actual_sha
            actual_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
            
            if [[ "$actual_sha" != "$expected_sha" ]]; then
                update_log_error "Commit hash verification failed: expected $expected_sha, got $actual_sha"
                return 1
            fi
            
            update_log_debug "Git security verification passed: $actual_sha"
        fi
    fi
    
    return 0
}

# 보안 강화된 임시 디렉토리 생성
create_secure_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if [[ $? -ne 0 || ! -d "$temp_dir" ]]; then
        update_log_error "Failed to create temporary directory"
        return 1
    fi
    
    # 권한을 700으로 제한 (소유자만 접근 가능)
    chmod 700 "$temp_dir" 2>/dev/null
    
    echo "$temp_dir"
    return 0
}

# 최신 소스 다운로드 (보안 강화)
download_latest() {
    local temp_dir="$1"
    local branch="${2:-$GITHUB_BRANCH}"
    
    if [[ -z "$temp_dir" ]]; then
        update_log_error "Temporary directory not specified"
        return 1
    fi
    
    echo -e "${BLUE}최신 소스를 다운로드하는 중...${NC}"
    
    cd "$temp_dir" || return 1
    
    # Git 클론 (보안 강화)
    local git_url="https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
    
    # SSL 인증서 검증 활성화
    git config --global http.sslVerify true
    
    if ! git clone --depth 1 --branch "$branch" "$git_url" >/dev/null 2>&1; then
        update_log_error "Failed to download latest source"
        return 1
    fi
    
    local repo_dir="$temp_dir/$GITHUB_REPO"
    
    # 보안 검증 수행
    if ! verify_git_security "$repo_dir"; then
        update_log_error "Git security verification failed"
        rm -rf "$repo_dir" 2>/dev/null
        return 1
    fi
    
    echo -e "${GREEN}✓ 다운로드 및 보안 검증 완료${NC}"
    echo "$repo_dir"  # 다운로드된 소스 경로 반환
    return 0
}

# --- 업데이트 적용 함수 ---

# 권한 문제 감지 및 복구
handle_permission_error() {
    local target_path="$1"
    local operation="$2"
    
    update_log_error "Permission error during $operation: $target_path"
    
    # 경로의 권한 상태 확인
    if [[ -e "$target_path" ]]; then
        local permissions
        permissions=$(ls -ld "$target_path" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        update_log_debug "Current permissions: $permissions"
    fi
    
    # 권한 복구 시도
    echo -e "${YELLOW}권한 문제 복구를 시도하는 중...${NC}"
    
    if [[ -d "$target_path" ]]; then
        # 디렉토리 경우
        if chmod -R u+rwX "$target_path" 2>/dev/null; then
            echo -e "${GREEN}✓ 디렉토리 권한 복구 성공${NC}"
            return 0
        fi
    elif [[ -f "$target_path" ]]; then
        # 파일 경우
        if chmod u+rw "$target_path" 2>/dev/null; then
            echo -e "${GREEN}✓ 파일 권한 복구 성공${NC}"
            return 0
        fi
    fi
    
    # 복구 실패 시 가이드 제공
    echo -e "${RED}권한 복구에 실패했습니다${NC}"
    echo -e "${YELLOW}수동 복구 방법:${NC}"
    echo "sudo chown -R \$USER \"$target_path\""
    echo "chmod -R u+rwX \"$target_path\""
    
    return 1
}

# 안전한 설정 파일 백업
safe_backup_config() {
    local source_file="$1"
    local backup_file="$2"
    
    if [[ ! -f "$source_file" ]]; then
        update_log_debug "Config file does not exist: $source_file"
        return 0  # 파일이 없는 것은 오류가 아님
    fi
    
    # 백업 파일 생성 시도
    if cp "$source_file" "$backup_file" 2>/dev/null; then
        chmod 600 "$backup_file" 2>/dev/null
        update_log_debug "Config backed up: $source_file -> $backup_file"
        return 0
    fi
    
    # 백업 실패 시 권한 문제 처리
    update_log_error "Failed to backup config file: $source_file"
    
    if ! handle_permission_error "$source_file" "config backup"; then
        return 1
    fi
    
    # 권한 복구 후 재시도
    if cp "$source_file" "$backup_file" 2>/dev/null; then
        chmod 600 "$backup_file" 2>/dev/null
        update_log_debug "Config backed up after permission fix: $source_file -> $backup_file"
        return 0
    fi
    
    return 1
}

# 안전한 설정 파일 복원
safe_restore_config() {
    local backup_file="$1"
    local target_file="$2"
    
    if [[ ! -f "$backup_file" ]]; then
        update_log_debug "No backup to restore: $backup_file"
        return 0  # 백업이 없는 것은 오류가 아님
    fi
    
    # 직접 복원 시도
    if cp "$backup_file" "$target_file" 2>/dev/null; then
        update_log_debug "Config restored: $backup_file -> $target_file"
        return 0
    fi
    
    # 복원 실패 시 처리
    update_log_error "Failed to restore config file: $backup_file -> $target_file"
    
    # 대상 디렉토리가 없는 경우 생성 시도
    local target_dir
    target_dir=$(dirname "$target_file")
    if [[ ! -d "$target_dir" ]]; then
        update_log_debug "Creating target directory: $target_dir"
        if ! mkdir -p "$target_dir" 2>/dev/null; then
            if ! handle_permission_error "$target_dir" "directory creation"; then
                return 1
            fi
            mkdir -p "$target_dir" 2>/dev/null || return 1
        fi
    fi
    
    # 권한 문제 처리 후 재시도
    if ! handle_permission_error "$target_dir" "config restore"; then
        return 1
    fi
    
    if cp "$backup_file" "$target_file" 2>/dev/null; then
        update_log_debug "Config restored after permission fix: $backup_file -> $target_file"
        return 0
    fi
    
    update_log_error "Config restore failed even after permission fixes"
    return 1
}

# 설정 보존하며 업데이트 적용 (강화됨)
apply_update() {
    local source_dir="$1"
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local claude_config="${HOME}/.claude/settings.json"
    
    if [[ ! -d "$source_dir" ]]; then
        update_log_error "Source directory not found: $source_dir"
        return 1
    fi
    
    echo -e "${BLUE}업데이트를 적용하는 중...${NC}"
    
    # 기존 사용자 설정 백업 (보안 강화됨)
    local temp_config
    temp_config=$(mktemp)
    if [[ $? -ne 0 ]]; then
        update_log_error "Failed to create temporary config file"
        return 1
    fi
    chmod 600 "$temp_config" 2>/dev/null
    local current_mode="basic"
    local current_hook_type="UserPromptSubmit"
    
    # 현재 모드 및 설정 읽기
    if [[ -f "$install_dir/config.sh" ]]; then
        current_mode=$(grep "^CLAUDE_CONTEXT_MODE=" "$install_dir/config.sh" 2>/dev/null | cut -d'"' -f2 || echo "basic")
        update_log_debug "Current mode: $current_mode"
    fi
    
    # Claude 설정에서 현재 훅 타입 확인
    if [[ -f "$claude_config" ]] && command -v jq &> /dev/null; then
        if jq -e '.hooks.UserPromptSubmit' "$claude_config" >/dev/null 2>&1; then
            current_hook_type="UserPromptSubmit"
        elif jq -e '.hooks.PreToolUse' "$claude_config" >/dev/null 2>&1; then
            current_hook_type="PreToolUse"
        fi
        update_log_debug "Current hook type: $current_hook_type"
    fi
    
    # 기존 설치 제거 (설정은 보존)
    if [[ -d "$install_dir" ]]; then
        # 사용자 정의 설정 파일들 임시 보존
        local user_configs=()
        [[ -f "$install_dir/config.sh" ]] && user_configs+=("config.sh")
        [[ -f "$install_dir/.user_settings" ]] && user_configs+=(".user_settings")
        
        # 사용자 설정 안전 백업
        local temp_backup
        temp_backup=$(create_secure_temp_dir)
        if [[ $? -ne 0 ]]; then
            update_log_error "Failed to create secure backup directory"
            return 1
        fi
        
        local backup_failed=false
        for config in "${user_configs[@]}"; do
            if [[ -f "$install_dir/$config" ]]; then
                if ! safe_backup_config "$install_dir/$config" "$temp_backup/$config"; then
                    update_log_error "Failed to backup user config: $config"
                    backup_failed=true
                fi
            fi
        done
        
        if [[ "$backup_failed" == "true" ]]; then
            update_log_error "Some user configs could not be backed up"
            rm -rf "$temp_backup" 2>/dev/null
            return 1
        fi
        
        # 기존 설치 안전 제거
        if ! rm -rf "$install_dir" 2>/dev/null; then
            if ! handle_permission_error "$install_dir" "directory removal"; then
                update_log_error "Failed to remove existing installation"
                rm -rf "$temp_backup" 2>/dev/null
                return 1
            fi
            # 권한 복구 후 재시도
            if ! rm -rf "$install_dir" 2>/dev/null; then
                update_log_error "Failed to remove existing installation even after permission fix"
                rm -rf "$temp_backup" 2>/dev/null
                return 1
            fi
        fi
        
        # 새 버전 설치 (기존 install.sh 사용)
        cd "$source_dir"
        if [[ -f "install/install.sh" ]]; then
            chmod +x install/install.sh
            ./install/install.sh --mode "$current_mode" --hook-type "$current_hook_type" >/dev/null
        else
            update_log_error "Installation script not found in source"
            return 1
        fi
        
        # 사용자 설정 안전 복원
        local restore_failed=false
        for config in "${user_configs[@]}"; do
            if [[ -f "$temp_backup/$config" ]]; then
                if ! safe_restore_config "$temp_backup/$config" "$install_dir/$config"; then
                    update_log_error "Failed to restore user config: $config"
                    restore_failed=true
                fi
            fi
        done
        
        if [[ "$restore_failed" == "true" ]]; then
            update_log_error "Some user configs could not be restored"
            echo -e "${YELLOW}경고: 일부 사용자 설정 복원에 실패했습니다${NC}"
            echo -e "${YELLOW}수동 복원 위치: $temp_backup${NC}"
            # 전체 실패로 처리하지 않고 경고만 표시
        fi
        
        rm -rf "$temp_backup"
    else
        # 새 설치
        cd "$source_dir"
        if [[ -f "install/install.sh" ]]; then
            chmod +x install/install.sh
            ./install/install.sh --mode "$current_mode" --hook-type "$current_hook_type"
        else
            update_log_error "Installation script not found in source"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✓ 업데이트 적용 완료${NC}"
    return 0
}

# --- 의존성 확인 함수 ---

check_update_dependencies() {
    local missing=()
    
    # 필수 도구 확인
    for cmd in curl git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # jq는 선택적이지만 권장
    if ! command -v jq &> /dev/null; then
        update_log_debug "jq not found, some features may be limited"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        update_log_error "Missing required tools: ${missing[*]}"
        echo -e "${RED}다음 도구가 필요합니다: ${missing[*]}${NC}"
        echo "설치 후 다시 시도해주세요:"
        echo "  - macOS: brew install ${missing[*]}"
        echo "  - Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  - RHEL/CentOS: sudo yum install ${missing[*]}"
        return 1
    fi
    
    return 0
}

# --- 업데이트 정보 함수 ---

get_update_info() {
    local current_version
    local latest_version
    
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}업데이트 정보를 가져올 수 없습니다${NC}"
        return 1
    fi
    
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}        Claude Context 업데이트 정보      ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}현재 버전:${NC} $current_version"
    echo -e "${YELLOW}최신 버전:${NC} $latest_version"
    echo
    
    local comparison=$(compare_versions "$current_version" "$latest_version")
    case "$comparison" in
        "older")
            echo -e "${GREEN}✨ 새로운 버전이 있습니다!${NC}"
            return 0
            ;;
        "newer")
            echo -e "${BLUE}ℹ️  현재 버전이 최신보다 높습니다${NC}"
            return 1
            ;;
        "same")
            echo -e "${GREEN}✅ 최신 버전을 사용하고 있습니다${NC}"
            return 1
            ;;
        *)
            echo -e "${RED}❌ 버전 비교 중 오류가 발생했습니다${NC}"
            return 2
            ;;
    esac
}

# --- 전체 업데이트 프로세스 ---

perform_update() {
    local force_update="${1:-false}"
    local backup_dir=""
    local temp_dir=""
    local source_dir=""
    
    # Cleanup function
    cleanup_update() {
        [[ -n "$temp_dir" && -d "$temp_dir" ]] && rm -rf "$temp_dir"
    }
    trap cleanup_update EXIT
    
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Claude Context 업데이트             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
    
    # 의존성 확인
    if ! check_update_dependencies; then
        return 1
    fi
    
    # 업데이트 필요 여부 확인
    if [[ "$force_update" != "true" ]]; then
        if ! is_update_available; then
            return 0  # 업데이트 불필요
        fi
    fi
    
    # 사용자 확인
    if [[ "$force_update" != "true" ]]; then
        echo
        read -p "업데이트를 진행하시겠습니까? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "업데이트가 취소되었습니다."
            return 0
        fi
    fi
    
    # 백업 생성
    backup_dir=$(create_backup)
    if [[ $? -ne 0 ]]; then
        update_log_error "Backup failed, aborting update"
        return 1
    fi
    
    # 보안 강화된 임시 디렉토리 생성
    temp_dir=$(create_secure_temp_dir)
    if [[ $? -ne 0 ]]; then
        update_log_error "Failed to create secure temporary directory"
        return 1
    fi
    
    # 최신 소스 다운로드
    source_dir=$(download_latest "$temp_dir")
    if [[ $? -ne 0 ]]; then
        update_log_error "Download failed, restoring from backup"
        restore_from_backup "$backup_dir"
        return 1
    fi
    
    # 업데이트 적용 (강화된 에러 처리)
    if ! apply_update "$source_dir"; then
        update_log_error "Update failed, initiating safe rollback"
        
        # 안전한 복원 시도
        if ! safe_restore_from_backup "$backup_dir"; then
            update_log_error "Safe restore failed, attempting quick restore"
            
            # 빠른 복원 시도
            if ! quick_restore_from_backup "$backup_dir"; then
                update_log_error "All restore attempts failed - system may be in inconsistent state"
                echo -e "${RED}경고: 업데이트 및 복원이 모두 실패했습니다!${NC}"
                echo -e "${YELLOW}수동 복원 방법:${NC}"
                echo "1. 백업 디렉토리: $backup_dir"
                echo "2. 설치 디렉토리: ${HOME}/.claude/hooks/claude-context"
                echo "3. 명령어: cp -r \"$backup_dir\" \"${HOME}/.claude/hooks/claude-context\""
                return 2  # 완전 실패를 나타내는 접수 코드
            fi
        fi
        
        return 1
    fi
    
    # 백업 정리
    cleanup_old_backups
    
    echo
    echo -e "${GREEN}🎉 업데이트가 성공적으로 완료되었습니다!${NC}"
    echo
    
    # 업데이트 후 버전 정보 표시
    local new_version=$(get_current_version)
    echo -e "${BLUE}업데이트된 버전: $new_version${NC}"
    echo
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "1. Claude Code를 재시작하세요"
    echo "2. 설정이 올바르게 적용되었는지 확인하세요"
    echo
    
    return 0
}