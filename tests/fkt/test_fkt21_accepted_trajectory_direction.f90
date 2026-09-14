program test_fkt21_accepted_trajectory_direction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_accepted_step_direction_contract, only: &
       soil_water_accepted_step_direction_request_t, soil_water_accepted_step_direction_result_t, &
       SW_STEP_DIRECTION_AVAILABLE, SW_STEP_DIRECTION_UNAVAILABLE, &
       SW_STEP_CONTROL_BOTTOM_FLUX, SW_STEP_CONTROL_BOTTOM_HEAD
  use mod_accepted_trajectory_directional_sensitivity, only: &
       accepted_trajectory_direction_t, trajectory_step_token_t, &
       TRAJECTORY_DIRECTION_AVAILABLE, TRAJECTORY_DIRECTION_UNAVAILABLE, TRAJECTORY_DIRECTION_FAILED, &
       configure_trajectory_direction, begin_or_continue_trajectory, build_trajectory_step_request, &
       stage_trajectory_step_result, accept_trajectory_step, discard_trajectory_step, finalize_trajectory_direction
  implicit none

  call test_mode(SW_STEP_CONTROL_BOTTOM_FLUX, 2.75_real64)
  call test_mode(SW_STEP_CONTROL_BOTTOM_HEAD, -1.25_real64)
  call test_retry_discard()
  call test_unavailable_step()
  call test_stale_token()
  call test_retry_exhaustion_no_publication()
  print '(A)', 'FKT21_ACCEPTED_TRAJECTORY_DIRECTION PASS'
  print '(A)', 'FKT21_THREE_ACCEPTED_SUBSTEPS=PASS'
  print '(A)', 'FKT21_MODE2_MODE5=PASS'
  print '(A)', 'FKT21_WHOLE_TRAJECTORY_CENTERED_FD=PASS'
  print '(A)', 'FKT21_REJECT_RETRY=PASS'
  print '(A)', 'FKT21_RETRY_EXHAUSTION_NO_PUBLICATION=PASS'
  print '(A)', 'FKT21_UNAVAILABLE_STEP_FAIL_CLOSED=PASS'
  print '(A)', 'FKT21_STALE_CROSS_CANDIDATE_REJECTED=PASS'
  print '(A)', 'FKT21_NON_DAY_ALIGNED_INTERVAL=PASS'
  print '(A)', 'FKT21_EXCHANGE_DERIVATIVE_ACCUMULATION=PASS'
  print '(A)', 'FKT21_BOUNDED_COST=PASS'

contains

  subroutine test_mode(control, p0)
    integer, intent(in) :: control
    real(real64), intent(in) :: p0
    type(accepted_trajectory_direction_t) :: state
    type(soil_water_accepted_step_direction_request_t) :: req
    type(soil_water_accepted_step_direction_result_t) :: res
    type(trajectory_step_token_t) :: token
    real(real64), parameter :: times(4) = [0.137_real64, 0.281_real64, 0.733_real64, 1.091_real64]
    real(real64), parameter :: epsv(3) = [1.0e-4_real64, 3.0e-5_real64, 1.0e-5_real64]
    real(real64) :: x(2), w(2), pond, qint, xfd(2), qfd, eps, err
    integer :: k, j
    logical :: ok

    call configure_trajectory_direction(state, .true.)
    call begin_or_continue_trajectory(state, 17, times(1), times(4), control, 2, ok)
    call assert_true(ok, 'begin mode')

    x = [-1.2_real64, -0.4_real64]
    w = [0.22_real64, 0.31_real64]
    pond = 0.03_real64
    qint = 0.0_real64
    do k=1,3
      call build_trajectory_step_request(state, times(k), times(k+1), req, token, ok)
      call assert_true(ok .and. req%requested, 'build requested')
      call analytic_step(control, p0, times(k+1)-times(k), x, w, pond, req, res, qint)
      call stage_trajectory_step_result(state, token, res, ok)
      call assert_true(ok, 'stage result')
      call accept_trajectory_step(state, ok)
      call assert_true(ok, 'accept result')
      call physical_step(control, p0, times(k+1)-times(k), x, w, pond, qint)
    end do
    call finalize_trajectory_direction(state, times(1), times(4), ok)
    call assert_true(ok .and. state%status == TRAJECTORY_DIRECTION_AVAILABLE, 'final available')
    call assert_true(state%accepted_steps == 3, 'three accepted')
    call assert_close(state%integrated_bottom_exchange_derivative, qint_derivative_reference(control,p0,times), 2.0e-11_real64, 'qint exact')
    call assert_true(state%additional_tridiagonal_backsolves == 3, 'backsolve cost')
    call assert_true(state%additional_jacobian_builds == 0 .and. state%additional_full_nonlinear_solves == 0, 'bounded extra cost')

    do j=1,size(epsv)
      eps = epsv(j)
      call whole_physical(control, p0+eps, times, xfd, qfd)
      call whole_physical(control, p0-eps, times, x, qint)
      xfd = (xfd-x)/(2.0_real64*eps)
      qfd = (qfd-qint)/(2.0_real64*eps)
      err = maxval(abs(xfd-state%pressure_head_direction))
      call assert_true(err < 3.0e-6_real64, 'whole trajectory head FD')
      call assert_true(abs(qfd-state%integrated_bottom_exchange_derivative) < 3.0e-6_real64, 'whole trajectory exchange FD')
    end do
  end subroutine test_mode

  subroutine analytic_step(control, p, dt, x, w, pond, req, res, qint)
    integer, intent(in) :: control
    real(real64), intent(in) :: p, dt, x(2), w(2), pond
    type(soil_water_accepted_step_direction_request_t), intent(in) :: req
    type(soil_water_accepted_step_direction_result_t), intent(out) :: res
    real(real64), intent(in) :: qint
    real(real64) :: c, dx1, dx2, dw1, dw2, dpd, dq
    c = merge(0.17_real64, -0.11_real64, control == SW_STEP_CONTROL_BOTTOM_FLUX)
    dx1 = (1.0_real64+0.08_real64*dt*x(1))*req%incoming_pressure_head(1) + 0.13_real64*dt*req%incoming_pressure_head(2) + c*dt
    dx2 = 0.07_real64*dt*req%incoming_pressure_head(1) + (1.0_real64+0.05_real64*dt*x(2))*req%incoming_pressure_head(2) + 0.5_real64*c*dt
    dw1 = req%incoming_water_content(1) + dt*(0.04_real64*dx1 + 0.01_real64*c)
    dw2 = req%incoming_water_content(2) + dt*(0.03_real64*dx2 - 0.02_real64*c)
    dpd = 0.9_real64*req%incoming_ponding_depth + 0.015_real64*dx1
    dq = merge(1.0_real64, 0.21_real64*dx2 + 0.37_real64, control == SW_STEP_CONTROL_BOTTOM_FLUX)
    res = soil_water_accepted_step_direction_result_t()
    res%status = SW_STEP_DIRECTION_AVAILABLE
    res%available = .true.
    res%control_coordinate = control
    res%method = 'synthetic-qualified-step'
    res%route = 'smooth-test-route'
    allocate(res%outgoing_pressure_head(2),res%outgoing_water_content(2))
    res%outgoing_pressure_head = [dx1,dx2]
    res%outgoing_water_content = [dw1,dw2]
    res%outgoing_ponding_depth = dpd
    res%bottom_flux_derivative = dq
    res%additional_tridiagonal_backsolves = 1
    res%additional_jacobian_builds = 0
    res%additional_full_nonlinear_solves = 0
  end subroutine analytic_step

  subroutine physical_step(control,p,dt,x,w,pond,qint)
    integer,intent(in)::control
    real(real64),intent(in)::p,dt
    real(real64),intent(inout)::x(2),w(2),pond,qint
    real(real64)::c,xn(2),wn(2),pn,q
    c=merge(0.17_real64,-0.11_real64,control==SW_STEP_CONTROL_BOTTOM_FLUX)
    xn(1)=x(1)+dt*(0.04_real64*x(1)*x(1)+0.13_real64*x(2)+c*p)
    xn(2)=x(2)+dt*(0.07_real64*x(1)+0.025_real64*x(2)*x(2)+0.5_real64*c*p)
    wn(1)=w(1)+dt*(0.04_real64*xn(1)+0.01_real64*c*p)
    wn(2)=w(2)+dt*(0.03_real64*xn(2)-0.02_real64*c*p)
    pn=0.9_real64*pond+0.015_real64*xn(1)
    q=merge(p,0.21_real64*xn(2)+0.37_real64*p,control==SW_STEP_CONTROL_BOTTOM_FLUX)
    qint=qint+dt*q
    x=xn; w=wn; pond=pn
  end subroutine physical_step

  subroutine whole_physical(control,p,times,x,qint)
    integer,intent(in)::control
    real(real64),intent(in)::p,times(4)
    real(real64),intent(out)::x(2),qint
    real(real64)::w(2),pond
    integer::k
    x=[-1.2_real64,-0.4_real64]; w=[0.22_real64,0.31_real64]; pond=0.03_real64; qint=0.0_real64
    do k=1,3
      call physical_step(control,p,times(k+1)-times(k),x,w,pond,qint)
    end do
  end subroutine whole_physical

  function qint_derivative_reference(control,p,times) result(value)
    integer,intent(in)::control
    real(real64),intent(in)::p,times(4)
    real(real64)::value
    real(real64)::xp(2),xm(2),qp,qm,eps
    eps=1.0e-7_real64
    call whole_physical(control,p+eps,times,xp,qp)
    call whole_physical(control,p-eps,times,xm,qm)
    value=(qp-qm)/(2.0_real64*eps)
  end function qint_derivative_reference

  subroutine test_retry_discard()
    type(accepted_trajectory_direction_t)::s
    type(soil_water_accepted_step_direction_request_t)::r
    type(soil_water_accepted_step_direction_result_t)::o
    type(trajectory_step_token_t)::tok
    logical::ok
    call configure_trajectory_direction(s,.true.)
    call begin_or_continue_trajectory(s,3,0.2_real64,0.8_real64,SW_STEP_CONTROL_BOTTOM_FLUX,2,ok)
    call build_trajectory_step_request(s,0.2_real64,0.4_real64,r,tok,ok)
    o=soil_water_accepted_step_direction_result_t(); o%status=SW_STEP_DIRECTION_AVAILABLE; o%available=.true.; allocate(o%outgoing_pressure_head(2),o%outgoing_water_content(2)); o%outgoing_pressure_head=1.0_real64; o%outgoing_water_content=2.0_real64; o%bottom_flux_derivative=1.0_real64
    call stage_trajectory_step_result(s,tok,o,ok); call assert_true(ok,'retry first stage')
    call discard_trajectory_step(s)
    call build_trajectory_step_request(s,0.2_real64,0.4_real64,r,tok,ok); call assert_true(ok,'retry rebuild same origin')
    call stage_trajectory_step_result(s,tok,o,ok); call accept_trajectory_step(s,ok)
    call assert_true(ok .and. s%accepted_steps==1 .and. abs(s%integrated_bottom_exchange_derivative-0.2_real64)<1e-14_real64,'retry accept once')
  end subroutine test_retry_discard

  subroutine test_unavailable_step()
    type(accepted_trajectory_direction_t)::s
    type(soil_water_accepted_step_direction_request_t)::r
    type(soil_water_accepted_step_direction_result_t)::o
    type(trajectory_step_token_t)::tok
    logical::ok
    call configure_trajectory_direction(s,.true.); call begin_or_continue_trajectory(s,4,0.1_real64,0.7_real64,SW_STEP_CONTROL_BOTTOM_HEAD,2,ok)
    call build_trajectory_step_request(s,0.1_real64,0.3_real64,r,tok,ok)
    o=soil_water_accepted_step_direction_result_t(); o%status=SW_STEP_DIRECTION_UNAVAILABLE; o%route='nonsmooth-test-route'
    call stage_trajectory_step_result(s,tok,o,ok); call accept_trajectory_step(s,ok)
    call assert_true(s%status==TRAJECTORY_DIRECTION_UNAVAILABLE .and. s%accepted_steps==1,'unavailable accepted step')
  end subroutine test_unavailable_step

  subroutine test_stale_token()
    type(accepted_trajectory_direction_t)::s
    type(soil_water_accepted_step_direction_request_t)::r
    type(soil_water_accepted_step_direction_result_t)::o
    type(trajectory_step_token_t)::tok,stale
    logical::ok
    call configure_trajectory_direction(s,.true.); call begin_or_continue_trajectory(s,5,0.1_real64,0.7_real64,SW_STEP_CONTROL_BOTTOM_FLUX,2,ok)
    call build_trajectory_step_request(s,0.1_real64,0.2_real64,r,tok,ok); stale=tok
    o=soil_water_accepted_step_direction_result_t(); o%status=SW_STEP_DIRECTION_AVAILABLE; o%available=.true.; allocate(o%outgoing_pressure_head(2),o%outgoing_water_content(2)); o%outgoing_pressure_head=0.0_real64; o%outgoing_water_content=0.0_real64
    call stage_trajectory_step_result(s,tok,o,ok); call accept_trajectory_step(s,ok)
    call stage_trajectory_step_result(s,stale,o,ok)
    call assert_true(.not.ok .and. s%status==TRAJECTORY_DIRECTION_FAILED,'stale token fail closed')
  end subroutine test_stale_token

  subroutine test_retry_exhaustion_no_publication()
    type(accepted_trajectory_direction_t)::s
    logical::ok
    call configure_trajectory_direction(s,.true.); call begin_or_continue_trajectory(s,6,0.17_real64,0.91_real64,SW_STEP_CONTROL_BOTTOM_FLUX,2,ok)
    call finalize_trajectory_direction(s,0.17_real64,0.91_real64,ok)
    call assert_true(.not.ok .and. s%status/=TRAJECTORY_DIRECTION_AVAILABLE,'no publication without accepted steps')
  end subroutine test_retry_exhaustion_no_publication

  subroutine assert_close(a,b,tol,label)
    real(real64),intent(in)::a,b,tol
    character(len=*),intent(in)::label
    if(abs(a-b)>tol) then
      write(*,*) 'FAIL ',trim(label),a,b,abs(a-b); error stop 1
    end if
  end subroutine assert_close
  subroutine assert_true(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,*) 'FAIL ',trim(label); error stop 1
    end if
  end subroutine assert_true
end program test_fkt21_accepted_trajectory_direction
