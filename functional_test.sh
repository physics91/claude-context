#!/usr/bin/env bash

echo "=== Claude Context 기능 테스트 ==="
echo

# 테스트 환경 설정
TEST_HOME="/tmp/claude_test_$$"
export HOME="$TEST_HOME"
export CLAUDE_HOME="$TEST_HOME/.claude"
export CLAUDE_CONTEXT_MODE="basic"

# 테스트 디렉토리 생성
mkdir -p "$CLAUDE_HOME"
echo "# Test CLAUDE.md Content" > "$CLAUDE_HOME/CLAUDE.md"
echo "This is a test file for Claude Context." >> "$CLAUDE_HOME/CLAUDE.md"

echo "1. 테스트 환경 설정:"
echo "  ✓ 테스트 홈 디렉토리: $TEST_HOME"
echo "  ✓ Claude 홈 디렉토리: $CLAUDE_HOME"
echo

# 2. Injector 테스트
echo "2. Injector 기능 테스트:"
if OUTPUT=$(bash core/injector.sh 2>/dev/null); then
    if echo "$OUTPUT" | grep -q "Test CLAUDE.md Content"; then
        echo "  ✓ Injector 실행 성공 - CLAUDE.md 내용 포함됨"
    else
        echo "  ⚠ Injector 실행됨 - CLAUDE.md 내용 확인 필요"
        echo "    출력 미리보기: $(echo "$OUTPUT" | head -1)"
    fi
else
    echo "  ✗ Injector 실행 실패"
fi

# 3. Precompact 테스트
echo
echo "3. Precompact 기능 테스트:"
if OUTPUT=$(bash core/precompact.sh 2>/dev/null); then
    echo "  ✓ Precompact 실행 성공"
    if [[ -n "$OUTPUT" ]]; then
        echo "    출력 길이: $(echo "$OUTPUT" | wc -c) 문자"
    fi
else
    echo "  ✗ Precompact 실행 실패"
fi

# 4. 메인 스크립트 테스트
echo
echo "4. 메인 스크립트 테스트:"
if OUTPUT=$(bash claude_context_injector.sh 2>/dev/null); then
    echo "  ✓ claude_context_injector.sh 실행 성공"
else
    echo "  ✗ claude_context_injector.sh 실행 실패"
fi

if OUTPUT=$(bash claude_context_precompact.sh 2>/dev/null); then
    echo "  ✓ claude_context_precompact.sh 실행 성공"
else
    echo "  ✗ claude_context_precompact.sh 실행 실패"
fi

# 5. 설정 파일 테스트
echo
echo "5. 설정 파일 테스트:"
if [[ -f "config.sh" ]]; then
    if bash -n config.sh 2>/dev/null; then
        echo "  ✓ config.sh 구문 정상"
    else
        echo "  ✗ config.sh 구문 오류"
    fi
else
    echo "  ⚠ config.sh 파일 없음"
fi

# 정리
echo
echo "6. 정리:"
rm -rf "$TEST_HOME" 2>/dev/null || true
echo "  ✓ 테스트 환경 정리 완료"

echo
echo "=== 기능 테스트 완료 ==="
