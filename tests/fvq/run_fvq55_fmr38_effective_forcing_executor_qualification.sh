#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE="adf79478f55458c05444ad9b90e52644e6cf36b6"
BASE_TREE="ea5b54a971cf35ba0f49b1e283d13f7f69304654"
MATERIALIZED="40c6da0a19f54434552d0e568a833bc712739899"
OWNER_CLOSEOUT="eb7300829be05e1500ef94720673a13cb10cdeca"
OWNER_TESTED="28f7709eff1e9901ce27ebe40b479b7e95c41176"
OWNER_RUN="34532295713"
FMR37="e21ae30a3f3a5cb2a4a34f00c74e5a46c67645d1"
CANDIDATE="b2e31bc8993075bc346f80ad7eb9dc4d92ff7ded"
CANDIDATE_PARENT="a818003a27ea7c9ba360f7227ebbe8c1525d2e21"
RUNTIME="src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
SOURCE_BLOB="fe5a06c9af59308cdad86c5126379f413591b0cd"
CANDIDATE_BLOB="f06a2eef7b47880e449cf9b201342d7bd1e197e1"
FMQ26_BLOB="26cc6e0ace986dc40db7635de7192958a1c0b868"
FVQ51_TEST_BLOB="b8206e0388568f5e792304af9bf9bd889212a10c"
FVQ51_EXPECTED_HASH="a2e8056d5d1ab9e2ae52204b5dd3418a253603300726a51660db86f050895f87"
BUILD="${RUNNER_TEMP:-/tmp}/fvq55-${GITHUB_RUN_ID:-local}"
rm -rf "$BUILD"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

fail() { echo "FVQ55_GATE_FAIL $*" >&2; exit 55; }
need_commit() {
  local sha="$1"
  git cat-file -e "${sha}^{commit}" 2>/dev/null || git fetch --no-tags origin "$sha" >/dev/null 2>&1 || fail "cannot fetch commit $sha"
}

for sha in "$BASE" "$MATERIALIZED" "$OWNER_CLOSEOUT" "$OWNER_TESTED" "$FMR37" "$CANDIDATE" "$CANDIDATE_PARENT"; do
  need_commit "$sha"
done

# 1. Current-canonical composition and immutable production materialization.
test "$(git rev-parse ${BASE}^{tree})" = "$BASE_TREE" || fail 'canonical base tree drift'
test "$(git rev-parse ${MATERIALIZED}^)" = "$BASE" || fail 'qualification materialization is not direct current-canonical child'
test "$(git rev-parse ${BASE}:$RUNTIME)" = "$SOURCE_BLOB" || fail 'current canonical runtime source blob changed'
test "$(git rev-parse ${CANDIDATE_PARENT}:$RUNTIME)" = "$SOURCE_BLOB" || fail 'owner candidate parent source blob mismatch'
test "$(git rev-parse 8fa79a70a9faccaf8b63826df607a685eb75b046:$RUNTIME)" = "$SOURCE_BLOB" || fail 'owner source-authority runtime blob mismatch'
test "$(git rev-parse ${CANDIDATE}:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'owner candidate blob mismatch'
test "$(git rev-parse ${MATERIALIZED}:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'materialized candidate is not immutable owner blob'
test "$(git rev-parse HEAD:$RUNTIME)" = "$CANDIDATE_BLOB" || fail 'qualification head changed production candidate blob'
mapfile -t src_delta < <(git diff --name-only "$BASE".."$MATERIALIZED" -- src)
[[ ${#src_delta[@]} -eq 1 && "${src_delta[0]}" == "$RUNTIME" ]] || fail "unexpected production materialization delta: ${src_delta[*]:-none}"
git diff --quiet "$MATERIALIZED"..HEAD -- src || fail 'qualification authored production changes after immutable materialization'
git diff --quiet "$BASE"..HEAD -- reference || fail 'qualification changed reference source'
echo 'FVQ55_CURRENT_CANONICAL_SOURCE_COMPOSITION=PASS'
echo 'FVQ55_IMMUTABLE_CANDIDATE_MATERIALIZATION=PASS'

# 2. Owner and readiness are provenance only. The independent oracle below is not the owner test.
python3 - "$OWNER_CLOSEOUT" "$FMR37" "$CANDIDATE" "$CANDIDATE_BLOB" "$OWNER_RUN" <<'PY'
import json, subprocess, sys
owner, fmr37, candidate, blob, run = sys.argv[1:]
def show(sha,path):
    return subprocess.check_output(['git','show',f'{sha}:{path}'], text=True)
o=json.loads(show(owner,'integration/f-mr/F-MR38_STATUS.json'))
assert o['decision']=='OWNER_QUALIFIED_GENERIC_RESOLVED_COLUMN_EXPLICIT_EFFECTIVE_FORCING_EXECUTOR_READY_FOR_INDEPENDENT_FVQ'
assert o['candidate']['commit']==candidate
assert o['candidate']['path']=='src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
assert o['candidate']['blob']==blob
assert str(o['qualification']['run'])==run
assert o['qualification']['conclusion']=='success'
r=json.loads(show(fmr37,'integration/f-mr/F-MR37_STATUS.json'))
assert r['decision']=='QUALIFIED_GENERIC_RESOLVED_COLUMN_EXPLICIT_EFFECTIVE_FORCING_SEAM_READY_FOR_STRUCTURAL_CANDIDATE'
print('FVQ55_OWNER_PROVENANCE_AND_READINESS_LOCK=PASS')
PY

# 3. Static attack on the new boundary. No registry, persistent forcing or drainage-specific executor leaks below it.
python3 - "$RUNTIME" "$BASE" "$MATERIALIZED" <<'PY'
from pathlib import Path
import re, subprocess, sys
path, base, materialized = sys.argv[1:]
s=Path(path).read_text()
low=s.lower()
assert 'public :: fmr_execute_serialized_resolved_physical_column' in low
m=re.search(r'subroutine\s+fmr_execute_serialized_resolved_physical_column\b(.*?)end\s+subroutine\s+fmr_execute_serialized_resolved_physical_column',s,re.I|re.S)
assert m
pub=m.group(1).lower()
assert re.search(r'type\(fmr_b110_physical_forcing_t\)\s*,\s*intent\(in\)\s*::\s*effective_forcing',pub,re.I)
assert 'forcing_registry' not in pub
assert 'state_registry' not in pub
assert 'parameter_registry' not in pub
m=re.search(r'subroutine\s+execute_resolved_column\b(.*?)end\s+subroutine\s+execute_resolved_column',s,re.I|re.S)
assert m
body=m.group(1).lower()
for forbidden in ('forcing_registry','state_registry','parameter_registry'):
    assert forbidden not in body, forbidden
assert 'call fmr_capture_checkpoint(committed_state' in body
assert 'call backend%run_trial(column, template, parameters, committed_state, effective_forcing' in body
assert 'kernel_result%mass%complete' in body
assert 'kernel_result%mass%missing_contribution_mask /= tx_mass_missing_none' in body
assert 'call fmr_discard_candidate(' in body
assert 'call fmr_commit_candidate(' in body
assert 'bind_committed_actual_transpiration(parameters, effective_forcing' in body
assert not re.search(r'\bsave\b',body)
assert not re.search(r'allocate\s*\([^\n]*effective_forcing',body)
assert not re.search(r'deallocate\s*\([^\n]*effective_forcing',body)
# Registry wrapper must resolve exactly the selected handles and pass one selected forcing to the common executor.
m=re.search(r'subroutine\s+execute_column\b(.*?)end\s+subroutine\s+execute_column',s,re.I|re.S)
assert m
wrapper=m.group(1).lower()
for token in ('state_index = int(column%state_handle)','parameter_index = int(column%parameter_ref)',
              'forcing_index = int(column%forcing_handle)','template_index = find_template_index(column%template_id, templates)'):
    assert token in wrapper, token
assert 'forcing_registry(forcing_index)' in wrapper
# The production delta may refactor transaction ownership but may not add drainage science or a second mass-booking route.
diff=subprocess.check_output(['git','diff','--unified=0',base+'..'+materialized,'--',path],text=True)
added='\n'.join(line[1:] for line in diff.splitlines() if line.startswith('+') and not line.startswith('+++')).lower()
for forbidden in ('mod_drainage_spatial_distribution','modflow','.swp','mass%total_in =','mass%total_out =','mass%storage_change ='):
    assert forbidden not in added, forbidden
print('FVQ55_RESOLVED_SEAM_STATIC_BOUNDARY=PASS')
print('FVQ55_NO_SECOND_MASS_BOOKING_PATH=PASS')
print('FVQ55_NO_DRAINAGE_SPECIFIC_EXECUTOR_SCOPE_GROWTH=PASS')
PY

# 4. Materialize independent historical regression fixtures by exact blob, not by owner-branch test files.
git cat-file blob "$FMQ26_BLOB" > "$BUILD/fmq26.f90"
[[ "$(git hash-object "$BUILD/fmq26.f90")" == "$FMQ26_BLOB" ]] || fail 'FMQ26 immutable fixture blob mismatch'
git cat-file blob "$FVQ51_TEST_BLOB" > "$BUILD/fvq51-source.f90"
[[ "$(git hash-object "$BUILD/fvq51-source.f90")" == "$FVQ51_TEST_BLOB" ]] || fail 'FVQ51 immutable fixture blob mismatch'
cp "$BUILD/fvq51-source.f90" "$BUILD/fvq51.f90"
# Historical FVQ51 fixture has one reallocation-only harness defect. Keep the source blob locked, then derive a local non-production repair.
python3 - "$BUILD/fvq51.f90" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
s=s.replace('    allocate(req(', '    if (allocated(req)) deallocate(req)\n    allocate(req(')
p.write_text(s)
PY

echo 'FVQ55_IMMUTABLE_REGRESSION_FIXTURES=PASS'

# 5. Held-out direct executor attack derived independently from the admitted FMQ26 fixture.
cp "$BUILD/fmq26.f90" "$BUILD/heldout.f90"
python3 - "$BUILD/heldout.f90" <<'PY'
from pathlib import Path
import re, sys
p=Path(sys.argv[1]); s=p.read_text()
def one(old,new,label):
    global s
    n=s.count(old)
    if n != 1: raise SystemExit(f'{label}: expected one occurrence got {n}')
    s=s.replace(old,new,1)
one('program test_fmq26_parallel_v1_admission','program test_fvq55_effective_forcing_executor','program')
one('end program test_fmq26_parallel_v1_admission','end program test_fvq55_effective_forcing_executor','end program')
one('  use mod_kernel_transactions, only: kernel_committed_state_t\n',
    '  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t\n','kernel executor import')
one('       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state\n',
    '       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state, fmr_serialized_reference_backend_t\n','backend import')
one('       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK\n',
    '       fmr_run_serialized_physical_multiswap, fmr_execute_serialized_physical_column, &\n       fmr_execute_serialized_resolved_physical_column, FMR_SERIAL_DISPATCH_OK\n','runtime imports')
one('  do k = 1, ncases\n',
    "  call run_fvq55_effective_forcing_matrix()\n  write(*,'(A)') 'FVQ55_HELDOUT_EFFECTIVE_FORCING_MATRIX=PASS'\n\n  do k = 1, ncases\n",'main heldout call')
needle='  subroutine run_positive_case(n, batch_size, order_code)\n'
if needle not in s: raise SystemExit('heldout insertion point missing')
helper=r'''  subroutine run_fvq55_effective_forcing_matrix()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(1)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), forcing_snapshot(:)
    type(fmr_b110_physical_forcing_t) :: effective_forcing
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: s_registry(:), s_resolved(:), s_override_a(:), s_override_b(:)
    type(fmr_serialized_column_result_t) :: r_registry, r_resolved, r_override_a, r_override_b
    type(fmr_column_diagnostics_t) :: d_registry, d_resolved, d_override_a, d_override_b
    type(fmr_serialized_batch_diagnostics_t) :: rt_registry, rt_resolved, rt_override_a, rt_override_b
    type(fmr_serialized_reference_backend_t) :: b_registry, b_resolved, b_override_a, b_override_b
    type(kernel_executor_t) :: tx_registry, tx_resolved, tx_override_a, tx_override_b
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t) :: config
    real(real64) :: conductivity0
    integer :: active_registry, active_resolved, active_override_a, active_override_b

    call build_fixture(3,columns,templates,parameters,forcings,seed,conductivity0)
    forcing_snapshot = forcings
    call configure_transaction(config)
    call initialize_states(s_registry,columns,seed)
    call initialize_states(s_resolved,columns,seed)
    call initialize_states(s_override_a,columns,seed)
    call initialize_states(s_override_b,columns,seed)
    call b_registry%initialize(top_provider)
    call b_resolved%initialize(top_provider)
    call b_override_a%initialize(top_provider)
    call b_override_b%initialize(top_provider)
    active_registry=0; active_resolved=0; active_override_a=0; active_override_b=0

    ! Inactive/base path: registry handle 2 must be exactly the same execution as explicitly supplying registry row 2.
    call fmr_execute_serialized_physical_column(b_registry,tx_registry,columns(2),templates,parameters,forcings, &
         s_registry,config,t0,t1,r_registry,d_registry,rt_registry,active_registry)
    call fmr_execute_serialized_resolved_physical_column(b_resolved,tx_resolved,columns(2),templates(1),parameters(1), &
         forcings(2),s_resolved(2),config,t0,t1,r_resolved,d_resolved,rt_resolved,active_resolved)
    call require(r_registry%committed .and. r_resolved%committed,'heldout base executions commit')
    call require(column_result_identical(r_registry,r_resolved),'registry-selected forcing equals resolved selected forcing')
    call require(diagnostic_semantic(d_registry,d_resolved),'registry-selected forcing diagnostic identity')
    call require(committed_state_identical(s_registry(2),s_resolved(2)),'registry-selected forcing state identity')
    call require(runtime_semantically_identical(rt_registry,rt_resolved),'registry-selected forcing runtime identity')
    call require(active_registry==0 .and. active_resolved==0,'base active-call counters close')
    call require(forcing_registry_identical(forcings,forcing_snapshot),'base forcing registry immutable')

    ! Active effective-forcing path: keep column forcing_handle=2 but explicitly supply independently valid row 3.
    call require(columns(2)%forcing_handle==2_int64,'heldout forcing handle fixed at two')
    effective_forcing = forcings(3)
    call require(.not. forcing_identical(effective_forcing,forcings(2)),'heldout effective forcing differs from registered row')
    call fmr_execute_serialized_resolved_physical_column(b_override_a,tx_override_a,columns(2),templates(1),parameters(1), &
         effective_forcing,s_override_a(2),config,t0,t1,r_override_a,d_override_a,rt_override_a,active_override_a)
    call fmr_execute_serialized_resolved_physical_column(b_override_b,tx_override_b,columns(2),templates(1),parameters(1), &
         effective_forcing,s_override_b(2),config,t0,t1,r_override_b,d_override_b,rt_override_b,active_override_b)
    call require(r_override_a%committed .and. r_override_b%committed,'valid explicit effective forcing commits')
    call require(r_override_a%mass%complete .and. r_override_b%mass%complete,'effective forcing mass complete')
    call require(abs(r_override_a%mass%residual)<=hard_mass_gate .and. abs(r_override_b%mass%residual)<=hard_mass_gate, &
         'effective forcing hard mass')
    call require(column_result_identical(r_override_a,r_override_b),'effective forcing deterministic replay result')
    call require(diagnostic_semantic(d_override_a,d_override_b),'effective forcing deterministic replay diagnostic')
    call require(committed_state_identical(s_override_a(2),s_override_b(2)),'effective forcing deterministic replay state')
    call require(runtime_semantically_identical(rt_override_a,rt_override_b),'effective forcing deterministic replay runtime')
    call require(active_override_a==0 .and. active_override_b==0,'override active-call counters close')
    call require(columns(2)%forcing_handle==2_int64,'effective forcing does not mutate logical forcing handle')
    call require(forcing_registry_identical(forcings,forcing_snapshot),'effective forcing leaves shared registry immutable')
  end subroutine run_fvq55_effective_forcing_matrix

  logical function forcing_registry_identical(left,right) result(equal)
    type(fmr_b110_physical_forcing_t), intent(in) :: left(:),right(:)
    integer :: j
    equal=size(left)==size(right); if(.not.equal)return
    do j=1,size(left)
      if(.not.forcing_identical(left(j),right(j)))then; equal=.false.; return; end if
    end do
  end function forcing_registry_identical

  logical function forcing_identical(left,right) result(equal)
    type(fmr_b110_physical_forcing_t), intent(in) :: left,right
    equal=same_bits(left%top_flux,right%top_flux) .and. same_bits(left%top_head,right%top_head) .and. &
         same_bits(left%bottom_flux,right%bottom_flux) .and. same_bits(left%bottom_head,right%bottom_head)
    if(.not.equal)return
    equal=allocated(left%drainage_flux_by_level).eqv.allocated(right%drainage_flux_by_level); if(.not.equal)return
    if(allocated(left%drainage_flux_by_level))then
      equal=all(left%drainage_flux_by_level==right%drainage_flux_by_level); if(.not.equal)return
    end if
    equal=allocated(left%subsurface_irrigation_source).eqv.allocated(right%subsurface_irrigation_source); if(.not.equal)return
    if(allocated(left%subsurface_irrigation_source))then
      equal=all(left%subsurface_irrigation_source==right%subsurface_irrigation_source); if(.not.equal)return
    end if
    equal=allocated(left%root_extraction_sink).eqv.allocated(right%root_extraction_sink); if(.not.equal)return
    if(allocated(left%root_extraction_sink)) equal=all(left%root_extraction_sink==right%root_extraction_sink)
  end function forcing_identical

'''
s=s.replace(needle,helper+needle,1)
p.write_text(s)
PY

echo 'FVQ55_HELDOUT_TEST_DERIVED_FROM_INDEPENDENT_FMQ26_FIXTURE=PASS'

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
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done
  obj="$OUT/mod_fmr_serialized_multiswap_runtime.o"
  gfortran "${STRICT[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$RUNTIME" -o "$obj"
  objects+=("$obj")
  for src in "${POST_RUNTIME[@]}"; do
    obj="$OUT/$(basename "${src%.*}").o"
    gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$src" -o "$obj"
    objects+=("$obj")
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fmq26.f90" -o "$OUT/fmq26.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fmq26.o" -o "$OUT/fmq26"
  "$OUT/fmq26" > "$OUT/fmq26.txt" 2>&1 || { cat "$OUT/fmq26.txt" >&2; fail "FMQ26 replay O$opt"; }
  for marker in FMQ26_INPUT_ORDER_INDEPENDENCE=PASS FMQ26_REJECTION_AT_BATCH_BOUNDARY=PASS FMQ26_REJECTION_INTERIOR=PASS FMQ26_TWO_WORKER_SEPARATED_REJECTIONS=PASS FMQ26_HARD_MASS_ALL_CASES=PASS FMQ26_DETERMINISTIC_REPLAY=PASS 'FMQ26_PARALLEL_V1_ADMISSION_TEST PASS'; do
    grep -Fq "$marker" "$OUT/fmq26.txt" || fail "FMQ26 missing marker $marker O$opt"
  done

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/heldout.f90" -o "$OUT/heldout.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/heldout.o" -o "$OUT/heldout"
  "$OUT/heldout" > "$OUT/heldout.txt" 2>&1 || { cat "$OUT/heldout.txt" >&2; fail "heldout executor matrix O$opt"; }
  grep -Fq 'FVQ55_HELDOUT_EFFECTIVE_FORCING_MATRIX=PASS' "$OUT/heldout.txt" || fail "heldout marker O$opt"

  gfortran "${COMMON[@]}" -O"$opt" -J "$OUT" -I "$OUT" -c "$BUILD/fvq51.f90" -o "$OUT/fvq51.o"
  gfortran -fopenmp -O"$opt" "${objects[@]}" "$OUT/fvq51.o" -o "$OUT/fvq51"
  "$OUT/fvq51" > "$OUT/fvq51.txt" 2>&1 || { cat "$OUT/fvq51.txt" >&2; fail "serialized active DIVDRA replay O$opt"; }
  grep -Fq 'FVQ51_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS' "$OUT/fvq51.txt" || fail "FVQ51 pass marker O$opt"
  [[ "$(grep -c '^FVQ51_SINGLE ' "$OUT/fvq51.txt")" == 12 ]] || fail "FVQ51 12-case count O$opt"
  fvhash="$(sha256sum "$OUT/fvq51.txt" | awk '{print $1}')"
  [[ "$fvhash" == "$FVQ51_EXPECTED_HASH" ]] || fail "FVQ51 output drift O$opt expected=$FVQ51_EXPECTED_HASH actual=$fvhash"
  echo "FVQ55_O${opt}_MATRIX=PASS"
done

cmp -s "$BUILD/o0/fmq26.txt" "$BUILD/o2/fmq26.txt" || fail 'parallel-V1 O0/O2 output drift'
cmp -s "$BUILD/o0/heldout.txt" "$BUILD/o2/heldout.txt" || fail 'heldout executor O0/O2 output drift'
cmp -s "$BUILD/o0/fvq51.txt" "$BUILD/o2/fvq51.txt" || fail 'serialized active DIVDRA O0/O2 output drift'
echo "FVQ55_FMQ26_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fmq26.txt" | awk '{print $1}')"
echo "FVQ55_HELDOUT_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/heldout.txt" | awk '{print $1}')"
echo "FVQ55_FVQ51_OUTPUT_SHA256=$(sha256sum "$BUILD/o0/fvq51.txt" | awk '{print $1}')"
echo 'FVQ55_CHANGED_CALLER_ORDER=PASS'
echo 'FVQ55_MULTIPLE_COLUMNS=PASS'
echo 'FVQ55_REJECTED_TRIAL_ROLLBACK=PASS'
echo 'FVQ55_FORCING_HANDLE_IDENTITY=PASS'
echo 'FVQ55_FORCING_REGISTRY_IMMUTABILITY=PASS'
echo 'FVQ55_NO_SHARED_FORCING_MUTATION=PASS'
echo 'FVQ55_VALID_EFFECTIVE_FORCING=PASS'
echo 'FVQ55_INACTIVE_FORCING_PATH=PASS'
echo 'FVQ55_DETERMINISTIC_REPLAY=PASS'
echo 'FVQ55_PARALLEL_V1_REPLAY=PASS'
echo 'FVQ55_SERIALIZED_ACTIVE_DIVDRA_REPLAY=PASS'
echo 'FVQ55_HARD_MASS=PASS'
echo 'FVQ55_O0_O2_IDENTITY=PASS'
echo 'FVQ55_GATE=PASS'
