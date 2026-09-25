#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-/tmp}/fpe-hdir04-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace)
for opt in 0 2; do
  OUT="$BUILD/o$opt"
  mkdir -p "$OUT"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c     src/solver/mod_soil_water_accepted_step_direction_contract.f90 -o "$OUT/contract.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c     src/transaction/mod_accepted_trajectory_directional_sensitivity.f90 -o "$OUT/sensitivity.o"
  gfortran "${COMMON[@]}" -O"$opt" -J"$OUT" -I"$OUT" -c     tests/fpe/test_fpe_zero_waste01_hdir04_consuming_stage.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "$OUT/contract.o" "$OUT/sensitivity.o" "$OUT/test.o" -o "$OUT/test"
  "$OUT/test" > "$OUT/out.txt"
  grep -Fq 'FPE_ZERO_WASTE01_HDIR04_CONTRACT=PASS' "$OUT/out.txt"
done
diff -u "$BUILD/o0/out.txt" "$BUILD/o2/out.txt"
cat "$BUILD/o0/out.txt"
echo 'FPE_ZERO_WASTE01_HDIR04_O0_O2_IDENTITY=PASS'

PARENT=f3c8e1642310f7303802e23f187d1f4981e39539
SOURCE=tests/fpe/run_fpe_zero_waste01_paired_runtime.sh
TARGET="$BUILD/run_hdir04_paired.sh"
python3 - "$SOURCE" "$TARGET" "$PARENT" "$ROOT" <<'PY'
from pathlib import Path
import sys
source,target,parent,root=sys.argv[1:]
s=Path(source).read_text(encoding='utf-8')
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"',f'ROOT="{root}"',1)
s=s.replace('BASELINE_COMMIT=82d9938976fd92ff3230e7739539e467c3243225',f'BASELINE_COMMIT={parent}')
copy_anchor='src/adapter/mod_reference_richards_accepted_step_directional_service.f90   src/runtime/mod_fmr_serialized_reference_backend.f90; do'
if copy_anchor not in s:
    raise SystemExit('HDIR04 paired copy anchor missing')
s=s.replace(copy_anchor,
    'src/adapter/mod_reference_richards_accepted_step_directional_service.f90   '
    'src/transaction/mod_accepted_trajectory_directional_sensitivity.f90   '
    'src/runtime/mod_fmr_serialized_reference_backend.f90; do',1)
module_anchor='  src/transaction/mod_accepted_trajectory_directional_sensitivity.f90\n'
if module_anchor not in s:
    raise SystemExit('HDIR04 sensitivity module anchor missing')
s=s.replace(module_anchor,'  SENSITIVITY_PLACEHOLDER\n',1)
case_anchor='      LINEAR_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_reference_linear_solver.f90" || source="src/solver/mod_reference_linear_solver.f90" ;;\n'
if case_anchor not in s:
    raise SystemExit('HDIR04 paired case anchor missing')
insert=case_anchor+'      SENSITIVITY_PLACEHOLDER)\n        [[ "$name" == baseline ]] && source="$BUILD/src/mod_accepted_trajectory_directional_sensitivity.f90" || source="src/transaction/mod_accepted_trajectory_directional_sensitivity.f90" ;;\n'
s=s.replace(case_anchor,insert,1)
Path(target).write_text(s,encoding='utf-8')
PY
chmod +x "$TARGET"
TIMING_MODE=directional bash "$TARGET"
echo 'FPE_ZERO_WASTE01_HDIR04_PAIRED=PASS'
