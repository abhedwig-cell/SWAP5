program test_fpm08c1r_tabulated_drainage_remediation
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_tabulated_response, only: drainage_tabulated_parameters_t, drainage_tabulated_result_t, &
       drainage_tabulated_diagnostics_t, evaluate_tabulated_drainage_response, DRAIN_TAB_OK, &
       DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE
  implicit none

  type(drainage_tabulated_parameters_t) :: p_zero, p_positive, p_two
  type(process_hydraulic_view_t) :: view
  type(drainage_tabulated_result_t) :: r
  type(drainage_tabulated_diagnostics_t) :: d
  real(real64), parameter :: tol = 4096.0_real64*epsilon(1.0_real64)
  real(real64), dimension(4) :: probes
  integer :: i

  allocate(p_zero%groundwater_depth(1),p_zero%signed_exchange_rate(1))
  p_zero%groundwater_depth = [0.0_real64]
  p_zero%signed_exchange_rate = [2.75_real64]
  probes = [0.0_real64,1.0_real64,-1.0_real64,100.0_real64]
  do i=1,size(probes)
    view = process_hydraulic_view_t()
    view%groundwater_level = probes(i)
    call evaluate_tabulated_drainage_response(p_zero,view,r,d)
    call require(d%status == DRAIN_TAB_UNSUPPORTED_LEGACY_DEGENERATE, 'zero-depth singleton status')
    call require(.not. d%evaluated, 'zero-depth singleton not evaluated')
    call require(close(r%signed_soil_to_drain_rate,0.0_real64), 'zero-depth singleton default exchange')
    call require(.not. r%derivative_defined, 'zero-depth singleton derivative unavailable')
    call require(close(d%groundwater_level,probes(i)), 'zero-depth singleton diagnostic gwl')
    call require(close(d%groundwater_depth,abs(probes(i))), 'zero-depth singleton diagnostic depth')
  end do
  write(*,'(A)') 'FPM08C1R_ZERO_DEPTH_SINGLETON_FAIL_CLOSED=PASS'

  allocate(p_positive%groundwater_depth(1),p_positive%signed_exchange_rate(1))
  p_positive%groundwater_depth = [40.0_real64]
  p_positive%signed_exchange_rate = [0.17_real64]
  probes = [0.0_real64,40.0_real64,-999.0_real64,1200.0_real64]
  do i=1,size(probes)
    view%groundwater_level = probes(i)
    call evaluate_tabulated_drainage_response(p_positive,view,r,d)
    call require(d%status == DRAIN_TAB_OK .and. d%evaluated, 'positive singleton valid')
    call require(close(r%signed_soil_to_drain_rate,0.17_real64), 'positive singleton constant')
    call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), &
         'positive singleton zero derivative')
    call require(d%clamped_lower .and. d%clamped_upper, 'positive singleton clamp metadata')
  end do
  write(*,'(A)') 'FPM08C1R_POSITIVE_DEPTH_SINGLETON_CONSTANT=PASS'

  allocate(p_two%groundwater_depth(2),p_two%signed_exchange_rate(2))
  p_two%groundwater_depth = [0.0_real64,10.0_real64]
  p_two%signed_exchange_rate = [1.0_real64,3.0_real64]

  view%groundwater_level = -5.0_real64
  call evaluate_tabulated_drainage_response(p_two,view,r,d)
  call require(d%status == DRAIN_TAB_OK .and. d%evaluated, 'two-point negative active')
  call require(close(r%signed_soil_to_drain_rate,2.0_real64), 'two-point negative interpolation')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,-0.2_real64), &
       'two-point negative derivative')

  view%groundwater_level = 5.0_real64
  call evaluate_tabulated_drainage_response(p_two,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,2.0_real64), 'two-point positive interpolation')
  call require(r%derivative_defined .and. close(r%dq_dgroundwater_level,0.2_real64), &
       'two-point positive derivative')

  view%groundwater_level = 0.0_real64
  call evaluate_tabulated_drainage_response(p_two,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,1.0_real64), 'two-point zero knot')
  call require(d%at_table_knot .and. .not. r%derivative_defined, 'two-point zero knot derivative held')

  view%groundwater_level = 100.0_real64
  call evaluate_tabulated_drainage_response(p_two,view,r,d)
  call require(close(r%signed_soil_to_drain_rate,3.0_real64), 'two-point upper clamp')
  call require(d%clamped_upper .and. r%derivative_defined .and. close(r%dq_dgroundwater_level,0.0_real64), &
       'two-point upper clamp derivative')
  write(*,'(A)') 'FPM08C1R_MULTI_POINT_ZERO_START_UNCHANGED=PASS'

  call require(.not. d%persistent_process_state, 'no persistent process state')
  call require(d%mass_is_authoritative_external_transfer, 'authoritative signed transfer unchanged')
  write(*,'(A)') 'FPM08C1R_STATE_AND_MASS_BOUNDARY_UNCHANGED=PASS'
  write(*,'(A)') 'FPM08C1R_TABULATED_DRAINAGE_REMEDIATION_TEST PASS'

contains

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C1R_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08c1r_tabulated_drainage_remediation
