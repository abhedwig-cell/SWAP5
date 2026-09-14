from pathlib import Path
import textwrap


def once(path, old, new):
    p = Path(path)
    text = p.read_text()
    n = text.count(old)
    if n != 1:
        raise SystemExit(f"FCI68_PATCH_ANCHOR_MISMATCH {path} count={n} anchor={old[:80]!r}")
    p.write_text(text.replace(old, new, 1))
    print(f"FCI68_PATCHED {path}")

# Kernel: expose the already-admitted F-CI66 selector only as an optional tail
# argument.  Omitting it executes the exact previous call.
K = 'src/kernel/mod_kernel_transactions.f90'
once(K,
     '  use mod_canonical_interval_runtime, only: run_canonical_interval\n',
     '  use mod_canonical_interval_runtime, only: run_canonical_interval, canonical_subinterval_target_selector\n')
once(K,
'''  subroutine kernel_advance_interval(self, parameters, committed_state, forcing, numerical_config, t0, t1, &
                                     result, candidate_state, diagnostics, checkpoint)
''',
'''  subroutine kernel_advance_interval(self, parameters, committed_state, forcing, numerical_config, t0, t1, &
                                     result, candidate_state, diagnostics, checkpoint, target_selector)
''')
once(K,
'''    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_checkpoint_t), intent(in), optional :: checkpoint

    class(transaction_state_t), allocatable :: working
''',
'''    type(kernel_diagnostics_t), intent(out) :: diagnostics
    type(kernel_checkpoint_t), intent(in), optional :: checkpoint
    procedure(canonical_subinterval_target_selector), optional :: target_selector

    class(transaction_state_t), allocatable :: working
''')
once(K,
'''    interval%t0 = t0
    interval%t1 = t1
    call run_canonical_interval(self%model, working, forcing, interval, numerical_config, runtime_result)

    call map_runtime_result(runtime_result, result)
''',
'''    interval%t0 = t0
    interval%t1 = t1
    if (present(target_selector)) then
      call run_canonical_interval(self%model, working, forcing, interval, numerical_config, runtime_result, target_selector)
    else
      call run_canonical_interval(self%model, working, forcing, interval, numerical_config, runtime_result)
    end if

    call map_runtime_result(runtime_result, result)
''')

# Checkpoint bridge: generic optional forwarding only.
C = 'src/runtime/mod_fmr_checkpoint_orchestrator.f90'
once(C,
'''  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
''',
'''  use mod_canonical_contracts, only: canonical_forcing_t, canonical_numerical_config_t
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_committed_state_t, kernel_checkpoint_t, &
''')
once(C,
'''  subroutine fmr_trial_from_checkpoint(kernel, parameters, committed_state, forcing, numerical_config, &
                                       t0, t1, checkpoint, result, candidate_state, diagnostics)
''',
'''  subroutine fmr_trial_from_checkpoint(kernel, parameters, committed_state, forcing, numerical_config, &
                                       t0, t1, checkpoint, result, candidate_state, diagnostics, target_selector)
''')
once(C,
'''    type(kernel_candidate_state_t), intent(out) :: candidate_state
    type(kernel_diagnostics_t), intent(out) :: diagnostics

    call kernel%advance_interval(parameters, committed_state, forcing, numerical_config, t0, t1, &
         result, candidate_state, diagnostics, checkpoint)
''',
'''    type(kernel_candidate_state_t), intent(out) :: candidate_state
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    procedure(canonical_subinterval_target_selector), optional :: target_selector

    if (present(target_selector)) then
      call kernel%advance_interval(parameters, committed_state, forcing, numerical_config, t0, t1, &
           result, candidate_state, diagnostics, checkpoint, target_selector)
    else
      call kernel%advance_interval(parameters, committed_state, forcing, numerical_config, t0, t1, &
           result, candidate_state, diagnostics, checkpoint)
    end if
''')

# Concrete serialized backend: transport only, no scheduling semantics.
B = 'src/runtime/mod_fmr_serialized_reference_backend.f90'
once(B,
'''  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
''',
'''  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
''')
once(B,
'''  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics)
''',
'''  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics, target_selector)
''')
once(B,
'''    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    logical :: bottom_thermal_ok
''',
'''    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    procedure(canonical_subinterval_target_selector), optional :: target_selector
    logical :: bottom_thermal_ok
''')
once(B,
'''    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
''',
'''    if (present(target_selector)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector)
    else
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
    end if
''')

# Resolved serialized worker seam.  Existing batch/energy callers omit the
# selector and therefore preserve their current semantics.
M = 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
once(M,
'''  use mod_canonical_contracts, only: canonical_mass_accounting_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
''',
'''  use mod_canonical_contracts, only: canonical_mass_accounting_t, canonical_numerical_config_t
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
''')
once(M,
'''  subroutine fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
                                                              effective_forcing, committed_state, numerical_config, t0, t1, &
                                                              output, diagnostic, runtime, active_physical_calls)
''',
'''  subroutine fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
                                                              effective_forcing, committed_state, numerical_config, t0, t1, &
                                                              output, diagnostic, runtime, active_physical_calls, target_selector)
''')
once(M,
'''    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls

    if (.not. resolved_column_is_routable(column, template)) then
''',
'''    type(fmr_serialized_batch_diagnostics_t), intent(inout) :: runtime
    integer, intent(inout) :: active_physical_calls
    procedure(canonical_subinterval_target_selector), optional :: target_selector

    if (.not. resolved_column_is_routable(column, template)) then
''')
once(M,
'''    call execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
         committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
  end subroutine fmr_execute_serialized_resolved_physical_column
''',
'''    if (present(target_selector)) then
      call execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
           committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls, &
           target_selector=target_selector)
    else
      call execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
           committed_state, numerical_config, t0, t1, output, diagnostic, runtime, active_physical_calls)
    end if
  end subroutine fmr_execute_serialized_resolved_physical_column
''')
once(M,
'''  subroutine execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
                                     committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
                                     active_physical_calls, commit_receipt, bottom_energy_parameters, &
                                     bottom_thermal_provider, bottom_energy_publication)
''',
'''  subroutine execute_resolved_column(backend, transaction_control, column, template, parameters, effective_forcing, &
                                     committed_state, numerical_config, t0, t1, output, diagnostic, runtime, &
                                     active_physical_calls, commit_receipt, bottom_energy_parameters, &
                                     bottom_thermal_provider, bottom_energy_publication, target_selector)
''')
once(M,
'''    procedure(fmr_external_bottom_thermal_provider_i), optional :: bottom_thermal_provider
    type(fmr_serialized_bottom_energy_publication_t), intent(out), optional :: bottom_energy_publication

    type(kernel_checkpoint_t) :: checkpoint
''',
'''    procedure(fmr_external_bottom_thermal_provider_i), optional :: bottom_thermal_provider
    type(fmr_serialized_bottom_energy_publication_t), intent(out), optional :: bottom_energy_publication
    procedure(canonical_subinterval_target_selector), optional :: target_selector

    type(kernel_checkpoint_t) :: checkpoint
''')
once(M,
'''    call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
         numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)
''',
'''    if (present(target_selector)) then
      call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag, target_selector)
    else
      call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)
    end if
''')

runner = r'''#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fci68-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
cd "$ROOT"
TEST=tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90
cp "$TEST" "$BUILD/original_test.f90"
cleanup(){ cp "$BUILD/original_test.f90" "$TEST" 2>/dev/null || true; rm -rf "$BUILD"; }
trap cleanup EXIT

# Exact absent-selector production regression.
bash tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh | tee "$BUILD/absent.log"
grep -Fq 'FMR44R_QUALIFICATION_GATE=PASS' "$BUILD/absent.log"

# Present-selector routing proof: only the test caller is temporarily changed.
python3 - <<'PYTEST'
from pathlib import Path
p=Path('tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90')
t=p.read_text()
def o(a,b):
    global t
    n=t.count(a)
    if n != 1: raise SystemExit(f'FCI68_TEST_PATCH_ANCHOR_MISMATCH count={n} anchor={a[:70]!r}')
    t=t.replace(a,b,1)
o('  real(real64) :: k0, qeq\n','  real(real64) :: k0, qeq\n  integer :: fci68_selector_calls = 0\n')
o("  call verify_unowned_mode_rejected(qeq)\n\n  write(*,'(A,ES26.17E3)') 'FMR44R_QEQ=', qeq\n",
  "  call verify_unowned_mode_rejected(qeq)\n  call require(fci68_selector_calls > 0, 'F-CI68 selector propagated through resolved serialized seam')\n  write(*,'(A,I0)') 'FCI68_SELECTOR_CALLS=', fci68_selector_calls\n  write(*,'(A)') 'FCI68_SELECTOR_PROPAGATION=PASS'\n\n  write(*,'(A,ES26.17E3)') 'FMR44R_QEQ=', qeq\n")
o('''    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls)
''','''    call fmr_execute_serialized_resolved_physical_column(backend, transaction_control, column, template, parameters, &
         forcing, committed, config, 0.0_real64, duration, output, diagnostic, runtime, active_physical_calls, &
         target_selector=fci68_identity_selector)
''')
o('''  subroutine initialize_parameters(parameters, bottom_mode)
''','''  subroutine fci68_identity_selector(cursor, requested_t1, target_t1, max_retries_cap, valid)
    real(real64), intent(in) :: cursor, requested_t1
    real(real64), intent(out) :: target_t1
    integer, intent(out) :: max_retries_cap
    logical, intent(out) :: valid
    fci68_selector_calls = fci68_selector_calls + 1
    target_t1 = requested_t1
    max_retries_cap = 8
    valid = requested_t1 > cursor
  end subroutine fci68_identity_selector

  subroutine initialize_parameters(parameters, bottom_mode)
''')
p.write_text(t)
PYTEST
bash tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh | tee "$BUILD/present.log"
grep -Fq 'FCI68_SELECTOR_PROPAGATION=PASS' "$BUILD/present.log"
grep -Eq 'FCI68_SELECTOR_CALLS=[1-9][0-9]*' "$BUILD/present.log"
cp "$BUILD/original_test.f90" "$TEST"

# Reuse immutable admitted authorities.
bash tests/fci/run_fci66_window_target_selector_current_canonical_admission.sh
bash tests/fci/run_fci67_rossfast_d3r_execution_policy_admission.sh

# Generic propagation may not contain RossFast semantics.
if grep -Eiq 'ROSSFAST|ROSS01' src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_checkpoint_orchestrator.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90; then
  echo 'FCI68_STATIC_GATE FAIL: RossFast semantics leaked into generic propagation' >&2; exit 1
fi
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' src/kernel/mod_kernel_transactions.f90
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' src/runtime/mod_fmr_checkpoint_orchestrator.f90
grep -Fq 'procedure(canonical_subinterval_target_selector), optional :: target_selector' src/runtime/mod_fmr_serialized_reference_backend.f90
grep -Fq 'target_selector=target_selector' src/runtime/mod_fmr_serialized_multiswap_runtime.f90
git diff --check -- src/kernel/mod_kernel_transactions.f90 src/runtime/mod_fmr_checkpoint_orchestrator.f90 src/runtime/mod_fmr_serialized_reference_backend.f90 src/runtime/mod_fmr_serialized_multiswap_runtime.f90 tests/fci/run_fci68_fmr_selector_propagation.sh
echo 'FCI68_GENERIC_SELECTOR_PROPAGATION_QUALIFICATION=PASS'
'''
Path('tests/fci/run_fci68_fmr_selector_propagation.sh').write_text(runner)

workflow = '''name: F-CI68 FMR selector propagation qualification
on:
  push:
    branches: [work/f-ci68-fmr-selector-propagation, integration/f-ci-canonical]
    paths:
      - 'src/kernel/mod_kernel_transactions.f90'
      - 'src/runtime/mod_fmr_checkpoint_orchestrator.f90'
      - 'src/runtime/mod_fmr_serialized_reference_backend.f90'
      - 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
      - 'src/runtime/mod_canonical_interval_runtime.f90'
      - 'src/runtime/mod_rossfast_d3r_execution_policy.f90'
      - 'tests/fci/run_fci68_fmr_selector_propagation.sh'
      - 'tests/fci/run_fci66_window_target_selector_current_canonical_admission.sh'
      - 'tests/fci/run_fci67_rossfast_d3r_execution_policy_admission.sh'
      - 'tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh'
      - 'tests/fmr/test_fmr44r_serialized_prescribed_qbot_runtime.f90'
      - 'integration/f-ci/FCI68_EVIDENCE.json'
      - 'integration/f-ci/FCI68_STATUS.json'
      - '.github/workflows/fci68-fmr-selector-propagation.yml'
  pull_request:
    paths:
      - 'src/kernel/mod_kernel_transactions.f90'
      - 'src/runtime/mod_fmr_checkpoint_orchestrator.f90'
      - 'src/runtime/mod_fmr_serialized_reference_backend.f90'
      - 'src/runtime/mod_fmr_serialized_multiswap_runtime.f90'
      - 'src/runtime/mod_canonical_interval_runtime.f90'
      - 'src/runtime/mod_rossfast_d3r_execution_policy.f90'
      - 'tests/fci/run_fci68_fmr_selector_propagation.sh'
      - '.github/workflows/fci68-fmr-selector-propagation.yml'
permissions:
  contents: read
jobs:
  qualification:
    runs-on: ubuntu-24.04
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - name: Compiler identity
        run: gfortran --version
      - name: Qualify generic selector propagation through resolved serialized FMR seam
        run: bash tests/fci/run_fci68_fmr_selector_propagation.sh
'''
Path('.github/workflows/fci68-fmr-selector-propagation.yml').write_text(workflow)
Path(__file__).unlink()
print('FCI68_PATCHSET_READY')
