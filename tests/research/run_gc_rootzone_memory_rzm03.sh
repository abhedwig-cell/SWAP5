#!/usr/bin/env bash
set -euo pipefail
BUILD="build/gc-rootzone-memory-rzm03"
rm -rf "$BUILD"; mkdir -p "$BUILD"
python3 tests/research/test_gc_rootzone_memory_rzm03.py | tee "$BUILD/rzm03.txt"
grep -Fq 'GC_RZM03_TESTS=7/7' "$BUILD/rzm03.txt"
grep -Fq 'GC_RZM03_GATE=PASS' "$BUILD/rzm03.txt"
echo 'GC_ROOTZONE_MEMORY_RZM03_EXECUTION=PASS'
