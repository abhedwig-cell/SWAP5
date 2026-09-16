program test_m1_c4_canonical_result_text_adapter
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_result_t, CANONICAL_STATUS_COMPLETED
  use mod_canonical_result_text_adapter, only: serialize_canonical_result_text
  implicit none

  type(canonical_result_t) :: result, before
  character(len=:), allocatable :: text

  call seed_result(result)
  before = result

  call serialize_canonical_result_text(result, text)

  call require(len_trim(text) > 0, 'serialized text nonempty')
  call require(index(text, 'SWAP5_CANONICAL_RESULT_SNAPSHOT') == 1, 'snapshot header')
  call require(index(text, 'status=0') > 0, 'status serialized')
  call require(index(text, 'completed=true') > 0, 'completion serialized')
  call require(index(text, 'mass_origin_lineage_id=440044') > 0, 'lineage serialized')
  call require(index(text, 'diagnostics_external_commits=1') > 0, 'commit count serialized')
  call require(index(text, 'bottom_interface_exchange_available=true') > 0, 'bottom exchange availability serialized')
  call require(same_result_probe(result, before), 'typed result unchanged by serialization')

  write(*,'(A)') 'M1_C4_TYPED_RESULT_SERIALIZATION=PASS'
  write(*,'(A)') 'M1_C4_RESULT_INPUT_IDENTITY=PASS'
  write(*,'(A)') 'M1_C4_NO_PHYSICAL_STATE_AUTHORITY=PASS'
  write(*,'(A)') 'M1_C4_OUTPUT_SERIALIZATION_GATE=PASS'

contains

  subroutine seed_result(value)
    type(canonical_result_t), intent(out) :: value

    value = canonical_result_t()
    value%status = CANONICAL_STATUS_COMPLETED
    value%completed = .true.
    value%requested_t0 = 2700.125_real64
    value%requested_t1 = 2700.375_real64
    value%completed_t = 2700.375_real64

    value%mass%complete = .true.
    value%mass%interval_t0 = value%requested_t0
    value%mass%interval_t1 = value%requested_t1
    value%mass%origin_lineage_id = 440044_int64
    value%mass%origin_revision = 7_int64
    value%mass%accepted_transaction_count = 1
    value%mass%missing_contribution_mask = 0_int64
    value%mass%storage_start = 10.0_real64
    value%mass%storage_end = 10.125_real64
    value%mass%storage_change = 0.125_real64
    value%mass%total_in = 0.25_real64
    value%mass%total_out = 0.125_real64
    value%mass%residual = 0.0_real64

    value%diagnostics%transaction_calls = 1
    value%diagnostics%committed_substeps = 1
    value%diagnostics%external_commits = 1
    value%diagnostics%attempts = 1
    value%diagnostics%retries = 0
    value%diagnostics%rollbacks = 0
    value%diagnostics%solver_rejections = 0
    value%diagnostics%temporal_rejections = 0
    value%diagnostics%mass_rejections = 0
    value%diagnostics%max_abs_step_mass_residual = 0.0_real64
    value%diagnostics%max_temporal_indicator = 0.25_real64
    value%diagnostics%min_accepted_substep_duration = 0.25_real64
    value%diagnostics%max_accepted_substep_duration = 0.25_real64

    value%interface_sensitivity%available = .true.
    value%interface_sensitivity%semantic = 1
    value%interface_sensitivity%dh_bottom_dq_bottom = -2.5_real64
    value%interface_sensitivity%method = 'test-probe'
    value%interface_sensitivity%origin_t0 = value%requested_t0
    value%interface_sensitivity%origin_t1 = value%requested_t1
    value%interface_sensitivity%covers_requested_interval = .true.

    value%accepted_trajectory_direction%requested = .true.
    value%accepted_trajectory_direction%available = .true.
    value%accepted_trajectory_direction%worker_id = 3
    value%accepted_trajectory_direction%generation = 9_int64
    value%accepted_trajectory_direction%control_coordinate = 2
    value%accepted_trajectory_direction%accepted_steps = 1
    value%accepted_trajectory_direction%origin_t0 = value%requested_t0
    value%accepted_trajectory_direction%accepted_t1 = value%requested_t1
    allocate(value%accepted_trajectory_direction%final_pressure_head_direction(2))
    allocate(value%accepted_trajectory_direction%final_water_content_direction(2))
    value%accepted_trajectory_direction%final_pressure_head_direction = [1.25_real64, -3.5_real64]
    value%accepted_trajectory_direction%final_water_content_direction = [0.31_real64, 0.29_real64]
    value%accepted_trajectory_direction%final_ponding_direction = 0.01_real64
    value%accepted_trajectory_direction%accepted_bottom_exchange_derivative = 4.0_real64
    value%accepted_trajectory_direction%method = 'test-direction'
    value%accepted_trajectory_direction%route = 'accepted-trajectory'
    value%accepted_trajectory_direction%additional_tridiagonal_backsolves = 1
    value%accepted_trajectory_direction%additional_jacobian_builds = 0
    value%accepted_trajectory_direction%additional_full_nonlinear_solves = 0

    value%bottom_interface_exchange_available = .true.
    value%bottom_outward_exchange_native = -0.125_real64
    value%terminal_bottom_outward_flux_native = -0.5_real64
  end subroutine seed_result

  logical function same_result_probe(a, b) result(equal)
    type(canonical_result_t), intent(in) :: a, b

    equal = a%status == b%status .and. a%completed .eqv. b%completed .and. &
            same_real(a%requested_t0, b%requested_t0) .and. &
            same_real(a%requested_t1, b%requested_t1) .and. &
            same_real(a%completed_t, b%completed_t) .and. &
            a%mass%complete .eqv. b%mass%complete .and. &
            a%mass%origin_lineage_id == b%mass%origin_lineage_id .and. &
            a%mass%origin_revision == b%mass%origin_revision .and. &
            a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
            a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
            same_real(a%mass%storage_start, b%mass%storage_start) .and. &
            same_real(a%mass%storage_end, b%mass%storage_end) .and. &
            same_real(a%mass%storage_change, b%mass%storage_change) .and. &
            same_real(a%mass%total_in, b%mass%total_in) .and. &
            same_real(a%mass%total_out, b%mass%total_out) .and. &
            same_real(a%mass%residual, b%mass%residual) .and. &
            a%diagnostics%external_commits == b%diagnostics%external_commits .and. &
            a%diagnostics%attempts == b%diagnostics%attempts .and. &
            a%diagnostics%retries == b%diagnostics%retries .and. &
            same_real(a%diagnostics%max_temporal_indicator, b%diagnostics%max_temporal_indicator) .and. &
            a%interface_sensitivity%available .eqv. b%interface_sensitivity%available .and. &
            a%interface_sensitivity%semantic == b%interface_sensitivity%semantic .and. &
            same_real(a%interface_sensitivity%dh_bottom_dq_bottom, b%interface_sensitivity%dh_bottom_dq_bottom) .and. &
            a%interface_sensitivity%method == b%interface_sensitivity%method .and. &
            a%accepted_trajectory_direction%requested .eqv. b%accepted_trajectory_direction%requested .and. &
            a%accepted_trajectory_direction%available .eqv. b%accepted_trajectory_direction%available .and. &
            a%accepted_trajectory_direction%generation == b%accepted_trajectory_direction%generation .and. &
            a%accepted_trajectory_direction%method == b%accepted_trajectory_direction%method .and. &
            a%accepted_trajectory_direction%route == b%accepted_trajectory_direction%route .and. &
            a%bottom_interface_exchange_available .eqv. b%bottom_interface_exchange_available .and. &
            same_real(a%bottom_outward_exchange_native, b%bottom_outward_exchange_native) .and. &
            same_real(a%terminal_bottom_outward_flux_native, b%terminal_bottom_outward_flux_native)

    if (.not. equal) return
    equal = allocated(a%accepted_trajectory_direction%final_pressure_head_direction) .and. &
            allocated(b%accepted_trajectory_direction%final_pressure_head_direction) .and. &
            allocated(a%accepted_trajectory_direction%final_water_content_direction) .and. &
            allocated(b%accepted_trajectory_direction%final_water_content_direction)
    if (.not. equal) return
    equal = size(a%accepted_trajectory_direction%final_pressure_head_direction) == &
            size(b%accepted_trajectory_direction%final_pressure_head_direction) .and. &
            size(a%accepted_trajectory_direction%final_water_content_direction) == &
            size(b%accepted_trajectory_direction%final_water_content_direction)
    if (.not. equal) return
    equal = all(transfer(a%accepted_trajectory_direction%final_pressure_head_direction, &
                         [0_int64, 0_int64]) == &
                transfer(b%accepted_trajectory_direction%final_pressure_head_direction, &
                         [0_int64, 0_int64])) .and. &
            all(transfer(a%accepted_trajectory_direction%final_water_content_direction, &
                         [0_int64, 0_int64]) == &
                transfer(b%accepted_trajectory_direction%final_water_content_direction, &
                         [0_int64, 0_int64]))
  end function same_result_probe

  logical function same_real(a, b) result(equal)
    real(real64), intent(in) :: a, b
    equal = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,A)') 'M1_C4_FAIL ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_m1_c4_canonical_result_text_adapter
