#!/usr/bin/env python3
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]

EXPECTED = {
    'src/transaction/mod_transaction_reference.f90': '4a573316b77252b56bcb429fd519aa57123e9a06',
    'src/runtime/mod_a23bu_worker_execution_context.f90': '2a190d206200ad201c37c9a82d3e32e651d37a37',
    'src/adapter/mod_b1_10_process_checkpoint.f90': '4084f979d86e0a97d2b7b570af38ad44d85dca6c',
    'src/adapter/mod_b1_10_transaction_binding.f90': 'c832de128186be34a7eafd9ad744ab3d2ecfa3c5',
    'src/adapter/mod_b1_10_mass_seam.f90': '4b205a9b7df465deffe5a34349da91f2102f3f51',
    'src/adapter/mod_b1_10_trial_mass.f90': 'b1a4bb35f6bd2050c72b49203630287df78e0021',
    'src/adapter/mod_b1_10_interval_seam.f90': '1801fe492c4986a1de0226b2049abe8945e87367',
    'src/legacy/b1_10_fci11_port/swap_part04.inc': '69395d5e01eed58e96fec9d5879cf416abc69154',
    'src/legacy/b1_10_fci11_port/swap_part05.inc': 'beb729ff8b399c5522c9e54a7a8429bb0a1504e5',
    'src/legacy/b1_10_fci11_port/swap_part06.inc': 'a69c24fbce2768b1f6310b403fe2562ada46c4ec',
    'src/adapter/mod_b1_10_physical_interval_executor.f90': '6097e9e338ed823fe89f5e2d854992e0d3e4b798',
    'src/adapter/mod_b1_10_temporal_characterization.f90': 'dd41426fcbea2d009613050aa94988885ae24f8b',
    'src/adapter/mod_b1_10_reference_model.f90': '366a4df93a829413bed552b050ca723544e31ce4',
}

for rel, expected in EXPECTED.items():
    path = ROOT / rel
    got = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
    if got != expected:
        raise SystemExit(f'F-CI12 provenance pin mismatch: {rel} {got} != {expected}')

executor = (ROOT / 'src/adapter/mod_b1_10_physical_interval_executor.f90').read_text().lower()
temporal = (ROOT / 'src/adapter/mod_b1_10_temporal_characterization.f90').read_text().lower()
reference = (ROOT / 'src/adapter/mod_b1_10_reference_model.f90').read_text().lower()
swap4 = (ROOT / 'src/legacy/b1_10_fci11_port/swap_part04.inc').read_text().lower()
swap5 = (ROOT / 'src/legacy/b1_10_fci11_port/swap_part05.inc').read_text().lower()
swap6 = (ROOT / 'src/legacy/b1_10_fci11_port/swap_part06.inc').read_text().lower()

new_source = '\n'.join([executor, temporal, reference])
checks = {
    'executor_uses_generic_interval': 'begin_b1_10_interval(interval, t0, t1)' in executor,
    'executor_uses_unrounded_trial_mass': 'begin_b1_10_trial_mass(trial_mass)' in executor,
    'executor_prepares_task22': 'call swap(0, 22' in executor,
    'executor_runs_task2': 'call swap(0, 2' in executor,
    'executor_passes_worker_mass_interval': 'worker=worker, trial_mass=trial_mass, interval=interval' in executor,
    'executor_resets_attempt_diagnostics': 'a23bu_reset_attempt_diagnostics(worker)' in executor,
    'executor_resets_attempt_control': 'a23bu_reset_attempt_control(worker)' in executor,
    'executor_has_no_file_io': not re.search(r'\b(open|read|write)\s*\(', executor),
    'reference_extends_fci09_binding': 'extends(b1_10_transaction_model_t)' in reference,
    'reference_enables_generic_advance': 'generic_interval_advance = .true.' in reference,
    'reference_enables_trial_mass': 'trial_mass_flux_contract = .true.' in reference,
    'reference_enables_qualified_storage': 'mass_storage_contract = .true.' in reference,
    'reference_keeps_scalar_temporal_blocked': 'temporal_error_contract = .false.' in reference,
    'reference_keeps_recoverable_solver_failure_blocked': 'recoverable_solver_failure_status = .false.' in reference,
    'reference_keeps_scalar_policy_blocked': 'scalar_temporal_error_policy = .false.' in reference,
    'advance_restores_trial_start': reference.count('restore_b1_10_process_state(physical)') >= 2,
    'advance_captures_only_success_poststate': 'call capture_b1_10_process_state(physical)' in reference,
    'advance_returns_unrounded_mass': 'outcome%mass_in = trial_mass%total_in' in reference and 'outcome%mass_out = trial_mass%total_out' in reference,
    'storage_uses_fci10_seam': 'b1_10_qualified_profile_storage' in reference,
    'temporal_scalar_fail_closed': 'scalar temporal error policy not admitted' in reference,
    'reference_execution_requires_solver_status': 'reference_capabilities%recoverable_solver_failure_status' in reference,
    'reference_execution_requires_temporal_policy': 'reference_capabilities%scalar_temporal_error_policy' in reference,
    'temporal_keeps_head_and_theta_separate': 'max_abs_h_cm' in temporal and 'max_abs_theta' in temporal,
    'temporal_tracks_allocation_mismatch': 'allocation_mismatches' in temporal,
    'temporal_marks_optional_scope_incomplete': 'process_scope_complete = delta%compatible .and. .not. delta%optional_process_state_present' in temporal,
    'no_reference_executor_admission': 'execute_reference_interval' not in new_source,
    'new_source_has_no_file_io': not re.search(r'\b(open|read|write)\s*\(', new_source),
    'fci11_task22_still_present': 'if (itask == 22)' in swap4,
    'fci11_step_mass_still_wired': 'call integral(3, trial_mass)' in swap5,
    'fci11_dayend_mass_still_wired': 'call integral (4, trial_mass)' in swap6,
}
failed = [name for name, ok in checks.items() if not ok]
print({'work_unit': 'F-CI12', 'checks': checks, 'failed': failed})
if failed:
    raise SystemExit(2)
