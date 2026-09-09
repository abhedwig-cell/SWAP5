#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fsi20-headnorm-policy-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

FVQ27=1dc8219beda37fbcd6fd4232c964208fa0f17c8f
BACKEND_BLOB=6f39d60a87c1987ae95d7faec2f55f865af90a08
FGC02_BRANCH=origin/work/f-gc02-physical-coupling-seam
FGC02_FIXTURE=tests/fgc/test_fgc02_physical_coupling.f90
FGC02_FIXTURE_BLOB=d8c3863a1acb08eb60712c7dd58bafc4cc5de5a6
PROBE="$BUILD/mod_fmr_serialized_reference_backend_headnorm.f90"

fail() { echo "FSI20_HEADNORM_POLICY_FAIL $*" >&2; exit 1; }

git diff --quiet "$FVQ27" -- src || fail 'production src drift from F-VQ27'
[[ "$(git rev-parse HEAD:src/runtime/mod_fmr_serialized_reference_backend.f90)" == "$BACKEND_BLOB" ]] || fail 'serialized backend blob drift'
[[ "$(git rev-parse "$FGC02_BRANCH:$FGC02_FIXTURE")" == "$FGC02_FIXTURE_BLOB" ]] || fail 'F-GC02 fixture drift'
git show "$FGC02_BRANCH:$FGC02_FIXTURE" > "$BUILD/fgc02.f90"
grep -Fq 'cfg%transaction%max_retries = 2' "$BUILD/fgc02.f90"
grep -Fq 'cfg%max_committed_substeps = 8' "$BUILD/fgc02.f90"
grep -Fq 'cfg%transaction%retry_scale = 0.5_real64' "$BUILD/fgc02.f90"
grep -Fq 'p%max_iterations = 8' "$BUILD/fgc02.f90"
grep -Fq 'p%max_backtracking = 4' "$BUILD/fgc02.f90"
grep -Fq 'p%min_step_duration = 1.0e-6_real64' "$BUILD/fgc02.f90"
echo 'FSI20_HEADNORM_POLICY_SOURCE_LOCK=PASS'
echo 'FSI20_HEADNORM_POLICY_EXACT_FGC02_NUMERICAL_POLICY=PASS'

cp src/runtime/mod_fmr_serialized_reference_backend.f90 "$PROBE"
python3 - "$PROBE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
start=s.index('  real(real64) function fmr_serialized_temporal_identity')
end_marker='  end function fmr_serialized_temporal_identity\n'
end=s.index(end_marker,start)+len(end_marker)
new='''  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)\n    class(fmr_serialized_reference_model_t), intent(in) :: self\n    class(transaction_state_t), intent(in) :: full_state, half_state\n    logical :: admissible\n    value = huge(0.0_real64)\n    if (self%bottom_mode /= 5) return\n    admissible = .false.\n    select type (full => full_state)\n    type is (fmr_b110_physical_state_t)\n      select type (half => half_state)\n      type is (fmr_b110_physical_state_t)\n        admissible = full%active_nodes == half%active_nodes .and. full%active_nodes > 0 .and. &\n             allocated(full%pressure_head) .and. allocated(half%pressure_head) .and. &\n             allocated(full%water_content) .and. allocated(half%water_content) .and. &\n             .not. allocated(full%snow) .and. .not. allocated(half%snow)\n        if (admissible) admissible = size(full%pressure_head) == full%active_nodes .and. &\n             size(half%pressure_head) == half%active_nodes .and. &\n             size(full%water_content) == full%active_nodes .and. size(half%water_content) == half%active_nodes\n        if (admissible) admissible = ieee_is_finite(full%ponding_depth) .and. ieee_is_finite(half%ponding_depth) .and. &\n             ieee_is_finite(full%groundwater_level) .and. ieee_is_finite(half%groundwater_level)\n        if (admissible) admissible = full%ponding_depth == half%ponding_depth .and. &\n             full%groundwater_level == half%groundwater_level .and. &\n             full%ponding_depth == 0.0_real64\n        if (admissible) admissible = all(ieee_is_finite(full%pressure_head)) .and. &\n             all(ieee_is_finite(half%pressure_head))\n        if (admissible) value = maxval(abs(full%pressure_head-half%pressure_head))\n      end select\n    end select\n  end function fmr_serialized_temporal_identity\n'''
s=s[:start]+new+s[end:]
p.write_text(s)
print('FSI20_HEADNORM_POLICY_EPHEMERAL_COMPARATOR_GENERATED=PASS')
PY

# Normalize the ephemeral comparator back to the production source except for the intended function body.
python3 - "$PROBE" <<'PY'
from pathlib import Path
import sys
probe=Path(sys.argv[1]).read_text(); prod=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text()
for text,name in ((probe,'probe'),(prod,'prod')):
    if text.count('  real(real64) function fmr_serialized_temporal_identity')!=1:
        raise SystemExit(f'{name} comparator function count drift')
def without_function(s):
    a=s.index('  real(real64) function fmr_serialized_temporal_identity')
    marker='  end function fmr_serialized_temporal_identity\n'
    b=s.index(marker,a)+len(marker)
    return s[:a]+'<TEMPORAL_FUNCTION>\n'+s[b:]
if without_function(probe)!=without_function(prod):
    raise SystemExit('ephemeral comparator copy contains changes outside temporal function')
print('FSI20_HEADNORM_POLICY_PROBE_ONLY_TEMPORAL_FUNCTION_DIFFERS=PASS')
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

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${MODULE_SRC[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c tests/fsi/test_fsi20_candidate_headnorm_fgc02_policy.f90 -o "$OUT/test.o"
  gfortran -O"$opt" "${objects[@]}" "$OUT/test.o" -o "$OUT/test"
  timeout 120s "$OUT/test" > "$OUT/run1.txt" 2>&1 || { cat "$OUT/run1.txt" >&2; exit 1; }
  timeout 120s "$OUT/test" > "$OUT/run2.txt" 2>&1 || { cat "$OUT/run2.txt" >&2; exit 1; }
  cmp "$OUT/run1.txt" "$OUT/run2.txt"
  grep -Fq 'FSI20_HEADNORM_FGC02_POLICY_DRIVER PASS' "$OUT/run1.txt"
  echo "FSI20_HEADNORM_POLICY_REPEAT_O${opt}=PASS"
done
cmp "$BUILD/o0/run1.txt" "$BUILD/o2/run1.txt"
echo 'FSI20_HEADNORM_POLICY_O0_O2_IDENTITY=PASS'
cat "$BUILD/o0/run1.txt"

python3 - "$BUILD/o0/run1.txt" <<'PY'
from pathlib import Path
import re,sys
rows=[]
for line in Path(sys.argv[1]).read_text().splitlines():
    if not line.startswith('FSI20_HEADNORM_POLICY_CASE='): continue
    m=re.match(r'FSI20_HEADNORM_POLICY_CASE=(\d+):TEMPORAL_TOL=\s*([^:]+):COMPLETED=([TF]):ATTEMPTS=(\d+):RETRIES=(\d+):SOLVER_REJECTIONS=(\d+):TEMPORAL_REJECTIONS=(\d+):MASS_REJECTIONS=(\d+):ACCEPTED_SUBSTEPS=(\d+):CANDIDATE_READY=([TF]):LAST_QBOT=\s*(\S+)',line)
    if not m: raise SystemExit('bad policy row: '+line)
    rows.append({'case':int(m.group(1)),'tol':float(m.group(2)),'completed':m.group(3)=='T',
                 'attempts':int(m.group(4)),'retries':int(m.group(5)),'solver':int(m.group(6)),
                 'temporal':int(m.group(7)),'mass':int(m.group(8)),'substeps':int(m.group(9)),
                 'ready':m.group(10)=='T','qbot':float(m.group(11))})
if len(rows)!=9: raise SystemExit(f'expected 9 policy rows, got {len(rows)}')
if any(r['mass']!=0 for r in rows): raise SystemExit('mass rejection appeared')
completed=[r for r in rows if r['completed']]
failed=[r for r in rows if not r['completed']]
if not completed or not failed: raise SystemExit('sweep did not straddle acceptance boundary')
if any(not r['ready'] for r in completed) or any(r['ready'] for r in failed): raise SystemExit('candidate readiness mismatch')
# Descending tolerance must yield a single completed prefix followed by a failed suffix.
seen_fail=False
for r in rows:
    if not r['completed']: seen_fail=True
    elif seen_fail: raise SystemExit('nonmonotone tolerance acceptance classification')
# Exact measured outer defect is accepted by <=; the immediately lower decimal probe is not.
exact=rows[4]; below=rows[5]
if not exact['completed']: raise SystemExit('exact measured head defect should be accepted by <= semantics')
if below['completed']: raise SystemExit('below-defect probe unexpectedly completed')
if exact['attempts']!=1 or exact['substeps']!=1 or exact['temporal']!=0:
    raise SystemExit('exact threshold did not complete as one full-window accepted transaction')
if below['attempts']!=3 or below['retries']!=2 or below['temporal']!=3 or below['substeps']!=0:
    raise SystemExit('below-threshold F-GC02 retry classification changed')
print(f"FSI20_HEADNORM_POLICY_LOWEST_COMPLETING_TOL={min(r['tol'] for r in completed):.17e}")
print(f"FSI20_HEADNORM_POLICY_HIGHEST_FAILING_TOL={max(r['tol'] for r in failed):.17e}")
print('FSI20_HEADNORM_POLICY_ACCEPTANCE_BOUNDARY_EQUALS_OUTER_DEFECT=PASS')
print('FSI20_HEADNORM_POLICY_BELOW_BOUNDARY_RETRIES_DO_NOT_RESCUE=PASS')
print('FSI20_HEADNORM_POLICY_MASS_REMAINS_HARD=PASS')
print('FSI20_HEADNORM_POLICY_PRODUCTION_METRIC_SELECTED=NO')
PY

echo 'FSI20_CANDIDATE_HEADNORM_FGC02_POLICY PASS'
