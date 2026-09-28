from pathlib import Path
import re
import subprocess

CANON = "origin/integration/f-ci-canonical"
PPA = "origin/backup/ppa-before-reconcile-20260928"

def git_show(ref, path):
    return subprocess.check_output(["git", "show", f"{ref}:{path}"], text=True)

def extract_function(text, name):
    marker = f"function {name}"
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f"{name}: function start not found")
    line_start = text.rfind("\n", 0, start) + 1
    end_marker = f"end function {name}"
    end = text.find(end_marker, start)
    if end < 0:
        raise SystemExit(f"{name}: function end not found")
    end += len(end_marker)
    return text[line_start:end]

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

# 4. Production application bootstrap: canonical owns the current scalable
# bootstrap/parallel/direct-retention mechanics; PPA adds irrigation state and
# standalone constitutive services. Reconstruct only the conflicted procedures.
boot_path = "src/runtime/mod_fmr_production_application_bootstrap.f90"
p = Path(boot_path)
s = p.read_text()
canon_boot = git_show(CANON, boot_path)
ppa_boot = git_show(PPA, boot_path)

preamble = """module mod_fmr_production_application_bootstrap
  use mod_canonical_interval_runtime, only: canonical_subinterval_target_selector
  use mod_soil_water_solver_contract, only: constitutive_storage_difference_ifc
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_result_t
  use mod_canonical_result_text_adapter, only: serialize_canonical_result_text
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE, transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_executor_t
  use mod_irrigation_process, only: irrigation_state_t, ppa_weekly_identity_t, valid_weekly_identity, &
       ppa_tcsfix_identity_t, valid_tcsfix_identity, valid_tcsfix_transition
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, fmr_serialized_execution_plan_t, fmr_build_serialized_execution_plan, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_EXECUTION_EASY, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_black_evaporation_committed_state, &
       fmr_new_b110_boesten_evaporation_committed_state, prepare_fmr_b110_default_mvg, &
       free_drainage_indicator_service, fmr_new_b110_irrigation_committed_state, &
       ppa_irrigation_event_state_t, PPA_IRRIGATION_EVENT_LAYOUT
  use mod_restricted_surface_evaporation, only: black_evaporation_state_t, boesten_evaporation_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_serialized_commit_receipt_record_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, &
       fmr_execute_serialized_irrigation_resolved_column
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_direct_retention_core, only: begin_b110_direct_retention_application, &
       end_b110_direct_retention_application, freeze_b110_direct_retention_pool
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_temporal_budget_policy_t
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_topology_composition, only: groundwater_topology_t, groundwater_topology_cell_t, &
       GW_TOPOLOGY_OK, GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_application_plan_t, groundwater_tile_predictor_input_t, &
       groundwater_cell_area_input_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, &
       release_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK, FMR_GW_APP_C_API_INVALID_CONTEXT, &
       FMR_GW_APP_C_API_CONTEXT_BUSY
"""
s = replace_once(
    s,
    r"module mod_fmr_production_application_bootstrap\n.*?(?=  implicit none)",
    preamble,
    "bootstrap preamble",
    re.S,
)

combined_init = extract_subroutine(canon_boot, "production_application_initialize")
combined_init = combined_init.replace(
    """    if (.not. groundwater_profile .and. config%groundwater_parallel_workers /= 1) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if (groundwater_profile) then""",
    """    if (.not. groundwater_profile .and. config%groundwater_parallel_workers /= 1) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if (associated(config%free_drainage_indicator)) then
      if (.not. standalone_profile) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
      do i = 1, n
        if (config%tiles(i)%template%numerical_continuation_layout_id /= &
             FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) then
          status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
          return
        end if
      end do
    end if
    if (associated(config%storage_difference)) then
      if (.not. standalone_profile) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
    end if
    if (groundwater_profile) then""",
)
combined_init = combined_init.replace(
    "    allocate(self%columns(n), self%templates(n))\n",
    "    allocate(self%columns(n), self%templates(n))\n    allocate(self%irrigation_nodes(n))\n",
)
combined_init = combined_init.replace(
    "    self%numerical = config%numerical\n\n    call self%backend%initialize(self%top_boundary)",
    """    self%numerical = config%numerical
    self%free_drainage_indicator => config%free_drainage_indicator
    self%storage_difference => config%storage_difference

    call self%backend%initialize(self%top_boundary)
    if (associated(config%free_drainage_indicator)) &
         call self%backend%set_free_drainage_indicator(config%free_drainage_indicator)
    if (associated(config%storage_difference)) &
         call self%backend%set_storage_difference(config%storage_difference)""",
)
combined_init = combined_init.replace(
    "      self%parameters(i) = config%tiles(i)%parameters\n      call prepare_fmr_b110_default_mvg",
    "      self%parameters(i) = config%tiles(i)%parameters\n"
    "      self%irrigation_nodes(i) = config%tiles(i)%irrigation_ssdi_node\n"
    "      call prepare_fmr_b110_default_mvg",
)
combined_init = combined_init.replace(
    """      case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
        if (allocated(config%tiles(i)%initial_right_derivative)) then""",
    """      case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
        if (self%irrigation_nodes(i) > 0) then
          call fmr_new_b110_irrigation_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, self%templates(i), config%initial_time, &
               config%tiles(i)%initial_right_derivative, ok)
        else if (allocated(config%tiles(i)%initial_right_derivative)) then""",
)

s = replace_once(
    s,
    r"  subroutine production_application_initialize\(.*?end subroutine production_application_initialize",
    combined_init,
    "bootstrap initialize",
    re.S,
)

ppa_prepared = extract_subroutine(ppa_boot, "production_application_run_prepared_irrigation")
if "subroutine production_application_run_prepared_irrigation" in s:
    s = replace_once(
        s,
        r"  subroutine production_application_run_prepared_irrigation\(.*?end subroutine production_application_run_prepared_irrigation",
        ppa_prepared,
        "bootstrap prepared irrigation",
        re.S,
    )
else:
    anchor = "  end subroutine production_application_initialize"
    pos = s.find(anchor)
    if pos < 0:
        raise SystemExit("bootstrap prepared irrigation insertion anchor missing")
    pos += len(anchor)
    s = s[:pos] + "\n\n" + ppa_prepared + s[pos:]

ppa_tile_valid = extract_function(ppa_boot, "tile_config_valid")
s = replace_once(
    s,
    r"  logical function tile_config_valid\(.*?end function tile_config_valid",
    ppa_tile_valid,
    "bootstrap tile_config_valid",
    re.S,
)

combined_discard = extract_subroutine(canon_boot, "discard_owner_storage")
combined_discard = combined_discard.replace(
    "    nullify(self%backend)\n    nullify(self%top_boundary)",
    "    nullify(self%backend)\n"
    "    nullify(self%free_drainage_indicator)\n"
    "    nullify(self%storage_difference)\n"
    "    nullify(self%top_boundary)",
)
combined_discard = combined_discard.replace(
    "    if (allocated(self%templates)) deallocate(self%templates)\n",
    "    if (allocated(self%templates)) deallocate(self%templates)\n"
    "    if (allocated(self%irrigation_nodes)) deallocate(self%irrigation_nodes)\n",
)
s = replace_once(
    s,
    r"  subroutine discard_owner_storage\(.*?end subroutine discard_owner_storage",
    combined_discard,
    "bootstrap discard_owner_storage",
    re.S,
)

p.write_text(s)
print("PPA_RECONCILE_RESOLVER=PASS")
