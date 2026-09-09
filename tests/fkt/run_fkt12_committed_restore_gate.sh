#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt12-restore-$$"
mkdir -p "$BUILD/o0" "$BUILD/o2"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

# Preserve the reusable checkpoint/provenance boundary that F-KT12 extends.
bash tests/fkt/run_fkt05_gate.sh

DONOR=tests/fkt/test_fkt05_reusable_checkpoint.f90
EXPECTED_DONOR_BLOB=1e476c3492044fe3b87118fc84e079e9574a3d92
ACTUAL_DONOR_BLOB="$(git hash-object "$DONOR")"
if [[ "$ACTUAL_DONOR_BLOB" != "$EXPECTED_DONOR_BLOB" ]]; then
  echo "F-KT12 donor drift: expected $EXPECTED_DONOR_BLOB got $ACTUAL_DONOR_BLOB" >&2
  exit 1
fi

python3 - "$DONOR" "$BUILD/mod_fkt05_test_model.f90" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1]).read_text(encoding='utf-8')
marker = '\nprogram test_fkt05_reusable_checkpoint\n'
if src.count(marker) != 1:
    raise SystemExit(f'F-KT12 model extraction anchor count={src.count(marker)}')
Path(sys.argv[2]).write_text(src.split(marker, 1)[0] + '\n', encoding='utf-8')
PY

COMMON=(-std=f2008 -Wall -Wextra -Werror -fcheck=all -fbacktrace -fopenmp)
SOURCES=(
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/kernel/mod_kernel_committed_persistence.f90
  "$BUILD/mod_fkt05_test_model.f90"
  tests/fkt/test_fkt12_committed_restore.f90
)

for OPT in o0 o2; do
  FLAG=-O0
  [[ "$OPT" == o2 ]] && FLAG=-O2
  gfortran "${COMMON[@]}" "$FLAG" -J "$BUILD/$OPT" "${SOURCES[@]}" -o "$BUILD/test_$OPT"
  "$BUILD/test_$OPT" > "$BUILD/output_$OPT.txt"
done

cmp "$BUILD/output_o0.txt" "$BUILD/output_o2.txt"
cat "$BUILD/output_o0.txt"

for marker in \
  'FKT12_EXPORT_RESTORE_PHYSICAL_LINEAGE_REVISION_TIME_EXACT=PASS' \
  'FKT12_RESTORE_ZERO_PHYSICAL_TRANSFER=PASS' \
  'FKT12_PRE_RESTART_STALE_PROVENANCE_REMAINS_REJECTED=PASS' \
  'FKT12_EXACT_SPLIT_RUN_ENDPOINT_IDENTITY=PASS' \
  'FKT12_REVISION_AND_LINEAGE_CONTINUATION=PASS' \
  'FKT12_MASS_CONTINUATION_WITHOUT_LEDGER_RESET=PASS' \
  'FKT12_REQUEST_BASE_IMMUTABILITY=PASS' \
  'FKT12_INVALID_SCHEMA_LAYOUT_TARGET_FAIL_CLOSED=PASS' \
  'FKT12_COMMITTED_RESTORE_GATE PASS'; do
  grep -Fq "$marker" "$BUILD/output_o0.txt" || { cat "$BUILD/output_o0.txt" >&2; exit 1; }
done

echo 'FKT12_O0_O2_OUTPUT_IDENTITY=PASS'
echo 'FKT12_COMMITTED_BOUNDARY_RESTORE_QUALIFICATION_GATE PASS'
