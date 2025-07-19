#!/usr/bin/env bash

echo "=== Claude Context 설치 스크립트 테스트 ==="
echo

# 1. 설치 스크립트 파일 확인
echo "1. 설치 스크립트 파일 확인:"
for script in "install/install.sh" "install/configure_hooks.sh" "install/one-line-install.sh"; do
    if [[ -f "$script" ]]; then
        echo "  ✓ $script 존재"
    else
        echo "  ✗ $script 없음"
    fi
done
echo

# 2. PowerShell 스크립트 파일 확인
echo "2. PowerShell 스크립트 파일 확인:"
for script in "install/install.ps1" "install/configure_hooks.ps1" "install/one-line-install.ps1" "install/claude_context_native.ps1" "install/uninstall.ps1"; do
    if [[ -f "$script" ]]; then
        echo "  ✓ $script 존재"
    else
        echo "  ✗ $script 없음"
    fi
done
echo

# 3. Bash 설치 스크립트 구문 검사
echo "3. Bash 설치 스크립트 구문 검사:"
for script in "install/install.sh" "install/configure_hooks.sh" "install/one-line-install.sh"; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            echo "  ✓ $script 구문 정상"
        else
            echo "  ✗ $script 구문 오류"
        fi
    fi
done
echo

# 4. 언인스톨 스크립트 확인
echo "4. 언인스톨 스크립트 확인:"
if [[ -f "uninstall.sh" ]]; then
    if bash -n "uninstall.sh" 2>/dev/null; then
        echo "  ✓ uninstall.sh 구문 정상"
    else
        echo "  ✗ uninstall.sh 구문 오류"
    fi
else
    echo "  ✗ uninstall.sh 없음"
fi
echo

# 5. 모니터링 스크립트 확인
echo "5. 모니터링 스크립트 확인:"
for script in "monitor/claude_history_manager.sh" "monitor/claude_token_monitor_claude.sh" "monitor/claude_token_monitor_oauth.sh" "monitor/claude_token_monitor_safe.sh"; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            echo "  ✓ $script 구문 정상"
        else
            echo "  ✗ $script 구문 오류"
        fi
    else
        echo "  ✗ $script 없음"
    fi
done
echo

# 6. 유틸리티 스크립트 확인
echo "6. 유틸리티 스크립트 확인:"
if [[ -f "utils/common_functions.sh" ]]; then
    if bash -n "utils/common_functions.sh" 2>/dev/null; then
        echo "  ✓ utils/common_functions.sh 구문 정상"
    else
        echo "  ✗ utils/common_functions.sh 구문 오류"
    fi
else
    echo "  ✗ utils/common_functions.sh 없음"
fi

echo
echo "=== 설치 스크립트 테스트 완료 ==="
