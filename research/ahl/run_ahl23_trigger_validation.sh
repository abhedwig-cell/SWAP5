#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-ahl23-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD/tables"; trap 'rm -rf "$BUILD"' EXIT; cd "$ROOT"

PYTHONPATH=research/ahl python3 research/ahl/ahl23_trigger_predictions.py "$BUILD/tables" | tee /tmp/ahl23_predictions.txt

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
SRC=(
 tests/fsi/fsi04_real_headcalc_stubs.f90
 src/solver/mod_soil_water_accepted_step_direction_contract.f90
 src/transaction/mod_accepted_trajectory_directional_sensitivity.f90
 src/runtime/mod_a23bu_worker_execution_context.f90
 src/solver/mod_soil_water_solver_contract.f90
 src/solver/mod_reference_richards_workspace.f90
 src/solver/mod_reference_richards_state_binding.f90
 src/solver/mod_reference_linear_solver.f90
 src/solver/mod_b110_default_mvg_provider.f90
 src/solver/mod_b110_source_sink_provider.f90
 src/solver/mod_b110_root_sink_provider.f90
 src/solver/mod_fixed_flux_top_boundary_provider.f90
 src/solver/mod_reference_richards_temporal_indicator.f90
 tests/fmr/mod_fmr04_fixed_top_provider.f90
 src/legacy/b1_10_port/headcalc.f90
 src/adapter/mod_reference_richards_legacy_binding.f90
 research/ahl/mod_ahl09_dc_provider.f90
)
objects=()
for source in "${SRC[@]}"; do
 obj="$BUILD/$(basename "${source%.*}").o"
 gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c "$source" -o "$obj"
 objects+=("$obj")
done
gfortran "${COMMON[@]}" -O2 -J "$BUILD" -I "$BUILD" -c research/ahl/test_ahl23_trigger_validation.f90 -o "$BUILD/test.o"
gfortran -O2 "${objects[@]}" "$BUILD/test.o" -o "$BUILD/test"

RESULT="${1:-/tmp/ahl23_result.txt}"; : > "$RESULT"
for spec in  "B01_dry_dt0060 B01 -500 0.060"  "B01_dry_dt0065 B01 -500 0.065"  "O05_dry_dt0060 O05 -500 0.060"  "O05_dry_dt0065 O05 -500 0.065"; do
 read -r cid mid h dt <<< "$spec"
 "$BUILD/test" "$BUILD/tables/${mid}_dc.dat" "$mid" "$cid" "$h" 0.0 0.99 "$dt" | tee -a "$RESULT"
done

python3 - /tmp/ahl23_predictions.txt "$RESULT" <<'PY'
import re,sys
pred={}
for line in open(sys.argv[1]):
    m=re.search(r'AHL23_TRIGGER (S+) metric=([0-9.Ee+-]+).* prediction=(S+)',line)
    if m: pred[m.group(1)]=(float(m.group(2)),m.group(3))
obs={}
for line in open(sys.argv[2]):
    m=re.search(r'AHL23_PATH_IDENTITY (S+) (PASS|FAIL)',line)
    if m:
        cid=m.group(1).split(':')[-1] if ':' in m.group(1) else m.group(1)
        obs[cid]=m.group(2)
print("AHL23_PREDICTIONS",pred)
print("AHL23_OBSERVED",obs)
if set(pred)!=set(obs):
    raise SystemExit(f'case mismatch pred={set(pred)} obs={set(obs)}')
false_neg=[];false_pos=[]
for cid,(metric,p) in pred.items():
    actual=obs[cid]
    if p=="LOOKUP_SAFE" and actual=="FAIL": false_neg.append(cid)
    if p=="FALLBACK" and actual=="PASS": false_pos.append(cid)
    print(f"AHL23_CLASSIFICATION {cid} metric={metric:.17e} prediction={p} observed={actual}")
if false_neg:
    print("AHL23_TRIGGER=FALSIFIED_FALSE_NEGATIVE",false_neg)
    raise SystemExit(2)
if false_pos:
    print("AHL23_TRIGGER=NO_FALSE_NEGATIVES_WITH_FALSE_POSITIVES",false_pos)
else:
    print("AHL23_TRIGGER=PASS_PROSPECTIVE_SET")
PY
