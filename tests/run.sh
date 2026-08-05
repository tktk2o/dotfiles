#!/bin/bash
# Test runner for tests/*_test.sh — the invariant checks for this repo.
#
# Deliberately simple: no framework, no parallelism. Each *_test.sh is a
# standalone script that prints its own pass/fail lines and exits non-zero on
# any failure. This script just runs them all, tallies exit codes, and
# reports a summary. That is enough for a dotfiles repo with a handful of
# tests; anything fancier would be more code than the thing it tests.
#
# Usage: tests/run.sh (from anywhere; resolves paths relative to this file)

set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$TESTS_DIR/.." || exit 1

total=0
failed=0
failed_names=()

for test_file in "$TESTS_DIR"/*_test.sh; do
    [ -e "$test_file" ] || continue
    total=$((total + 1))
    name="$(basename "$test_file")"
    echo "=== $name ==="
    if bash "$test_file"; then
        echo "--- $name: PASS ---"
    else
        echo "--- $name: FAIL ---"
        failed=$((failed + 1))
        failed_names+=("$name")
    fi
    echo ""
done

echo "============================================"
echo "  $((total - failed))/$total tests passed"
if [ "$failed" -gt 0 ]; then
    echo "  Failed: ${failed_names[*]}"
fi
echo "============================================"

exit "$failed"
