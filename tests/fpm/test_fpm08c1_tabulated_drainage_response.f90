program test_fpm08c1_tabulated_drainage_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_tabulated_response, only: drainage_tabulated_parameters_t, drainage_tabulated_result_t, &
       drainage_tabulated_diagnostics_t, evaluate_tabulated_drainage_response, DRAIN_TAB_OK, &
       DRAIN_TAB_INVALID_PARAMETERS, DRAIN_TAB_INVALID_HYDRAULIC_VIEW
  implicit none

  type(drainage_tabulated_parameters_t) :: p, p_signed, p_bad, p_single
  type(process_hydraulic_view_t) :: view, view_b, bad_view
  type(drainage_tabulated_result_t) :: a1, a2, b, r, r_plus, r_minus
  type(drainage_tabulated_diagnostics_t) :: da1, da2, db, d, d_plus, d_minus
  real(real64), parameter :: tol = 4096.0_real64*epsilon(1.0_real64)
  real(real64), parameter :: delta = 1.0e-5_real64
  real(real64) :: analytic_derivative, fd_derivative

  call configure_base(p)

  view = process_hydraulic_view_t()
  view%groundwater_level = -75.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(d%status == DRAIN_TAB_OK .and. d%evaluated, 'negative-gwl active status')
  call require(close(r%signed_soil_to_drain_rate,0.35_real64), 'negative-gwl interpolation')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,-0.006_real64), &
       'negative-gwl derivative')
  call require(d%segment_index == 2, 'negative-gwl segment')
  write(*,'(A)') 'FPM08C1_NEGATIVE_GWL_LINEAR_SEGMENT=PASS'

  view%groundwater_level = 75.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.35_real64), 'positive-gwl abs parity')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.006_real64), &
       'positive-gwl derivative sign')
  write(*,'(A)') 'FPM08C1_LEGACY_ABS_GWL_PARITY=PASS'

  view%groundwater_level = -25.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.1_real64), 'first segment interpolation')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,-0.004_real64), &
       'first segment derivative')
  analytic_derivative = r%dq_dgroundwater_level
  write(*,'(A)') 'FPM08C1_OPEN_SEGMENT_ANALYTIC_DERIVATIVE=PASS'

  view%groundwater_level = -25.0_real64 + delta
  call evaluate_tabulated_drainage_response(p,view,r_plus,d_plus)
  view%groundwater_level = -25.0_real64 - delta
  call evaluate_tabulated_drainage_response(p,view,r_minus,d_minus)
  fd_derivative = (r_plus%signed_soil_to_drain_rate-r_minus%signed_soil_to_drain_rate)/(2.0_real64*delta)
  call require(d_plus%segment_index == 1 .and. d_minus%segment_index == 1, 'finite difference remains on segment')
  call require(close(fd_derivative,analytic_derivative), 'production derivative finite difference')
  write(*,'(A)') 'FPM08C1_ANALYTIC_DERIVATIVE_FINITE_DIFFERENCE=PASS'

  view%groundwater_level = -150.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.5_real64), 'upper clamp value')
  call require(d%clamped_upper .and. r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), &
       'upper clamp derivative')
  write(*,'(A)') 'FPM08C1_UPPER_ENDPOINT_CLAMP=PASS'

  p_signed = drainage_tabulated_parameters_t()
  allocate(p_signed%groundwater_depth(3),p_signed%signed_exchange_rate(3))
  p_signed%groundwater_depth = [10.0_real64,50.0_real64,100.0_real64]
  p_signed%signed_exchange_rate = [-0.2_real64,0.0_real64,0.5_real64]
  view%groundwater_level = 0.0_real64
  call evaluate_tabulated_drainage_response(p_signed,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,-0.2_real64), 'lower clamp signed value')
  call require(d%clamped_lower .and. r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), &
       'lower clamp derivative')
  view%groundwater_level = -30.0_real64
  call evaluate_tabulated_drainage_response(p_signed,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,-0.1_real64), 'negative exchange preserved')
  write(*,'(A)') 'FPM08C1_SIGNED_EXCHANGE_AND_LOWER_CLAMP=PASS'

  view%groundwater_level = -50.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.2_real64), 'interior knot value')
  call require(d%at_table_knot .and. .not. r%derivative_defined, 'interior knot derivative held')
  view%groundwater_level = 0.0_real64
  call evaluate_tabulated_drainage_response(p,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.0_real64), 'zero-depth knot value')
  call require(d%at_table_knot .and. .not. r%derivative_defined, 'abs-origin knot derivative held')
  write(*,'(A)') 'FPM08C1_TABLE_KNOT_DERIVATIVE_UNAVAILABLE=PASS'

  p_single = drainage_tabulated_parameters_t()
  allocate(p_single%groundwater_depth(1),p_single%signed_exchange_rate(1))
  p_single%groundwater_depth = [40.0_real64]
  p_single%signed_exchange_rate = [0.17_real64]
  view%groundwater_level = -999.0_real64
  call evaluate_tabulated_drainage_response(p_single,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,0.17_real64), 'single-point constant')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), &
       'single-point zero derivative')
  write(*,'(A)') 'FPM08C1_SINGLE_POINT_CONSTANT_TABLE=PASS'

  p_bad = p
  p_bad%groundwater_depth(3) = p_bad%groundwater_depth(2)
  view%groundwater_level = -75.0_real64
  call evaluate_tabulated_drainage_response(p_bad,view,r,d)
  call require(d%status == DRAIN_TAB_INVALID_PARAMETERS .and. .not. d%evaluated, &
       'duplicate knot rejected')

  p_bad = p
  p_bad%groundwater_depth(1) = -1.0_real64
  call evaluate_tabulated_drainage_response(p_bad,view,r,d)
  call require(d%status == DRAIN_TAB_INVALID_PARAMETERS, 'negative normalized depth rejected')

  p_bad = drainage_tabulated_parameters_t()
  allocate(p_bad%groundwater_depth(3),p_bad%signed_exchange_rate(2))
  p_bad%groundwater_depth = [0.0_real64,50.0_real64,100.0_real64]
  p_bad%signed_exchange_rate = [0.0_real64,0.2_real64]
  call evaluate_tabulated_drainage_response(p_bad,view,r,d)
  call require(d%status == DRAIN_TAB_INVALID_PARAMETERS, 'mismatched table lengths rejected')

  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_tabulated_drainage_response(p,bad_view,r,d)
  call require(d%status == DRAIN_TAB_INVALID_HYDRAULIC_VIEW .and. .not. d%evaluated, &
       'nonfinite groundwater level rejected')
  write(*,'(A)') 'FPM08C1_INVALID_DOMAIN_FAIL_CLOSED=PASS'

  view%groundwater_level = -75.0_real64
  call evaluate_tabulated_drainage_response(p,view,a1,da1)
  view_b = process_hydraulic_view_t()
  view_b%groundwater_level = -25.0_real64
  call evaluate_tabulated_drainage_response(p,view_b,b,db)
  call require(.not. same_result_bits(a1,b), 'B differs from A')
  view%groundwater_level = -75.0_real64
  call evaluate_tabulated_drainage_response(p,view,a2,da2)
  call require(same_result_bits(a1,a2), 'A/B/A result identity')
  call require(same_diag_bits(da1,da2), 'A/B/A diagnostics identity')
  call require(.not. da1%persistent_process_state, 'no persistent process state')
  call require(da1%mass_is_authoritative_external_transfer, 'scalar response owns exchange mass')
  write(*,'(A)') 'FPM08C1_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM08C1_STATE_AND_MASS_OWNERSHIP=PASS'

  write(*,'(A)') 'FPM08C1_TABULATED_DRAINAGE_RESPONSE_TEST PASS'

contains

  subroutine configure_base(parameters)
    type(drainage_tabulated_parameters_t), intent(out) :: parameters
    allocate(parameters%groundwater_depth(3),parameters%signed_exchange_rate(3))
    parameters%groundwater_depth = [0.0_real64,50.0_real64,100.0_real64]
    parameters%signed_exchange_rate = [0.0_real64,0.2_real64,0.5_real64]
  end subroutine configure_base

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

  logical function same_result_bits(a,b) result(equal)
    type(drainage_tabulated_result_t), intent(in) :: a,b
    equal = same_bits(a%signed_soil_to_drain_rate,b%signed_soil_to_drain_rate) .and. &
         (a%derivative_defined .eqv. b%derivative_defined) .and. &
         same_bits(a%dq_dgroundwater_level,b%dq_dgroundwater_level)
  end function same_result_bits

  logical function same_diag_bits(a,b) result(equal)
    type(drainage_tabulated_diagnostics_t), intent(in) :: a,b
    equal = a%status == b%status .and. (a%evaluated .eqv. b%evaluated) .and. &
         (a%clamped_lower .eqv. b%clamped_lower) .and. (a%clamped_upper .eqv. b%clamped_upper) .and. &
         (a%at_table_knot .eqv. b%at_table_knot) .and. a%segment_index == b%segment_index .and. &
         same_bits(a%groundwater_level,b%groundwater_level) .and. &
         same_bits(a%groundwater_depth,b%groundwater_depth) .and. &
         (a%mass_is_authoritative_external_transfer .eqv. b%mass_is_authoritative_external_transfer) .and. &
         (a%persistent_process_state .eqv. b%persistent_process_state)
  end function same_diag_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08c1_tabulated_drainage_response
