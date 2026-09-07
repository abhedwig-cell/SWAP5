#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fci08-gate-$$"
trap 'rm -rf "$BUILD"' EXIT
mkdir -p "$BUILD/o0" "$BUILD/o2"

SRC="$ROOT/src/transaction/mod_transaction_reference.f90"
TEST="$ROOT/tests/transaction/test_transaction_attempt_context.f90"

python - "$SRC" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(); low=s.lower()
checks={
 'attempt_context_type':'type, public :: transaction_attempt_context_t' in low,
 'model_capture_hook':'procedure :: capture_attempt_context' in low,
 'model_restore_hook':'procedure :: restore_attempt_context' in low,
 'checkpoint_context':'checkpoint_context' in low,
 'restore_before_full':'call model%restore_attempt_context(checkpoint_context)' in low,
 'capture_half_context':'call model%capture_attempt_context(half_context)' in low,
 'context_not_state_extension':not re.search(r'type[^\n]*extends\(transaction_state_t\)[^\n]*transaction_attempt_context',low),
}
failed=[k for k,v in checks.items() if not v]
print({'work_unit':'F-CI08','checks':checks,'failed':failed})
if failed: raise SystemExit(2)
PY

for opt in 0 2; do
  O="$BUILD/o$opt"
  FLAGS=(-O$opt -std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffree-line-length-none -J "$O" -I "$O")
  gfortran "${FLAGS[@]}" "$SRC" "$TEST" -o "$O/test_context"
  "$O/test_context" > "$O/gate.log"
  grep -q 'FCI08_TRANSACTION_ATTEMPT_CONTEXT PASS' "$O/gate.log"
done
cmp "$BUILD/o0/gate.log" "$BUILD/o2/gate.log"
echo FCI08_GATE_PASS
