#!/usr/bin/env bash
set -euo pipefail
B=build/gc-rootzone-memory-rzm04
rm -rf "$B"; mkdir -p "$B"
python3 tests/research/test_gc_rootzone_memory_rzm04.py | tee "$B/rzm04.txt"
grep -Fq 'GC_RZM04_TESTS=7/7' "$B/rzm04.txt"
grep -Fq 'GC_RZM04_GATE=PASS' "$B/rzm04.txt"
echo 'GC_ROOTZONE_MEMORY_RZM04_EXECUTION=PASS'
