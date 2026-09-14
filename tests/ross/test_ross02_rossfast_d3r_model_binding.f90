module mod_ross02_test_kernel
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED
  use mod_rossfast_d3r_execution_policy, only: rossfast_d3r_full_duration_for_index
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_trial_kernel_t, &
       rossfast_d3r_kernel_request_t, rossfast_d3r_kernel_result_t, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_SIGMA, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM, ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION, &
       ROSSFAST_D3R_STATE_CONSISTENCY_TOL, ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR, &
       ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE
  implicit none
  private

  integer, parameter, public :: MOCK_GOOD = 0
  integer, parameter, public :: MOCK_MALFORMED_CANDIDATE = 1
  integer, parameter, public :: MOCK_INCOMPLETE_MASS = 2
  integer, parameter, public :: MOCK_NO_CERTIFICATE = 3

  type, extends(rossfast_d3r_trial_kernel_t), public :: mock_rossfast_kernel_t
    integer :: mode = MOCK_GOOD
    logical :: reject_initial_above_level2 = .false.
    real(real64) :: outer_t0 = 0.0_real64
  contains
    procedure :: solve => mock_solve
  end type mock_rossfast_kernel_t

contains

  subroutine mock_solve(self, request, result)
    class(mock_rossfast_kernel_t), intent(in) :: self
    type(rossfast_d3r_kernel_request_t), intent(in) :: request
    type(rossfast_d3r_kernel_result_t), intent(out) :: result
    real(real64) :: dt, storage_increment, theta_increment, level2, origin_tol

    result = rossfast_d3r_kernel_result_t()
    if (request%base_state%active_nodes /= ROSSFAST_D3R_N_CELLS) return
    if (request%equal_internal_substeps /= 8) return
    if (request%sigma /= ROSSFAST_D3R_SIGMA) return
    if (request%hard_mass_tolerance_cm /= ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (request%boundary_envelope_fraction /= ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION) return
    if (request%state_consistency_tolerance /= ROSSFAST_D3R_STATE_CONSISTENCY_TOL) return
    if (request%temporal_resolution_floor /= ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR) return
    if (request%temporal_accuracy_tolerance /= ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE) return
    if (trim(request%material%material_id) /= 'O14') return

    dt = request%t1_day - request%t0_day
    if (dt <= 0.0_real64) return
    level2 = rossfast_d3r_full_duration_for_index(2)
    origin_tol = 4.0_real64 * max(spacing(request%t0_day), spacing(self%outer_t0))
    if (self%reject_initial_above_level2 .and. &
        abs(request%t0_day - self%outer_t0) <= origin_tol .and. dt > level2 + 1.0e-15_real64) then
      result%request_admitted = .true.
      result%solver_ok = .true.
      result%candidate_state = request%base_state
      result%mass_accounting_complete = .true.
      result%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      result%temporal_certificate_available = .true.
      result%temporal_indicator = 2.0_real64
      return
    end if

    result%request_admitted = .true.
    result%solver_ok = .true.
    if (self%mode == MOCK_MALFORMED_CANDIDATE) return

    result%candidate_state = request%base_state
    storage_increment = dt
    theta_increment = storage_increment / &
         (real(ROSSFAST_D3R_N_CELLS, real64) * ROSSFAST_D3R_DZ_CM)
    result%candidate_state%water_content = result%candidate_state%water_content + theta_increment
    result%candidate_state%pressure_head_cm = result%candidate_state%pressure_head_cm - dt
    result%mass_in_cm = storage_increment
    result%mass_out_cm = 0.0_real64
    result%mass_accounting_complete = .true.
    result%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    result%temporal_certificate_available = .true.
    result%temporal_indicator = 0.25_real64
    result%bottom_interface_exchange_available = .true.
    result%bottom_outward_exchange_cm = 0.0_real64
    result%terminal_bottom_outward_flux_cm_per_day = 0.0_real64
    result%local_terminal_sensitivity_available = .true.
    result%dh_bottom_dq_bottom_day = 0.125_real64
    result%linear_solves = 3
    result%alternative_solver_calls = 1

    if (self%mode == MOCK_INCOMPLETE_MASS) then
      result%mass_accounting_complete = .false.
      result%missing_mass_contribution_mask = TX_MASS_MISSING_UNSPECIFIED
    else if (self%mode == MOCK_NO_CERTIFICATE) then
      result%temporal_certificate_available = .false.
    end if
  end subroutine mock_solve

end module mod_ross02_test_kernel

program test_ross02_rossfast_d3r_model_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, &
       canonical_result_t, CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_select_transaction_window, rossfast_d3r_full_duration_for_index, &
       ROSSFAST_D3R_OUTER_HORIZON_DAY, ROSSFAST_D3R_MIN_FULL_DURATION_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_model_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_t, bind_rossfast_d3r_model, &
       rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_ross02_test_kernel, only: mock_rossfast_kernel_t, MOCK_GOOD, &
       MOCK_MALFORMED_CANDIDATE, MOCK_INCOMPLETE_MASS, MOCK_NO_CERTIFICATE
  implicit none

  call test_binding_contract_rejects_drift()
  call test_full_interval_commits_once()
  call test_certificate_retry_composes_remainder()
  call test_malformed_candidate_fails_closed()
  call test_incomplete_mass_fails_closed()
  call test_missing_certificate_fails_closed()

  write(*,'(a)') 'ROSS02_ROSSFAST_D3R_MODEL_BINDING_GATE PASS'

contains

  subroutine init_config(config)
    type(canonical_numerical_config_t), intent(out) :: config

    config = canonical_numerical_config_t()
    config%max_committed_substeps = 32
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%mass_tolerance = 1.0e-12_real64
    call apply_rossfast_d3r_retry_policy(config)
  end subroutine init_config

  subroutine init_state(committed)
    class(transaction_state_t), allocatable, intent(out) :: committed

    allocate(rossfast_d3r_state_t :: committed)
    select type(state => committed)
    type is(rossfast_d3r_state_t)
      state%active_nodes = ROSSFAST_D3R_N_CELLS
      allocate(state%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
      allocate(state%water_content(ROSSFAST_D3R_N_CELLS))
      state%pressure_head_cm = -100.0_real64
      state%water_content = 0.2_real64
    class default
      error stop 101
    end select
  end subroutine init_state

  subroutine init_model(model, kernel)
    type(rossfast_d3r_model_t), intent(out) :: model
    type(mock_rossfast_kernel_t), target, intent(in) :: kernel
    type(rossfast_d3r_material_t) :: material
    real(real64) :: dz(ROSSFAST_D3R_N_CELLS)
    logical :: found, valid

    call rossfast_d3r_material_from_id('O14', material, found)
    if (.not. found) error stop 102
    dz = ROSSFAST_D3R_DZ_CM
    call bind_rossfast_d3r_model(model, kernel, material, dz, 8, valid)
    if (.not. valid) error stop 103
  end subroutine init_model

  function committed_storage(committed) result(value)
    class(transaction_state_t), allocatable, intent(in) :: committed
    real(real64) :: value

    select type(state => committed)
    type is(rossfast_d3r_state_t)
      value = ROSSFAST_D3R_DZ_CM * sum(state%water_content)
    class default
      error stop 104
    end select
  end function committed_storage

  subroutine assert_close(actual, expected, tolerance, code)
    real(real64), intent(in) :: actual, expected, tolerance
    integer, intent(in) :: code
    if (abs(actual - expected) > tolerance) error stop code
  end subroutine assert_close

  subroutine test_binding_contract_rejects_drift()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_material_t) :: material
    real(real64) :: dz(ROSSFAST_D3R_N_CELLS)
    logical :: found, valid

    call rossfast_d3r_material_from_id('O14', material, found)
    if (.not. found) error stop 111
    dz = ROSSFAST_D3R_DZ_CM

    material%ksatfit_cm_per_day = material%ksatfit_cm_per_day + 1.0e-12_real64
    call bind_rossfast_d3r_model(model, kernel, material, dz, 8, valid)
    if (valid) error stop 112

    call rossfast_d3r_material_from_id('O14', material, found)
    dz = ROSSFAST_D3R_DZ_CM
    dz(1) = 9.0_real64
    call bind_rossfast_d3r_model(model, kernel, material, dz, 8, valid)
    if (valid) error stop 113

    dz = ROSSFAST_D3R_DZ_CM
    call bind_rossfast_d3r_model(model, kernel, material, dz, 3, valid)
    if (valid) error stop 114
  end subroutine test_binding_contract_rejects_drift

  subroutine test_full_interval_commits_once()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0

    kernel%mode = MOCK_GOOD
    call init_model(model, kernel)
    call init_state(committed)
    call init_config(config)
    storage0 = committed_storage(committed)
    interval = canonical_interval_t(5.0_real64, 5.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 121
    if (result%diagnostics%transaction_calls /= 1) error stop 122
    if (result%diagnostics%external_commits /= 1) error stop 123
    if (result%mass%accepted_transaction_count /= 1 .or. .not. result%mass%complete) error stop 124
    call assert_close(committed_storage(committed) - storage0, &
         ROSSFAST_D3R_OUTER_HORIZON_DAY, 2.0e-13_real64, 125)
    call assert_close(result%mass%residual, 0.0_real64, 2.0e-13_real64, 126)
    if (result%diagnostics%linear_solves /= 3) error stop 127
    if (result%diagnostics%alternative_solver_calls /= 1) error stop 128
    if (.not. result%interface_sensitivity%available) error stop 129
    if (.not. result%interface_sensitivity%covers_requested_interval) error stop 130
    if (.not. result%bottom_interface_exchange_available) error stop 131
  end subroutine test_full_interval_commits_once

  subroutine test_certificate_retry_composes_remainder()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0

    kernel%mode = MOCK_GOOD
    kernel%reject_initial_above_level2 = .true.
    kernel%outer_t0 = 7.0_real64
    call init_model(model, kernel)
    call init_state(committed)
    call init_config(config)
    storage0 = committed_storage(committed)
    interval = canonical_interval_t(7.0_real64, 7.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 141
    if (result%diagnostics%transaction_calls /= 3) error stop 142
    if (result%diagnostics%retries /= 2 .or. result%diagnostics%rollbacks /= 2) error stop 143
    if (result%diagnostics%temporal_rejections /= 2) error stop 144
    if (result%diagnostics%solver_rejections /= 0) error stop 145
    if (result%diagnostics%external_commits /= 1) error stop 146
    call assert_close(result%diagnostics%min_accepted_substep_duration, &
         rossfast_d3r_full_duration_for_index(2), 2.0e-13_real64, 147)
    call assert_close(result%diagnostics%max_accepted_substep_duration, &
         rossfast_d3r_full_duration_for_index(1), 2.0e-13_real64, 148)
    call assert_close(committed_storage(committed) - storage0, &
         ROSSFAST_D3R_OUTER_HORIZON_DAY, 2.0e-13_real64, 149)
    if (.not. result%interface_sensitivity%available) error stop 150
    if (result%interface_sensitivity%covers_requested_interval) error stop 151
  end subroutine test_certificate_retry_composes_remainder

  subroutine test_malformed_candidate_fails_closed()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0

    kernel%mode = MOCK_MALFORMED_CANDIDATE
    call init_model(model, kernel)
    call init_state(committed)
    call init_config(config)
    storage0 = committed_storage(committed)
    interval = canonical_interval_t(11.0_real64, 11.0_real64 + ROSSFAST_D3R_MIN_FULL_DURATION_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED) error stop 161
    if (result%diagnostics%solver_rejections /= 1) error stop 162
    if (result%diagnostics%external_commits /= 0) error stop 163
    call assert_close(committed_storage(committed), storage0, 0.0_real64, 164)
  end subroutine test_malformed_candidate_fails_closed

  subroutine test_incomplete_mass_fails_closed()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0

    kernel%mode = MOCK_INCOMPLETE_MASS
    call init_model(model, kernel)
    call init_state(committed)
    call init_config(config)
    storage0 = committed_storage(committed)
    interval = canonical_interval_t(13.0_real64, 13.0_real64 + ROSSFAST_D3R_MIN_FULL_DURATION_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED) error stop 171
    if (result%diagnostics%mass_rejections /= 1) error stop 172
    if (result%diagnostics%external_commits /= 0) error stop 173
    call assert_close(committed_storage(committed), storage0, 0.0_real64, 174)
  end subroutine test_incomplete_mass_fails_closed

  subroutine test_missing_certificate_fails_closed()
    type(rossfast_d3r_model_t) :: model
    type(mock_rossfast_kernel_t), target :: kernel
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0

    kernel%mode = MOCK_NO_CERTIFICATE
    call init_model(model, kernel)
    call init_state(committed)
    call init_config(config)
    storage0 = committed_storage(committed)
    interval = canonical_interval_t(17.0_real64, 17.0_real64 + ROSSFAST_D3R_MIN_FULL_DURATION_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED) error stop 181
    if (result%diagnostics%temporal_rejections /= 1) error stop 182
    if (result%diagnostics%temporal_certificate_unavailable_rejections /= 1) error stop 183
    if (result%diagnostics%external_commits /= 0) error stop 184
    call assert_close(committed_storage(committed), storage0, 0.0_real64, 185)
  end subroutine test_missing_certificate_fails_closed

end program test_ross02_rossfast_d3r_model_binding
