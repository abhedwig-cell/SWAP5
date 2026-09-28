from pathlib import Path
import re
import subprocess

CANON = "origin/integration/f-ci-canonical"
PPA = "origin/backup/ppa-before-reconcile-20260928"

def git_show(ref, path):
    return subprocess.check_output(["git", "show", f"{ref}:{path}"], text=True)

def extract_subroutine(text, name):
    marker = f"subroutine {name}"
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f"{name}: subroutine start not found")
    # Preserve normal two-space module indentation when present.
    line_start = text.rfind("\n", 0, start) + 1
    end_marker = f"end subroutine {name}"
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"{name}: subroutine end not found")
    end += len(end_marker)
    return text[line_start:end]

def replace_once(text, pattern, repl, label, flags=0):
    out, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        raise SystemExit(f"{label}: expected one replacement, got {n}")
    return out

# 1. Legacy binding: PPA was based on the pre-workspace-component local name.
p = Path("src/adapter/mod_reference_richards_legacy_binding.f90")
s = p.read_text()
s = s.replace("ws%ws%state_binding%", "ws%state_binding%")
s = re.sub(r"(?<!ws%)state_binding%", "ws%state_binding%", s)
p.write_text(s)

# 2. Serialized backend: combine the current prepared-parameter fast path with
# the PPA target-selector continuation route.
p = Path("src/runtime/mod_fmr_serialized_reference_backend.f90")
s = p.read_text()

header = """  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics, &
                                               trusted_prepared_parameters, target_selector)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self"""
s = replace_once(
    s,
    r"  subroutine fmr_serialized_backend_run_trial\(self, column, template, parameters, committed, forcing, config, &\n.*?\n    class\(fmr_serialized_reference_backend_t\), intent\(inout\) :: self",
    header,
    "backend run_trial header",
    re.S,
)

# Forward target_selector by name from the irrigation wrapper so it cannot bind
# to trusted_prepared_parameters.
s = s.replace(
    "         diagnostics,target_selector)\n",
    "         diagnostics,target_selector=target_selector)\n",
)

# Reconcile the post-trial section. The union merge contains both alternatives;
# replace the entire region once with the semantically composed route.
post = """    if (present(target_selector)) then
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics, target_selector)
    else
      call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
           result, candidate, diagnostics)
    end if
    self%model%last_observation%snow_event_evaluation_calls = self%model%snow_event_evaluation_calls
    self%model%last_observation%black_evaporation_evaluation_calls = &
         self%model%black_evaporation_evaluation_calls
    self%model%last_observation%boesten_evaporation_evaluation_calls = &
         self%model%boesten_evaporation_evaluation_calls
    self%model%last_observation%soil_temperature_evaluation_calls = &
         self%model%soil_temperature_evaluation_calls
    self%model%last_observation%drainage_response_evaluation_calls = &
         self%model%drainage_response_evaluation_calls
    self%model%last_observation%common_work_payload_bytes = &
         serialized_common_work_payload_bytes(self%model)
    self%model%last_observation%soil_temperature_optional_payload_bytes = &
         serialized_optional_work_payload_bytes(self%model)
    if (associated(self%model%constitutive)) nullify(self%model%constitutive%parameters)
    nullify(self%model%hydraulic_parameters)
    nullify(self%model%trusted_parameter_source)
    self%model%trusted_prepared_default_mvg = .false.
"""
s = replace_once(
    s,
    r"    call fmr_trial_from_checkpoint\(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &\n.*?(?=    if \(self%model%bottom_thermal_carrier_active)",
    post,
    "backend post-trial composition",
    re.S,
)

# Preserve the canonical trusted-parameter path for pending irrigation too.
s = s.replace(
    "       tcsfix_proposal)\n    class(fmr_serialized_reference_backend_t),intent(inout)::self",
    "       tcsfix_proposal,trusted_prepared_parameters)\n    class(fmr_serialized_reference_backend_t),intent(inout)::self",
)
s = s.replace(
    "    procedure(canonical_subinterval_target_selector),optional::target_selector\n"
    "    class(transaction_state_t),allocatable::snapshot",
    "    procedure(canonical_subinterval_target_selector),optional::target_selector\n"
    "    logical,intent(in),optional::trusted_prepared_parameters\n"
    "    class(transaction_state_t),allocatable::snapshot",
)
s = s.replace(
    "         diagnostics,target_selector=target_selector)\n",
    "         diagnostics,trusted_prepared_parameters=trusted_prepared_parameters,target_selector=target_selector)\n",
)

p.write_text(s)

# 3. MultiSWAP runtime: use canonical structure as the ABI backbone and splice
# the PPA irrigation/free-drainage surfaces into the exact conflicting seams.
multi_path = "src/runtime/mod_fmr_serialized_multiswap_runtime.f90"
p = Path(multi_path)
s = p.read_text()
canon = git_show(CANON, multi_path)
ppa = git_show(PPA, multi_path)

# Main batch signature: retain current canonical optional-argument order and
# append PPA procedure services so existing positional canonical calls remain valid.
main_header = """  subroutine fmr_run_serialized_physical_multiswap(columns, templates, parameter_registry, forcing_registry, &
                                                    state_registry, numerical_config, top_boundary, t0, t1, &
                                                    batch_size, results, diagnostics, aggregate, dispatch_status, &
                                                    runtime_diagnostics, receipt_column_ids, commit_receipts, execution_plan, &
                                                    materialize_worker_assignments, materialize_summary_diagnostics, &
                                                    materialize_diagnostic_metadata, materialize_column_diagnostics, &
                                                    trusted_prepared_parameters, free_drainage_indicator, storage_difference)
    procedure(constitutive_storage_difference_ifc), optional :: storage_difference
    procedure(free_drainage_indicator_service), optional :: free_drainage_indicator
    type(fmr_logical_column_t), intent(in) :: columns(:)"""
s = replace_once(
    s,
    r"  subroutine fmr_run_serialized_physical_multiswap\(columns, templates, parameter_registry, forcing_registry, &\n.*?\n    type\(fmr_logical_column_t\), intent\(in\) :: columns\(:\)",
    main_header,
    "multiswap main header",
    re.S,
)

# Replace the union-damaged initialize_outputs region with the independent PPA
# irrigation wrapper followed by the current canonical initialize_outputs.
ppa_irrigation_wrapper = extract_subroutine(ppa, "fmr_execute_serialized_irrigation_resolved_column")
canon_initialize = extract_subroutine(canon, "initialize_outputs")
s = replace_once(
    s,
    r"  subroutine initialize_outputs\(.*?end subroutine initialize_outputs",
    ppa_irrigation_wrapper + "\n\n" + canon_initialize,
    "multiswap irrigation wrapper + initialize_outputs",
    re.S,
)

# Build one transaction body from the richer PPA observation/publication body,
# adding the current canonical concurrency and trusted-parameter controls.
resolved = extract_subroutine(ppa, "execute_resolved_column")
resolved = resolved.replace(
    "                                     bottom_thermal_provider, bottom_energy_publication, irrigation_node, &",
    "                                     bottom_thermal_provider, bottom_energy_publication, track_physical_concurrency, &\n"
    "                                     trusted_prepared_parameters, irrigation_node, &",
)
resolved = resolved.replace(
    "    type(fmr_serialized_bottom_energy_publication_t), intent(out), optional :: bottom_energy_publication\n"
    "    integer, intent(in), optional :: irrigation_node",
    "    type(fmr_serialized_bottom_energy_publication_t), intent(out), optional :: bottom_energy_publication\n"
    "    logical, intent(in), optional :: track_physical_concurrency\n"
    "    logical, intent(in), optional :: trusted_prepared_parameters\n"
    "    integer, intent(in), optional :: irrigation_node",
)
resolved = resolved.replace(
    "    logical :: checkpoint_ok, candidate_ready, did_commit, energy_requested, receipt_path, exported_receipt_available\n\n"
    "    output%initial_revision",
    "    logical :: checkpoint_ok, candidate_ready, did_commit, energy_requested, receipt_path, exported_receipt_available\n"
    "    logical :: do_track_physical_concurrency\n\n"
    "    do_track_physical_concurrency = .true.\n"
    "    if (present(track_physical_concurrency)) do_track_physical_concurrency = track_physical_concurrency\n\n"
    "    output%initial_revision",
)
resolved = resolved.replace(
    """    !$omp atomic capture
    active_physical_calls = active_physical_calls + 1
    simultaneous_physical_calls = active_physical_calls
    !$omp end atomic""",
    """    if (do_track_physical_concurrency) then
      !$omp atomic capture
      active_physical_calls = active_physical_calls + 1
      simultaneous_physical_calls = active_physical_calls
      !$omp end atomic
    else
      simultaneous_physical_calls = 1
    end if""",
)
resolved = resolved.replace(
    """    if (present(irrigation_node)) then
      call backend%run_pending_irrigation_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, irrigation_node, t0, t1, checkpoint, kernel_result, candidate, kernel_diag, &
           selected_irrigation_event,weekly_proposal,target_selector,tcsfix_proposal)
    else
      call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag)
    end if""",
    """    if (present(irrigation_node)) then
      call backend%run_pending_irrigation_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, irrigation_node, t0, t1, checkpoint, kernel_result, candidate, kernel_diag, &
           selected_event=selected_irrigation_event, weekly_proposal=weekly_proposal, &
           target_selector=target_selector, tcsfix_proposal=tcsfix_proposal, &
           trusted_prepared_parameters=trusted_prepared_parameters)
    else
      call backend%run_trial(column, template, parameters, committed_state, effective_forcing, &
           numerical_config, t0, t1, checkpoint, kernel_result, candidate, kernel_diag, &
           trusted_prepared_parameters=trusted_prepared_parameters)
    end if""",
)
resolved = resolved.replace(
    """      if (output%solver_executed) then
        runtime%max_simultaneous_real_physical_solves = max( &
             runtime%max_simultaneous_real_physical_solves, simultaneous_physical_calls)
      end if
    end if
    !$omp atomic update
    active_physical_calls = active_physical_calls - 1
    !$omp end atomic""",
    """      if (output%solver_executed .and. do_track_physical_concurrency) then
        runtime%max_simultaneous_real_physical_solves = max( &
             runtime%max_simultaneous_real_physical_solves, simultaneous_physical_calls)
      end if
    end if
    if (do_track_physical_concurrency) then
      !$omp atomic update
      active_physical_calls = active_physical_calls - 1
      !$omp end atomic
    end if""",
)
s = replace_once(
    s,
    r"  subroutine execute_resolved_column\(.*?end subroutine execute_resolved_column",
    resolved,
    "multiswap execute_resolved_column",
    re.S,
)

p.write_text(s)
print("PPA_RECONCILE_RESOLVER=PASS")
