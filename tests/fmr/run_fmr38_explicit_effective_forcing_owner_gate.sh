#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${TMPDIR:-/tmp}/swap5-fmr38-$$"
BASE="8fa79a70a9faccaf8b63826df607a685eb75b046"
CANDIDATE="b2e31bc8993075bc346f80ad7eb9dc4d92ff7ded"
CANDIDATE_BLOB="f06a2eef7b47880e449cf9b201342d7bd1e197e1"
FMR37="e21ae30a3f3a5cb2a4a34f00c74e5a46c67645d1"
FMQ26_MATRIX_BLOB="26cc6e0ace986dc40db7635de7192958a1c0b868"
FVQ51="716d0952c2a9580b213cd22d8c3c1dc824f53dff"
FVQ51_TEST_BLOB="b8206e0388568f5e792304af9bf9bd889212a10c"
FVQ51_EXPECTED_HASH="a2e8056d5d1ab9e2ae52204b5dd3418a253603300726a51660db86f050895f87"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
cd "$ROOT"

fail() { echo "FMR38_GATE_FAIL $*" >&2; exit 38; }
check_blob() {
  local path="$1" expected="$2" actual
  actual="$(git rev-parse "HEAD:$path")"
  [[ "$actual" == "$expected" ]] || fail "blob drift $path expected=$expected actual=$actual"
}

git merge-base --is-ancestor "$BASE" "$CANDIDATE" || fail 'candidate not descended from exact canonical source authority'
git merge-base --is-ancestor "$CANDIDATE" HEAD || fail 'HEAD not descended from exact structural candidate'
mapfile -t src_delta < <(git diff --name-only "$BASE".."$CANDIDATE" -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "src/runtime/mod_fmr_serialized_multiswap_runtime.f90" ]] || fail "unexpected candidate src delta ${src_delta[*]:-none}"
git diff --quiet "$CANDIDATE"..HEAD -- src || fail 'production source changed after exact structural candidate'
git diff --quiet "$BASE"..HEAD -- reference || fail 'reference source changed'
check_blob src/runtime/mod_fmr_serialized_multiswap_runtime.f90 "$CANDIDATE_BLOB"
check_blob src/runtime/mod_fmr_parallel_worker_pool.f90 0e700797cbaed4aaab7f04db0054f72faddcfc15
check_blob src/runtime/mod_fmr_parallel_physical_scheduler.f90 544a1ca16fdeebdfce7f89d1ddf1825fa32fa654
check_blob src/runtime/mod_fmr_serialized_reference_backend.f90 9af5a494526810324dc00706b444e448e770cba9
check_blob src/runtime/mod_fmr_divdra_serialized_composition.f90 5cc7bd8674e24e4642f3ad909e6c93b8259a1cf5
check_blob src/runtime/mod_fmr_divdra_serialized_runtime.f90 9a384658ec37b68d2ef911e741aa89707dcb3e77
check_blob src/runtime/mod_fmr_divdra_runtime_binding.f90 e4737fb6f00a11ed16e34bee44b3442ac84b31aa
check_blob src/process/mod_drainage_spatial_distribution.f90 1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a
echo 'FMR38_SOURCE_SCOPE_AND_BLOB_LOCK=PASS'

python3 - "$FMR37" "$FVQ51" <<'PY'
import json, subprocess, sys
fmr37,fvq51=sys.argv[1:]
r=json.loads(subprocess.check_output(['git','show',f'{fmr37}:integration/f-mr/F-MR37_STATUS.json'],text=True))
assert r['decision']=='QUALIFIED_GENERIC_RESOLVED_COLUMN_EXPLICIT_EFFECTIVE_FORCING_SEAM_READY_FOR_STRUCTURAL_CANDIDATE'
q=json.loads(subprocess.check_output(['git','show',f'{fvq51}:integration/f-vq/F-VQ51_EVIDENCE.json'],text=True))
assert q['independent_decision']=='QUALIFIED_RESTRICTED_DIVDRA_ACTIVE_RUNTIME_CALLSITE_FOR_CANONICAL_ADMISSION'
assert q['decisive_independent_ci']['output_sha256']=='a2e8056d5d1ab9e2ae52204b5dd3418a253603300726a51660db86f050895f87'
print('FMR38_UPSTREAM_AUTHORITY_LOCK=PASS')
PY

python3 - <<'PY'
from pathlib import Path
import json,re
p=Path('src/runtime/mod_fmr_serialized_multiswap_runtime.f90').read_text().lower()
assert 'public :: fmr_execute_serialized_physical_column' in p
assert 'public :: fmr_execute_serialized_resolved_physical_column' in p
assert re.search(r'type\(fmr_b110_physical_forcing_t\),\s*intent\(in\)\s*::\s*effective_forcing',p)
assert p.count('subroutine execute_resolved_column(')==1
assert p.count('call execute_resolved_column(')==3
assert 'forcing_index = int(column%forcing_handle)' in p
assert 'parameter_index = int(column%parameter_ref)' in p
assert 'state_index = int(column%state_handle)' in p
body=p.split('subroutine execute_resolved_column(',1)[1].split('end subroutine execute_resolved_column',1)[0]
assert 'forcing_registry' not in body
assert 'parameter_registry' not in body
assert 'state_registry' not in body
assert 'call fmr_capture_checkpoint(committed_state' in body
assert 'call backend%run_trial(column, template, parameters, committed_state, effective_forcing' in body
assert 'kernel_result%mass%complete' in body
assert 'kernel_result%mass%missing_contribution_mask /= tx_mass_missing_none' in body
assert 'call fmr_commit_candidate(' in body
assert 'call fmr_discard_candidate(' in body
assert 'bind_committed_actual_transpiration(parameters, effective_forcing' in body
for forbidden in ('modflow','.swp','headcalc','response_tangent'):
    assert forbidden not in p, forbidden
assert not re.search(r'\bsave\b',body)
audit=json.loads(Path('integration/f-mr/F-MR38_INVARIANT_AUDIT.json').read_text())
assert [x['id'] for x in audit['invariants']]==list(range(1,31))
assert all(x['status']=='SATISFIED' for x in audit['invariants'])
print('FMR38_SINGLE_SHARED_TRANSACTION_BODY=PASS')
print('FMR38_EXPLICIT_EFFECTIVE_FORCING_INTENT_IN=PASS')
print('FMR38_ALL_30_ARCHITECTURE_INVARIANTS=PASS')
PY

# Materialize immutable prior matrices from exact Git blobs.
git cat-file blob "$FMQ26_MATRIX_BLOB" > "$BUILD/fmq26.f90"
[[ "$(git hash-object "$BUILD/fmq26.f90")" == "$FMQ26_MATRIX_BLOB" ]] || fail 'FMQ26 immutable matrix blob mismatch'
git cat-file blob "$FVQ51_TEST_BLOB" > "$BUILD/fvq51.f90"
[[ "$(git hash-object "$BUILD/fvq51.f90")" == "$FVQ51_TEST_BLOB" ]] || fail 'FVQ51 immutable test blob mismatch'
# Reproduce the documented F-VQ51 allocation-hygiene transform in the ephemeral copy only.
python3 - "$BUILD/fvq51.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(); s=s.replace('    allocate(req(', '    if (allocated(req)) deallocate(req)\n    allocate(req('); p.write_text(s)
PY

# Deterministically derive a direct identity attack from the immutable FMQ26 fixture.
cp "$BUILD/fmq26.f90" "$BUILD/seam.f90"
python3 - "$BUILD/seam.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
def one(old,new,label):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f'{label}: expected one token got {n}')
    s=s.replace(old,new,1)
one('program test_fmq26_parallel_v1_admission','program test_fmr38_resolved_seam_identity','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fmr38_resolved_seam_identity','end program')
one('  use mod_kernel_transactions, only: kernel_committed_state_t\n','  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t\n','kernel executor import')
one('       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state\n','       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t\n','backend import')
one('       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK\n','       fmr_run_serialized_physical_multiswap, fmr_execute_serialized_physical_column, &\n       fmr_execute_serialized_resolved_physical_column, FMR_SERIAL_DISPATCH_OK\n','runtime imports')
one('  do k = 1, ncases\n','  call run_resolved_seam_identity()\n  write(*,\'(A)\') \'FMR38_RESOLVED_SEAM_EXACT_IDENTITY=PASS\'\n  do k = 1, ncases\n','main seam call')
needle='  subroutine run_positive_case(n, batch_size, order_code)\n'
if needle not in s: raise SystemExit('missing insertion point')
helper=r'''  subroutine run_resolved_seam_identity()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1), bad_template
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: state_registry(:), state_resolved(:), state_bad(:), state_initial(:)
    type(fmr_serialized_column_result_t) :: out_registry, out_resolved, out_bad
    type(fmr_column_diagnostics_t) :: diag_registry, diag_resolved, diag_bad
    type(fmr_serialized_batch_diagnostics_t) :: rt_registry, rt_resolved, rt_bad
    type(fmr_serialized_reference_backend_t) :: backend_registry, backend_resolved, backend_bad
    type(kernel_executor_t) :: tx_registry, tx_resolved, tx_bad
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: active_registry, active_resolved, active_bad

    call build_fixture(1,columns,templates,parameters,forcings,seed,conductivity0)
    call configure_transaction(config)
    call initialize_states(state_registry,columns,seed)
    call initialize_states(state_resolved,columns,seed)
    call backend_registry%initialize(top_provider)
    call backend_resolved%initialize(top_provider)
    active_registry=0; active_resolved=0
    call fmr_execute_serialized_physical_column(backend_registry,tx_registry,columns(1),templates,parameters,forcings, &
         state_registry,config,t0,t1,out_registry,diag_registry,rt_registry,active_registry)
    call fmr_execute_serialized_resolved_physical_column(backend_resolved,tx_resolved,columns(1),templates(1),parameters(1), &
         forcings(1),state_resolved(1),config,t0,t1,out_resolved,diag_resolved,rt_resolved,active_resolved)
    call require(column_result_identical(out_registry,out_resolved),'registry vs resolved result identity')
    call require(diagnostic_semantic(diag_registry,diag_resolved),'registry vs resolved diagnostic identity')
    call require(committed_state_identical(state_registry(1),state_resolved(1)),'registry vs resolved state identity')
    call require(runtime_semantically_identical(rt_registry,rt_resolved),'registry vs resolved runtime identity')
    call require(active_registry==0 .and. active_resolved==0,'resolved active-call counter closure')

    call initialize_states(state_bad,columns,seed)
    call initialize_states(state_initial,columns,seed)
    bad_template=templates(1); bad_template%template_id=bad_template%template_id+1_int64
    call backend_bad%initialize(top_provider)
    active_bad=0
    call fmr_execute_serialized_resolved_physical_column(backend_bad,tx_bad,columns(1),bad_template,parameters(1),forcings(1), &
         state_bad(1),config,t0,t1,out_bad,diag_bad,rt_bad,active_bad)
    call require(trim(out_bad%admission_status)=='ROUTING_REJECTED','resolved mismatch rejected')
    call require(.not.out_bad%solver_executed .and. .not.out_bad%committed,'resolved mismatch pretrial')
    call require(diag_bad%rejected==1 .and. trim(diag_bad%failure_classification)=='ROUTING_REJECTED','resolved reject diagnostic')
    call require(committed_state_identical(state_bad(1),state_initial(1)),'resolved mismatch nonmutation')
    call require(active_bad==0,'resolved mismatch zero active physical calls')
  end subroutine run_resolved_seam_identity

'''
s=s.replace(needle,helper+needle,1)
p.write_text(s)
PY

echo 'FMR38_IMMUTABLE_FIXTURES_MATERIALIZED=PASS'
echo 'FMR38_DIRECT_SEAM_ATTACK_DERIVED=PASS'

COMMON=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
STRICT=(-std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow -fopenmp)
PRE_RUNTIME=(
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
  src/process/mod_drainage_spatial_distribution.f90
  src/runtime/mod_fmr_serialized_reference_backend.f90
  src/runtime/mod_fmr_accepted_commit_receipt.f90
)
POST_RUNTIME=(
  src/runtime/mod_fmr_divdra_runtime_binding.f90
  src/runtime/mod_fmr_divdra_serialized_composition.f90
  src/runtime/mod_fmr_divdra_serialized_runtime.f90
  src/runtime/mod_fmr_parallel_physical_scheduler.f90
  src/runtime/mod_fmr_parallel_worker_pool.f90
  tests/fmr/mod_fmr04_fixed_top_provider.f90
)

export OMP_DYNAMIC=FALSE
export OMP_THREAD_LIMIT=4
export OMP_PROC_BIND=spread
export OMP_PLACES=cores

for opt in 0 2; do
  OUT="$BUILD/o$opt"; mkdir -p "$OUT"; objects=()
  for src in "${PRE_RUNTIME[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
  done
  obj="$OUT/mod_fmr_serialized_multiswap_runtime.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c src/runtime/mod_fmr_serialized_multiswap_runtime.f90 -o "$obj"; objects+=("$obj")
  for src in "${POST_RUNTIME[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"; gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"; objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmq26.f90" -o "$OUT/fmq26.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fmq26.o" -o "$OUT/fmq26"
  "$OUT/fmq26" > "$OUT/fmq26.txt" 2>&1 || { cat "$OUT/fmq26.txt" >&2; fail "FMQ26 replay O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_UNSUPPORTED_PROFILES_FAIL_CLOSED=PASS FMQ26_TRUE_MULTIWORKER_OVERLAP_CONTROL=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_WORKER_COUNT_INDEPENDENCE=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do grep -Fq "$marker" "$OUT/fmq26.txt" || fail "FMQ26 marker $marker O$opt"; done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/seam.f90" -o "$OUT/seam.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/seam.o" -o "$OUT/seam"
  "$OUT/seam" > "$OUT/seam.txt" 2>&1 || { cat "$OUT/seam.txt" >&2; fail "resolved seam test O$opt"; }
  grep -Fq 'FMR38_RESOLVED_SEAM_EXACT_IDENTITY=PASS' "$OUT/seam.txt" || fail "direct seam identity marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq51.f90" -o "$OUT/fvq51.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fvq51.o" -o "$OUT/fvq51"
  "$OUT/fvq51" > "$OUT/fvq51.txt" 2>&1 || { cat "$OUT/fvq51.txt" >&2; fail "FVQ51 replay O$opt"; }
  grep -Fq 'FVQ51_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS' "$OUT/fvq51.txt" || fail "FVQ51 pass marker O$opt"
  [[ "$(grep -c '^FVQ51_SINGLE ' "$OUT/fvq51.txt")" == 12 ]] || fail "FVQ51 12-case count O$opt"
  fvhash="$(sha256sum "$OUT/fvq51.txt" | awk '{print $1}')"
  [[ "$fvhash" == "$FVQ51_EXPECTED_HASH" ]] || fail "FVQ51 historical output drift O$opt expected=$FVQ51_EXPECTED_HASH actual=$fvhash"
  echo "FMR38_O${opt}_ALL_REPLAYS=PASS"
done

cmp -s "$BUILD/o0/fmq26.txt" "$BUILD/o2/fmq26.txt" || fail 'FMQ26 O0/O2 output drift'
cmp -s "$BUILD/o0/seam.txt" "$BUILD/o2/seam.txt" || fail 'resolved seam O0/O2 output drift'
cmp -s "$BUILD/o0/fvq51.txt" "$BUILD/o2/fvq51.txt" || fail 'FVQ51 O0/O2 output drift'
echo "FMR38_FMQ26_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fmq26.txt" | awk '{print $1}')"
echo "FMR38_SEAM_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/seam.txt" | awk '{print $1}')"
echo "FMR38_FVQ51_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fvq51.txt" | awk '{print $1}')"
echo 'FMR38_PARALLEL_V1_REGRESSION=NONE_OBSERVED'
echo 'FMR38_SERIALIZED_ACTIVE_DIVDRA_REGRESSION=NONE_OBSERVED'
echo 'FMR38_RESOLVED_SEAM_REGISTRY_IDENTITY=PASS'
echo 'FMR38_MASS_AND_TRANSACTION_PATH_SINGLE=PASS'
echo 'FMR38_OWNER_GATE=PASS'
