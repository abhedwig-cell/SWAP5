module mod_fross02_mock_kernel
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: TX_MASS_MISSING_NONE
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_trial_kernel_t, &
       rossfast_d3r_kernel_request_t, rossfast_d3r_kernel_result_t, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_SIGMA, &
       ROSSFAST_D3R_HARD_MASS_TOL_CM, ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR, &
       ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE
  implicit none
  private

  integer, parameter, public :: MOCK_GOOD = 0
  integer, parameter, public :: MOCK_BAD_MASS = 1
  integer, parameter, public :: MOCK_BAD_TEMPORAL = 2

  type, extends(rossfast_d3r_trial_kernel_t), public :: mock_kernel_t
    integer :: mode = MOCK_GOOD
  contains
    procedure :: solve => mock_solve
  end type mock_kernel_t

contains

  subroutine mock_solve(self, request, result)
    class(mock_kernel_t), intent(in) :: self
    type(rossfast_d3r_kernel_request_t), intent(in) :: request
    type(rossfast_d3r_kernel_result_t), intent(out) :: result
    real(real64) :: dt, top_transfer, bottom_transfer, net_transfer, delta_theta

    result = rossfast_d3r_kernel_result_t()
    if (request%base_state%active_nodes /= ROSSFAST_D3R_N_CELLS) return
    if (request%equal_internal_substeps /= 8) return
    if (request%sigma /= ROSSFAST_D3R_SIGMA) return
    if (request%hard_mass_tolerance_cm /= ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (request%temporal_resolution_floor /= ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR) return
    if (request%temporal_accuracy_tolerance /= ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE) return

    dt = request%t1_day - request%t0_day
    top_transfer = dt * request%forcing%top_flux_cm_per_day
    bottom_transfer = dt * request%forcing%bottom_flux_upward_cm_per_day
    net_transfer = top_transfer + bottom_transfer
    delta_theta = net_transfer / (real(ROSSFAST_D3R_N_CELLS, real64) * ROSSFAST_D3R_DZ_CM)

    result%request_admitted = .true.
    result%solver_ok = .true.
    result%candidate_state = request%base_state
    if (self%mode /= MOCK_BAD_MASS) then
      result%candidate_state%water_content = request%base_state%water_content + delta_theta
    end if

    result%mass_in_cm = max(top_transfer, 0.0_real64) + max(bottom_transfer, 0.0_real64)
    result%mass_out_cm = max(-top_transfer, 0.0_real64) + max(-bottom_transfer, 0.0_real64)
    result%mass_accounting_complete = .true.
    result%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    result%temporal_certificate_available = .true.
    if (self%mode == MOCK_BAD_TEMPORAL) then
      result%temporal_indicator = 2.0_real64
    else
      result%temporal_indicator = 0.5_real64
    end if

    result%bottom_interface_exchange_available = .true.
    result%bottom_outward_exchange_cm = -bottom_transfer
    result%terminal_bottom_outward_flux_cm_per_day = -request%forcing%bottom_flux_upward_cm_per_day
    result%local_terminal_sensitivity_available = .true.
    result%dh_bottom_dq_bottom_day = 1.0_real64
    result%linear_solves = request%equal_internal_substeps
  end subroutine mock_solve

end module mod_fross02_mock_kernel

program test_fross02_rossfast_d3r_model_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_interval_t, canonical_numerical_config_t, canonical_result_t, &
       CANONICAL_STATUS_COMPLETED, CANONICAL_STATUS_TRANSACTION_FAILED
  use mod_canonical_interval_runtime, only: run_canonical_interval
  use mod_rossfast_d3r_execution_policy, only: apply_rossfast_d3r_retry_policy, &
       rossfast_d3r_select_transaction_window, ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_model_t, rossfast_d3r_state_t, &
       rossfast_d3r_forcing_t, rossfast_d3r_material_t, bind_rossfast_d3r_model, &
       rossfast_d3r_material_from_id, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_fross02_mock_kernel, only: mock_kernel_t, MOCK_GOOD, MOCK_BAD_MASS, MOCK_BAD_TEMPORAL
  implicit none

  call test_good_canonical_binding()
  call test_mass_gate_owns_commit()
  call test_temporal_gate_owns_commit()
  call test_binding_fails_closed_outside_frozen_material()

  write(*,'(a)') 'FROSS02_ROSSFAST_D3R_MODEL_BINDING_GATE PASS'

contains

  subroutine init_config(config)
    type(canonical_numerical_config_t), intent(out) :: config

    config = canonical_numerical_config_t()
    config%max_committed_substeps = 32
    config%transaction%temporal_mode = TX_TEMPORAL_MODEL_CERTIFICATE
    config%transaction%temporal_tolerance = 1.0e-6_real64
    config%transaction%mass_tolerance = 1.0e-12_real64
    call apply_rossfast_d3r_retry_policy(config)
  end subroutine init_config

  subroutine init_committed(committed)
    class(transaction_state_t), allocatable, intent(out) :: committed

    allocate(rossfast_d3r_state_t :: committed)
    select type(committed)
    type is(rossfast_d3r_state_t)
      committed%active_nodes = ROSSFAST_D3R_N_CELLS
      allocate(committed%pressure_head_cm(ROSSFAST_D3R_N_CELLS))
      allocate(committed%water_content(ROSSFAST_D3R_N_CELLS))
      committed%pressure_head_cm = -100.0_real64
      committed%water_content = 0.2_real64
    class default
      error stop 101
    end select
  end subroutine init_committed

  function storage_of(committed) result(storage)
    class(transaction_state_t), allocatable, intent(in) :: committed
    real(real64) :: storage

    select type(committed)
    type is(rossfast_d3r_state_t)
      storage = ROSSFAST_D3R_DZ_CM * sum(committed%water_content)
    class default
      error stop 102
    end select
  end function storage_of

  subroutine bind_fixture(model, kernel, valid)
    type(rossfast_d3r_model_t), intent(out) :: model
    type(mock_kernel_t), target, intent(in) :: kernel
    logical, intent(out) :: valid
    type(rossfast_d3r_material_t) :: material
    real(real64) :: thickness(ROSSFAST_D3R_N_CELLS)
    logical :: found

    call rossfast_d3r_material_from_id('B01', material, found)
    if (.not. found) error stop 103
    thickness = ROSSFAST_D3R_DZ_CM
    call bind_rossfast_d3r_model(model, kernel, material, thickness, 8, valid)
  end subroutine bind_fixture

  subroutine assert_close(actual, expected, tolerance, code)
    real(real64), intent(in) :: actual, expected, tolerance
    integer, intent(in) :: code
    if (abs(actual - expected) > tolerance) error stop code
  end subroutine assert_close

  subroutine test_good_canonical_binding()
    type(mock_kernel_t), target :: kernel
    type(rossfast_d3r_model_t) :: model
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0, expected_transfer
    logical :: valid

    kernel%mode = MOCK_GOOD
    call bind_fixture(model, kernel, valid)
    if (.not. valid) error stop 201
    call init_committed(committed)
    storage0 = storage_of(committed)
    call init_config(config)
    forcing%top_flux_cm_per_day = 1.0_real64
    forcing%bottom_flux_upward_cm_per_day = 0.25_real64
    interval = canonical_interval_t(5.0_real64, 5.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    expected_transfer = ROSSFAST_D3R_OUTER_HORIZON_DAY * 1.25_real64
    if (result%status /= CANONICAL_STATUS_COMPLETED .or. .not. result%completed) error stop 202
    if (result%diagnostics%transaction_calls /= 1 .or. result%diagnostics%external_commits /= 1) error stop 203
    if (.not. result%mass%complete .or. result%mass%accepted_transaction_count /= 1) error stop 204
    call assert_close(storage_of(committed) - storage0, expected_transfer, 2.0e-13_real64, 205)
    call assert_close(result%mass%total_in, expected_transfer, 2.0e-15_real64, 206)
    call assert_close(result%mass%total_out, 0.0_real64, 0.0_real64, 207)
    call assert_close(result%mass%residual, 0.0_real64, 2.0e-13_real64, 208)
    if (.not. result%bottom_interface_exchange_available) error stop 209
    call assert_close(result%bottom_outward_exchange_native, -0.25_real64 * ROSSFAST_D3R_OUTER_HORIZON_DAY, &
         2.0e-15_real64, 210)
    call assert_close(result%terminal_bottom_outward_flux_native, -0.25_real64, 0.0_real64, 211)
    if (.not. result%interface_sensitivity%available) error stop 212
    if (.not. result%interface_sensitivity%covers_requested_interval) error stop 213
    call assert_close(result%interface_sensitivity%dh_bottom_dq_bottom, 1.0_real64, 0.0_real64, 214)
  end subroutine test_good_canonical_binding

  subroutine test_mass_gate_owns_commit()
    type(mock_kernel_t), target :: kernel
    type(rossfast_d3r_model_t) :: model
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0
    logical :: valid

    kernel%mode = MOCK_BAD_MASS
    call bind_fixture(model, kernel, valid)
    if (.not. valid) error stop 221
    call init_committed(committed)
    storage0 = storage_of(committed)
    call init_config(config)
    forcing%top_flux_cm_per_day = 1.0_real64
    forcing%bottom_flux_upward_cm_per_day = 0.25_real64
    interval = canonical_interval_t(7.0_real64, 7.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED .or. result%completed) error stop 222
    if (result%diagnostics%mass_rejections /= 9) error stop 223
    if (result%diagnostics%attempts /= 9 .or. result%diagnostics%external_commits /= 0) error stop 224
    call assert_close(storage_of(committed), storage0, 0.0_real64, 225)
  end subroutine test_mass_gate_owns_commit

  subroutine test_temporal_gate_owns_commit()
    type(mock_kernel_t), target :: kernel
    type(rossfast_d3r_model_t) :: model
    type(rossfast_d3r_forcing_t) :: forcing
    type(canonical_interval_t) :: interval
    type(canonical_numerical_config_t) :: config
    type(canonical_result_t) :: result
    class(transaction_state_t), allocatable :: committed
    real(real64) :: storage0
    logical :: valid

    kernel%mode = MOCK_BAD_TEMPORAL
    call bind_fixture(model, kernel, valid)
    if (.not. valid) error stop 231
    call init_committed(committed)
    storage0 = storage_of(committed)
    call init_config(config)
    forcing%top_flux_cm_per_day = 0.5_real64
    forcing%bottom_flux_upward_cm_per_day = 0.0_real64
    interval = canonical_interval_t(9.0_real64, 9.0_real64 + ROSSFAST_D3R_OUTER_HORIZON_DAY)

    call run_canonical_interval(model, committed, forcing, interval, config, result, &
         rossfast_d3r_select_transaction_window)

    if (result%status /= CANONICAL_STATUS_TRANSACTION_FAILED .or. result%completed) error stop 232
    if (result%diagnostics%temporal_rejections /= 9) error stop 233
    if (result%diagnostics%attempts /= 9 .or. result%diagnostics%external_commits /= 0) error stop 234
    call assert_close(storage_of(committed), storage0, 0.0_real64, 235)
  end subroutine test_temporal_gate_owns_commit

  subroutine test_binding_fails_closed_outside_frozen_material()
    type(mock_kernel_t), target :: kernel
    type(rossfast_d3r_model_t) :: model
    type(rossfast_d3r_material_t) :: material
    real(real64) :: thickness(ROSSFAST_D3R_N_CELLS)
    logical :: found, valid

    call rossfast_d3r_material_from_id('B01', material, found)
    if (.not. found) error stop 241
    material%theta_s = material%theta_s + 1.0e-6_real64
    thickness = ROSSFAST_D3R_DZ_CM
    call bind_rossfast_d3r_model(model, kernel, material, thickness, 8, valid)
    if (valid) error stop 242

    call rossfast_d3r_material_from_id('B01', material, found)
    call bind_rossfast_d3r_model(model, kernel, material, thickness, 3, valid)
    if (valid) error stop 243
  end subroutine test_binding_fails_closed_outside_frozen_material

end program test_fross02_rossfast_d3r_model_binding
