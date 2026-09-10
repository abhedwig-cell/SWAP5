program test_fpm08c3_empirical_interflow_response
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_empirical_interflow_response
  implicit none

  type(drainage_empirical_interflow_parameters_t) :: p, p2
  type(drainage_empirical_interflow_control_t) :: control
  type(process_hydraulic_view_t) :: view
  type(drainage_empirical_interflow_result_t) :: r, rminus, rplus, a, a2
  type(drainage_empirical_interflow_diagnostics_t) :: d, dm, dp, da, da2
  real(real64), parameter :: tol = 8192.0_real64*epsilon(1.0_real64)
  real(real64) :: h, fd, expected_q, expected_dq

  p%coefficient = 2.0_real64
  p%exponent = 0.5_real64
  control%resolved_drain_head = -100.0_real64

  view = process_hydraulic_view_t()
  view%groundwater_level = -91.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  expected_q = 6.0_real64
  expected_dq = 1.0_real64/3.0_real64
  call require(d%status == INTERFLOW_OK .and. d%evaluated .and. d%active, 'representative active status')
  call require(close(r%signed_soil_to_drain_rate,expected_q), 'representative active flux')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,expected_dq), 'representative active derivative')
  write(*,'(A)') 'FPM08C3_ACTIVE_SOURCE_EQUATION=PASS'

  h = 1.0e-5_real64
  view%groundwater_level = -91.0_real64-h
  call evaluate_drainage_empirical_interflow_response(p,control,view,rminus,dm)
  view%groundwater_level = -91.0_real64+h
  call evaluate_drainage_empirical_interflow_response(p,control,view,rplus,dp)
  fd = (rplus%signed_soil_to_drain_rate-rminus%signed_soil_to_drain_rate)/(2.0_real64*h)
  call require(close_rel(r%dq_dgroundwater_level,fd,2.0e-9_real64), 'representative finite difference tangent')

  p%exponent = 0.1_real64
  view%groundwater_level = -96.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  expected_q = p%coefficient*4.0_real64**p%exponent
  expected_dq = p%coefficient*p%exponent*4.0_real64**(p%exponent-1.0_real64)
  call require(close(r%signed_soil_to_drain_rate,expected_q), 'minimum exponent flux')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,expected_dq), 'minimum exponent derivative')

  h = 1.0e-5_real64
  view%groundwater_level = -96.0_real64-h
  call evaluate_drainage_empirical_interflow_response(p,control,view,rminus,dm)
  view%groundwater_level = -96.0_real64+h
  call evaluate_drainage_empirical_interflow_response(p,control,view,rplus,dp)
  fd = (rplus%signed_soil_to_drain_rate-rminus%signed_soil_to_drain_rate)/(2.0_real64*h)
  call require(close_rel(r%dq_dgroundwater_level,fd,2.0e-8_real64), 'minimum exponent finite difference tangent')
  write(*,'(A)') 'FPM08C3_STABLE_BRANCH_TANGENTS_FD=PASS'

  p%coefficient = INTERFLOW_COEFFICIENT_MIN
  p%exponent = INTERFLOW_EXPONENT_MIN
  view%groundwater_level = -99.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_OK .and. r%derivative_defined, 'lower parameter endpoints admitted')
  p%coefficient = INTERFLOW_COEFFICIENT_MAX
  p%exponent = INTERFLOW_EXPONENT_MAX
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_OK .and. r%derivative_defined, 'upper parameter endpoints admitted')

  p%coefficient = 0.009_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS .and. .not. d%evaluated, 'coefficient below source range rejected')
  p%coefficient = 10.01_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'coefficient above source range rejected')
  p%coefficient = 1.0_real64
  p%exponent = 0.09_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'exponent below source range rejected')
  p%exponent = 1.01_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'exponent above source range rejected')
  write(*,'(A)') 'FPM08C3_LEGACY_PARAMETER_DOMAIN=PASS'

  p%coefficient = 2.0_real64
  p%exponent = 0.5_real64
  view%groundwater_level = -101.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_OK .and. d%evaluated .and. d%inactive_below_activation, 'inactive branch status')
  call require(d%negative_branch_not_evaluated .and. d%drainage_side_only, 'negative branch ownership explicit')
  call require(close(r%signed_soil_to_drain_rate,0.0_real64), 'inactive interflow contribution zero')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), 'inactive derivative zero')
  write(*,'(A)') 'FPM08C3_NEGATIVE_DIFFERENCE_SCOPE_EXPLICIT=PASS'

  view%groundwater_level = -100.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%at_activation .and. d%right_tangent_singular, 'sublinear activation singular')
  call require(.not. r%derivative_defined .and. .not. r%right_tangent_defined_at_activation, &
       'sublinear activation no fabricated tangent')
  call require(close(r%signed_soil_to_drain_rate,0.0_real64), 'sublinear activation flux zero')
  write(*,'(A)') 'FPM08C3_SUBLINEAR_ACTIVATION_SINGULAR_RIGHT_TANGENT=PASS'

  p%exponent = 1.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%at_activation .and. d%finite_right_tangent_but_two_sided_kink, 'linear activation kink')
  call require(.not. r%derivative_defined, 'linear activation full derivative unavailable')
  call require(r%right_tangent_defined_at_activation .and. &
       close(r%right_dq_dgroundwater_level_at_activation,p%coefficient), 'linear activation right tangent')
  write(*,'(A)') 'FPM08C3_LINEAR_ACTIVATION_FINITE_RIGHT_KINK=PASS'

  p%exponent = 0.1_real64
  control%resolved_drain_head = 0.0_real64
  view%groundwater_level = tiny(1.0_real64)
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%active .and. r%signed_soil_to_drain_rate > 0.0_real64, 'tiny positive difference remains active')
  call require(r%derivative_defined .and. ieee_is_finite(r%dq_dgroundwater_level) .and. &
       r%dq_dgroundwater_level > 0.0_real64, 'tiny positive exact tangent representable')
  call require(.not. d%tangent_numerically_unrepresentable, 'tiny positive tangent not hidden')
  write(*,'(A)') 'FPM08C3_NO_ARBITRARY_NEAR_ACTIVATION_CUTOFF=PASS'

  p%coefficient = 1.5_real64
  p%exponent = 0.6_real64
  control%resolved_drain_head = -40.0_real64
  view%groundwater_level = -30.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,a,da)
  p2%coefficient = 4.0_real64
  p2%exponent = 1.0_real64
  control%resolved_drain_head = 2.0_real64
  view%groundwater_level = 8.0_real64
  call evaluate_drainage_empirical_interflow_response(p2,control,view,r,d)
  control%resolved_drain_head = -40.0_real64
  view%groundwater_level = -30.0_real64
  call evaluate_drainage_empirical_interflow_response(p,control,view,a2,da2)
  call require(close(a%signed_soil_to_drain_rate,a2%signed_soil_to_drain_rate) .and. &
       close(a%dq_dgroundwater_level,a2%dq_dgroundwater_level) .and. &
       a%derivative_defined .eqv. a2%derivative_defined, 'A/B/A response identity')
  call require(da%persistent_process_state .eqv. da2%persistent_process_state, 'A/B/A state metadata identity')
  write(*,'(A)') 'FPM08C3_STATELESS_A_B_A_IDENTITY=PASS'

  control%resolved_drain_head = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_CONTROL .and. .not. d%evaluated, 'nonfinite control rejected')
  control%resolved_drain_head = 0.0_real64
  view%groundwater_level = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_drainage_empirical_interflow_response(p,control,view,r,d)
  call require(d%status == INTERFLOW_INVALID_HYDRAULIC_VIEW .and. .not. d%evaluated, 'nonfinite hydraulic view rejected')
  write(*,'(A)') 'FPM08C3_NONFINITE_INPUTS_FAIL_CLOSED=PASS'

  call require(.not. d%persistent_process_state, 'persistent process state false')
  call require(d%mass_is_authoritative_external_transfer, 'mass ownership metadata')
  write(*,'(A)') 'FPM08C3_STATE_AND_MASS_OWNERSHIP=PASS'
  write(*,'(A)') 'FPM08C3_EMPIRICAL_INTERFLOW_RESPONSE_TEST PASS'

contains

  logical function close(a,b) result(ok)
    real(real64), intent(in) :: a,b
    ok = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function close_rel(a,b,rtol) result(ok)
    real(real64), intent(in) :: a,b,rtol
    ok = abs(a-b) <= rtol*max(1.0_real64,abs(a),abs(b))
  end function close_rel

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm08c3_empirical_interflow_response
