program test_fpm08a_single_level_linear_drainage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_process, only: drainage_linear_parameters_t, drainage_control_t, drainage_transfer_t, &
       drainage_diagnostics_t, evaluate_single_level_linear_drainage, DRAINAGE_OK, DRAINAGE_INVALID_PARAMETERS, &
       DRAINAGE_INVALID_HYDRAULIC_VIEW, DRAINAGE_INVALID_CONTROL
  implicit none

  type(drainage_linear_parameters_t) :: parameters, bad_parameters
  type(drainage_control_t) :: control, bad_control
  type(process_hydraulic_view_t) :: view, view_b, bad_view
  type(drainage_transfer_t) :: transfer_a1, transfer_a2, transfer_b, flux, plus_transfer, minus_transfer
  type(drainage_diagnostics_t) :: diag_a1, diag_a2, diag_b, diag, plus_diag, minus_diag
  real(real64), parameter :: tol = 2048.0_real64*epsilon(1.0_real64)
  real(real64), parameter :: delta = 1.0e-5_real64
  real(real64) :: fd

  parameters%drainage_resistance = 100.0_real64
  control%drain_head = -50.0_real64
  view = process_hydraulic_view_t()
  view%groundwater_level = -20.0_real64

  call evaluate_single_level_linear_drainage(parameters, view, control, transfer_a1, diag_a1)
  call require(diag_a1%status == DRAINAGE_OK, 'active status')
  call require(diag_a1%evaluated .and. diag_a1%active, 'active route')
  call require(close(diag_a1%head_difference, 30.0_real64), 'active head difference')
  call require(close(transfer_a1%soil_to_drain_rate, 0.3_real64), 'active linear drainage law')
  call require(transfer_a1%derivative_defined, 'active derivative defined')
  call require(close(transfer_a1%dq_dgroundwater_level, 0.01_real64), 'active analytic derivative')
  call require(diag_a1%mass_is_authoritative_external_transfer, 'authoritative external transfer flag')
  write(*,'(A)') 'FPM08A_ACTIVE_LINEAR_DRAINAGE_LAW=PASS'

  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = -20.0_real64
  call evaluate_single_level_linear_drainage(parameters, bad_view, control, flux, diag)
  call require(diag%status == DRAINAGE_OK .and. close(flux%soil_to_drain_rate, 0.3_real64), &
       'groundwater-only hydraulic dependency')
  call require(.not. allocated(bad_view%pressure_head) .and. .not. allocated(bad_view%water_content), &
       'unrelated hydraulic arrays remain unnecessary')
  write(*,'(A)') 'FPM08A_GROUNDWATER_ONLY_HYDRAULIC_VIEW=PASS'

  view%groundwater_level = control%drain_head - 10.0_real64
  call evaluate_single_level_linear_drainage(parameters, view, control, flux, diag)
  call require(diag%status == DRAINAGE_OK .and. diag%evaluated .and. .not. diag%active, 'inactive route')
  call require(flux%soil_to_drain_rate == 0.0_real64, 'inactive route zero transfer')
  call require(flux%derivative_defined .and. flux%dq_dgroundwater_level == 0.0_real64, &
       'inactive route zero derivative')
  write(*,'(A)') 'FPM08A_DRAINAGE_ONLY_NO_REVERSE_EXCHANGE=PASS'

  view%groundwater_level = control%drain_head
  call evaluate_single_level_linear_drainage(parameters, view, control, flux, diag)
  call require(diag%status == DRAINAGE_OK .and. diag%activation_kink, 'activation kink diagnostic')
  call require(flux%soil_to_drain_rate == 0.0_real64, 'activation kink zero flux')
  call require(.not. flux%derivative_defined, 'activation kink derivative unavailable')
  write(*,'(A)') 'FPM08A_NONSMOOTH_ACTIVATION_DIAGNOSTIC=PASS'

  view%groundwater_level = -20.0_real64 + delta
  call evaluate_single_level_linear_drainage(parameters, view, control, plus_transfer, plus_diag)
  view%groundwater_level = -20.0_real64 - delta
  call evaluate_single_level_linear_drainage(parameters, view, control, minus_transfer, minus_diag)
  fd = (plus_transfer%soil_to_drain_rate - minus_transfer%soil_to_drain_rate) / (2.0_real64*delta)
  call require(close(fd, 1.0_real64/parameters%drainage_resistance), 'active derivative finite difference')
  call require(plus_diag%active .and. minus_diag%active, 'finite-difference probes stay active')
  write(*,'(A)') 'FPM08A_ACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS'

  view%groundwater_level = -80.0_real64 + delta
  call evaluate_single_level_linear_drainage(parameters, view, control, plus_transfer, plus_diag)
  view%groundwater_level = -80.0_real64 - delta
  call evaluate_single_level_linear_drainage(parameters, view, control, minus_transfer, minus_diag)
  fd = (plus_transfer%soil_to_drain_rate - minus_transfer%soil_to_drain_rate) / (2.0_real64*delta)
  call require(fd == 0.0_real64, 'inactive derivative finite difference')
  call require(.not. plus_diag%active .and. .not. minus_diag%active, 'inactive finite-difference probes stay inactive')
  write(*,'(A)') 'FPM08A_INACTIVE_DERIVATIVE_FINITE_DIFFERENCE=PASS'

  view%groundwater_level = -20.0_real64
  call evaluate_single_level_linear_drainage(parameters, view, control, transfer_a1, diag_a1)
  view_b = process_hydraulic_view_t()
  view_b%groundwater_level = -5.0_real64
  call evaluate_single_level_linear_drainage(parameters, view_b, control, transfer_b, diag_b)
  call require(.not. same_bits(transfer_a1%soil_to_drain_rate, transfer_b%soil_to_drain_rate), 'B differs from A')
  view%groundwater_level = -20.0_real64
  call evaluate_single_level_linear_drainage(parameters, view, control, transfer_a2, diag_a2)
  call require(same_transfer_bits(transfer_a1, transfer_a2), 'A/B/A transfer identity')
  call require(same_diag_bits(diag_a1, diag_a2), 'A/B/A diagnostic identity')
  write(*,'(A)') 'FPM08A_STATELESS_A_B_A_IDENTITY=PASS'

  bad_parameters = parameters
  bad_parameters%drainage_resistance = 0.0_real64
  call evaluate_single_level_linear_drainage(bad_parameters, view, control, flux, diag)
  call require(diag%status == DRAINAGE_INVALID_PARAMETERS .and. .not. diag%evaluated, 'zero resistance rejected')

  bad_parameters = parameters
  bad_parameters%drainage_resistance = -1.0_real64
  call evaluate_single_level_linear_drainage(bad_parameters, view, control, flux, diag)
  call require(diag%status == DRAINAGE_INVALID_PARAMETERS, 'negative resistance rejected')

  bad_control = control
  bad_control%drain_head = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_single_level_linear_drainage(parameters, view, bad_control, flux, diag)
  call require(diag%status == DRAINAGE_INVALID_CONTROL, 'nonfinite drain head rejected')

  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_single_level_linear_drainage(parameters, bad_view, control, flux, diag)
  call require(diag%status == DRAINAGE_INVALID_HYDRAULIC_VIEW, 'nonfinite groundwater level rejected')
  write(*,'(A)') 'FPM08A_INVALID_DOMAIN_FAIL_CLOSED=PASS'

  view%groundwater_level = -20.0_real64
  call evaluate_single_level_linear_drainage(parameters, view, control, flux, diag)
  call require(flux%soil_to_drain_rate >= 0.0_real64, 'candidate transfer cannot inject soil water')
  call require(close(flux%soil_to_drain_rate*2.5_real64, 0.75_real64), 'external ledger rate integrates once')
  write(*,'(A)') 'FPM08A_AUTHORITATIVE_TRANSFER_SIGN_AND_RATE=PASS'

  write(*,'(A)') 'FPM08A_SINGLE_LEVEL_LINEAR_DRAINAGE_TEST PASS'

contains

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function same_transfer_bits(a,b) result(equal)
    type(drainage_transfer_t), intent(in) :: a,b
    equal = same_bits(a%soil_to_drain_rate,b%soil_to_drain_rate) .and. &
         (a%derivative_defined .eqv. b%derivative_defined) .and. &
         same_bits(a%dq_dgroundwater_level,b%dq_dgroundwater_level)
  end function same_transfer_bits

  logical function same_diag_bits(a,b) result(equal)
    type(drainage_diagnostics_t), intent(in) :: a,b
    equal = a%status == b%status .and. (a%evaluated .eqv. b%evaluated) .and. &
         (a%active .eqv. b%active) .and. (a%activation_kink .eqv. b%activation_kink) .and. &
         same_bits(a%groundwater_level,b%groundwater_level) .and. &
         same_bits(a%drain_head,b%drain_head) .and. same_bits(a%head_difference,b%head_difference) .and. &
         (a%mass_is_authoritative_external_transfer .eqv. b%mass_is_authoritative_external_transfer)
  end function same_diag_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08a_single_level_linear_drainage
