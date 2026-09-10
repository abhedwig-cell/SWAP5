#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/tests/fmr/run_fmr27_parallel_current_canonical_gate.sh"
TMP="$ROOT/tests/fmr/.fmr27-owner-v2-$$.sh"
trap 'rm -f "$TMP"' EXIT
cp "$SOURCE" "$TMP"

python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
replacements = {
    'CANDIDATE=d9085be7bd14f4aae8aa6e9ce1731c61bbf45e7a':
        'CANDIDATE=151ad84b9ebb3bbb133fa0bf77f67797a3d5547e',
    'POST_SRC=7d990c6e3fcb596f33a9528be8ff45224e72f356':
        'POST_SRC=6120672c3caaa640f902fdc20b43ae6ba722f38b',
    'RUNTIME_BLOB=1540203a2e9007586f1015dfaec6a5859c31dfe0':
        'RUNTIME_BLOB=7bfb4a269256f0f1d50c32a20fd42479cf033528',
    "trap 'rm -rf \"$BUILD\"; rm -f \"$ROOT/tests/fmr/.fmr27-fmr18-replay-$$.sh\" \"$ROOT/tests/fci/.fmr27-fci28-replay-$$.sh' EXIT":
        "trap 'rm -rf \"$BUILD\"; rm -f \"$ROOT/tests/fmr/.fmr27-fmr18-replay-$$.sh\" \"$ROOT/tests/fci/.fmr27-fci28-replay-$$.sh\"' EXIT",
}
for old, new in replacements.items():
    if old not in s:
        raise SystemExit(f'F-MR27 V2 missing rebind anchor: {old}')
    s = s.replace(old, new, 1)

needle = "echo 'FMR27_FROZEN_PARALLEL_ATTACK_BLOBS=PASS'\n"
assert needle in s
s = s.replace(needle, needle + "echo 'FMR27_ATOMIC_OVERLAP_REMEDIATION_REBOUND=PASS'\n", 1)

# Patch only the historical F-MR18 MODULE_SRC block in its disposable replay.
# Other transaction-reference occurrences belong to downstream replay sections
# and must remain untouched.
inner_anchor = "needle='cat \"$BUILD/o0/out.txt\"\\n'\n"
inner_patch = """old_history=('MODULE_SRC=(\\n'\n             '  \"$BUILD/fsi04_real_headcalc_stubs.f90\"\\n'\n             '  src/runtime/mod_a23bu_worker_execution_context.f90\\n'\n             '  src/transaction/mod_transaction_reference.f90\\n'\n             '  src/runtime/mod_canonical_contracts.f90')\nnew_history=('MODULE_SRC=(\\n'\n             '  \"$BUILD/fsi04_real_headcalc_stubs.f90\"\\n'\n             '  src/runtime/mod_a23bu_worker_execution_context.f90\\n'\n             '  src/transaction/mod_transaction_reference.f90\\n'\n             '  src/transaction/mod_fkt_temporal_indicator_history.f90\\n'\n             '  src/runtime/mod_canonical_contracts.f90')\nif old_history not in s:\n    raise SystemExit('F-MR27 F-MR18 MODULE_SRC history anchor missing')\ns=s.replace(old_history,new_history,1)\nold_solver=('  src/solver/mod_b110_source_sink_provider.f90\\n'\n            '  src/legacy/b1_10_port/headcalc.f90\\n'\n            '  src/adapter/mod_reference_richards_legacy_binding.f90')\nnew_solver=('  src/solver/mod_b110_source_sink_provider.f90\\n'\n            '  src/legacy/b1_10_port/headcalc.f90\\n'\n            '  src/solver/mod_fixed_flux_top_boundary_provider.f90\\n'\n            '  src/solver/mod_reference_richards_temporal_indicator.f90\\n'\n            '  src/adapter/mod_reference_richards_legacy_binding.f90')\nif old_solver not in s:\n    raise SystemExit('F-MR27 F-MR18 MODULE_SRC solver anchor missing')\ns=s.replace(old_solver,new_solver,1)\nprint('FMR27_FMR18_CURRENT_RUNTIME_DEPENDENCIES_REBOUND=PASS')\n"""
if inner_anchor not in s:
    raise SystemExit('F-MR27 V2 missing inner F-MR18 replay anchor')
s = s.replace(inner_anchor, inner_patch + inner_anchor, 1)

p.write_text(s, encoding='utf-8')
PY

bash "$TMP"
