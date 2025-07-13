#!/usr/bin/env bash
set -euo pipefail

# Claude Context v2 전체 테스트 실행 스크립트

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔════════════════════════════════════════╗"
echo "║     Claude Context 전체 테스트         ║"
echo "╚════════════════════════════════════════╝"
echo

# 테스트 스위트 실행
exec "$TESTS_DIR/test_suite.sh"