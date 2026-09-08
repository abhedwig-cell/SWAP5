#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ORIGINAL_RUNNER="$ROOT/tests/fci/run_fci14_gate.sh"
ORIGINAL_GATE="$ROOT/tools/fci/fci14_reference_temporal_policy_gate.py"
TX="$ROOT/src/transaction/mod_transaction_reference.f90"
EXPECTED_RUNNER_BLOB="552211f48d98404d23ef6d1d50ecf25d6676aaae"
EXPECTED_GATE_BLOB="f52e3134ef94908d45193f7d50ea9d1721dd2846"
HISTORICAL_TX_BLOB="4a573316b77252b56bcb429fd519aa57123e9a06"
F_KT08_TX_BLOB="b1878606ae6cb2b04a7b4b15e3e537deacf4477f"

runner_blob="$(git hash-object "$ORIGINAL_RUNNER")"
gate_blob="$(git hash-object "$ORIGINAL_GATE")"
tx_blob="$(git hash-object "$TX")"
if [[ "$runner_blob" != "$EXPECTED_RUNNER_BLOB" ]]; then
  echo "F-KT08 F-CI14 runner provenance mismatch: $runner_blob != $EXPECTED_RUNNER_BLOB" >&2
  exit 2
fi
if [[ "$gate_blob" != "$EXPECTED_GATE_BLOB" ]]; then
  echo "F-KT08 F-CI14 static-gate provenance mismatch: $gate_blob != $EXPECTED_GATE_BLOB" >&2
  exit 3
fi
if [[ "$tx_blob" != "$F_KT08_TX_BLOB" ]]; then
  echo "F-KT08 transaction provenance mismatch: $tx_blob != $F_KT08_TX_BLOB" >&2
  exit 4
fi

TMP_GATE="$ROOT/tools/fci/.fkt08-forward-fci14-gate-$$.py"
TMP_RUNNER="$ROOT/tests/fci/.fkt08-forward-fci14-$$.sh"
trap 'rm -f "$TMP_GATE" "$TMP_RUNNER"' EXIT
python3 - "$ORIGINAL_GATE" "$TMP_GATE" "$HISTORICAL_TX_BLOB" "$F_KT08_TX_BLOB" <<'PY'
from pathlib import Path
import sys
src, dst, old, new = sys.argv[1:]
text = Path(src).read_text()
if text.count(old) != 1:
    raise SystemExit('F-KT08 expected exactly one historical F-CI14 transaction provenance pin')
Path(dst).write_text(text.replace(old, new, 1))
PY
python3 - "$ORIGINAL_RUNNER" "$TMP_RUNNER" "$(basename "$ORIGINAL_GATE")" "$(basename "$TMP_GATE")" <<'PY'
from pathlib import Path
import sys
src, dst, old, new = sys.argv[1:]
text = Path(src).read_text()
if text.count(old) != 1:
    raise SystemExit('F-KT08 expected exactly one F-CI14 static-gate invocation')
Path(dst).write_text(text.replace(old, new, 1))
PY
chmod +x "$TMP_RUNNER"

# Execute unchanged F-CI14 policy and O0/O2 executable semantics while
# substituting only the explicitly evolved F-KT08 transaction source pin.
bash "$TMP_RUNNER"
echo FKT08_FCI14_FORWARD_REGRESSION_PASS
