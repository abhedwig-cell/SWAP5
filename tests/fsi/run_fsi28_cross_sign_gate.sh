#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BASE_RUNNER="$ROOT/tests/fsi/run_fsi28_interface_sensitivity_gate.sh"
TMP_RUNNER="$ROOT/tests/fsi/.fsi28_cross_sign_gate_$$.sh"
trap 'rm -f "$TMP_RUNNER"' EXIT

[[ -f "$BASE_RUNNER" ]] || { echo 'FSI28_CROSS_SIGN_FAIL base runner missing' >&2; exit 1; }
cp "$BASE_RUNNER" "$TMP_RUNNER"

python3 - "$TMP_RUNNER" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
anchor = "  call check_fsi28_tangent(qeq, 1.01_real64*qeq, 'symmetric-neighbor')\n"
insert = anchor + "  ! Frozen-contract cross-sign probes. Keep the F-SI27 top forcing and\n" \
    + "  ! cross qbot=0 by the smallest predeclared 1% qeq-scale companion.\n" \
    + "  ! These establish native-qbot sign coverage only; they do not widen the\n" \
    + "  ! qualified forcing envelope beyond the explicitly tested points.\n" \
    + "  call check_fsi28_tangent(qeq, 0.0_real64, 'zero-qbot')\n" \
    + "  call check_fsi28_tangent(qeq, -0.01_real64*qeq, 'positive-qbot-minimal')\n"
if s.count(anchor) != 1:
    raise SystemExit('FSI28_CROSS_SIGN_TRANSFORM_FAIL tangent insertion anchor mismatch')
s = s.replace(anchor, insert, 1)
old = "[[ \"$(grep -c '^FSI28_TANGENT:' \"$out/output.txt\")\" == 3 ]] || fail \"O${opt} expected three tangent cases\""
new = "[[ \"$(grep -c '^FSI28_TANGENT:' \"$out/output.txt\")\" == 5 ]] || fail \"O${opt} expected five tangent cases\""
if s.count(old) != 1:
    raise SystemExit('FSI28_CROSS_SIGN_TRANSFORM_FAIL tangent-count anchor mismatch')
s = s.replace(old, new, 1)
p.write_text(s)
PY

bash "$TMP_RUNNER"
echo 'FSI28_CROSS_SIGN_GATE PASS'
