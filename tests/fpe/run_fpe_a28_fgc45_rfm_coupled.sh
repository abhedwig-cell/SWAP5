#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${A28_BUILD_DIR:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-a28-fd-$$}"
EVIDENCE="${A28_EVIDENCE_DIR:-$BUILD/evidence}"
mkdir -p "$BUILD" "$EVIDENCE"
export PYTHONDONTWRITEBYTECODE=1
python3 tests/fpe/build_fpe_a28_coupled_local.py "$BUILD" > "$EVIDENCE/build.log" 2>&1
export FGC45_MULTISWAP_LIB="$BUILD/libfgc45_multiswap.so"
if [[ -z "${LIBMF6:-}" ]]; then
 mkdir -p "$BUILD/modflow-bin" "$BUILD/downloads"
 python3 - "$BUILD" <<'PY'
from pathlib import Path
from flopy.utils.get_modflow import run_main
import sys,hashlib
p=Path(sys.argv[1])
run_main(p/'modflow-bin',owner='MODFLOW-ORG',repo='modflow6',release_id='6.8.0',subset={'mf6','libmf6.so'},downloads_dir=p/'downloads',force=True)
a=p/'downloads/modflow6-6.8.0-linux.zip'
assert hashlib.sha256(a.read_bytes()).hexdigest()=='33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e'
PY
 export LIBMF6="$BUILD/modflow-bin/libmf6.so"
fi
for mode in exact a28; do
 python3 tests/fpe/test_fpe_a28_coupled_local.py "$mode" > "$EVIDENCE/$mode-correctness.log" 2>&1
 grep -Fq 'FGC45_REAL_MULTISWAP_MODFLOW_END_TO_END=PASS' "$EVIDENCE/$mode-correctness.log"
done
python3 tests/fpe/compare_fpe_a28_coupled.py "$EVIDENCE/exact-correctness.log" "$EVIDENCE/a28-correctness.log" > "$EVIDENCE/near-equilibrium-comparison.json"
# Stop at the exact blocker; never run A28 against an unqualified exact fixture.
for mode in exact a28; do
 A28_RESULT="$EVIDENCE/$mode-windows.json" python3 tests/fpe/test_fpe_a28_coupled_windows.py "$mode" "${A28_WINDOWS:-64}" > "$EVIDENCE/$mode-windows.log" 2>&1
done
python3 tests/fpe/compare_fpe_a28_coupled.py "$EVIDENCE/exact-windows.json" "$EVIDENCE/a28-windows.json" > "$EVIDENCE/windows-comparison.json"
echo "A28_COUPLED_QUALIFICATION=PASS evidence=$EVIDENCE"
