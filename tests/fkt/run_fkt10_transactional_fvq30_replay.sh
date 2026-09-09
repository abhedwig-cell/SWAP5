#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fkt10-gate-g-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

PLAN=integration/f-vq/F-VQ30_QUALIFICATION_PLAN.json
PLAN_BLOB=8bf40e19ba547ec93c4d8ce18d7ac6111707afe7
EVIDENCE=integration/f-vq/F-VQ30_HELD_OUT_EVIDENCE.json
EVIDENCE_BLOB=39832173174271f4ad97278662467eb4dab13599
LINEAR=tests/fvq/test_fvq30_exact_linear_regression.py
LINEAR_BLOB=18efc3b8fb8d4610e9a2bd4dbb30a9edf23b3528
DRIVER=tests/fkt/test_fkt10_transactional_fvq30_replay.f90
STUB=tests/fsi/fsi04_real_headcalc_stubs.f90
FSI18_BRANCH=origin/work/f-si18-reference-convergence-cliff
FSI18_GENERATOR=tests/fsi/fsi18_make_reference_tridag_stubs.py
FSI18_GENERATOR_BLOB=bf25c4c7fefaa59811255b0bc25c041522ab008e

fail() { echo "FKT10_GATE_G_RUNNER_FAIL $*" >&2; exit 1; }

[[ "$(git rev-parse HEAD:$PLAN)" == "$PLAN_BLOB" ]] || fail 'F-VQ30 frozen plan drift'
[[ "$(git rev-parse HEAD:$EVIDENCE)" == "$EVIDENCE_BLOB" ]] || fail 'F-VQ30 held-out evidence drift'
[[ "$(git rev-parse HEAD:$LINEAR)" == "$LINEAR_BLOB" ]] || fail 'F-VQ30 exact-linear oracle drift'

python3 - "$PLAN" "$EVIDENCE" "$BUILD/cases.tsv" <<'PY'
import json,sys
plan,evidence,out=sys.argv[1:]
p=json.load(open(plan)); e=json.load(open(evidence))
assert p['frozen_before_execution'] is True
assert p['held_out_matrix']['case_count']==16
assert p['held_out_matrix']['exact_triplet_overlap_with_owner_matrix']==0
assert e['qualification_plan']['case_count']==16
assert e['held_out_matrix']['negative_transfer_cases']==0
rows={r['case']:r for r in e['case_rows']}
assert len(rows)==16
with open(out,'w') as f:
    for c in p['held_out_matrix']['cases']:
        r=rows[c['case']]
        assert r['h0_cm']==c['h0_cm']
        assert r['jump_cm']==c['jump_cm']
        assert r['horizon_day']==c['horizon_day']
        f.write(f"{c['case']}\t{c['h0_cm']:.17e}\t{c['jump_cm']:.17e}\t{c['horizon_day']:.17e}\t{r['B_inf']:.17e}\n")
print('FKT10_GATE_G_FVQ30_MATRIX_LOCK=PASS')
print('FKT10_GATE_G_FVQ30_CASES=16')
PY

python3 "$LINEAR" > "$BUILD/exact_linear.txt"
grep -Fq 'FVQ30_G02_EXACT_LINEAR_REGRESSION PASS' "$BUILD/exact_linear.txt" || fail 'exact-linear formula regression failed'
echo 'FKT10_GATE_G_EXACT_LINEAR_REPLAY=PASS'

# The seed seam must remain optional and fail closed on incompatible shape.
python3 - <<'PY'
from pathlib import Path
src=Path('src/runtime/mod_fmr_serialized_reference_backend.f90').read_text().lower()
needle='subroutine fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, state, initial_time, ok, &'
assert needle in src
assert 'real(real64), intent(in), optional :: initial_right_derivative(:)' in src
assert 'size(initial_right_derivative) /= state%active_nodes' in src
assert 'call typed_carrier%temporal_history%replace(initial_right_derivative, seeded)' in src
assert 'outcome%temporal_certificate_available = .true.' not in src
print('FKT10_GATE_G_OPTIONAL_SEED_SOURCE_GUARD=PASS')
print('FKT10_GATE_G_NO_CERTIFICATE_PROMOTION_SOURCE_GUARD=PASS')
PY

git fetch --quiet --no-tags origin work/f-si18-reference-convergence-cliff:refs/remotes/origin/work/f-si18-reference-convergence-cliff
[[ "$(git rev-parse "$FSI18_BRANCH:$FSI18_GENERATOR")" == "$FSI18_GENERATOR_BLOB" ]] || fail 'F-SI18 TRIDAG generator drift'
git show "$FSI18_BRANCH:$FSI18_GENERATOR" > "$BUILD/make_reference_tridag.py"
python3 "$BUILD/make_reference_tridag.py" "$STUB" "$BUILD/reference_tridag_stubs.f90"
grep -Fq 'SWAP 4.3.1 tridag.f90' "$BUILD/reference_tridag_stubs.f90" || fail 'reference TRIDAG marker missing'
if grep -Fq 'solution(i) = 0.0d0' "$BUILD/reference_tridag_stubs.f90"; then
  fail 'zero-correction TRIDAG survived reference replacement'
fi
echo 'FKT10_GATE_G_REFERENCE_TRIDAG_SOURCE=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  "$BUILD/reference_tridag_stubs.f90"
  src/runtime/mod_a23bu_worker_execution_context.f90
  src/transaction/mod_transaction_reference.f90
  src/transaction/mod_fkt_temporal_indicator_history.f90
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
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
)

build_and_run() {
  local opt="$1" tag="$2" out="$BUILD/$2"
  mkdir -p "$out"
  local objects=() src obj cid h0 jump dt expected runout
  for src in "${MODULE_SRC[@]}"; do
    obj="$out/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" "$opt" -J "$out" -I "$out" -c "$DRIVER" -o "$out/test.o"
  gfortran "$opt" "${objects[@]}" "$out/test.o" -o "$out/fkt10_gate_g"

  while IFS=$'\t' read -r cid h0 jump dt expected; do
    runout="$out/case_${cid}.txt"
    timeout 180s "$out/fkt10_gate_g" "$h0" "$jump" "$dt" "$expected" > "$runout" 2>&1 || {
      cat "$runout" >&2
      fail "transactional frozen case failed opt=$tag case=$cid"
    }
    grep -Fq 'FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASE PASS' "$runout" || fail "PASS marker missing opt=$tag case=$cid"
    echo "FKT10_GATE_G_CASE_RUN=PASS:OPT=$tag:CASE=$cid:H0=$h0:JUMP=$jump:DT=$dt:EXPECTED_BINF=$expected"
  done < "$BUILD/cases.tsv"
}

build_and_run -O0 o0
build_and_run -O2 o2

for i in $(seq 1 16); do
  cmp "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" || {
    diff -u "$BUILD/o0/case_${i}.txt" "$BUILD/o2/case_${i}.txt" >&2 || true
    fail "transactional frozen O0/O2 drift case=$i"
  }
done
echo 'FKT10_GATE_G_FROZEN_O0_O2_IDENTITY=PASS'

python3 - "$BUILD" <<'PY'
from pathlib import Path
import re,sys
b=Path(sys.argv[1])
row=re.compile(r'^FKT10_G_ROW:H0=\s*([^:]+):JUMP=\s*([^:]+):DT=\s*([^:]+):BINF=\s*([^:]+):EXPECTED=\s*([^:]+):EXTRA_TRIDAG=(\d+):EXTRA_NONLINEAR=(\d+)$')
diag=re.compile(r'^FKT10_G_DIAG:BINF_ABS_DIFF=\s*([^:]+):MAX_STEP_MASS=\s*([^:]+):HEADCALC_CALLS=(\d+)$')
maxdiff=0.0; maxmass=0.0
for cid in range(1,17):
    lines=(b/'o0'/f'case_{cid}.txt').read_text().splitlines()
    rr=[row.match(x) for x in lines if x.startswith('FKT10_G_ROW:')]
    dd=[diag.match(x) for x in lines if x.startswith('FKT10_G_DIAG:')]
    if len(rr)!=1 or rr[0] is None or len(dd)!=1 or dd[0] is None:
        raise SystemExit(f'case {cid}: output parse failure')
    r=rr[0]; d=dd[0]
    diff=float(d.group(1)); mass=float(d.group(2)); tri=int(r.group(6)); nl=int(r.group(7)); hc=int(d.group(3))
    if tri!=1 or nl!=0 or hc!=1: raise SystemExit(f'case {cid}: cost shape tri={tri} nl={nl} hc={hc}')
    if mass>1.0e-12: raise SystemExit(f'case {cid}: mass={mass}')
    maxdiff=max(maxdiff,diff); maxmass=max(maxmass,mass)
    print(f'FKT10_GATE_G_TRANSACTIONAL_ROW:CASE={cid}:BINF={float(r.group(4)):.17e}:EXPECTED={float(r.group(5)):.17e}:ABS_DIFF={diff:.17e}:MASS={mass:.17e}')
print('FKT10_GATE_G_TRANSACTIONAL_FROZEN_CASES=16')
print(f'FKT10_GATE_G_MAX_BINF_ABS_DIFF={maxdiff:.17e}')
print(f'FKT10_GATE_G_MAX_MASS={maxmass:.17e}')
print('FKT10_GATE_G_TRANSACTIONAL_FVQ30_REPLAY=PASS')
PY

cat "$BUILD/o0/case_1.txt"
echo 'FKT10_GATE_G_OWNER_REPLAY PASS'
