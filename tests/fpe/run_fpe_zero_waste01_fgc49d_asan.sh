#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

TMP_RUNNER="tests/fgc/.run_fgc49d_asan_$$.sh"
trap 'rm -f "$TMP_RUNNER"' EXIT

python3 - <<'PY'
from pathlib import Path
src = Path("tests/fgc/run_fgc49d_production_application_context.sh").read_text(encoding="utf-8")
needle = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)'
replacement = 'COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fPIC -fopenmp -fcheck=all -fbacktrace -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer)'
if needle not in src:
    raise SystemExit("FGC49D ASAN runner: compiler flag anchor not found")
src = src.replace(needle, replacement, 1)
src = src.replace('gfortran -shared -fopenmp -O"$opt" "${objects[@]}" -o "$OUT/libfgc49d_application.so"',
                  'gfortran -shared -fopenmp -g -O0 -fsanitize=address,undefined -fno-omit-frame-pointer "${objects[@]}" -o "$OUT/libfgc49d_application.so"')
src = src.replace('for opt in 0 2; do', 'for opt in 2; do', 1)
src = src.replace('diff -u "$BUILD/o0/stable.txt" "$BUILD/o2/stable.txt"', 'true # ASAN single-build diagnostic')
src = src.replace("echo 'FGC49D_CONTEXT_O0_O2_OUTPUT_IDENTITY=PASS'", "echo 'FGC49D_ASAN_O2_SINGLE_BUILD=PASS'")
Path("tests/fgc/.run_fgc49d_asan_PLACEHOLDER.sh").write_text(src, encoding="utf-8")
PY
mv tests/fgc/.run_fgc49d_asan_PLACEHOLDER.sh "$TMP_RUNNER"
chmod +x "$TMP_RUNNER"

ASAN_LIB="$(gcc -print-file-name=libasan.so)"
if [[ ! -f "$ASAN_LIB" ]]; then
  echo "FGC49D_ASAN_FAIL libasan not found: $ASAN_LIB" >&2
  exit 1
fi
export LD_PRELOAD="$ASAN_LIB${LD_PRELOAD:+:$LD_PRELOAD}"
export ASAN_OPTIONS="detect_leaks=0:abort_on_error=1:symbolize=1:fast_unwind_on_malloc=0"
export UBSAN_OPTIONS="print_stacktrace=1:halt_on_error=1"
echo "FGC49D_ASAN_PRELOAD=$ASAN_LIB"
bash "$TMP_RUNNER"
