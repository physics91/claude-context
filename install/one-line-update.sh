#!/usr/bin/env bash
# Claude Context 원클릭 업데이트 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/physics91/claude-context/main/install/one-line-update.sh | bash
# 
# 환경 변수로 옵션 설정 가능:
# CLAUDE_UPDATE_FORCE=true curl -sSL ... | bash  # 강제 업데이트
# CLAUDE_UPDATE_BACKUP_KEEP=10 curl -sSL ... | bash  # 백업 보관 개수

set -euo pipefail

# 설정
GITHUB_USER="physics91"
GITHUB_REPO="claude-context"
GITHUB_BRANCH="main"

# 입력 값 검증 및 옵션 설정
validate_input() {
    local backup_keep="${CLAUDE_UPDATE_BACKUP_KEEP:-5}"
    
    # 숫자 형식 검증
    if ! [[ "$backup_keep" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Error: CLAUDE_UPDATE_BACKUP_KEEP는 숫자여야 합니다: $backup_keep${NC}"
        exit 1
    fi
    
    # 범위 검증 (1-50)
    if [[ $backup_keep -lt 1 || $backup_keep -gt 50 ]]; then
        echo -e "${RED}Error: CLAUDE_UPDATE_BACKUP_KEEP 값이 범위를 벗어납니다 (1-50): $backup_keep${NC}"
        exit 1
    fi
    
    echo "$backup_keep"
}

# 옵션
FORCE_UPDATE="${CLAUDE_UPDATE_FORCE:-false}"
BACKUP_KEEP=$(validate_input)

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Claude Context 업데이트             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo

# 보안 강화된 임시 디렉토리 생성
create_secure_temp_dir() {
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if [[ $? -ne 0 || ! -d "$temp_dir" ]]; then
        echo -e "${RED}Error: 임시 디렉토리 생성 실패${NC}"
        exit 1
    fi
    
    # 권한을 700으로 제한 (소유자만 접근 가능)
    chmod 700 "$temp_dir" 2>/dev/null
    
    echo "$temp_dir"
}

TEMP_DIR=$(create_secure_temp_dir)
trap 'rm -rf "$TEMP_DIR"' EXIT

cd "$TEMP_DIR"

# 필수 도구 확인
check_dependencies() {
    local missing=()
    
    for cmd in curl git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}Error: 다음 도구가 설치되어 있지 않습니다: ${missing[*]}${NC}"
        echo "설치 후 다시 시도해주세요:"
        echo "  - macOS: brew install ${missing[*]}"
        echo "  - Ubuntu/Debian: sudo apt install ${missing[*]}"
        echo "  - RHEL/CentOS: sudo yum install ${missing[*]}"
        exit 1
    fi
    
    # jq는 선택적이지만 권장
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}Warning: jq가 설치되어 있지 않습니다.${NC}"
        echo "일부 기능이 제한될 수 있습니다. jq 설치를 권장합니다:"
        echo "  - macOS: brew install jq"
        echo "  - Ubuntu/Debian: sudo apt install jq"
        echo "  - RHEL/CentOS: sudo yum install jq"
        echo
    fi
}

# Claude Context 설치 여부 확인
check_installation() {
    local install_dir="${HOME}/.claude/hooks/claude-context"
    
    if [[ ! -d "$install_dir" ]]; then
        echo -e "${RED}Error: Claude Context가 설치되어 있지 않습니다.${NC}"
        echo "먼저 설치를 진행하세요:"
        echo "curl -sSL https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/main/install/one-line-install.sh | bash"
        exit 1
    fi
}

# 현재 버전 가져오기
get_current_version() {
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local version_file="$install_dir/VERSION"
    
    if [[ -f "$version_file" ]]; then
        cat "$version_file" 2>/dev/null | tr -d '\n\r'
    else
        echo "unknown"
    fi
}

# 최신 버전 가져오기
get_latest_version() {
    local api_url="https://api.github.com/repos/$GITHUB_USER/$GITHUB_REPO/releases/latest"
    
    # GitHub API에서 최신 릴리즈 확인
    if command -v jq &> /dev/null; then
        local latest_version
        latest_version=$(curl -s "$api_url" 2>/dev/null | jq -r '.tag_name // empty' 2>/dev/null)
        
        if [[ -n "$latest_version" && "$latest_version" != "null" ]]; then
            echo "$latest_version" | sed 's/^v//'
            return 0
        fi
    fi
    
    # 릴리즈가 없으면 메인 브랜치의 VERSION 파일 확인
    local version_url="https://raw.githubusercontent.com/$GITHUB_USER/$GITHUB_REPO/$GITHUB_BRANCH/VERSION"
    local main_version
    main_version=$(curl -s "$version_url" 2>/dev/null | tr -d '\n\r')
    
    if [[ -n "$main_version" ]]; then
        echo "$main_version"
        return 0
    fi
    
    echo "unknown"
    return 1
}

# 버전 비교
compare_versions() {
    local version1="$1"
    local version2="$2"
    
    if [[ "$version1" == "unknown" ]]; then
        echo "older"
        return 0
    fi
    
    if [[ "$version2" == "unknown" ]]; then
        echo "newer"
        return 0
    fi
    
    if [[ "$version1" == "$version2" ]]; then
        echo "same"
        return 0
    fi
    
    local v1_parts=(${version1//./ })
    local v2_parts=(${version2//./ })
    
    for i in {0..2}; do
        local v1_part=${v1_parts[i]:-0}
        local v2_part=${v2_parts[i]:-0}
        
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
check_update_needed() {
    local current_version
    local latest_version
    local comparison
    
    echo "버전 정보를 확인하는 중..."
    
    current_version=$(get_current_version)
    latest_version=$(get_latest_version)
    
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: 최신 버전 정보를 가져올 수 없습니다.${NC}"
        echo "네트워크 연결을 확인하고 다시 시도해주세요."
        exit 1
    fi
    
    comparison=$(compare_versions "$current_version" "$latest_version")
    
    echo
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${BLUE}        버전 정보                        ${NC}"
    echo -e "${BLUE}═══════════════════════════════════════${NC}"
    echo -e "${YELLOW}현재 버전:${NC} $current_version"
    echo -e "${YELLOW}최신 버전:${NC} $latest_version"
    echo
    
    case "$comparison" in
        "older")
            echo -e "${GREEN}✨ 새로운 버전이 있습니다!${NC}"
            return 0  # 업데이트 필요
            ;;
        "newer")
            echo -e "${BLUE}ℹ️  현재 버전이 최신보다 높습니다${NC}"
            if [[ "$FORCE_UPDATE" != "true" ]]; then
                echo "강제 업데이트를 원하면 CLAUDE_UPDATE_FORCE=true를 설정하세요."
                exit 0
            fi
            echo "강제 업데이트를 진행합니다."
            return 0
            ;;
        "same")
            echo -e "${GREEN}✅ 이미 최신 버전을 사용하고 있습니다${NC}"
            if [[ "$FORCE_UPDATE" != "true" ]]; then
                exit 0
            fi
            echo "강제 업데이트를 진행합니다."
            return 0
            ;;
        *)
            echo -e "${RED}❌ 버전 비교 중 오류가 발생했습니다${NC}"
            exit 1
            ;;
    esac
}

# 권한 문제 처리 함수
handle_permission_error() {
    local target_path="$1"
    local operation="$2"
    
    echo -e "${YELLOW}경고: $operation 중 권한 문제 발생: $target_path${NC}"
    echo "권한 문제 복구를 시도하는 중..."
    
    # 권한 복구 시도
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

# 강화된 백업 생성
create_backup() {
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local backup_base="${HOME}/.claude/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local current_version=$(get_current_version)
    local backup_dir="$backup_base/claude-context-$current_version-$timestamp"
    
    echo "기존 설치를 백업하는 중..."
    
    # 백업 디렉토리 생성
    if ! mkdir -p "$backup_base" 2>/dev/null; then
        if ! handle_permission_error "$(dirname "$backup_base")" "backup directory creation"; then
            echo -e "${RED}Error: 백업 디렉토리 생성 실패${NC}"
            return 1
        fi
        mkdir -p "$backup_base" 2>/dev/null || return 1
    fi
    
    # 백업 실행
    if cp -r "$install_dir" "$backup_dir" 2>/dev/null; then
        echo -e "${GREEN}✓ 백업 완료: $backup_dir${NC}"
        echo "$backup_dir"
        return 0
    else
        echo -e "${RED}Error: 백업 생성 실패${NC}"
        
        # 권한 문제 복구 시도
        if handle_permission_error "$install_dir" "backup creation"; then
            if cp -r "$install_dir" "$backup_dir" 2>/dev/null; then
                echo -e "${GREEN}✓ 권한 복구 후 백업 완료: $backup_dir${NC}"
                echo "$backup_dir"
                return 0
            fi
        fi
        
        echo -e "${RED}Error: 백업 생성에 실패했습니다${NC}"
        return 1
    fi
}

# 오래된 백업 정리
cleanup_old_backups() {
    local backup_base="${HOME}/.claude/backups"
    
    if [[ ! -d "$backup_base" ]]; then
        return 0
    fi
    
    local backup_count
    backup_count=$(find "$backup_base" -maxdepth 1 -name "claude-context-*" -type d | wc -l)
    
    if [[ $backup_count -gt $BACKUP_KEEP ]]; then
        local excess=$((backup_count - BACKUP_KEEP))
        find "$backup_base" -maxdepth 1 -name "claude-context-*" -type d -print0 | \
            sort -z | head -z -n "$excess" | xargs -0 rm -rf
        echo -e "${GREEN}✓ 오래된 백업 $excess개 정리 완료${NC}"
    fi
}

# Git 저장소 보안 검증
verify_git_security() {
    local repo_dir="$1"
    local expected_user="$GITHUB_USER"
    local expected_repo="$GITHUB_REPO"
    
    if [[ ! -d "$repo_dir/.git" ]]; then
        echo -e "${RED}Error: 유효한 Git 저장소가 아닙니다: $repo_dir${NC}"
        return 1
    fi
    
    cd "$repo_dir" || return 1
    
    # 원격 저장소 URL 검증
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
    
    if [[ "$remote_url" != "https://github.com/$expected_user/$expected_repo.git" && 
          "$remote_url" != "git@github.com:$expected_user/$expected_repo.git" ]]; then
        echo -e "${RED}Error: 저장소 URL 검증 실패: $remote_url${NC}"
        return 1
    fi
    
    # 최신 커밋 검증
    if command -v curl &> /dev/null; then
        local api_url="https://api.github.com/repos/$expected_user/$expected_repo/commits/$GITHUB_BRANCH"
        local expected_sha
        expected_sha=$(curl -s "$api_url" 2>/dev/null | 
                      grep '"sha"' | head -n1 | 
                      sed 's/.*"sha": "\([^"]*\)".*/\1/' || echo "")
        
        if [[ -n "$expected_sha" ]]; then
            local actual_sha
            actual_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
            
            if [[ "$actual_sha" != "$expected_sha" ]]; then
                echo -e "${RED}Error: 커밋 해시 검증 실패: expected $expected_sha, got $actual_sha${NC}"
                return 1
            fi
            
            echo "✓ Git 보안 검증 완료: $actual_sha"
        fi
    fi
    
    return 0
}

# 메인 업데이트 프로세스 (보안 강화)
perform_update() {
    local backup_dir=""
    
    # 1. 백업 생성
    backup_dir=$(create_backup)
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Error: 백업 실패로 업데이트를 중단합니다${NC}"
        exit 1
    fi
    
    # 2. 보안 강화된 최신 소스 다운로드
    echo "최신 소스를 다운로드하는 중..."
    
    local git_url="https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
    
    # SSL 인증서 검증 활성화
    git config --global http.sslVerify true
    
    if ! git clone --depth 1 --branch "$GITHUB_BRANCH" "$git_url" >/dev/null 2>&1; then
        echo -e "${RED}Error: 소스 다운로드에 실패했습니다${NC}"
        echo "네트워크 연결을 확인하고 다시 시도해주세요."
        exit 1
    fi
    
    local repo_dir="$TEMP_DIR/$GITHUB_REPO"
    
    # Git 보안 검증 수행
    if ! verify_git_security "$repo_dir"; then
        echo -e "${RED}Error: Git 보안 검증 실패${NC}"
        rm -rf "$repo_dir" 2>/dev/null
        exit 1
    fi
    
    echo -e "${GREEN}✓ 다운로드 및 보안 검증 완료${NC}"
    
    # 3. 현재 설정 정보 백업
    local install_dir="${HOME}/.claude/hooks/claude-context"
    local current_mode="basic"
    local current_hook_type="UserPromptSubmit"
    
    if [[ -f "$install_dir/config.sh" ]]; then
        current_mode=$(grep "^CLAUDE_CONTEXT_MODE=" "$install_dir/config.sh" 2>/dev/null | cut -d'"' -f2 || echo "basic")
    fi
    
    # Claude 설정에서 현재 훅 타입 확인
    local claude_config="${HOME}/.claude/settings.json"
    if [[ -f "$claude_config" ]] && command -v jq &> /dev/null; then
        if jq -e '.hooks.UserPromptSubmit' "$claude_config" >/dev/null 2>&1; then
            current_hook_type="UserPromptSubmit"
        elif jq -e '.hooks.PreToolUse' "$claude_config" >/dev/null 2>&1; then
            current_hook_type="PreToolUse"
        fi
    fi
    
    # 4. 새 버전 설치
    echo "새 버전을 설치하는 중..."
    cd "$repo_dir"
    
    if [[ -f install/install.sh ]]; then
        chmod +x install/install.sh
        if ./install/install.sh --mode "$current_mode" --hook-type "$current_hook_type" >/dev/null; then
            echo -e "${GREEN}✓ 설치 완료${NC}"
        else
            echo -e "${RED}Error: 설치 중 오류가 발생했습니다${NC}"
            echo "안전한 롤백을 시작합니다..."
            
            # 강화된 롤백 메커니즘
            local temp_restore_dir="${install_dir}.restore.$$"
            
            # 1단계: 임시 위치에 복원
            if cp -r "$backup_dir" "$temp_restore_dir" 2>/dev/null; then
                echo "✓ 임시 복원 완료"
                
                # 2단계: 기존 설치 제거
                rm -rf "$install_dir" 2>/dev/null
                echo "✓ 기존 설치 제거 완료"
                
                # 3단계: 최종 위치로 이동
                if mv "$temp_restore_dir" "$install_dir" 2>/dev/null; then
                    echo -e "${GREEN}✓ 안전한 복원 완료${NC}"
                else
                    echo -e "${RED}Error: 안전한 복원에 실패했습니다${NC}"
                    # 빠른 복원 시도
                    rm -rf "$temp_restore_dir" 2>/dev/null
                    if cp -r "$backup_dir" "$install_dir" 2>/dev/null; then
                        echo -e "${YELLOW}✓ 빠른 복원 완료${NC}"
                    else
                        echo -e "${RED}경고: 모든 복원 시도가 실패했습니다!${NC}"
                        echo -e "${YELLOW}수동 복원 방법:${NC}"
                        echo "1. 백업 디렉토리: $backup_dir"
                        echo "2. 설치 디렉토리: $install_dir"
                        echo "3. 명령어: cp -r \"$backup_dir\" \"$install_dir\""
                    fi
                fi
            else
                echo -e "${RED}Error: 임시 복원에 실패했습니다${NC}"
                # 빠른 복원 시도
                rm -rf "$install_dir" 2>/dev/null
                if cp -r "$backup_dir" "$install_dir" 2>/dev/null; then
                    echo -e "${YELLOW}✓ 빠른 복원 완료${NC}"
                else
                    echo -e "${RED}경고: 모든 복원 시도가 실패했습니다!${NC}"
                    echo -e "${YELLOW}수동 복원 방법:${NC}"
                    echo "1. 백업 디렉토리: $backup_dir"
                    echo "2. 설치 디렉토리: $install_dir"
                    echo "3. 명령어: cp -r \"$backup_dir\" \"$install_dir\""
                fi
            fi
            
            exit 1
        fi
    else
        echo -e "${RED}Error: 설치 스크립트를 찾을 수 없습니다${NC}"
        exit 1
    fi
    
    # 5. 백업 정리
    cleanup_old_backups
}

# 메인 실행 함수
main() {
    # 의존성 확인
    check_dependencies
    
    # 설치 여부 확인
    check_installation
    
    # 업데이트 필요 여부 확인
    check_update_needed
    
    # 사용자 확인 (강제 업데이트가 아닌 경우)
    if [[ "$FORCE_UPDATE" != "true" ]]; then
        echo
        read -p "업데이트를 진행하시겠습니까? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "업데이트가 취소되었습니다."
            exit 0
        fi
    fi
    
    # 업데이트 실행
    echo
    echo "업데이트를 시작합니다..."
    perform_update
    
    # 완료 메시지
    echo
    echo -e "${GREEN}🎉 Claude Context가 성공적으로 업데이트되었습니다!${NC}"
    echo
    
    # 업데이트 후 버전 정보
    local new_version=$(get_current_version)
    echo -e "${BLUE}업데이트된 버전: $new_version${NC}"
    echo
    echo -e "${BLUE}다음 단계:${NC}"
    echo "1. Claude Code를 재시작하세요"
    echo "2. 설정이 올바르게 적용되었는지 확인하세요"
    echo
    echo -e "${BLUE}백업 위치:${NC} ~/.claude/backups/"
    echo -e "${BLUE}롤백 방법:${NC} 백업 디렉토리의 내용을 ~/.claude/hooks/claude-context/로 복사"
    echo
    echo "자세한 사용법: https://github.com/$GITHUB_USER/$GITHUB_REPO"
    echo "문제 발생 시: https://github.com/$GITHUB_USER/$GITHUB_REPO/issues"
}

# 스크립트 실행
main "$@"