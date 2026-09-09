from pathlib import Path
import hashlib
import subprocess

TEST = Path('tests/fmr/test_fmr20_parallel_v1_qualification.f90')
RUNNER = Path('tests/fmr/run_fmr20_parallel_v1_qualification.sh')
EXPECTED_TEST_BLOB = 'b1e9ff7933d4da0957ecd39fe84a0ae3121a6bf9'


def git_blob_sha(path: Path) -> str:
    return subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()

if git_blob_sha(TEST) != EXPECTED_TEST_BLOB:
    raise SystemExit('FMR20_V1_REJECT_G01_PREIMAGE_LOCK=FAIL')
print('FMR20_V1_REJECT_G01_PREIMAGE_LOCK=PASS')

text = TEST.read_text()
old = """  call require(pool_status == FMR_PARALLEL_POOL_OK, 'perturbed 4-worker status')
  call require(all_committed(results_perturbed), 'perturbed all committed')
  call require(max_abs_residual(results_perturbed) <= hard_mass_gate, 'perturbed hard mass gate')
  do i = 1, ncol
    if (i == perturb_index) cycle
    call require(column_result_identical(results_4(i), results_perturbed(i)), 'cross-column result isolation')
    call require(committed_state_identical(states_4(i), states_perturbed(i)), 'cross-column state isolation')
  end do
  call require(.not. column_result_identical(results_4(perturb_index), results_perturbed(perturb_index)) .or. &
       .not. committed_state_identical(states_4(perturb_index), states_perturbed(perturb_index)), 'perturbation observable')
  write(*,'(A)') 'FMR20_V1_CROSS_COLUMN_ISOLATION=PASS'
"""
new = """  call require(pool_status == FMR_PARALLEL_POOL_OK, 'perturbed 4-worker status')
  call require(runtime_perturbed%number_committed == ncol-1 .and. runtime_perturbed%number_rejected == 1, &
       'perturbed local rejection cardinality')
  call require(max_abs_residual(results_perturbed) <= hard_mass_gate, 'perturbed committed-column hard mass gate')
  do i = 1, ncol
    if (i == perturb_index) cycle
    call require(results_perturbed(i)%committed, 'perturbed unaffected column committed')
    call require(column_result_identical(results_4(i), results_perturbed(i)), 'cross-column result isolation')
    call require(committed_state_identical(states_4(i), states_perturbed(i)), 'cross-column state isolation')
  end do
  call require(.not. results_perturbed(perturb_index)%committed, 'perturbed target locally rejected')
  call require(committed_state_identical(states_perturbed(perturb_index), states_reject_reference(perturb_index)), &
       'perturbed target rollback nonmutation')
  call require(.not. column_result_identical(results_4(perturb_index), results_perturbed(perturb_index)), &
       'perturbed target rejection observable')
  write(*,'(A)') 'FMR20_V1_CROSS_COLUMN_REJECTION_ISOLATION=PASS'
"""
if text.count(old) != 1:
    raise SystemExit('FMR20_V1_REJECT_G02_REJECTION_BLOCK_EXACT=FAIL')
text = text.replace(old, new)

replacements = {
    'left%admission_assessed .eqv. right%admission_assessed': '(left%admission_assessed .eqv. right%admission_assessed)',
    'left%admitted .eqv. right%admitted': '(left%admitted .eqv. right%admitted)',
    'left%completed .eqv. right%completed': '(left%completed .eqv. right%completed)',
    'left%committed .eqv. right%committed': '(left%committed .eqv. right%committed)',
    'left%solver_executed .eqv. right%solver_executed': '(left%solver_executed .eqv. right%solver_executed)',
    'left%final_committed_time_bound .eqv. right%final_committed_time_bound': '(left%final_committed_time_bound .eqv. right%final_committed_time_bound)',
    'left%complete .eqv. right%complete': '(left%complete .eqv. right%complete)',
    'allocated(left(i)%worker_assignments) .neqv. allocated(right(j)%worker_assignments)': '(allocated(left(i)%worker_assignments) .neqv. allocated(right(j)%worker_assignments))',
    'left%committed_time_bound .eqv. right%committed_time_bound': '(left%committed_time_bound .eqv. right%committed_time_bound)',
    'left(i)%root_extraction_active .neqv. right(i)%root_extraction_active': '(left(i)%root_extraction_active .neqv. right(i)%root_extraction_active)',
    'left(i)%macropore_active .neqv. right(i)%macropore_active': '(left(i)%macropore_active .neqv. right(i)%macropore_active)',
    'left(i)%snow_active .neqv. right(i)%snow_active': '(left(i)%snow_active .neqv. right(i)%snow_active)',
    'left(i)%hysteresis_active .neqv. right(i)%hysteresis_active': '(left(i)%hysteresis_active .neqv. right(i)%hysteresis_active)',
    'left(i)%tabulated_hydraulics_active .neqv. right(i)%tabulated_hydraulics_active': '(left(i)%tabulated_hydraulics_active .neqv. right(i)%tabulated_hydraulics_active)',
    'left(i)%elasticity_active .neqv. right(i)%elasticity_active': '(left(i)%elasticity_active .neqv. right(i)%elasticity_active)',
    'left(i)%frost_active .neqv. right(i)%frost_active': '(left(i)%frost_active .neqv. right(i)%frost_active)',
    'allocated(left(i)%snow) .neqv. allocated(right(i)%snow)': '(allocated(left(i)%snow) .neqv. allocated(right(i)%snow))',
    'lb .eqv. rb': '(lb .eqv. rb)',
}
for old_token, new_token in replacements.items():
    count = text.count(old_token)
    if count < 1:
        raise SystemExit(f'FMR20_V1_REJECT_G03_LOGICAL_PARENTHESES=FAIL missing {old_token}')
    text = text.replace(old_token, new_token)

TEST.write_text(text)
new_blob = git_blob_sha(TEST)
print('FMR20_V1_REJECT_G02_REJECTION_BLOCK_EXACT=PASS')
print('FMR20_V1_REJECT_G03_LOGICAL_PARENTHESES=PASS')
print('FMR20_V1_REJECT_TEST_POSTIMAGE=' + new_blob)

runner = RUNNER.read_text()
if runner.count(EXPECTED_TEST_BLOB) != 1:
    raise SystemExit('FMR20_V1_REJECT_G04_RUNNER_LOCK_UPDATE=FAIL')
runner = runner.replace(EXPECTED_TEST_BLOB, new_blob)
if runner.count('FMR20_V1_CROSS_COLUMN_ISOLATION=PASS') != 1:
    raise SystemExit('FMR20_V1_REJECT_G04_RUNNER_MARKER_UPDATE=FAIL')
runner = runner.replace('FMR20_V1_CROSS_COLUMN_ISOLATION=PASS', 'FMR20_V1_CROSS_COLUMN_REJECTION_ISOLATION=PASS')
RUNNER.write_text(runner)
print('FMR20_V1_REJECT_G04_RUNNER_LOCK_AND_MARKER_UPDATE=PASS')

# Trigger-only comment: the materialization logic above is unchanged.
