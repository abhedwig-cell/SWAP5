program test_fpe_timearch11_controller_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_b1_10_timestep_decision_service, only: b1_10_timestep_decision_t, b1_10_legacy_accepted_step_decision
  use mod_timestep_controller_contract
  implicit none

  type(legacy_compat_timestep_controller_t) :: legacy
  type(auto_reference_null_controller_t) :: null_auto
  type(timestep_accepted_context_t) :: context
  type(timestep_controller_limits_t) :: limits
  type(timestep_proposal_t) :: proposal, limited
  type(b1_10_timestep_decision_t) :: reference
  real(real64), parameter :: dtmin=1.0e-6_real64, dtmax=0.04_real64
  real(real64), parameter :: inc=2.0_real64, dec=0.5_real64
  real(real64), dimension(7) :: dts
  integer, dimension(8) :: its
  integer :: i,j

  dts=[1.0e-6_real64,1.0e-5_real64,1.0e-4_real64,1.0e-3_real64,5.0e-3_real64,2.0e-2_real64,4.0e-2_real64]
  its=[0,1,4,5,7,8,15,30]

  legacy%dtmin=dtmin
  legacy%dtmax=dtmax
  legacy%numbit_crit=4
  legacy%maxit=30
  legacy%fact_increase=inc
  legacy%fact_decrease=dec

  do i=1,size(dts)
    do j=1,size(its)
      context=timestep_accepted_context_t()
      context%accepted_time=1.0_real64
      context%previous_accepted_dt=dts(i)
      context%executed_dt=dts(i)
      context%nonlinear_iterations=its(j)
      call legacy%propose(context,proposal)
      reference=b1_10_legacy_accepted_step_decision(dts(i),dtmin,dtmax,its(j),4,30,inc,dec)
      call require(proposal%available,'legacy proposal unavailable')
      call require(proposal%preferred_dt==reference%preferred_dt,'legacy preferred mismatch')
    end do
  end do

  context=timestep_accepted_context_t()
  context%accepted_time=1.0_real64
  context%previous_accepted_dt=0.02_real64
  context%previous_preferred_dt=0.04_real64
  context%preferred_available=.true.
  context%executed_dt=0.005_real64
  context%event_clipped=.true.
  context%nonlinear_iterations=3
  call legacy%propose(context,proposal)
  call require(proposal%preferred_dt==0.01_real64,'event-clipped execution leaked preferred memory')
  call require(context%previous_preferred_dt==0.04_real64,'controller mutated context')

  limits=timestep_controller_limits_t()
  limits%retry_floor=1.0e-4_real64
  limits%expert_ceiling_present=.true.
  limits%expert_ceiling=0.03_real64

  proposal=timestep_proposal_t(.true.,0.08_real64,TS_CTRL_REASON_LEGACY_COMPAT)
  call apply_timestep_safety_limits(proposal,limits,limited)
  call require(limited%available,'ceiling made unavailable')
  call require(limited%preferred_dt==0.03_real64,'ceiling not applied')
  call require(limited%reason==TS_CTRL_REASON_SAFETY_CEILING,'ceiling reason wrong')

  proposal=timestep_proposal_t(.true.,1.0e-6_real64,TS_CTRL_REASON_LEGACY_COMPAT)
  call apply_timestep_safety_limits(proposal,limits,limited)
  call require(limited%preferred_dt==1.0e-4_real64,'floor not applied')
  call require(limited%reason==TS_CTRL_REASON_SAFETY_FLOOR,'floor reason wrong')

  context=timestep_accepted_context_t()
  context%accepted_time=1.0_real64
  context%previous_accepted_dt=0.01_real64
  context%executed_dt=0.01_real64
  context%nonlinear_iterations=3
  call null_auto%propose(context,proposal)
  call require(.not.proposal%available,'null auto unexpectedly available')
  call require(proposal%reason==TS_CTRL_REASON_UNAVAILABLE,'null auto reason wrong')

  print '(A)', 'F_PE_TIMEARCH11_CONTROLLER_CONTRACT=PASS'

contains
  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_TIMEARCH11_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine require
end program test_fpe_timearch11_controller_contract
