#!/usr/bin/env bash
set -euo pipefail

BUILD="build/gc-rootzone-memory-rzm01"
rm -rf "$BUILD"
mkdir -p "$BUILD"

python3 tests/research/test_gc_rootzone_memory_rzm01.py | tee "$BUILD/rzm01.txt"

grep -Fq 'GC_RZM01_GATE=PASS' "$BUILD/rzm01.txt"
grep -Fq 'GC_RZM01_TESTS=12/12' "$BUILD/rzm01.txt"

echo 'GC_ROOTZONE_MEMORY_RZM01_EXECUTION=PASS'
