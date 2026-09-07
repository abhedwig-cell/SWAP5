#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL="$ROOT/tests/fci/run_fci09_gate.sh"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
EXPECTED_RUNNER_BLOB="4811a4653cb98d9d9c3630ed303c2fe0cc8975f7"
HISTORICAL_PROCESS_BLOB="4084f979d86e0a97d2b7b570af38ad44d85dca6c"
F_KT07_PROCESS_BLOB="bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae"

runner_blob="$(git hash-object "$ORIGINAL")"
process_blob="$(git hash-object "$PROCESS")"
if [[ "$runner_blob" != "$EXPECTED_RUNNER_BLOB" ]]; then
  echo "F-KT07 F-CI09 runner provenance mismatch: $runner_blob != $EXPECTED_RUNNER_BLOB" >&2
  exit 2
fi
if [[ "$process_blob" != "$F_KT07_PROCESS_BLOB" ]]; then
  echo "F-KT07 process-state provenance mismatch: $process_blob != $F_KT07_PROCESS_BLOB" >&2
  exit 3
fi

TMP="${TMPDIR:-/tmp}/swap5-fkt07-fci09-$$.sh"
trap 'rm -f "$TMP"' EXIT
python3 - "$ORIGINAL" "$TMP" "$HISTORICAL_PROCESS_BLOB" "$F_KT07_PROCESS_BLOB" <<'PY'
from pathlib import Path
import sys
src, dst, old, new = sys.argv[1:]
text = Path(src).read_text()
if text.count(old) != 1:
    raise SystemExit('F-KT07 expected exactly one historical F-CI09 process provenance pin')
text = text.replace(old, new, 1)
Path(dst).write_text(text)
PY
chmod +x "$TMP"

# This executes the exact historical F-CI09 gate logic with one controlled
# provenance substitution: only the legitimately evolved B1.10 process-state blob.
bash "$TMP"
echo FKT07_FCI09_FORWARD_REGRESSION_PASS
