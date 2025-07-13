#!/usr/bin/env bash
set -euo pipefail

# Claude Code Hooks 설정 업데이트 스크립트 (토큰 모니터링 포함)
# 사용자가 선택할 수 있는 옵션 제공

# --- 설정 ---
INSTALL_DIR="$HOME/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

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
    
    return 1
}

# 메인 로직
main() {
    info "Claude Code Hooks 설정 업데이트"
    echo
    
    # 설정 파일 찾기
    if ! SETTINGS_FILE=$(find_claude_settings); then
        error "Claude 설정 파일을 찾을 수 없습니다."
    fi
    
    # 백업
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.backup.$(date +%s)"
    info "설정 백업 완료"
    
    # 옵션 선택
    echo "사용할 기능을 선택하세요:"
    echo "1) 기본 CLAUDE.md 주입 (PreToolUse + PreCompact)"
    echo "2) 토큰 모니터링 포함 (대화 추적 + 자동 요약)"
    echo "3) 기존 설정 유지"
    echo
    
    read -p "선택 (1-3): " choice
    
    case "$choice" in
        1)
            info "기본 설정 적용 중..."
            jq --arg pretool "$INSTALL_DIR/claude_md_injector.sh" \
               --arg precompact "$INSTALL_DIR/claude_md_precompact.sh" '
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
            ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            success "기본 설정이 적용되었습니다."
            ;;
            
        2)
            info "토큰 모니터링 포함 설정 적용 중..."
            
            # 필수 디렉토리 생성
            mkdir -p "$HOME/.claude/history" "$HOME/.claude/summaries"
            
            # gemini 확인
            if ! command -v gemini &>/dev/null; then
                warning "gemini가 설치되어 있지 않습니다. 자동 요약 기능이 제한됩니다."
                echo "계속하시겠습니까? (y/N): "
                read -r response
                [[ ! "$response" =~ ^[Yy]$ ]] && exit 1
            fi
            
            jq --arg pretool "$INSTALL_DIR/claude_md_injector_with_monitor.sh" \
               --arg precompact "$INSTALL_DIR/claude_md_enhanced_precompact.sh" '
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
            ' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
            success "토큰 모니터링 포함 설정이 적용되었습니다."
            
            info "추가 정보:"
            echo "  - 대화 기록: ~/.claude/history/"
            echo "  - 요약 저장: ~/.claude/summaries/"
            echo "  - 30개 메시지마다 자동 요약"
            echo
            info "정리 명령: $INSTALL_DIR/claude_token_monitor_safe.sh cleanup"
            ;;
            
        3)
            info "기존 설정을 유지합니다."
            ;;
            
        *)
            warning "잘못된 선택입니다."
            exit 1
            ;;
    esac
    
    echo
    success "설정 업데이트 완료!"
    info "Claude Code를 재시작하면 변경사항이 적용됩니다."
}

main "$@"