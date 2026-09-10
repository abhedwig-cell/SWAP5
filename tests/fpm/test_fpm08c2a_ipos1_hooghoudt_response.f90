program test_fpm08c2a_ipos1_hooghoudt_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_hooghoudt_ipos1_response, only: drainage_hooghoudt_ipos1_parameters_t, &
       drainage_hooghoudt_ipos1_result_t, drainage_hooghoudt_ipos1_diagnostics_t, &
       evaluate_drainage_hooghoudt_ipos1_response, DRAIN_IPOS1_OK, DRAIN_IPOS1_INVALID_PARAMETERS, &
       DRAIN_IPOS1_INVALID_HYDRAULIC_VIEW, DRAIN_IPOS1_B110_DIFFL_CUTOFF
  implicit none

  type(drainage_hooghoudt_ipos1_parameters_t) :: p, p_bad, p_cut
  type(process_hydraulic_view_t) :: view, view_plus, view_minus, view_b, bad_view
  type(drainage_hooghoudt_ipos1_result_t) :: r, r_plus, r_minus, a1, a2, b
  type(drainage_hooghoudt_ipos1_diagnostics_t) :: d, d_plus, d_minus, da1, da2, db
  real(real64), parameter :: tol = 8192.0_real64 * epsilon(1.0_real64)
  real(real64), parameter :: fd_step = 1.0e-4_real64
  real(real64) :: expected, numeric_derivative

  call configure_base(p)
  view = process_hydraulic_view_t()
  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p, view, r, d)
  expected = legacy_ipos1_reference(p, view%groundwater_level)
  call require(d%status == DRAIN_IPOS1_OK .and. d%evaluated .and. d%active, 'active branch status')
  call require(close(r%signed_soil_to_drain_rate, expected), 'active flux matches source equation')
  call require(r%signed_soil_to_drain_rate > 0.0_real64, 'active flux sign')
  call require(r%derivative_defined .and. r%dq_dgroundwater_level > 0.0_real64, 'active derivative')
  write(*,'(A)') 'FPM08C2A_ACTIVE_SOURCE_EQUATION=PASS'

  view_plus = process_hydraulic_view_t()
  view_minus = process_hydraulic_view_t()
  view_plus%groundwater_level = view%groundwater_level + fd_step
  view_minus%groundwater_level = view%groundwater_level - fd_step
  call evaluate_drainage_hooghoudt_ipos1_response(p, view_plus, r_plus, d_plus)
  call evaluate_drainage_hooghoudt_ipos1_response(p, view_minus, r_minus, d_minus)
  call require(d_plus%active .and. d_minus%active, 'finite difference stays active')
  numeric_derivative = (r_plus%signed_soil_to_drain_rate-r_minus%signed_soil_to_drain_rate) / &
       (2.0_real64*fd_step)
  call require(abs(numeric_derivative-r%dq_dgroundwater_level) <= 2.0e-10_real64, &
       'analytic tangent finite difference')
  write(*,'(A)') 'FPM08C2A_ANALYTIC_TANGENT_FINITE_DIFFERENCE=PASS'

  view%groundwater_level = p%drain_bottom_level
  call evaluate_drainage_hooghoudt_ipos1_response(p, view, r, d)
  call require(d%status == DRAIN_IPOS1_OK .and. d%inactive_below_compatibility_cutoff, &
       'inactive cutoff branch')
  call require(close(r%signed_soil_to_drain_rate, 0.0_real64), 'inactive zero flux')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level, 0.0_real64), &
       'inactive zero derivative')
  write(*,'(A)') 'FPM08C2A_INACTIVE_COMPATIBILITY_BRANCH=PASS'

  p_cut = drainage_hooghoudt_ipos1_parameters_t()
  p_cut%drain_spacing = 1000.0_real64
  p_cut%shape_factor = 1.0_real64
  p_cut%drain_bottom_level = 0.0_real64
  p_cut%horizontal_conductivity_top = 10.0_real64
  p_cut%entry_resistance = 5.0_real64
  view%groundwater_level = DRAIN_IPOS1_B110_DIFFL_CUTOFF
  call evaluate_drainage_hooghoudt_ipos1_response(p_cut, view, r, d)
  call require(d%active .and. d%at_exact_compatibility_cutoff, 'exact cutoff active by legacy less-than rule')
  call require(r%signed_soil_to_drain_rate > 0.0_real64, 'exact cutoff nonzero flux')
  call require(.not. r%derivative_defined, 'exact cutoff derivative unavailable')
  write(*,'(A)') 'FPM08C2A_EXACT_CUTOFF_FLUX_PARITY_TANGENT_HELD=PASS'

  view%groundwater_level = 0.5_real64 * DRAIN_IPOS1_B110_DIFFL_CUTOFF
  call evaluate_drainage_hooghoudt_ipos1_response(p_cut, view, r, d)
  call require(d%inactive_below_compatibility_cutoff .and. close(r%signed_soil_to_drain_rate, 0.0_real64), &
       'below cutoff inactive')
  view%groundwater_level = 2.0_real64 * DRAIN_IPOS1_B110_DIFFL_CUTOFF
  call evaluate_drainage_hooghoudt_ipos1_response(p_cut, view, r, d)
  call require(d%active .and. .not. d%at_exact_compatibility_cutoff .and. r%derivative_defined, &
       'above cutoff active')
  write(*,'(A)') 'FPM08C2A_CUTOFF_SIDEDNESS_EXPLICIT=PASS'

  p_bad = p
  p_bad%horizontal_conductivity_top = 0.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p_bad, view, r, d)
  call require(d%status == DRAIN_IPOS1_INVALID_PARAMETERS .and. .not. d%evaluated, 'zero conductivity rejected')
  p_bad = p
  p_bad%shape_factor = 0.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p_bad, view, r, d)
  call require(d%status == DRAIN_IPOS1_INVALID_PARAMETERS, 'zero shape rejected')
  p_bad = p
  p_bad%drain_spacing = 0.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p_bad, view, r, d)
  call require(d%status == DRAIN_IPOS1_INVALID_PARAMETERS, 'zero spacing rejected')
  p_bad = p
  p_bad%entry_resistance = -1.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p_bad, view, r, d)
  call require(d%status == DRAIN_IPOS1_INVALID_PARAMETERS, 'negative entry resistance rejected')
  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = ieee_value(0.0_real64, ieee_quiet_nan)
  call evaluate_drainage_hooghoudt_ipos1_response(p, bad_view, r, d)
  call require(d%status == DRAIN_IPOS1_INVALID_HYDRAULIC_VIEW .and. .not. d%evaluated, 'nonfinite gwl rejected')
  write(*,'(A)') 'FPM08C2A_NORMALIZED_DOMAIN_FAIL_CLOSED=PASS'

  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p, view, a1, da1)
  view_b = process_hydraulic_view_t()
  view_b%groundwater_level = -75.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p, view_b, b, db)
  call require(.not. same_result_bits(a1,b), 'B differs from A')
  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos1_response(p, view, a2, da2)
  call require(same_result_bits(a1,a2), 'A/B/A result identity')
  call require(same_diag_bits(da1,da2), 'A/B/A diagnostic identity')
  call require(.not. da1%persistent_process_state, 'no persistent state')
  call require(da1%mass_is_authoritative_external_transfer, 'authoritative transfer output')
  write(*,'(A)') 'FPM08C2A_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM08C2A_STATE_AND_MASS_OWNERSHIP=PASS'

  write(*,'(A)') 'FPM08C2A_IPOS1_HOOGHOUDT_RESPONSE_TEST PASS'

contains

  subroutine configure_base(parameters)
    type(drainage_hooghoudt_ipos1_parameters_t), intent(out) :: parameters
    parameters%drain_spacing = 1000.0_real64
    parameters%shape_factor = 0.8_real64
    parameters%drain_bottom_level = -100.0_real64
    parameters%horizontal_conductivity_top = 10.0_real64
    parameters%entry_resistance = 5.0_real64
  end subroutine configure_base

  real(real64) function legacy_ipos1_reference(parameters, groundwater_level) result(q)
    type(drainage_hooghoudt_ipos1_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: groundwater_level
    real(real64) :: difference, resistance
    difference = (groundwater_level-parameters%drain_bottom_level)/parameters%shape_factor
    if (difference < DRAIN_IPOS1_B110_DIFFL_CUTOFF) then
      q = 0.0_real64
      return
    end if
    resistance = parameters%drain_spacing**2 / &
         (4.0_real64*parameters%horizontal_conductivity_top*abs(difference)) + parameters%entry_resistance
    q = difference/resistance
  end function legacy_ipos1_reference

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
    type(drainage_hooghoudt_ipos1_result_t), intent(in) :: a,b
    equal = same_bits(a%signed_soil_to_drain_rate,b%signed_soil_to_drain_rate) .and. &
         (a%derivative_defined .eqv. b%derivative_defined) .and. &
         same_bits(a%dq_dgroundwater_level,b%dq_dgroundwater_level)
  end function same_result_bits

  logical function same_diag_bits(a,b) result(equal)
    type(drainage_hooghoudt_ipos1_diagnostics_t), intent(in) :: a,b
    equal = a%status==b%status .and. (a%evaluated .eqv. b%evaluated) .and. &
         (a%inactive_below_compatibility_cutoff .eqv. b%inactive_below_compatibility_cutoff) .and. &
         (a%active .eqv. b%active) .and. &
         (a%at_exact_compatibility_cutoff .eqv. b%at_exact_compatibility_cutoff) .and. &
         same_bits(a%groundwater_level,b%groundwater_level) .and. same_bits(a%difference,b%difference) .and. &
         same_bits(a%horizontal_resistance,b%horizontal_resistance) .and. &
         same_bits(a%total_resistance,b%total_resistance) .and. &
         (a%mass_is_authoritative_external_transfer .eqv. b%mass_is_authoritative_external_transfer) .and. &
         (a%persistent_process_state .eqv. b%persistent_process_state)
  end function same_diag_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C2A_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08c2a_ipos1_hooghoudt_response
