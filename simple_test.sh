#!/usr/bin/env bash

echo "=== Claude Context 기본 테스트 ==="
echo

# 1. 스크립트 파일 존재 확인
echo "1. 스크립트 파일 확인:"
for script in "core/injector.sh" "core/precompact.sh" "claude_context_injector.sh" "claude_context_precompact.sh"; do
    if [[ -f "$script" ]]; then
        echo "  ✓ $script 존재"
    else
        echo "  ✗ $script 없음"
    fi
done
echo

# 2. 스크립트 실행 권한 확인
echo "2. 실행 권한 확인:"
for script in "core/injector.sh" "core/precompact.sh"; do
    if [[ -x "$script" ]]; then
        echo "  ✓ $script 실행 가능"
    else
        echo "  ✗ $script 실행 불가"
    fi
done
echo

# 3. 기본 구문 검사
echo "3. 구문 검사:"
for script in "core/injector.sh" "core/precompact.sh"; do
    if bash -n "$script" 2>/dev/null; then
        echo "  ✓ $script 구문 정상"
    else
        echo "  ✗ $script 구문 오류"
    fi
done
echo

# 4. 기본 환경 변수 테스트
echo "4. 환경 변수 테스트:"
export CLAUDE_CONTEXT_MODE="basic"
export HOME="${HOME:-/tmp/test_home}"
mkdir -p "$HOME/.claude" 2>/dev/null || true
echo "# Test Content" > "$HOME/.claude/CLAUDE.md" 2>/dev/null || true

if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    echo "  ✓ 테스트 파일 생성 성공"
else
    echo "  ✗ 테스트 파일 생성 실패"
fi

echo
echo "=== 테스트 완료 ==="
