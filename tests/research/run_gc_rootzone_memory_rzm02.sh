#!/usr/bin/env bash
set -euo pipefail

BUILD="build/gc-rootzone-memory-rzm02"
rm -rf "$BUILD"
mkdir -p "$BUILD"

python3 tests/research/test_gc_rootzone_memory_rzm02.py | tee "$BUILD/rzm02.txt"

grep -Fq 'GC_RZM02_TESTS=7/7' "$BUILD/rzm02.txt"
grep -Fq 'GC_RZM02_GATE=PASS' "$BUILD/rzm02.txt"

echo 'GC_ROOTZONE_MEMORY_RZM02_EXECUTION=PASS'
