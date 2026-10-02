program test_low03a_cauchy_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_legacy_cauchy_bottom_boundary_provider
  implicit none
  type(fmr_cauchy3_control_t) :: control
  type(fmr_cauchy3_proposal_t) :: proposal
  real(real64), parameter :: T0=5100.1875_real64
  real(real64) :: q4, sample, nan
  integer :: status
  nan=ieee_value(0.0_real64,ieee_quiet_nan)
  call control%initialize_table(T0,1000.0_real64, &
       [1000.0_real64,1000.5_real64,1001.0_real64],[-100.0_real64,-75.0_real64,-25.0_real64], &
       10.0_real64,.true.,status,[1000.0_real64,1001.0_real64],[0.0_real64,0.02_real64])
  call require(status==FMR_CAUCHY3_OK .and. control%ready(),'valid independent DATE3/DATE4 control')
  call control%resolve_proposal(T0,T0+0.5_real64,proposal,status)
  call require(status==FMR_CAUCHY3_OK .and. proposal%available,'table proposal')
  call require(same_bits(proposal%aquifer_total_head_cm,-75.0_real64),'DATE3 endpoint knot')
  call require(same_bits(proposal%legacy_head_sample_t1900,1000.5_real64),'DATE3 proposal endpoint time')
  call require(proposal%covers(T0,T0+0.125_real64),'short retry covered by original proposal')
  call control%resolve_q4(T0,T0+0.125_real64,q4,sample,status)
  call require(status==FMR_CAUCHY3_OK,'retry Q4')
  call require(abs(q4-0.0025_real64)<1.0e-15_real64,'Q4 resampled at shortened trial endpoint')
  call require(same_bits(sample,1000.125_real64),'DATE4 actual trial endpoint')
  call control%resolve_q4(T0,T0+0.5_real64,q4,sample,status)
  call require(abs(q4-0.01_real64)<1.0e-15_real64,'Q4 original endpoint differs from shortened retry')
  print '(a)', 'LOW03A_PROVIDER_PROPOSAL_VS_TRIAL_TIMING=PASS'
  call control%initialize_table(T0,1000.0_real64,[1000.25_real64,1000.75_real64],[-90.0_real64,-50.0_real64], &
       10.0_real64,.true.,status)
  call require(status==FMR_CAUCHY3_OK,'endpoint extension control')
  call control%resolve_proposal(T0,T0+0.125_real64,proposal,status)
  call require(same_bits(proposal%aquifer_total_head_cm,-90.0_real64),'DATE3 lower endpoint extension')
  call control%resolve_proposal(T0,T0+1.0_real64,proposal,status)
  call require(same_bits(proposal%aquifer_total_head_cm,-50.0_real64),'DATE3 upper endpoint extension')
  call control%initialize_sine(T0,1000.0_real64,[999.0_real64,1364.0_real64,1729.0_real64], &
       -300.0_real64,50.0_real64,30.0_real64,365.0_real64,10.0_real64,.true.,status)
  call require(status==FMR_CAUCHY3_OK,'valid sine control')
  call control%resolve_proposal(T0,T0+0.5_real64,proposal,status)
  call require(status==FMR_CAUCHY3_OK .and. same_bits(proposal%legacy_head_sample_t1900,1000.0_real64), &
       'sine samples proposal start calendar coordinate')
  call require(same_bits(proposal%sine_phase_day,1.0_real64),'sine calendar-year phase')
  call require(abs(proposal%aquifer_total_head_cm - &
       (-300.0_real64+50.0_real64*cos((8.0_real64*atan(1.0_real64)/365.0_real64)*(1.0_real64-30.0_real64)))) &
       <1.0e-13_real64,'sine law')
  print '(a)', 'LOW03A_PROVIDER_AFGEN_AND_SINE=PASS'
  call control%initialize_sine(T0,1000.0_real64,[999.0_real64,1364.0_real64], &
       -300.0_real64,50.0_real64,30.0_real64,0.0_real64,10.0_real64,.true.,status)
  call require(status/=FMR_CAUCHY3_OK .and. .not. control%ready(),'AQPER0 fail closed')
  call control%initialize_table(T0,1000.0_real64,[1000.0_real64],[-75.0_real64],0.0_real64,.false.,status)
  call require(status/=FMR_CAUCHY3_OK,'zero R without half-cell fail closed')
  call control%initialize_table(T0,1000.0_real64,[1000.0_real64,1000.0_real64],[-75.0_real64,-75.0_real64], &
       10.0_real64,.true.,status)
  call require(status/=FMR_CAUCHY3_OK,'duplicate DATE3 fail closed')
  call control%initialize_table(T0,1000.0_real64,[1000.0_real64],[1001.0_real64],10.0_real64,.true.,status)
  call require(status/=FMR_CAUCHY3_OK,'Haq bound fail closed')
  call control%initialize_table(T0,1000.0_real64,[1000.0_real64],[-75.0_real64],10.0_real64,.true.,status, &
       [1000.0_real64],[101.0_real64])
  call require(status/=FMR_CAUCHY3_OK,'Q4 bound fail closed')
  call control%initialize_table(T0,1000.0_real64,[1000.0_real64],[nan],10.0_real64,.true.,status)
  call require(status/=FMR_CAUCHY3_OK,'nonfinite head fail closed')
  print '(a)', 'LOW03A_PROVIDER_FAIL_CLOSED_DOMAIN=PASS'
  print '(a)', 'LOW03A_PROVIDER_GATE=PASS'
contains
  logical function same_bits(a,b) result(same)
    real(real64), intent(in) :: a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function
  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'LOW03A_PROVIDER_FAIL',trim(message)
      error stop 1
    end if
  end subroutine
end program test_low03a_cauchy_provider
