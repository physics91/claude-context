#!/usr/bin/env bash
# CLAUDE.md hook 테스트 스크립트

echo "=== CLAUDE.md Hook Test ==="
echo

# 1. 디버그 모드 테스트
echo "1. Testing with debug payload..."
DEBUG_PAYLOAD='{
  "working_directory": "/home/physics91/test-project",
  "transcript_path": "/tmp/test_transcript.txt"
}'

echo "$DEBUG_PAYLOAD" | /home/physics91/.claude/hooks/claude_md_injector.sh | jq '.' 2>&1

echo
echo "2. Checking log file..."
tail -5 /tmp/claude_md_injector.log

echo
echo "3. Cache status..."
ls -la ~/.cache/claude/md_cache/ | head -5

echo
echo "4. Testing CLAUDE.md detection in different scenarios..."

# 테스트 케이스들
test_scenarios() {
    local test_dir="/tmp/claude_test_$$"
    mkdir -p "$test_dir"
    
    # 시나리오 1: CLAUDE.md 없음
    echo "  - No CLAUDE.md:"
    echo '{"working_directory": "'$test_dir'"}' | \
        /home/physics91/.claude/hooks/claude_md_injector.sh | \
        jq -r '.metadata | "    Global: \(.global_claude_md), Project: \(.project_claude_md)"'
    
    # 시나리오 2: 프로젝트 CLAUDE.md만 있음
    echo "  - Project CLAUDE.md only:"
    echo "# Test Project" > "$test_dir/CLAUDE.md"
    echo '{"working_directory": "'$test_dir'"}' | \
        /home/physics91/.claude/hooks/claude_md_injector.sh | \
        jq -r '.metadata | "    Global: \(.global_claude_md), Project: \(.project_claude_md)"'
    
    # 시나리오 3: Git 저장소
    echo "  - Git repository:"
    cd "$test_dir" && git init -q
    echo '{"working_directory": "'$test_dir'"}' | \
        /home/physics91/.claude/hooks/claude_md_injector.sh | \
        jq -r '.metadata.project_root'
    
    # 정리
    rm -rf "$test_dir"
}

test_scenarios

echo
echo "5. Performance test (10 calls)..."
time for i in {1..10}; do
    echo '{"working_directory": "/home/physics91/.claude/hooks"}' | \
        /home/physics91/.claude/hooks/claude_md_injector.sh >/dev/null 2>&1
done

echo
echo "=== Test Complete ==="