#!/usr/bin/env bash
set -euo pipefail

# Claude Context 설치 스크립트 - 깔끔한 구조 버전
# ~/.claude/hooks/claude-context/ 디렉토리에 설치

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_BASE="${HOME}/.claude/hooks"
INSTALL_DIR="${INSTALL_BASE}/claude-context"
CONFIG_FILE="${INSTALL_BASE}/claude-context.conf"

# 헤더 출력
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║     Claude Context 설치                ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
    echo
}

# 모드 선택
select_mode() {
    echo -e "${BLUE}설치 모드를 선택하세요:${NC}" >&2
    echo >&2
    echo "1) Basic   - CLAUDE.md 주입만 (가장 간단)" >&2
    echo "2) History - 대화 기록 관리 추가 (Gemini 불필요)" >&2
    echo "3) Advanced - 토큰 모니터링 포함 (Gemini 필요)" >&2
    echo >&2
    read -p "선택 [1-3] (기본값: 2): " choice
    
    # 기본값 처리
    choice=${choice:-2}
    
    case $choice in
        1) echo "basic" ;;
        2) echo "history" ;;
        3) echo "advanced" ;;
        *) 
            echo -e "${RED}잘못된 선택입니다. 기본값(history)으로 진행합니다.${NC}" >&2
            echo "history"
            ;;
    esac
}

# 의존성 확인
check_dependencies() {
    local mode="$1"
    local missing=()
    
    # 기본 의존성
    for cmd in jq sha256sum gzip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    # Advanced 모드 의존성
    if [[ "$mode" == "advanced" ]]; then
        if ! command -v gemini &> /dev/null; then
            echo -e "${YELLOW}경고: 'gemini' CLI가 설치되어 있지 않습니다.${NC}"
            echo "Advanced 모드를 사용하려면 gemini가 필요합니다."
            read -p "계속하시겠습니까? [y/N]: " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo -e "${RED}다음 명령어가 필요합니다: ${missing[*]}${NC}"
        echo "설치 후 다시 시도해주세요."
        exit 1
    fi
}

# 백업 생성
create_backup() {
    if [[ -d "$INSTALL_DIR" ]]; then
        local backup_dir="${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        echo "기존 설치를 백업합니다..."
        cp -r "$INSTALL_DIR" "$backup_dir"
        echo -e "${GREEN}✓ 백업 완료: $backup_dir${NC}"
    fi
}

# 파일 설치
install_files() {
    echo "파일을 설치하는 중..."
    
    # claude-context 디렉토리 생성
    mkdir -p "$INSTALL_DIR"/{src/{core,monitor,utils},tests,docs,examples,config}
    
    # 필수 파일들의 존재 여부 체크
    local required_dirs=("core" "monitor" "utils")
    local missing_count=0
    
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$PROJECT_ROOT/$dir" ]]; then
            echo -e "${RED}오류: 필수 디렉토리 '$dir'를 찾을 수 없습니다${NC}"
            ((missing_count++))
        fi
    done
    
    if [[ $missing_count -gt 0 ]]; then
        echo -e "${RED}설치에 필요한 파일이 누락되었습니다.${NC}"
        echo "프로젝트 루트: $PROJECT_ROOT"
        echo "현재 디렉토리 구조:"
        ls -la "$PROJECT_ROOT"
        exit 1
    fi
    
    # 파일 복사 (flat 구조에서 claude-context로)
    cp -r "$PROJECT_ROOT/core" "$INSTALL_DIR/src/"
    cp -r "$PROJECT_ROOT/monitor" "$INSTALL_DIR/src/"
    cp -r "$PROJECT_ROOT/utils" "$INSTALL_DIR/src/"
    
    # 선택적 디렉토리 복사
    [[ -d "$PROJECT_ROOT/tests" ]] && cp -r "$PROJECT_ROOT/tests" "$INSTALL_DIR/"
    [[ -d "$PROJECT_ROOT/docs" ]] && cp -r "$PROJECT_ROOT/docs" "$INSTALL_DIR/"
    
    # 문서 파일 복사
    [[ -f "$PROJECT_ROOT/README.md" ]] && cp "$PROJECT_ROOT/README.md" "$INSTALL_DIR/"
    [[ -f "$PROJECT_ROOT/config.sh" ]] && cp "$PROJECT_ROOT/config.sh" "$INSTALL_DIR/"
    
    # uninstall 스크립트 복사
    [[ -f "$PROJECT_ROOT/uninstall.sh" ]] && cp "$PROJECT_ROOT/uninstall.sh" "$INSTALL_DIR/"
    
    # wrapper 스크립트 생성 (hooks 디렉토리 루트에)
    cat > "$INSTALL_BASE/claude_context_injector.sh" << 'EOF'
#!/usr/bin/env bash
# Claude Context Injector Wrapper
exec "${HOME}/.claude/hooks/claude-context/src/core/injector.sh" "$@"
EOF
    
    cat > "$INSTALL_BASE/claude_context_precompact.sh" << 'EOF'
#!/usr/bin/env bash
# Claude Context PreCompact Wrapper
exec "${HOME}/.claude/hooks/claude-context/src/core/precompact.sh" "$@"
EOF
    
    # 실행 권한 설정
    chmod +x "$INSTALL_BASE"/*.sh
    find "$INSTALL_DIR" -name "*.sh" -type f -exec chmod +x {} \;
    
    echo -e "${GREEN}✓ 파일 설치 완료${NC}"
}

# 설정 파일 생성
create_config() {
    local mode="$1"
    
    echo "설정 파일을 생성하는 중..."
    
    # claude-context.conf 생성 (프로젝트 위치 저장)
    cat > "$CONFIG_FILE" << EOF
# Claude Context Configuration
CLAUDE_CONTEXT_HOME="$INSTALL_DIR"
CLAUDE_CONTEXT_MODE="$mode"
EOF
    
    # config.sh 생성 (기존 파일이 있으면 모드만 업데이트)
    if [[ -f "$PROJECT_ROOT/config.sh" ]]; then
        # 기존 config.sh 복사하고 모드 업데이트
        cp "$PROJECT_ROOT/config.sh" "$INSTALL_DIR/config.sh"
        # macOS와 Linux 모두 지원하는 sed 사용
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/^CLAUDE_CONTEXT_MODE=.*/CLAUDE_CONTEXT_MODE=\"$mode\"/" "$INSTALL_DIR/config.sh"
        else
            sed -i "s/^CLAUDE_CONTEXT_MODE=.*/CLAUDE_CONTEXT_MODE=\"$mode\"/" "$INSTALL_DIR/config.sh"
        fi
    else
        cat > "$INSTALL_DIR/config.sh" << EOF
#!/usr/bin/env bash
# Claude Context Configuration

CLAUDE_CONTEXT_MODE="$mode"
CLAUDE_ENABLE_CACHE="true"
CLAUDE_INJECT_PROBABILITY="1.0"
CLAUDE_HOME="\${HOME}/.claude"
CLAUDE_HOOKS_DIR="\${HOME}/.claude/hooks"
CLAUDE_HISTORY_DIR="\${CLAUDE_HOME}/history"
CLAUDE_SUMMARY_DIR="\${CLAUDE_HOME}/summaries"
CLAUDE_CACHE_DIR="\${XDG_CACHE_HOME:-\${HOME}/.cache}/claude-context"
CLAUDE_LOG_DIR="\${CLAUDE_HOME}/logs"
CLAUDE_LOCK_TIMEOUT="5"
CLAUDE_CACHE_MAX_AGE="3600"

export CLAUDE_CONTEXT_MODE
export CLAUDE_ENABLE_CACHE
export CLAUDE_INJECT_PROBABILITY
export CLAUDE_HOME
export CLAUDE_HOOKS_DIR
export CLAUDE_HISTORY_DIR
export CLAUDE_SUMMARY_DIR
export CLAUDE_CACHE_DIR
export CLAUDE_LOG_DIR
export CLAUDE_LOCK_TIMEOUT
export CLAUDE_CACHE_MAX_AGE
EOF
    fi
    
    echo -e "${GREEN}✓ 설정 파일 생성 완료${NC}"
}

# Claude 설정 업데이트
update_claude_config() {
    local claude_config="${HOME}/.claude/settings.json"
    
    if [[ ! -f "$claude_config" ]]; then
        echo -e "${YELLOW}Claude 설정 파일을 찾을 수 없습니다.${NC}"
        echo "Claude Code를 한 번 실행한 후 다시 시도해주세요."
        return
    fi
    
    echo "Claude 설정을 업데이트하는 중..."
    
    # 백업 생성
    cp "$claude_config" "${claude_config}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # hooks 설정 업데이트 (wrapper 스크립트 사용)
    local temp_config=$(mktemp)
    jq '.hooks = {
        "PreToolUse": [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "'"${INSTALL_BASE}/claude_context_injector.sh"'",
                        "timeout": 30000
                    }
                ]
            }
        ],
        "PreCompact": [
            {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "'"${INSTALL_BASE}/claude_context_precompact.sh"'",
                        "timeout": 1000
                    }
                ]
            }
        ]
    }' "$claude_config" > "$temp_config"
    
    mv "$temp_config" "$claude_config"
    
    echo -e "${GREEN}✓ Claude 설정 업데이트 완료${NC}"
}

# 디렉토리 생성
create_directories() {
    local mode="$1"
    
    # 기본 디렉토리
    mkdir -p "${HOME}/.claude"
    mkdir -p "${XDG_CACHE_HOME:-${HOME}/.cache}/claude-context"
    
    # History 모드 디렉토리
    if [[ "$mode" == "history" || "$mode" == "advanced" ]]; then
        mkdir -p "${HOME}/.claude/history"
        mkdir -p "${HOME}/.claude/summaries"
    fi
}

# 관리 스크립트 생성
create_management_scripts() {
    # uninstall.sh는 이미 복사했으므로 실행 권한만 설정
    chmod +x "$INSTALL_DIR"/uninstall.sh 2>/dev/null || true
}

# 사용법 출력
print_usage() {
    local mode="$1"
    
    echo
    echo -e "${GREEN}🎉 설치가 완료되었습니다!${NC}"
    echo
    echo -e "${BLUE}설치 위치: $INSTALL_DIR${NC}"
    echo -e "${BLUE}설치된 모드: $(echo "$mode" | tr '[:lower:]' '[:upper:]')${NC}"
    echo
    echo -e "${YELLOW}⚠️  주의: PreCompact hook은 Claude Code v1.0.48+ 에서만 작동합니다.${NC}"
    echo -e "${YELLOW}   낮은 버전에서는 PreToolUse hook만 사용됩니다.${NC}"
    echo
    echo "다음 단계:"
    echo "1. CLAUDE.md 파일 생성:"
    echo "   - 전역: ~/.claude/CLAUDE.md"
    echo "   - 프로젝트별: <프로젝트루트>/CLAUDE.md"
    echo
    
    if [[ "$mode" == "history" || "$mode" == "advanced" ]]; then
        echo "2. 대화 기록 관리:"
        echo "   $INSTALL_DIR/src/monitor/claude_history_manager.sh --help"
        echo
    fi
    
    if [[ "$mode" == "advanced" ]]; then
        echo "3. Gemini API 설정:"
        echo "   export GEMINI_API_KEY=<your-api-key>"
        echo
    fi
    
    echo "4. Claude Code 재시작"
    echo
    echo "제거: $INSTALL_DIR/uninstall.sh"
}

# 메인 실행
main() {
    print_header
    
    # 모드 선택
    MODE=$(select_mode)
    echo
    echo -e "${BLUE}선택한 모드: $MODE${NC}"
    echo
    
    # 의존성 확인
    check_dependencies "$MODE"
    
    # 백업 생성
    create_backup
    
    # 설치 진행
    install_files
    create_config "$MODE"
    create_directories "$MODE"
    update_claude_config
    create_management_scripts
    
    # 완료 메시지
    print_usage "$MODE"
}

# 스크립트 실행
main "$@"