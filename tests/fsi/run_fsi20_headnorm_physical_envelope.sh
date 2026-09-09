#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-headnorm-envelope-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
BASE_DRIVER_BLOB=83e5b678ae4bd942d0b48ccf13ca13c867d6dabf
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
PROBE="$BUILD/mod_fmr_serialized_reference_backend_headnorm_envelope.f90"

fail() { echo "FSI20_HEADNORM_ENVELOPE_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production src drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'serialized backend blob drift'
[[ "$(git rev-parse HEAD:tests/fsi/test_fsi20_fine_reference_trajectory.f90)" == "$BASE_DRIVER_BLOB" ]] || fail 'fine-reference driver drift'
[[ "$(git rev-parse "$FGC02_BRANCH:tests/fgc/test_fgc02_physical_coupling.f90")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
echo 'FSI20_HEADNORM_ENVELOPE_SOURCE_LOCK=PASS'
echo 'FSI20_HEADNORM_ENVELOPE_PRODUCTION_IMMUTABILITY=PASS'

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$PROBE"
python3 - "$PROBE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
start=s.index('  real(real64) function fmr_serialized_temporal_identity')
marker='  end function fmr_serialized_temporal_identity\n'
end=s.index(marker,start)+len(marker)
new='''  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)\n    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: admissible\n    integer, save :: fsi20_envelope_calls = 0\n    value = huge(0.0_real64)\n    admissible = .false.\n    if (self%bottom_mode /= 5) return\n    select type (full => full_state)\n    type is (fmr_b110_physical_state_t)\n      select type (half => half_state)\n      type is (fmr_b110_physical_state_t)\n        admissible = full%active_nodes == half%active_nodes .and. full%active_nodes > 0 .and. &\n             allocated(full%pressure_head) .and. allocated(half%pressure_head) .and. &\n             allocated(full%water_content) .and. allocated(half%water_content) .and. &\n             .not. allocated(full%snow) .and. .not. allocated(half%snow)\n        if (admissible) admissible = size(full%pressure_head) == full%active_nodes .and. &\n             size(half%pressure_head) == half%active_nodes .and. &\n             size(full%water_content) == full%active_nodes .and. size(half%water_content) == half%active_nodes\n        if (admissible) admissible = ieee_is_finite(full%ponding_depth) .and. ieee_is_finite(half%ponding_depth) .and. &\n             ieee_is_finite(full%groundwater_level) .and. ieee_is_finite(half%groundwater_level)\n        if (admissible) admissible = full%ponding_depth == half%ponding_depth .and. &\n             full%groundwater_level == half%groundwater_level .and. full%ponding_depth == 0.0_real64\n        if (admissible) admissible = all(ieee_is_finite(full%pressure_head)) .and. &\n             all(ieee_is_finite(half%pressure_head))\n        if (admissible) then\n          value = maxval(abs(full%pressure_head-half%pressure_head))\n          fsi20_envelope_calls = fsi20_envelope_calls + 1\n          if (fsi20_envelope_calls == 1) write(*,'(A,1X,ES26.17E3)') 'FSI20_HEADNORM_ENVELOPE_OUTER_DEFECT', value\n        end if\n      end select\n    end select\n  end function fmr_serialized_temporal_identity\n'''
s=s[:start]+new+s[end:]
p.write_text(s)
print('FSI20_HEADNORM_ENVELOPE_EPHEMERAL_COMPARATOR=PASS')
PY

python3 - "$PROBE" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
def stripfun(s):
    a=s.index('  real(real64) function fmr_serialized_temporal_identity')
    m='  end function fmr_serialized_temporal_identity\n'
    b=s.index(m,a)+len(m)
    return s[:a]+'<TEMPORAL_FUNCTION>\n'+s[b:]
if stripfun(probe)!=stripfun(prod):
    raise SystemExit('ephemeral comparator changed code outside temporal function')
print('FSI20_HEADNORM_ENVELOPE_ONLY_TEMPORAL_FUNCTION_DIFFERS=PASS')
PY

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/runtime/mod_canonical_contracts.f90
  src/runtime/mod_canonical_interval_runtime.f90
  src/kernel/mod_kernel_transactions.f90
  src/runtime/mod_fmr_runtime_core.f90
  src/runtime/mod_fmr_checkpoint_orchestrator.f90
  src/solver/mod_soil_water_solver_contract.f90
  src/solver/mod_process_hydraulic_view.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  "$PROBE"
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/runtime/mod_fmr_serialized_multiswap_runtime.f90
  src/process/mod_irrigation_process.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

# Initial head, signed prescribed-head jump. Baseline plus wet/dry and magnitude axes.
CASES=(
  '-25.0 0.01'
  '-25.0 -0.01'
  '-75.0 0.001'
  '-75.0 -0.001'
  '-75.0 0.01'
  '-75.0 -0.01'
  '-75.0 0.1'
  '-75.0 -0.1'
  '-250.0 0.01'
  '-250.0 -0.01'
)

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  case_id=0
  for spec in "${CASES[@]}"; do
    case_id=$((case_id+1))
    read -r h0 jump <<<"$spec"
    driver="$OUT/case_${case_id}.f90"
    cp tests/fsi/test_fsi20_fine_reference_trajectory.f90 "$driver"
    python3 - "$driver" "$h0" "$jump" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); h0=float(sys.argv[2]); jump=float(sys.argv[3]); hb=h0+jump
s=p.read_text()
repls={
  'real(real64), parameter :: initial_head_cm = -75.0_real64':f'real(real64), parameter :: initial_head_cm = {h0:.17e}_real64',
  'real(real64), parameter :: predictor_bottom_head_cm = -74.99_real64':f'real(real64), parameter :: predictor_bottom_head_cm = {hb:.17e}_real64',
  'integer, parameter :: nlevels = 7':'integer, parameter :: nlevels = 1'
}
for old,new in repls.items():
    if s.count(old)!=1: raise SystemExit('driver token drift: '+old)
    s=s.replace(old,new,1)
p.write_text(s)
PY
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$driver" -o "$OUT/case_${case_id}.o"
    gfortran -O"$opt" "${objects[@]}" "$OUT/case_${case_id}.o" -o "$OUT/case_${case_id}"
    timeout 180s "$OUT/case_${case_id}" > "$OUT/case_${case_id}_run1.txt" 2>&1 || { cat "$OUT/case_${case_id}_run1.txt" >&2; exit 1; }
    grep -Fq 'FSI20_FINE_REFERENCE_TRAJECTORY_DRIVER PASS' "$OUT/case_${case_id}_run1.txt"
    if [[ "$opt" == 0 ]]; then
      timeout 180s "$OUT/case_${case_id}" > "$OUT/case_${case_id}_run2.txt" 2>&1 || { cat "$OUT/case_${case_id}_run2.txt" >&2; exit 1; }
      cmp "$OUT/case_${case_id}_run1.txt" "$OUT/case_${case_id}_run2.txt"
    fi
  done
done

echo 'FSI20_HEADNORM_ENVELOPE_REPEAT_DETERMINISM_O0=PASS'
for i in $(seq 1 ${#CASES[@]}); do
  cmp "$BUILD/o0/case_${i}_run1.txt" "$BUILD/o2/case_${i}_run1.txt"
done
echo 'FSI20_HEADNORM_ENVELOPE_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" "${CASES[@]}" <<'PY'
from pathlib import Path
import math,re,sys
build=Path(sys.argv[1]); specs=sys.argv[2:]
rows=[]
for idx,spec in enumerate(specs,1):
    h0,jump=map(float,spec.split())
    lines=(build/'o0'/f'case_{idx}_run1.txt').read_text().splitlines()
    defects=[]; summaries=[]
    for line in lines:
        if line.startswith('FSI20_HEADNORM_ENVELOPE_OUTER_DEFECT'):
            defects.append(float(line.split()[1]))
        if line.startswith('FSI20_FINE_REFERENCE_SUMMARY'):
            p=line.split(); summaries.append(tuple(float(x) for x in p[1:]))
    if len(defects)!=1: raise SystemExit(f'case {idx}: expected one outer defect, got {len(defects)}')
    if len(summaries)!=1: raise SystemExit(f'case {idx}: expected one summary, got {len(summaries)}')
    dt,eh,et,es,rh,rt,rs=summaries[0]
    vals=[h0,jump,defects[0],dt,eh,et,es,rh,rt,rs]
    if not all(math.isfinite(v) for v in vals): raise SystemExit(f'case {idx}: nonfinite result')
    if abs(dt-0.25)>1e-15: raise SystemExit(f'case {idx}: unexpected horizon {dt}')
    ratio=defects[0]/eh if eh!=0 else math.inf
    ref_ratio=eh/rh if rh!=0 else math.inf
    rows.append((idx,h0,jump,defects[0],eh,rh,ratio,ref_ratio,et,es))
    print('FSI20_HEADNORM_ENVELOPE_ROW:CASE='+str(idx)+
          ':H0_CM='+f'{h0:.17e}'+':JUMP_CM='+f'{jump:.17e}'+
          ':DHEAD='+f'{defects[0]:.17e}'+':HALF_TO_REF256_DHEAD='+f'{eh:.17e}'+
          ':REF128_TO_REF256_DHEAD='+f'{rh:.17e}'+':D_OVER_ENDPOINT_ERROR='+f'{ratio:.17e}'+
          ':ENDPOINT_ERROR_OVER_REF_DELTA='+f'{ref_ratio:.17e}'+
          ':HALF_TO_REF256_DTHETA='+f'{et:.17e}'+':SIGNED_STORAGE_ERROR='+f'{es:.17e}')
# No admission threshold is imposed. We only require that both signs are represented at every base state
# and that the baseline fixture reproduces the previously measured outer defect within rounding noise.
for h0 in (-25.0,-75.0,-250.0):
    subset=[r for r in rows if r[1]==h0 and abs(abs(r[2])-0.01)<1e-15]
    if len(subset)!=2 or {math.copysign(1.0,r[2]) for r in subset}!={-1.0,1.0}:
        raise SystemExit(f'missing sign pair for h0={h0}')
baseline=next(r for r in rows if r[1]==-75.0 and abs(r[2]-0.01)<1e-15)
known=2.55242948426825933e-4
if abs(baseline[3]-known) > 64*2.220446049250313e-16*max(1.0,abs(known)):
    raise SystemExit(f'baseline outer defect drift: {baseline[3]} vs {known}')
ratios=[r[6] for r in rows if math.isfinite(r[6])]
print('FSI20_HEADNORM_ENVELOPE_CASES='+str(len(rows)))
print('FSI20_HEADNORM_ENVELOPE_D_OVER_ENDPOINT_ERROR_MIN='+f'{min(ratios):.17e}')
print('FSI20_HEADNORM_ENVELOPE_D_OVER_ENDPOINT_ERROR_MAX='+f'{max(ratios):.17e}')
print('FSI20_HEADNORM_ENVELOPE_BASELINE_REPRODUCTION=PASS')
print('FSI20_HEADNORM_ENVELOPE_HARD_MASS_GATE=UNCHANGED_1E-12')
print('FSI20_HEADNORM_ENVELOPE_NORMALIZATION_SELECTED=NO')
print('FSI20_HEADNORM_ENVELOPE_PRODUCTION_TOLERANCE_SELECTED=NO')
print('FSI20_HEADNORM_PHYSICAL_ENVELOPE PASS')
PY
