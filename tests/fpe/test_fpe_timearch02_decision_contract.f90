program test_fpe_timearch02_decision_contract
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none

  integer, parameter :: LIMIT_NONE=0, LIMIT_PROCESS=1, LIMIT_EVENT=2
  type :: timestep_policy_t
    real(real64) :: numerical_min=0.001_real64
    real(real64) :: numerical_max=0.020_real64
    real(real64) :: increase=2.0_real64
    real(real64) :: decrease=0.5_real64
    real(real64) :: failure_divisor=2.0_real64
    integer :: numbit_crit=4
    integer :: maxit=8
  end type

  type :: timestep_decision_t
    real(real64) :: proposal_dt=0.0_real64
    real(real64) :: process_limited_dt=0.0_real64
    real(real64) :: executable_dt=0.0_real64
    integer :: limiting_reason=LIMIT_NONE
  end type

  type(timestep_policy_t) :: p
  real(real64), parameter :: dts(4)=[0.001_real64,sqrt(0.001_real64*0.020_real64),0.010_real64,0.020_real64]
  integer, parameter :: its(4)=[1,4,5,8]
  real(real64), parameter :: caps(5)=[huge(1.0_real64),0.050_real64,0.012_real64,0.006_real64,0.0005_real64]
  integer :: i,j,k,l,ncase
  real(real64) :: expected, event_cap, process_cap, retry_expected, retry_actual
  type(timestep_decision_t) :: d
  logical :: ok

  ncase=0
  do i=1,size(dts)
    do j=1,size(its)
      do k=1,size(caps)
        do l=1,size(caps)
          process_cap=caps(k)
          event_cap=caps(l)
          d=decide_after_accept(p,dts(i),its(j),process_cap,event_cap)
          expected=legacy_after_accept(p,dts(i),its(j))
          expected=min(expected,process_cap)
          expected=min(expected,event_cap)
          call require(close(d%executable_dt,expected),'accepted matrix mismatch')
          call require(close(d%proposal_dt,legacy_after_accept(p,dts(i),its(j))),'proposal mismatch')
          call require(close(p%numerical_max,0.020_real64),'numerical max mutated')
          call require(close(p%numerical_min,0.001_real64),'numerical min mutated')
          if(d%executable_dt<d%proposal_dt-1e-14_real64)then
            call require(d%limiting_reason/=LIMIT_NONE,'missing limiting reason')
          end if
          ncase=ncase+1
        end do
      end do
    end do
  end do

  do i=1,size(dts)
    retry_actual=decide_retry(p,dts(i))
    if(dts(i)>p%failure_divisor*p%numerical_min)then
      retry_expected=dts(i)/p%failure_divisor
    else
      retry_expected=p%numerical_min
    end if
    call require(close(retry_actual,retry_expected),'retry mismatch')
    call require(close(p%numerical_max,0.020_real64),'retry mutated max')
    call require(close(p%numerical_min,0.001_real64),'retry mutated min')
  end do

  d=decide_day_start(p,0.001_real64,.true.,huge(1.0_real64),huge(1.0_real64))
  call require(close(d%proposal_dt,sqrt(p%numerical_min*p%numerical_max)),'legacy day-start floor mismatch')

  d=decide_day_start(p,0.001_real64,.false.,huge(1.0_real64),huge(1.0_real64))
  call require(close(d%proposal_dt,0.001_real64),'modern day-start must not enlarge dt')

  d=decide_after_accept(p,0.010_real64,1,0.006_real64,0.004_real64)
  call require(close(d%proposal_dt,0.020_real64),'proposal provenance lost')
  call require(close(d%process_limited_dt,0.006_real64),'process cap wrong')
  call require(close(d%executable_dt,0.004_real64),'event cap wrong')
  call require(d%limiting_reason==LIMIT_EVENT,'event reason wrong')

  d=decide_after_accept(p,0.010_real64,1,0.004_real64,0.006_real64)
  call require(close(d%proposal_dt,0.020_real64),'proposal provenance lost 2')
  call require(close(d%process_limited_dt,0.004_real64),'process cap wrong 2')
  call require(close(d%executable_dt,0.004_real64),'executable wrong 2')
  call require(d%limiting_reason==LIMIT_PROCESS,'process reason wrong')

  ok=.true.
  write(*,'(*(g0))') 'F_PE_TIMEARCH02_MATRIX_CASES=',ncase
  write(*,'(A)') 'F_PE_TIMEARCH02=PASS'

contains

  pure function decide_after_accept(policy,accepted_dt,numbit,process_cap,event_cap) result(d)
    type(timestep_policy_t),intent(in)::policy
    real(real64),intent(in)::accepted_dt,process_cap,event_cap
    integer,intent(in)::numbit
    type(timestep_decision_t)::d
    real(real64)::x

    x=accepted_dt
    if(numbit<=policy%numbit_crit)x=min(x*policy%increase,policy%numerical_max)
    if(numbit>=policy%maxit)x=max(x*policy%decrease,policy%numerical_min)
    d%proposal_dt=x

    d%process_limited_dt=min(d%proposal_dt,process_cap)
    d%executable_dt=min(d%process_limited_dt,event_cap)
    d%limiting_reason=LIMIT_NONE
    if(d%process_limited_dt<d%proposal_dt-1e-14_real64)d%limiting_reason=LIMIT_PROCESS
    if(d%executable_dt<d%process_limited_dt-1e-14_real64)d%limiting_reason=LIMIT_EVENT
  end function

  pure function decide_day_start(policy,current_dt,legacy_floor,process_cap,event_cap) result(d)
    type(timestep_policy_t),intent(in)::policy
    real(real64),intent(in)::current_dt,process_cap,event_cap
    logical,intent(in)::legacy_floor
    type(timestep_decision_t)::d
    real(real64)::x

    x=current_dt
    if(legacy_floor)x=max(x,sqrt(policy%numerical_min*policy%numerical_max))
    d%proposal_dt=x
    d%process_limited_dt=min(x,process_cap)
    d%executable_dt=min(d%process_limited_dt,event_cap)
    d%limiting_reason=LIMIT_NONE
    if(d%process_limited_dt<d%proposal_dt-1e-14_real64)d%limiting_reason=LIMIT_PROCESS
    if(d%executable_dt<d%process_limited_dt-1e-14_real64)d%limiting_reason=LIMIT_EVENT
  end function

  pure real(real64) function decide_retry(policy,failed_dt) result(retry_dt)
    type(timestep_policy_t),intent(in)::policy
    real(real64),intent(in)::failed_dt
    if(failed_dt>policy%failure_divisor*policy%numerical_min)then
      retry_dt=failed_dt/policy%failure_divisor
    else
      retry_dt=policy%numerical_min
    end if
  end function

  pure real(real64) function legacy_after_accept(policy,accepted_dt,numbit) result(next_dt)
    type(timestep_policy_t),intent(in)::policy
    real(real64),intent(in)::accepted_dt
    integer,intent(in)::numbit
    next_dt=accepted_dt
    if(numbit<=policy%numbit_crit)next_dt=min(next_dt*policy%increase,policy%numerical_max)
    if(numbit>=policy%maxit)next_dt=max(next_dt*policy%decrease,policy%numerical_min)
  end function

  pure logical function close(a,b) result(ok)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    ok=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_TIMEARCH02_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_timearch02_decision_contract
