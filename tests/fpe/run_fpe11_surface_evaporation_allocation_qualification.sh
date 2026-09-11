#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=3c5f5bd3686e1632058b906be21abd73883e30ef
FVQ56=0cdbc193976c73bef208a82547b3c9ea81c4102c
PROCESS=src/process/mod_restricted_surface_evaporation.f90
CAPACITY_CONTRACT=src/solver/mod_surface_evaporation_capacity_contract.f90
CAPACITY_PROVIDER=src/solver/mod_b110_surface_evaporation_capacity_provider.f90
BINDING=src/runtime/mod_fmr_process_hydraulic_view_binding.f90
RUNTIME=src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
BUILD="${RUNNER_TEMP:-/tmp}/fpe11-${GITHUB_RUN_ID:-local}"
BASE_TREE="$BUILD/base"
rm -rf "$BUILD"
mkdir -p "$BUILD" "$BASE_TREE"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FPE11_GATE_FAIL $*" >&2; exit 11; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch $sha"
}
need_commit "$BASE"
need_commit "$FVQ56"

test "$(git merge-base "$BASE" HEAD)" = "$BASE" || fail 'candidate does not descend from F-CI41P authority'

# Scientific/capacity authority is frozen. F-PE11 may only change the narrow runtime path.
for path in "$PROCESS" "$CAPACITY_CONTRACT" "$CAPACITY_PROVIDER"; do
  test "$(git rev-parse HEAD:$path)" = "$(git rev-parse $BASE:$path)" || fail "frozen scientific/capacity blob changed: $path"
done
mapfile -t src_delta < <(git diff --name-only "$BASE"..HEAD -- src | sort)
expected=("$BINDING" "$RUNTIME")
[[ "${src_delta[*]}" == "${expected[*]}" ]] || fail "unexpected production delta: ${src_delta[*]:-none}"
echo 'FPE11_FROZEN_SCIENTIFIC_AUTHORITY=PASS'
echo 'FPE11_EXACT_TWO_FILE_RUNTIME_SCOPE=PASS'

python3 - "$BASE" "$BINDING" "$RUNTIME" <<'PY'
from pathlib import Path
import re, subprocess, sys
base, binding_path, runtime_path = sys.argv[1:]
b = Path(binding_path).read_text()
r = Path(runtime_path).read_text()
base_b = subprocess.check_output(['git','show',f'{base}:{binding_path}'], text=True)
base_r = subprocess.check_output(['git','show',f'{base}:{runtime_path}'], text=True)

def normalized_public_decls(text):
    out=[]
    for raw in text.splitlines():
        line=raw.split('!',1)[0].strip().lower()
        if 'public' in line and '::' in line:
            out.append(re.sub(r'\s+',' ',line))
    return out

def subroutine_signature(text, name):
    lines=text.splitlines()
    for i, raw in enumerate(lines):
        if re.match(rf'^\s*subroutine\s+{re.escape(name)}\s*\(', raw, re.I):
            acc=raw.strip()
            j=i
            while acc.rstrip().endswith('&'):
                j += 1
                acc += ' ' + lines[j].strip()
            return re.sub(r'\s+',' ',acc.lower().replace('&',''))
    raise AssertionError(f'missing {name}')

assert normalized_public_decls(b) == normalized_public_decls(base_b)
assert normalized_public_decls(r) == normalized_public_decls(base_r)
assert subroutine_signature(b, 'fmr_build_committed_process_hydraulic_view') == subroutine_signature(base_b, 'fmr_build_committed_process_hydraulic_view')
assert subroutine_signature(r, 'fmr_materialize_restricted_surface_evaporation') == subroutine_signature(base_r, 'fmr_materialize_restricted_surface_evaporation')

bl=b.lower(); rl=r.lower()
assert 'fmr_detach_committed_soil_water_state' not in bl
assert 'fmr_detach_committed_soil_water_state' not in rl
assert 'call committed%snapshot(snapshot, available)' in bl
assert 'call move_alloc(physical%pressure_head, view%pressure_head)' in bl
assert 'call move_alloc(physical%water_content, view%water_content)' in bl
assert 'call fmr_build_committed_process_hydraulic_view(committed, view, ok)' in rl
assert 'subroutine detached_state_from_view(view, state, ok)' in rl
assert 'type(process_hydraulic_view_t), intent(inout) :: view' in rl
assert 'call move_alloc(view%pressure_head, state%pressure_head)' in rl
assert 'call move_alloc(view%water_content, state%water_content)' in rl
assert not re.search(r'\ballocate\s*\(', bl)
assert not re.search(r'\ballocate\s*\(', rl)
assert 'call capacity_provider%evaluate(base_state, capacity)' in rl
assert 'call evaluate_restricted_surface_evaporation(demand, hydraulic, result)' in rl
for forbidden in ('headcalc','modflow','.swp','file_unit','pathname','midnight','day_of','month_of','year_of'):
    assert forbidden not in rl, forbidden
print('FPE11_PUBLIC_SURFACE_IDENTITY=PASS')
print('FPE11_DETACHED_OWNERSHIP_TRANSFER_SOURCE_GUARD=PASS')
print('FPE11_NO_DOWNSTREAM_EXPLICIT_PROFILE_ALLOCATE=PASS')
PY

# Materialize the exact F-CI41P source tree and the exact independent F-VQ56 oracle.
git archive "$BASE" | tar -x -C "$BASE_TREE"
git show ${FVQ56}:tests/fvq/test_fvq56_surface_evaporation_runtime_materialization_independent.f90 > "$BUILD/fvq56.f90"
sed -i 's/test_fvq56_surface_evaporation_runtime_materialization_independent/fpe11_fvq56/g' "$BUILD/fvq56.f90"

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -pedantic -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
MODULE_SRC=(
  tests/fsi/fsi04_real_headcalc_stubs.f90
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
  src/solver/mod_reference_richards_workspace.f90
  src/solver/mod_reference_richards_state_binding.f90
  src/solver/mod_b110_default_mvg_provider.f90
  src/solver/mod_b110_source_sink_provider.f90
  src/solver/mod_b110_root_sink_provider.f90
  src/solver/mod_fixed_flux_top_boundary_provider.f90
  src/solver/mod_reference_linear_solver.f90
  src/solver/mod_reference_richards_temporal_indicator.f90
  src/legacy/b1_10_port/headcalc.f90
  src/adapter/mod_reference_richards_legacy_binding.f90
  src/adapter/mod_b110_serialized_context_binding.f90
  src/process/mod_snow_process.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_process_hydraulic_view_binding.f90
  src/process/mod_reference_et_demand_process.f90
  src/runtime/mod_fmr_reference_et_demand_binding.f90
  src/solver/mod_surface_evaporation_capacity_contract.f90
  src/solver/mod_b110_surface_evaporation_capacity_provider.f90
  src/process/mod_restricted_surface_evaporation.f90
  src/runtime/mod_fmr_surface_evaporation_runtime_materialization.f90
)

compile_and_run() {
  local tree="$1" opt="$2" tag="$3"
  local out="$BUILD/${tag}-o${opt}"
  mkdir -p "$out"
  local objects=()
  for rel in "${MODULE_SRC[@]}"; do
    local src="$tree/$rel"
    local obj="$out/$(basename "${rel%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  gfortran "${COMMON[@]}" -O"$opt" -J"$out" -I"$out" -c "$BUILD/fvq56.f90" -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test.exe"
  "$out/test.exe" > "$out/output.txt" 2>&1 || { cat "$out/output.txt" >&2; fail "$tag O$opt oracle"; }
}

for opt in 0 2; do
  compile_and_run "$BASE_TREE" "$opt" baseline
  compile_and_run "$ROOT" "$opt" candidate
done

cmp -s "$BUILD/baseline-o0/output.txt" "$BUILD/baseline-o2/output.txt" || fail 'baseline O0/O2 drift'
cmp -s "$BUILD/candidate-o0/output.txt" "$BUILD/candidate-o2/output.txt" || fail 'candidate O0/O2 drift'
cmp -s "$BUILD/baseline-o0/output.txt" "$BUILD/candidate-o0/output.txt" || {
  diff -u "$BUILD/baseline-o0/output.txt" "$BUILD/candidate-o0/output.txt" >&2 || true
  fail 'candidate differs from F-CI41P observable oracle output at O0'
}
cmp -s "$BUILD/baseline-o2/output.txt" "$BUILD/candidate-o2/output.txt" || fail 'candidate differs from F-CI41P observable oracle output at O2'

grep -Fxq 'FVQ56_COMMITTED_STATE_IMMUTABLE=PASS' "$BUILD/candidate-o0/output.txt" || fail 'committed immutability marker missing'
grep -Fxq 'FVQ56_COLUMN_ORDER_ABA_DETERMINISM=PASS' "$BUILD/candidate-o0/output.txt" || fail 'ABA determinism marker missing'
grep -Fxq 'FVQ56_INDEPENDENT_ORACLE=PASS' "$BUILD/candidate-o0/output.txt" || fail 'independent oracle marker missing'
grep -Fxq 'FVQ56_NO_AUTHORITATIVE_MASS_BOOKING=PASS' "$BUILD/candidate-o0/output.txt" || fail 'mass-booking marker missing'

echo "FPE11_BASELINE_ORACLE_SHA256=$(sha256sum "$BUILD/baseline-o0/output.txt" | awk '{print $1}')"
echo "FPE11_CANDIDATE_ORACLE_SHA256=$(sha256sum "$BUILD/candidate-o0/output.txt" | awk '{print $1}')"
echo 'FPE11_FCI41P_OBSERVABLE_IDENTITY=PASS'
echo 'FPE11_O0_O2_IDENTITY=PASS'
echo 'FPE11_COMMITTED_STATE_IMMUTABILITY=PASS'
echo 'FPE11_ABA_DETERMINISM=PASS'
echo 'FPE11_NO_AUTHORITATIVE_MASS_BOOKING=PASS'
echo 'FPE11_FUNCTIONAL_QUALIFICATION=PASS'
echo 'FPE11_THROUGHPUT_SCALING_CLAIM=NOT_YET_MADE'
