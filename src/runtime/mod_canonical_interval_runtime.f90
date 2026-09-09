module mod_canonical_interval_runtime
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t, transaction_result_t, execute_reference_interval, &
       TX_STATUS_ACCEPTED, TX_MASS_MISSING_NONE, TX_MASS_MISSING_NONFINITE, TX_MASS_MISSING_UNSPECIFIED, &
       TX_TEMPORAL_NONE, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_physical_model_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t, canonical_result_t, CANONICAL_STATUS_COMPLETED, &
       CANONICAL_STATUS_INVALID_REQUEST, CANONICAL_STATUS_TRANSACTION_FAILED, &
       CANONICAL_STATUS_NO_PROGRESS, CANONICAL_STATUS_SUBSTEP_LIMIT
  implicit none
  private

  public :: run_canonical_interval

contains

  subroutine run_canonical_interval(model, committed, forcing, interval, config, result)
    class(canonical_physical_model_t), intent(inout) :: model
    class(transaction_state_t), allocatable, intent(inout) :: committed
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    type(canonical_result_t), intent(out) :: result

    class(transaction_state_t), allocatable :: working
    type(transaction_result_t) :: tx
    real(real64) :: cursor, next_cursor, tol
    logical :: aggregate_mass_complete
    integer :: isub

    result = canonical_result_t()
    result%requested_t0 = interval%t0
    result%requested_t1 = interval%t1
    result%completed_t = interval%t0
    result%mass%interval_t0 = interval%t0
    result%mass%interval_t1 = interval%t1

    if (.not. allocated(committed) .or. interval%t1 <= interval%t0 .or. &
        config%max_committed_substeps <= 0 .or. config%progress_tolerance < 0.0_real64) then
      result%status = CANONICAL_STATUS_INVALID_REQUEST
      return
    end if

    ! The externally committed physical state remains untouched until the full
    ! requested [t0,t1] interval has completed. Accepted internal substeps are
    ! committed only into this private working state.
    call committed%clone(working)
    call model%prepare_interval(forcing, interval, config)
    result%mass%missing_contribution_mask = TX_MASS_MISSING_NONE
    aggregate_mass_complete = .true.
    cursor = interval%t0

    do isub = 1, config%max_committed_substeps
      call execute_reference_interval(model, working, cursor, interval%t1, config%transaction, tx)
      call accumulate_transaction(result, tx)

      if (tx%status /= TX_STATUS_ACCEPTED) then
        result%status = CANONICAL_STATUS_TRANSACTION_FAILED
        result%completed_t = cursor
        result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
             TX_MASS_MISSING_UNSPECIFIED)
        return
      end if

      call accumulate_accepted_mass(result, tx, aggregate_mass_complete)
      next_cursor = tx%accepted_t1
      tol = progress_tolerance(config%progress_tolerance, cursor, interval%t1)
      if (next_cursor <= cursor .or. next_cursor > interval%t1 + tol) then
        result%status = CANONICAL_STATUS_NO_PROGRESS
        result%completed_t = cursor
        result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
             TX_MASS_MISSING_UNSPECIFIED)
        return
      end if

      cursor = next_cursor
      result%diagnostics%committed_substeps = result%diagnostics%committed_substeps + 1
      result%completed_t = cursor

      if (abs(cursor - interval%t1) <= tol) then
        call move_alloc(working, committed)
        result%status = CANONICAL_STATUS_COMPLETED
        result%completed = .true.
        result%diagnostics%external_commits = 1
        call finalize_interval_mass(result, aggregate_mass_complete)
        return
      end if
    end do

    result%status = CANONICAL_STATUS_SUBSTEP_LIMIT
    result%completed_t = cursor
    result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
         TX_MASS_MISSING_UNSPECIFIED)
  end subroutine run_canonical_interval

  subroutine accumulate_accepted_mass(result, tx, aggregate_complete)
    type(canonical_result_t), intent(inout) :: result
    type(transaction_result_t), intent(in) :: tx
    logical, intent(inout) :: aggregate_complete

    if (tx%status /= TX_STATUS_ACCEPTED) return
    if (result%mass%accepted_transaction_count == 0) then
      result%mass%storage_start = tx%accepted_storage_start
    end if
    result%mass%storage_end = tx%accepted_storage_end
    result%mass%total_in = result%mass%total_in + tx%accepted_total_in
    result%mass%total_out = result%mass%total_out + tx%accepted_total_out
    result%mass%accepted_transaction_count = result%mass%accepted_transaction_count + 1
    result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
         tx%accepted_missing_contribution_mask)
    aggregate_complete = aggregate_complete .and. tx%accepted_mass_complete
  end subroutine accumulate_accepted_mass

  subroutine finalize_interval_mass(result, aggregate_complete)
    type(canonical_result_t), intent(inout) :: result
    logical, intent(in) :: aggregate_complete
    logical :: finite_terms

    result%mass%storage_change = result%mass%storage_end - result%mass%storage_start
    result%mass%residual = result%mass%storage_change - &
         (result%mass%total_in - result%mass%total_out)
    finite_terms = ieee_is_finite(result%mass%interval_t0) .and. &
         ieee_is_finite(result%mass%interval_t1) .and. &
         ieee_is_finite(result%mass%storage_start) .and. &
         ieee_is_finite(result%mass%storage_end) .and. &
         ieee_is_finite(result%mass%storage_change) .and. &
         ieee_is_finite(result%mass%total_in) .and. &
         ieee_is_finite(result%mass%total_out) .and. ieee_is_finite(result%mass%residual)
    if (.not. finite_terms) then
      result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
           TX_MASS_MISSING_NONFINITE)
    end if
    if (result%mass%accepted_transaction_count <= 0) then
      result%mass%missing_contribution_mask = ior(result%mass%missing_contribution_mask, &
           TX_MASS_MISSING_UNSPECIFIED)
    end if
    result%mass%complete = aggregate_complete .and. finite_terms .and. &
         result%mass%accepted_transaction_count > 0 .and. &
         result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE
    if (.not. result%mass%complete .and. &
        result%mass%missing_contribution_mask == TX_MASS_MISSING_NONE) then
      result%mass%missing_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    end if
  end subroutine finalize_interval_mass

  subroutine accumulate_transaction(result, tx)
    type(canonical_result_t), intent(inout) :: result
    type(transaction_result_t), intent(in) :: tx

    result%diagnostics%transaction_calls = result%diagnostics%transaction_calls + 1
    result%diagnostics%attempts = result%diagnostics%attempts + tx%attempts
    result%diagnostics%retries = result%diagnostics%retries + tx%retries
    result%diagnostics%rollbacks = result%diagnostics%rollbacks + tx%rollbacks
    result%diagnostics%solver_rejections = result%diagnostics%solver_rejections + tx%solver_rejections
    result%diagnostics%temporal_rejections = result%diagnostics%temporal_rejections + tx%temporal_rejections
    result%diagnostics%temporal_certificate_unavailable_rejections = &
         result%diagnostics%temporal_certificate_unavailable_rejections + &
         tx%temporal_certificate_unavailable_rejections
    if (result%diagnostics%temporal_acceptance_source == TX_TEMPORAL_NONE) then
      result%diagnostics%temporal_acceptance_source = tx%temporal_acceptance_source
    else if (tx%temporal_acceptance_source /= TX_TEMPORAL_NONE .and. &
             tx%temporal_acceptance_source /= result%diagnostics%temporal_acceptance_source) then
      result%diagnostics%temporal_acceptance_source = TX_TEMPORAL_NONE
    end if
    result%diagnostics%mass_rejections = result%diagnostics%mass_rejections + tx%mass_rejections
    result%diagnostics%nonlinear_iterations = result%diagnostics%nonlinear_iterations + tx%nonlinear_iterations
    result%diagnostics%internal_retries = result%diagnostics%internal_retries + tx%internal_retries
    result%diagnostics%headcalc_calls = result%diagnostics%headcalc_calls + tx%headcalc_calls
    result%diagnostics%jacobian_builds = result%diagnostics%jacobian_builds + tx%jacobian_builds
    result%diagnostics%linear_solves = result%diagnostics%linear_solves + tx%linear_solves
    result%diagnostics%backtracking_attempts = result%diagnostics%backtracking_attempts + tx%backtracking_attempts
    result%diagnostics%alternative_solver_calls = result%diagnostics%alternative_solver_calls + &
         tx%alternative_solver_calls
    if (ieee_is_finite(tx%temporal_indicator) .and. tx%temporal_indicator >= 0.0_real64) then
      result%diagnostics%max_temporal_indicator = max(result%diagnostics%max_temporal_indicator, &
           tx%temporal_indicator)
    end if
    if (tx%status == TX_STATUS_ACCEPTED) then
      if (tx%temporal_acceptance_source == TX_TEMPORAL_MODEL_CERTIFICATE) then
        result%diagnostics%max_abs_step_mass_residual = max(result%diagnostics%max_abs_step_mass_residual, &
             abs(tx%accepted_mass_residual))
      else
        result%diagnostics%max_abs_step_mass_residual = max(result%diagnostics%max_abs_step_mass_residual, &
             abs(tx%full_mass_residual), abs(tx%half_mass_residual))
      end if
      result%diagnostics%min_accepted_substep_duration = min(result%diagnostics%min_accepted_substep_duration, &
           tx%accepted_dt)
      result%diagnostics%max_accepted_substep_duration = max(result%diagnostics%max_accepted_substep_duration, &
           tx%accepted_dt)
    end if
  end subroutine accumulate_transaction

  pure real(real64) function progress_tolerance(user_tolerance, t0, t1) result(tol)
    real(real64), intent(in) :: user_tolerance, t0, t1
    tol = max(user_tolerance, 64.0_real64 * epsilon(1.0_real64) * &
         max(1.0_real64, abs(t0), abs(t1)))
  end function progress_tolerance

end module mod_canonical_interval_runtime
