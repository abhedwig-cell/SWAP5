#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL="$ROOT/tests/fci/run_fci09_gate.sh"
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
PROCESS="$ROOT/src/adapter/mod_b1_10_process_checkpoint.f90"
EXPECTED_RUNNER_BLOB="4811a4653cb98d9d9c3630ed303c2fe0cc8975f7"
HISTORICAL_TX_BLOB="4a573316b77252b56bcb429fd519aa57123e9a06"
F_KT08_TX_BLOB="b1878606ae6cb2b04a7b4b15e3e537deacf4477f"
HISTORICAL_PROCESS_BLOB="4084f979d86e0a97d2b7b570af38ad44d85dca6c"
F_KT07_PROCESS_BLOB="bbb9f0fbfdb9624a426d75735e8b93fe3b68b3ae"

runner_blob="$(git hash-object "$ORIGINAL")"
tx_blob="$(git hash-object "$TX")"
process_blob="$(git hash-object "$PROCESS")"
if [[ "$runner_blob" != "$EXPECTED_RUNNER_BLOB" ]]; then
  echo "F-KT08 F-CI09 runner provenance mismatch: $runner_blob != $EXPECTED_RUNNER_BLOB" >&2
  exit 2
fi
if [[ "$tx_blob" != "$F_KT08_TX_BLOB" ]]; then
  echo "F-KT08 transaction provenance mismatch: $tx_blob != $F_KT08_TX_BLOB" >&2
  exit 3
fi
if [[ "$process_blob" != "$F_KT07_PROCESS_BLOB" ]]; then
  echo "F-KT08 process-state provenance mismatch: $process_blob != $F_KT07_PROCESS_BLOB" >&2
  exit 4
fi

TMP="$ROOT/tests/fci/.fkt08-forward-fci09-$$.sh"
trap 'rm -f "$TMP"' EXIT
python3 - "$ORIGINAL" "$TMP" "$HISTORICAL_TX_BLOB" "$F_KT08_TX_BLOB" "$HISTORICAL_PROCESS_BLOB" "$F_KT07_PROCESS_BLOB" <<'PY'
from pathlib import Path
import sys
src, dst, old_tx, new_tx, old_process, new_process = sys.argv[1:]
text = Path(src).read_text()
if text.count(old_tx) != 1:
    raise SystemExit('F-KT08 expected exactly one historical F-CI09 transaction provenance pin')
if text.count(old_process) != 1:
    raise SystemExit('F-KT08 expected exactly one historical F-CI09 process provenance pin')
text = text.replace(old_tx, new_tx, 1)
text = text.replace(old_process, new_process, 1)
Path(dst).write_text(text)
PY
chmod +x "$TMP"

# Execute the exact historical F-CI09 static/executable semantics while
# substituting only the two explicitly qualified evolved source blobs.
bash "$TMP"
echo FKT08_FCI09_FORWARD_REGRESSION_PASS
