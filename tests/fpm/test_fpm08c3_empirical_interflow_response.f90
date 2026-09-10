program test_fpm08c3_empirical_interflow_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_empirical_interflow_response, only: empirical_interflow_parameters_t, &
       empirical_interflow_control_t, empirical_interflow_response_t, empirical_interflow_diagnostics_t, &
       evaluate_empirical_interflow_response, INTERFLOW_OK, INTERFLOW_INVALID_PARAMETERS, &
       INTERFLOW_INVALID_CONTROL, INTERFLOW_INVALID_HYDRAULIC_VIEW, INTERFLOW_NUMERICAL_DOMAIN
  implicit none

  type(empirical_interflow_parameters_t) :: p, p_bad
  type(empirical_interflow_control_t) :: control, bad_control
  type(process_hydraulic_view_t) :: view, bad_view
  type(empirical_interflow_response_t) :: r, rp, rm, a1, a2, b
  type(empirical_interflow_diagnostics_t) :: d, dp, dm, da1, da2, db
  real(real64), parameter :: tol = 8192.0_real64 * epsilon(1.0_real64)
  real(real64), parameter :: fd_tol = 1.0e-10_real64
  real(real64), parameter :: delta = 1.0e-5_real64
  real(real64) :: analytic, fd, expected

  p%coefficient = 0.5_real64
  p%exponent = 0.5_real64
  control%drain_head = -100.0_real64
  view = process_hydraulic_view_t()
  view%groundwater_level = -96.0_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(d%status == INTERFLOW_OK .and. d%evaluated .and. d%active, 'active status')
  call require(close(r%signed_soil_to_drain_rate, 1.0_real64), 'active flux')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level, 0.125_real64), 'active tangent')
  call require(close(d%activation_difference, 4.0_real64), 'activation difference')
  write(*,'(A)') 'FPM08C3_ACTIVE_LEGACY_POWER_RESPONSE=PASS'

  analytic = r%dq_dgroundwater_level
  view%groundwater_level = -96.0_real64 + delta
  call evaluate_empirical_interflow_response(p, control, view, rp, dp)
  view%groundwater_level = -96.0_real64 - delta
  call evaluate_empirical_interflow_response(p, control, view, rm, dm)
  fd = (rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*delta)
  call require(dp%active .and. dm%active, 'fd probes remain active')
  call require(abs(fd-analytic) <= fd_tol*max(1.0_real64,abs(analytic)), 'analytic tangent finite difference')
  write(*,'(A)') 'FPM08C3_ANALYTIC_TANGENT_FINITE_DIFFERENCE=PASS'

  view%groundwater_level = -101.0_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(d%status == INTERFLOW_OK .and. d%evaluated .and. d%inactive_below_activation, 'inactive status')
  call require(close(r%signed_soil_to_drain_rate,0.0_real64), 'inactive contribution zero')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), 'inactive tangent zero')
  call require(d%negative_side_exchange_out_of_scope, 'negative-side scope explicit')
  write(*,'(A)') 'FPM08C3_NEGATIVE_SIDE_INTERFLOW_CONTRIBUTION_INACTIVE=PASS'

  view%groundwater_level = -100.0_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(d%status == INTERFLOW_OK .and. d%evaluated .and. d%at_activation, 'activation status')
  call require(close(r%signed_soil_to_drain_rate,0.0_real64) .and. .not. r%derivative_defined, 'activation response')
  call require(d%singular_activation_tangent .and. .not. d%drainage_side_activation_tangent_defined, 'sublinear singularity')
  write(*,'(A)') 'FPM08C3_SUBLINEAR_ACTIVATION_SINGULAR_TANGENT=PASS'

  p%coefficient = 3.0_real64
  p%exponent = 1.0_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(d%at_activation .and. .not. d%singular_activation_tangent, 'linear activation')
  call require(.not. r%derivative_defined .and. d%drainage_side_activation_tangent_defined, 'one-sided only')
  call require(close(d%drainage_side_activation_tangent,3.0_real64), 'one-sided tangent')
  write(*,'(A)') 'FPM08C3_LINEAR_ACTIVATION_ONE_SIDED_TANGENT_DIAGNOSTIC=PASS'

  view%groundwater_level = -98.0_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(close(r%signed_soil_to_drain_rate,6.0_real64), 'linear active flux')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,3.0_real64), 'linear active tangent')
  write(*,'(A)') 'FPM08C3_EXPONENT_ONE_ACTIVE_BRANCH=PASS'

  p%coefficient = 0.01_real64
  p%exponent = 0.1_real64
  control%drain_head = 0.0_real64
  view%groundwater_level = 1.0e-100_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  expected = p%coefficient*p%exponent*view%groundwater_level**(p%exponent-1.0_real64)
  call require(d%active .and. r%derivative_defined .and. close(r%dq_dgroundwater_level,expected), 'tiny positive exact tangent')
  call require(.not. d%process_side_tangent_regularization, 'no tangent regularization')
  write(*,'(A)') 'FPM08C3_NO_PROCESS_SIDE_NEAR_ACTIVATION_CAP=PASS'

  p%coefficient = 10.0_real64
  p%exponent = 0.1_real64
  view%groundwater_level = 1.0e6_real64
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  expected = 10.0_real64*(1.0e6_real64**0.1_real64)
  call require(d%active .and. close(r%signed_soil_to_drain_rate,expected), 'parameter bound flux')
  write(*,'(A)') 'FPM08C3_PARAMETER_BOUND_RESPONSE=PASS'

  p_bad = p; p_bad%coefficient = 0.009_real64
  call evaluate_empirical_interflow_response(p_bad, control, view, r, d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS .and. .not. d%evaluated, 'coefficient lower')
  p_bad = p; p_bad%coefficient = 10.001_real64
  call evaluate_empirical_interflow_response(p_bad, control, view, r, d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'coefficient upper')
  p_bad = p; p_bad%exponent = 0.099_real64
  call evaluate_empirical_interflow_response(p_bad, control, view, r, d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'exponent lower')
  p_bad = p; p_bad%exponent = 1.001_real64
  call evaluate_empirical_interflow_response(p_bad, control, view, r, d)
  call require(d%status == INTERFLOW_INVALID_PARAMETERS, 'exponent upper')

  bad_control%drain_head = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_empirical_interflow_response(p, bad_control, view, r, d)
  call require(d%status == INTERFLOW_INVALID_CONTROL .and. .not. d%evaluated, 'nonfinite control')
  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_empirical_interflow_response(p, control, bad_view, r, d)
  call require(d%status == INTERFLOW_INVALID_HYDRAULIC_VIEW .and. .not. d%evaluated, 'nonfinite view')
  view%groundwater_level = huge(1.0_real64)
  control%drain_head = -huge(1.0_real64)
  call evaluate_empirical_interflow_response(p, control, view, r, d)
  call require(d%status == INTERFLOW_NUMERICAL_DOMAIN .and. .not. d%evaluated, 'difference overflow')
  write(*,'(A)') 'FPM08C3_INVALID_AND_NUMERICAL_DOMAIN_FAIL_CLOSED=PASS'

  p%coefficient = 0.7_real64
  p%exponent = 0.6_real64
  control%drain_head = -20.0_real64
  view%groundwater_level = -10.0_real64
  call evaluate_empirical_interflow_response(p, control, view, a1, da1)
  view%groundwater_level = -30.0_real64
  call evaluate_empirical_interflow_response(p, control, view, b, db)
  call require(.not. same_result_bits(a1,b), 'A differs B')
  view%groundwater_level = -10.0_real64
  call evaluate_empirical_interflow_response(p, control, view, a2, da2)
  call require(same_result_bits(a1,a2) .and. same_diag_bits(da1,da2), 'A/B/A identity')
  call require(.not. da1%persistent_process_state, 'no state')
  call require(da1%mass_is_authoritative_external_transfer_contribution .and. da1%contribution_is_interflow_only, 'mass/scope')
  write(*,'(A)') 'FPM08C3_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM08C3_STATE_MASS_AND_SCOPE_OWNERSHIP=PASS'
  write(*,'(A)') 'FPM08C3_EMPIRICAL_INTERFLOW_RESPONSE_TEST PASS'

contains

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  logical function same_result_bits(a,b) result(equal)
    type(empirical_interflow_response_t), intent(in) :: a,b
    equal = same_bits(a%signed_soil_to_drain_rate,b%signed_soil_to_drain_rate) .and. &
         (a%derivative_defined .eqv. b%derivative_defined) .and. same_bits(a%dq_dgroundwater_level,b%dq_dgroundwater_level)
  end function same_result_bits

  logical function same_diag_bits(a,b) result(equal)
    type(empirical_interflow_diagnostics_t), intent(in) :: a,b
    equal = a%status==b%status .and. (a%evaluated .eqv. b%evaluated) .and. (a%active .eqv. b%active) .and. &
         (a%inactive_below_activation .eqv. b%inactive_below_activation) .and. (a%at_activation .eqv. b%at_activation) .and. &
         (a%singular_activation_tangent .eqv. b%singular_activation_tangent) .and. &
         (a%drainage_side_activation_tangent_defined .eqv. b%drainage_side_activation_tangent_defined) .and. &
         same_bits(a%drainage_side_activation_tangent,b%drainage_side_activation_tangent) .and. &
         same_bits(a%groundwater_level,b%groundwater_level) .and. same_bits(a%drain_head,b%drain_head) .and. &
         same_bits(a%activation_difference,b%activation_difference) .and. &
         (a%contribution_is_interflow_only .eqv. b%contribution_is_interflow_only) .and. &
         (a%negative_side_exchange_out_of_scope .eqv. b%negative_side_exchange_out_of_scope) .and. &
         (a%mass_is_authoritative_external_transfer_contribution .eqv. b%mass_is_authoritative_external_transfer_contribution) .and. &
         (a%persistent_process_state .eqv. b%persistent_process_state) .and. &
         (a%process_side_tangent_regularization .eqv. b%process_side_tangent_regularization)
  end function same_diag_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08c3_empirical_interflow_response
