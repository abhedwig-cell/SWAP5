program test_tabhyd_ksatexm_lower_layer
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK, F_TAB02_STATE_UNSUPPORTED_HENPR
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, bind_b110_generated_mvg_provider, &
       F_TAB02_PROVIDER_OK
  implicit none

  integer, parameter :: NS=2401
  real(real64), parameter :: STEP=4.0e-2_real64
  real(real64) :: cof(24,1), bad(24,1)
  real(real64) :: h(1), ta(1),ka(1),ca(1),da(1), tt(1),kt(1),ct(1),dt(1)
  real(real64) :: tt2(1),kt2(1),ct2(1),dt2(1)
  real(real64) :: frac, exponent, theta_err, cap_err, logk_err
  real(real64) :: logk_here, logk_head, logk_analytic, logk_table
  type(b110_default_mvg_parameters_t), target :: p_ext, p_default, p_bad
  type(b110_default_mvg_provider_t) :: analytic_ext, analytic_default
  type(b110_generated_mvg_table_state_t), target :: state, state2, state_default, bad_state
  type(b110_generated_mvg_provider_t) :: table, table2, table_default
  integer :: j, status

  cof=0.0_real64
  ! Exact Hupsel lower-layer B1.11 authority from F-SI39.
  cof(1,1)=0.02_real64
  cof(2,1)=0.3870640000000001_real64
  cof(3,1)=22.76176_real64
  cof(4,1)=0.016083_real64
  cof(5,1)=2.4396619999999993_real64
  cof(6,1)=1.524418_real64
  cof(7,1)=0.3440119442305195_real64
  cof(8,1)=0.016083_real64
  cof(9,1)=0.0_real64
  cof(10,1)=227.61759999999998_real64
  cof(11,1)=0.9981816467911503_real64
  cof(12,1)=15.814441314772257_real64

  call initialize_b110_default_mvg_parameters(p_ext,cof,enable_ksatexm_extension=.true.)
  call initialize_b110_default_mvg_parameters(p_default,cof)

  call initialize_b110_generated_mvg_table_state(state,p_ext,status)
  call require(status==F_TAB02_STATE_OK,'extended state init')
  call initialize_b110_generated_mvg_table_state(state2,p_ext,status)
  call require(status==F_TAB02_STATE_OK,'extended duplicate state init')
  call initialize_b110_generated_mvg_table_state(state_default,p_default,status)
  call require(status==F_TAB02_STATE_OK,'default state init')
  call require(state%matches(p_ext),'extended state identity')
  call require(.not.state%matches(p_default),'extension flag identity separation')
  call require(state_default%matches(p_default),'default state identity')

  call bind_b110_default_mvg_provider(analytic_ext,p_ext,STEP)
  call bind_b110_default_mvg_provider(analytic_default,p_default,STEP)
  call bind_b110_generated_mvg_provider(table,state,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK,'extended provider bind')
  call bind_b110_generated_mvg_provider(table2,state2,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK,'duplicate provider bind')
  call bind_b110_generated_mvg_provider(table_default,state_default,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK,'default provider bind')

  theta_err=0.0_real64
  cap_err=0.0_real64
  logk_err=0.0_real64
  logk_head=0.0_real64
  logk_analytic=0.0_real64
  logk_table=0.0_real64
  do j=1,NS
    frac=real(j-1,real64)/real(NS-1,real64)
    exponent=7.0_real64-15.0_real64*frac
    h=-10.0_real64**exponent
    call analytic_ext%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dt)
    call table2%evaluate(h,tt2,kt2,ct2,dt2)
    call require(tt(1)==tt2(1).and.kt(1)==kt2(1).and.ct(1)==ct2(1),'deterministic duplicate evaluation')
    theta_err=max(theta_err,abs(tt(1)-ta(1)))
    cap_err=max(cap_err,abs(ct(1)-ca(1)))
    logk_here=abs(log10(kt(1))-log10(ka(1)))
    if (logk_here > logk_err) then
      logk_err=logk_here
      logk_head=h(1)
      logk_analytic=ka(1)
      logk_table=kt(1)
    end if
    call require(dt(1)==0.0_real64,'K0 derivative slot')
  end do

  ! Exact admitted F-SI39 probes.
  h=1.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  call require(abs(ka(1)-227.61759999999998_real64)<2.0e-12_real64,'analytic saturated KSATEXM')
  call require(abs(kt(1)-ka(1))<2.0e-12_real64,'generated saturated KSATEXM')

  h=-1.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  call require(abs(ka(1)-153.81975964948478_real64)<2.0e-11_real64,'analytic near saturated oracle')
  call require(abs(log10(kt(1))-log10(ka(1)))<=5.0e-4_real64,'generated near saturated oracle')

  h=-5.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call analytic_default%evaluate(h,tt,kt,ct,dt)
  call require(ka(1)==kt(1),'extension exact noop below threshold')

  h=1.0_real64
  call analytic_default%evaluate(h,ta,ka,ca,da)
  call table_default%evaluate(h,tt,kt,ct,dt)
  call require(abs(ka(1)-22.76176_real64)<2.0e-12_real64,'default saturated authority')
  call require(abs(kt(1)-ka(1))<2.0e-12_real64,'default generated unchanged')

  bad=cof
  bad(9,1)=-10.0_real64
  call initialize_b110_default_mvg_parameters(p_bad,bad,enable_ksatexm_extension=.true.)
  call initialize_b110_generated_mvg_table_state(bad_state,p_bad,status)
  call require(status==F_TAB02_STATE_UNSUPPORTED_HENPR,'H_ENPR remains fail closed')

  write(*,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_THETA_MAX_ABS=',theta_err
  write(*,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_CAPACITY_MAX_ABS=',cap_err
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_THETA_MAX_ABS=',theta_err
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_CAPACITY_MAX_ABS=',cap_err
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_LOG10K_MAX_ABS=',logk_err
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_LOG10K_MAX_HEAD_CM=',logk_head
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_LOG10K_MAX_ANALYTIC_K=',logk_analytic
  write(error_unit,'(a,es24.16)') 'TABHYD_KSATEXM_LOWER_LOG10K_MAX_TABLE_K=',logk_table
  flush(error_unit)
  call require(theta_err<=1.0e-4_real64,'theta preregistered limit')
  call require(cap_err<=1.0e-4_real64,'capacity preregistered limit')
  call require(logk_err<=5.0e-4_real64,'conductivity preregistered limit')
  write(*,'(a)') 'TABHYD_KSATEXM_LOWER_DETERMINISTIC=PASS'
  write(*,'(a)') 'TABHYD_KSATEXM_LOWER_DEFAULT_PRESERVATION=PASS'
  write(*,'(a)') 'TABHYD_KSATEXM_LOWER_HENPR_FAIL_CLOSED=PASS'
  write(*,'(a)') 'TABHYD-KSATEXM PHASE-A LOWER-LAYER GATE PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'TABHYD_KSATEXM_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_tabhyd_ksatexm_lower_layer
