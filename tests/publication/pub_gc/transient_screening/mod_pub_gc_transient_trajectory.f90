module mod_pub_gc_transient_trajectory
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_discard_candidate, &
       groundwater_prepare_candidate, groundwater_commit_prepared, groundwater_abort_prepared, GW_EXCHANGE_OK
  use mod_pub_gc_gw_a, only: pub_gc_gw_a_service_t
  use mod_pub_gc_gc_ref, only: gc_ref_eval_t, gc_ref_solution_t, gc_ref_bisect, GC_REF_OK
  use mod_pub_gc_e2_terminal_comparator, only: pub_gc_e2_comparison_t, pub_gc_e2_compare, PUB_GC_E2_OK
  implicit none
  private

  integer, parameter, public :: PUB_GC_REF_TRAJECTORY_OK = 0
  integer, parameter, public :: PUB_GC_REF_TRAJECTORY_ROOT_FAILED = 1
  integer, parameter, public :: PUB_GC_REF_TRAJECTORY_RECONSTRUCTION_FAILED = 2
  integer, parameter, public :: PUB_GC_REF_TRAJECTORY_COMMIT_FAILED = 3
  integer, parameter, public :: PUB_GC_REF_TRAJECTORY_INVALID = 4

  real(real64), parameter :: initial_time_day = 4200.125_real64
  real(real64), parameter :: base_head_cm = -80.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  real(real64), parameter :: qualification_head_budget = 100.0_real64
  real(real64), parameter :: gw_area_m2 = 1.0_real64
  real(real64), parameter :: day_to_s = 86400.0_real64
  integer(int64), parameter :: origin_lineage = 850001_int64
  integer(int64), parameter :: gw_service_id = 850101_int64
  integer(int64), parameter :: gw_lineage_id = 850102_int64

  type, public :: pub_gc_reference_level_result_t
    logical :: completed = .false.
    integer :: status = PUB_GC_REF_TRAJECTORY_INVALID
    real(real64) :: coupling_window_day = 0.0_real64
    integer :: number_of_windows = 0
    real(real64), allocatable :: accepted_gw_head_m(:)
    real(real64), allocatable :: accepted_q_whole_cm(:)
    real(real64), allocatable :: terminal_flux_cm_per_day(:)
    real(real64), allocatable :: q_terminal_cm(:)
    real(real64), allocatable :: terminal_surrogate_mismatch_cm(:)
    real(real64), allocatable :: terminal_gw_head_m(:)
    real(real64), allocatable :: paired_gw_head_difference_m(:)
    real(real64), allocatable :: accepted_h_star_m(:)
    real(real64), allocatable :: accepted_residual_m(:)
    integer, allocatable :: outer_evaluations(:)
    real(real64) :: cumulative_q_whole_cm = 0.0_real64
    real(real64) :: gross_q_whole_cm = 0.0_real64
    real(real64) :: sum_abs_terminal_surrogate_mismatch_cm = 0.0_real64
    real(real64) :: max_abs_terminal_surrogate_mismatch_cm = 0.0_real64
    real(real64), allocatable :: final_pressure_head_cm(:)
    real(real64), allocatable :: final_water_content(:)
    real(real64) :: final_total_water_storage_cm = 0.0_real64
    integer(int64) :: final_swap_revision = -1_int64
    integer(int64) :: final_gw_revision = -1_int64
  end type pub_gc_reference_level_result_t

  type(fmr_logical_column_t), pointer :: active_column => null()
  type(fmr_template_t), pointer :: active_template => null()
  type(fmr_b110_physical_parameters_t), pointer :: active_parameters => null()
  type(fmr_b110_physical_forcing_t), pointer :: active_forcing_template => null()
  type(fmr_serialized_reference_backend_t), pointer :: active_backend => null()
  type(canonical_numerical_config_t), pointer :: active_config => null()
  type(kernel_committed_state_t), pointer :: active_origin => null()
  type(kernel_checkpoint_t), pointer :: active_swap_checkpoint => null()
  type(pub_gc_gw_a_service_t), pointer :: active_gw => null()
  type(groundwater_exchange_checkpoint_t), pointer :: active_gw_checkpoint => null()
  real(real64) :: active_t0 = 0.0_real64
  real(real64) :: active_t1 = 0.0_real64
  real(real64) :: active_k0 = 0.0_real64
  real(real64) :: active_top_flux_factors(3) = [-1.0_real64,-1.0_real64,-1.0_real64]

  public :: pub_gc_run_transient_reference_level

contains

  subroutine pub_gc_run_transient_reference_level(coupling_window_day, number_of_windows, initial_gw_head_m, &
       gw_specific_yield, top_flux_factors, level, status)
    real(real64), intent(in) :: coupling_window_day
    integer, intent(in) :: number_of_windows
    real(real64), intent(in) :: initial_gw_head_m, gw_specific_yield
    real(real64), intent(in) :: top_flux_factors(3)
    type(pub_gc_reference_level_result_t), intent(out) :: level
    integer, intent(out) :: status

    type(fmr_logical_column_t), target :: column
    type(fmr_template_t), target :: template
    type(fmr_b110_physical_parameters_t), target :: parameters
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_b110_physical_forcing_t), target :: forcing_template
    type(fmr_serialized_reference_backend_t), target :: backend
    type(fixed_flux_top_boundary_provider_t), target :: top_provider
    type(canonical_numerical_config_t), target :: config
    type(kernel_committed_state_t), target :: origin
    type(kernel_checkpoint_t), target :: swap_checkpoint
    type(pub_gc_gw_a_service_t), target :: gw
    type(groundwater_exchange_checkpoint_t), target :: gw_checkpoint
    type(gc_ref_solution_t) :: solution
    class(transaction_state_t), allocatable :: final_snapshot
    real(real64) :: accepted_predecessor_right_derivative(numnod)
    real(real64) :: q_accepted, residual_accepted, conductivity_reference
    type(pub_gc_e2_comparison_t) :: comparison
    real(real64) :: origin_time, gw_time
    logical :: ok, available
    integer :: w, local_status, gw_status

    level = pub_gc_reference_level_result_t()
    status = PUB_GC_REF_TRAJECTORY_INVALID
    if (.not. ieee_is_finite(coupling_window_day) .or. coupling_window_day <= 0.0_real64) return
    if (number_of_windows <= 0) return
    if (.not. ieee_is_finite(initial_gw_head_m)) return
    if (.not. ieee_is_finite(gw_specific_yield) .or. gw_specific_yield <= 0.0_real64 .or. gw_specific_yield > 1.0_real64) return
    if (any(.not. ieee_is_finite(top_flux_factors))) return

    level%coupling_window_day = coupling_window_day
    level%number_of_windows = number_of_windows
    allocate(level%accepted_gw_head_m(0:number_of_windows))
    allocate(level%accepted_q_whole_cm(number_of_windows))
    allocate(level%terminal_flux_cm_per_day(number_of_windows))
    allocate(level%q_terminal_cm(number_of_windows))
    allocate(level%terminal_surrogate_mismatch_cm(number_of_windows))
    allocate(level%terminal_gw_head_m(number_of_windows))
    allocate(level%paired_gw_head_difference_m(number_of_windows))
    allocate(level%accepted_h_star_m(number_of_windows))
    allocate(level%accepted_residual_m(number_of_windows))
    allocate(level%outer_evaluations(number_of_windows))
    level%accepted_gw_head_m = 0.0_real64
    level%accepted_q_whole_cm = 0.0_real64
    level%terminal_flux_cm_per_day = 0.0_real64
    level%q_terminal_cm = 0.0_real64
    level%terminal_surrogate_mismatch_cm = 0.0_real64
    level%terminal_gw_head_m = 0.0_real64
    level%paired_gw_head_difference_m = 0.0_real64
    level%accepted_h_star_m = 0.0_real64
    level%accepted_residual_m = 0.0_real64
    level%outer_evaluations = 0

    call configure_column(column, template)
    call configure_transaction(config)
    call configure_case(parameters, initial_state, forcing_template, base_head_cm, coupling_window_day, conductivity_reference)
    call backend%initialize(top_provider)

    accepted_predecessor_right_derivative = 0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(origin, origin_lineage, initial_state, initial_time_day, ok, &
         accepted_predecessor_right_derivative)
    if (.not. ok .or. .not. origin%ready()) return

    call gw%initialize(gw_service_id, gw_lineage_id, initial_gw_head_m, initial_time_day, gw_area_m2, gw_specific_yield, &
         0.0_real64, 0.0_real64, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. gw%is_configured()) return
    level%accepted_gw_head_m(0) = gw%accepted_head_m()

    active_column => column
    active_template => template
    active_parameters => parameters
    active_forcing_template => forcing_template
    active_backend => backend
    active_config => config
    active_origin => origin
    active_swap_checkpoint => swap_checkpoint
    active_gw => gw
    active_gw_checkpoint => gw_checkpoint
    active_k0 = conductivity_reference
    active_top_flux_factors = top_flux_factors

    do w = 1, number_of_windows
      active_t0 = initial_time_day + real(w-1,real64)*coupling_window_day
      active_t1 = initial_time_day + real(w,real64)*coupling_window_day

      call origin%current_time(origin_time, available)
      if (.not. available .or. .not. close_time(origin_time, active_t0)) then
        call clear_active_context()
        return
      end if
      gw_time = gw%accepted_time_day()
      if (.not. close_time(gw_time, active_t0)) then
        call clear_active_context()
        return
      end if

      call fmr_capture_checkpoint(origin, swap_checkpoint, ok)
      if (.not. ok .or. .not. swap_checkpoint%ready()) then
        call clear_active_context()
        return
      end if
      call groundwater_capture_checkpoint(gw, gw_checkpoint, gw_status)
      if (gw_status /= GW_EXCHANGE_OK .or. .not. gw_checkpoint%ready()) then
        call clear_active_context()
        return
      end if

      call gc_ref_bisect(evaluate_active_residual, -0.10_real64, 0.20_real64, 1.0e-8_real64, &
           1.0e-6_real64, 1.0e-8_real64, 64, solution, local_status)
      if (local_status /= GC_REF_OK .or. .not. solution%converged) then
        level%status = PUB_GC_REF_TRAJECTORY_ROOT_FAILED
        status = level%status
        call clear_active_context()
        return
      end if

      call reconstruct_prepare_commit(solution, q_accepted, residual_accepted, comparison, local_status)
      if (local_status /= PUB_GC_REF_TRAJECTORY_OK) then
        level%status = local_status
        status = local_status
        call clear_active_context()
        return
      end if

      level%accepted_h_star_m(w) = solution%h_star_m
      level%accepted_q_whole_cm(w) = q_accepted
      level%terminal_flux_cm_per_day(w) = comparison%q_terminal_flux_cm_per_day
      level%q_terminal_cm(w) = comparison%q_terminal_cm
      level%terminal_surrogate_mismatch_cm(w) = comparison%interface_residual_terminal_cm
      level%terminal_gw_head_m(w) = comparison%gw_head_terminal_m
      level%paired_gw_head_difference_m(w) = comparison%gw_head_difference_m
      level%accepted_residual_m(w) = residual_accepted
      level%outer_evaluations(w) = solution%evaluations
      level%cumulative_q_whole_cm = level%cumulative_q_whole_cm + q_accepted
      level%gross_q_whole_cm = level%gross_q_whole_cm + abs(q_accepted)
      level%sum_abs_terminal_surrogate_mismatch_cm = level%sum_abs_terminal_surrogate_mismatch_cm + &
           abs(comparison%interface_residual_terminal_cm)
      level%max_abs_terminal_surrogate_mismatch_cm = max(level%max_abs_terminal_surrogate_mismatch_cm, &
           abs(comparison%interface_residual_terminal_cm))
      level%accepted_gw_head_m(w) = gw%accepted_head_m()

      if (origin%current_revision() /= int(w,int64)) then
        level%status = PUB_GC_REF_TRAJECTORY_COMMIT_FAILED
        status = level%status
        call clear_active_context()
        return
      end if
      if (gw%current_revision() /= int(w,int64)) then
        level%status = PUB_GC_REF_TRAJECTORY_COMMIT_FAILED
        status = level%status
        call clear_active_context()
        return
      end if
    end do

    call origin%snapshot(final_snapshot, available)
    if (.not. available .or. .not. allocated(final_snapshot)) then
      call clear_active_context()
      return
    end if
    select type (physical => final_snapshot)
    class is (fmr_b110_physical_state_t)
      if (.not. allocated(physical%pressure_head) .or. .not. allocated(physical%water_content)) then
        call clear_active_context()
        return
      end if
      allocate(level%final_pressure_head_cm(size(physical%pressure_head)))
      allocate(level%final_water_content(size(physical%water_content)))
      level%final_pressure_head_cm = physical%pressure_head
      level%final_water_content = physical%water_content
      level%final_total_water_storage_cm = sum(physical%water_content * dz(1:size(physical%water_content)))
    class default
      call clear_active_context()
      return
    end select

    level%final_swap_revision = origin%current_revision()
    level%final_gw_revision = gw%current_revision()
    level%completed = .true.
    level%status = PUB_GC_REF_TRAJECTORY_OK
    status = PUB_GC_REF_TRAJECTORY_OK
    call clear_active_context()
  end subroutine pub_gc_run_transient_reference_level

  subroutine evaluate_active_residual(h_relative_m, evaluation, status)
    real(real64), intent(in) :: h_relative_m
    type(gc_ref_eval_t), intent(out) :: evaluation
    integer, intent(out) :: status

    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diag
    type(kernel_executor_t) :: discard_executor
    type(fmr_b110_physical_forcing_t) :: forcing
    type(groundwater_exchange_candidate_t) :: gw_candidate
    type(groundwater_exchange_trial_result_t) :: gw_trial
    type(groundwater_coupling_window_t) :: window
    real(real64) :: q_gw_mps
    integer :: gw_status

    evaluation = gc_ref_eval_t()
    status = 1
    if (.not. active_context_ready()) return
    if (.not. ieee_is_finite(h_relative_m)) return

    forcing = active_forcing_template
    forcing%top_flux = current_top_flux()
    forcing%bottom_head = base_head_cm + 100.0_real64*h_relative_m
    call poison_legacy_bottom_context()
    call active_backend%run_trial(active_column, active_template, active_parameters, active_origin, forcing, active_config, &
         active_t0, active_t1, active_swap_checkpoint, result, candidate, diagnostics)
    if (.not. result%completed .or. .not. candidate%ready()) return
    if (.not. result%bottom_interface_exchange_available .or. &
        .not. ieee_is_finite(result%bottom_outward_exchange_native)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    window%t0 = active_t0
    window%t1 = active_t1
    q_gw_mps = -(result%bottom_outward_exchange_native*0.01_real64)/((active_t1-active_t0)*day_to_s)
    call groundwater_trial_from_checkpoint(active_gw, active_gw_checkpoint, window, q_gw_mps, &
         gw_candidate, gw_trial, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. gw_candidate%ready()) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    evaluation%valid = .true.
    evaluation%h_m = h_relative_m
    evaluation%q_whole_cm = result%bottom_outward_exchange_native
    evaluation%residual_m = h_relative_m - gw_trial%h_groundwater_m

    call groundwater_discard_candidate(active_gw, gw_candidate, gw_status)
    if (gw_status /= GW_EXCHANGE_OK) evaluation%valid = .false.
    discard_diag = diagnostics
    call fmr_discard_candidate(discard_executor, candidate, discard_diag)
    if (candidate%ready()) evaluation%valid = .false.
    if (.not. evaluation%valid) return
    status = GC_REF_OK
  end subroutine evaluate_active_residual

  subroutine reconstruct_prepare_commit(solution, q_accepted, residual_accepted, comparison, status)
    type(gc_ref_solution_t), intent(in) :: solution
    real(real64), intent(out) :: q_accepted, residual_accepted
    type(pub_gc_e2_comparison_t), intent(out) :: comparison
    integer, intent(out) :: status

    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diag
    type(kernel_executor_t) :: commit_kernel, discard_executor
    type(fmr_accepted_commit_receipt_t) :: receipt
    type(fmr_b110_physical_forcing_t) :: forcing
    type(groundwater_exchange_candidate_t) :: gw_candidate
    type(groundwater_exchange_prepared_t) :: gw_prepared
    type(groundwater_exchange_trial_result_t) :: gw_trial
    type(groundwater_coupling_window_t) :: window
    real(real64) :: q_gw_mps, q_gw_integrated_cm
    logical :: did_commit
    integer :: receipt_status, commit_status, gw_status, abort_status

    status = PUB_GC_REF_TRAJECTORY_RECONSTRUCTION_FAILED
    comparison = pub_gc_e2_comparison_t()
    q_accepted = 0.0_real64
    residual_accepted = huge(0.0_real64)
    if (.not. active_context_ready()) return

    forcing = active_forcing_template
    forcing%top_flux = current_top_flux()
    forcing%bottom_head = base_head_cm + 100.0_real64*solution%h_star_m
    call poison_legacy_bottom_context()
    call active_backend%run_trial(active_column, active_template, active_parameters, active_origin, forcing, active_config, &
         active_t0, active_t1, active_swap_checkpoint, result, candidate, diagnostics)
    if (.not. result%completed .or. .not. candidate%ready()) return
    if (.not. result%bottom_interface_exchange_available .or. &
        .not. ieee_is_finite(result%bottom_outward_exchange_native)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if
    if (.not. same_bits(result%bottom_outward_exchange_native, solution%q_whole_cm)) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    call pub_gc_e2_compare(active_gw, active_gw_checkpoint, result%bottom_outward_exchange_native, &
         result%terminal_bottom_outward_flux_native, active_t1-active_t0, comparison, gw_status)
    if (gw_status /= PUB_GC_E2_OK .or. .not. comparison%valid) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    window%t0 = active_t0
    window%t1 = active_t1
    q_gw_mps = -(result%bottom_outward_exchange_native*0.01_real64)/((active_t1-active_t0)*day_to_s)
    call groundwater_trial_from_checkpoint(active_gw, active_gw_checkpoint, window, q_gw_mps, &
         gw_candidate, gw_trial, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. gw_candidate%ready()) then
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    residual_accepted = solution%h_star_m - gw_trial%h_groundwater_m
    if (.not. same_bits(residual_accepted, solution%residual_m) .or. abs(residual_accepted) > 1.0e-8_real64) then
      call groundwater_discard_candidate(active_gw, gw_candidate, gw_status)
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    q_accepted = result%bottom_outward_exchange_native
    q_gw_integrated_cm = q_gw_mps*((active_t1-active_t0)*day_to_s)*100.0_real64
    if (.not. close64(q_accepted + q_gw_integrated_cm, 0.0_real64)) then
      call groundwater_discard_candidate(active_gw, gw_candidate, gw_status)
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    call groundwater_prepare_candidate(active_gw, active_gw_checkpoint, gw_candidate, gw_prepared, gw_status)
    if (gw_status /= GW_EXCHANGE_OK .or. .not. gw_prepared%ready()) then
      if (gw_candidate%ready()) call groundwater_discard_candidate(active_gw, gw_candidate, gw_status)
      discard_diag = diagnostics
      call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      return
    end if

    call fmr_commit_candidate_with_receipt(commit_kernel, active_swap_checkpoint, active_origin, candidate, diagnostics, &
         did_commit, receipt, receipt_status, commit_status)
    if (.not. did_commit .or. receipt_status /= FMR_COMMIT_RECEIPT_OK .or. .not. receipt%ready()) then
      call groundwater_abort_prepared(active_gw, active_gw_checkpoint, gw_prepared, abort_status)
      if (candidate%ready()) then
        discard_diag = diagnostics
        call fmr_discard_candidate(discard_executor, candidate, discard_diag)
      end if
      status = PUB_GC_REF_TRAJECTORY_COMMIT_FAILED
      return
    end if

    call groundwater_commit_prepared(active_gw, active_gw_checkpoint, gw_prepared, gw_status)
    if (gw_status /= GW_EXCHANGE_OK) then
      status = PUB_GC_REF_TRAJECTORY_COMMIT_FAILED
      return
    end if

    status = PUB_GC_REF_TRAJECTORY_OK
  end subroutine reconstruct_prepare_commit

  logical function active_context_ready() result(ready)
    ready = associated(active_column) .and. associated(active_template) .and. associated(active_parameters) .and. &
         associated(active_forcing_template) .and. associated(active_backend) .and. associated(active_config) .and. &
         associated(active_origin) .and. associated(active_swap_checkpoint) .and. associated(active_gw) .and. &
         associated(active_gw_checkpoint) .and. active_t1 > active_t0
  end function active_context_ready

  subroutine clear_active_context()
    nullify(active_column, active_template, active_parameters, active_forcing_template, active_backend, active_config)
    nullify(active_origin, active_swap_checkpoint, active_gw, active_gw_checkpoint)
    active_t0 = 0.0_real64
    active_t1 = 0.0_real64
    active_k0 = 0.0_real64
    active_top_flux_factors = [-1.0_real64,-1.0_real64,-1.0_real64]
  end subroutine clear_active_context

  real(real64) function current_top_flux() result(qtop)
    real(real64) :: elapsed
    integer :: segment
    elapsed = active_t0 - initial_time_day
    if (elapsed < 0.08_real64 - 1.0e-10_real64) then
      segment = 1
    else if (elapsed < 0.16_real64 - 1.0e-10_real64) then
      segment = 2
    else
      segment = 3
    end if
    qtop = active_top_flux_factors(segment) * active_k0
  end function current_top_flux

  subroutine configure_column(c, tpl)
    type(fmr_logical_column_t), intent(out) :: c
    type(fmr_template_t), intent(out) :: tpl
    tpl%template_id = 8501_int64
    tpl%physics_topology_id = 850101_int64
    tpl%vertical_layout_id = 850102_int64
    tpl%state_layout_id = 850103_int64
    tpl%solver_interface_id = 850104_int64
    tpl%optional_state_layout_id = 0_int64
    tpl%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id = origin_lineage
    c%template_id = tpl%template_id
    c%parameter_ref = 1_int64
    c%state_handle = 1_int64
    c%forcing_handle = 1_int64
    c%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 4
    cfg%max_committed_substeps = 64
    cfg%progress_tolerance = 0.0_real64
    cfg%model_temporal_indicator_budget_available = .true.
    cfg%model_temporal_indicator_budget = qualification_head_budget
  end subroutine configure_transaction

  subroutine configure_case(p, state, forcing, initial_head_cm, dt, conductivity_reference)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: initial_head_cm, dt
    real(real64), intent(out) :: conductivity_reference
    real(real64) :: heads(numnod), conductivity(numnod)
    integer :: k
    call configure_base_parameters(p)
    heads = initial_head_cm
    call evaluate_state(p, heads, state, conductivity, dt)
    conductivity_reference = conductivity(1)
    do k=2,numnod
      if (.not. same_bits(conductivity(k),conductivity_reference)) return
    end do
    forcing%top_flux = -conductivity_reference
    forcing%top_head = initial_head_cm
    forcing%bottom_flux = 12345.0_real64
    forcing%bottom_head = initial_head_cm
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k
    p%parameter_set_id = 850101_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24,numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode = 5; p%swkimpl = 0; p%swkmean = 1; p%swsophy = 0
    p%root_extraction_active = .false.; p%macropore_active = .false.; p%snow_active = .false.
    p%hysteresis_active = .false.; p%tabulated_hydraulics_active = .false.; p%elasticity_active = .false.
    p%frost_active = .false.; p%soil_temperature_active = .false.; p%drainage_response_active = .false.
    p%max_iterations = 12; p%max_backtracking = 8; p%min_step_duration = 1.0e-7_real64
    p%compartment_balance_tolerance = hard_mass_gate; p%total_balance_tolerance = hard_mass_gate
    p%head_abs_tolerance = 1.0e-10_real64; p%head_rel_tolerance = 1.0e-10_real64
    p%ponding_tolerance = 1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p, heads, state, conductivity, dt)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    real(real64), intent(in) :: heads(:), dt
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity(:)
    type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: water(numnod), capacity(numnod), dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters, p%cofgen)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_parameters, dt)
    call constitutive%evaluate(heads, water, conductivity, capacity, dkdh)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t), intent(inout) :: f
    allocate(f%drainage_flux_by_level(1,numnod), f%subsurface_irrigation_source(numnod), f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine allocate_zero_forcing

  subroutine poison_legacy_bottom_context()
    swmacro=0; legacy_melt=0.0_real64; legacy_qdra=24680.0_real64; legacy_qssdi=-13579.0_real64
    legacy_qrot=0.0_real64; legacy_swbotb=3; legacy_hbot=99999.0_real64; legacy_qbot=-99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  pure logical function close64(a,b) result(value)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    value=abs(a-b)<=512.0_real64*epsilon(1.0_real64)*scale
  end function close64

  pure logical function close_time(a,b) result(value)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    value=abs(a-b)<=128.0_real64*epsilon(1.0_real64)*scale
  end function close_time

end module mod_pub_gc_transient_trajectory
