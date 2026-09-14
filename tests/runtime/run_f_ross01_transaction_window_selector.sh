#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/f-ross01-window-selector"
rm -rf "$WORK"
mkdir -p "$WORK"

build_and_run() {
  local opt="$1"
  local tag="$2"
  local dir="$WORK/$tag"
  mkdir -p "$dir"
  cd "$dir"

  gfortran -std=f2018 -Wall -Wextra -Werror -Wno-error=compare-reals "$opt" -c \
    "$ROOT/src/transaction/mod_transaction_reference.f90"
  gfortran -std=f2018 -Wall -Wextra -Werror "$opt" -I. -c \
    "$ROOT/src/runtime/mod_canonical_contracts.f90"
  gfortran -std=f2018 -Wall -Wextra -Werror -Wno-error=compare-reals "$opt" -I. -c \
    "$ROOT/src/runtime/mod_canonical_interval_runtime.f90"
  gfortran -std=f2018 -Wall -Wextra -Werror "$opt" -I. -c \
    "$ROOT/tests/runtime/test_f_ross01_transaction_window_selector.f90"
  gfortran "$opt" -o test_window_selector \
    mod_transaction_reference.o mod_canonical_contracts.o mod_canonical_interval_runtime.o \
    test_f_ross01_transaction_window_selector.o
  ./test_window_selector > "$WORK/$tag.out"
}

build_and_run -O0 O0
build_and_run -O2 O2
cmp "$WORK/O0.out" "$WORK/O2.out"
grep -qx 'F-ROSS01 transaction-window selector: PASS' "$WORK/O0.out"
sha256sum "$WORK/O0.out"
cat "$WORK/O0.out"
