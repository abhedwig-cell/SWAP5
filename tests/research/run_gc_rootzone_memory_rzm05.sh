#!/usr/bin/env bash
set -euo pipefail
B=build/gc-rootzone-memory-rzm05; rm -rf "$B"; mkdir -p "$B"
python3 tests/research/test_gc_rootzone_memory_rzm05.py | tee "$B/rzm05.txt"
grep -Fq 'GC_RZM05_TESTS=9/9' "$B/rzm05.txt"
grep -Fq 'GC_RZM05_GATE=PASS' "$B/rzm05.txt"
echo 'GC_ROOTZONE_MEMORY_RZM05_EXECUTION=PASS'
