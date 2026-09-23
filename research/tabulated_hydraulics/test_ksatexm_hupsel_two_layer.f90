program test_tabhyd_ksatexm_hupsel_two_layer
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, bind_b110_generated_mvg_provider, &
       F_TAB02_PROVIDER_OK
  implicit none

  integer, parameter :: NLAY=2, NS=2401
  real(real64), parameter :: STEP=4.0e-2_real64
  real(real64), parameter :: HTHR=-2.0_real64
  real(real64) :: cof(42,NLAY)
  real(real64) :: h(NLAY), ta(NLAY),ka(NLAY),ca(NLAY),da(NLAY)
  real(real64) :: tt(NLAY),kt(NLAY),ct(NLAY),dt(NLAY)
  real(real64) :: theta_err(NLAY), cap_err(NLAY), logk_err(NLAY)
  real(real64) :: frac, exponent, e, relthr, kth, term, m
  integer :: j, i, status
  type(b110_default_mvg_parameters_t), target :: p_ext, p_default
  type(b110_default_mvg_provider_t) :: analytic_ext, analytic_default
  type(b110_generated_mvg_table_state_t), target :: state
  type(b110_generated_mvg_provider_t) :: table

  cof=0.0_real64

  ! Exact Hupsel top layer from F-TAB02-F / M1-C3.
  cof(1,1)=0.02_real64
  cof(2,1)=0.433878_real64
  cof(3,1)=83.24164_real64
  cof(4,1)=0.021645_real64
  cof(5,1)=7.202077_real64
  cof(6,1)=1.34877_real64
  cof(7,1)=1.0_real64-1.0_real64/cof(6,1)
  cof(8,1)=cof(4,1)
  cof(9,1)=0.0_real64
  cof(10,1)=832.4163_real64
  cof(11,1)=0.9962891879895563_real64
  cof(12,1)=36.025513440889625_real64

  ! Exact Hupsel lower layer / admitted F-SI39 oracle.
  cof(1,2)=0.02_real64
  cof(2,2)=0.3870640000000001_real64
  cof(3,2)=22.76176_real64
  cof(4,2)=0.016083_real64
  cof(5,2)=2.4396619999999993_real64
  cof(6,2)=1.524418_real64
  cof(7,2)=0.3440119442305195_real64
  cof(8,2)=cof(4,2)
  cof(9,2)=0.0_real64
  cof(10,2)=227.61759999999998_real64
  cof(11,2)=0.9981816467911503_real64
  cof(12,2)=15.814441314772257_real64

  ! Reproduce the historical ReadSWAP hthr=-2 derivation for both layers.
  do i=1,NLAY
    m=cof(7,i)
    relthr=(1.0_real64+abs(HTHR*cof(4,i))**cof(6,i))**(-m)
    term=(1.0_real64-relthr**(1.0_real64/m))**m
    kth=cof(3,i)*(relthr**cof(5,i))*(1.0_real64-term)**2
    call require(abs(relthr-cof(11,i))<2.0e-15_real64,'ReadSWAP relsat threshold authority')
    call require(abs(kth-cof(12,i))<2.0e-12_real64,'ReadSWAP K threshold authority')
  end do

  call initialize_b110_default_mvg_parameters(p_ext,cof,enable_ksatexm_extension=.true.)
  call initialize_b110_default_mvg_parameters(p_default,cof)
  call initialize_b110_generated_mvg_table_state(state,p_ext,status)
  call require(status==F_TAB02_STATE_OK,'two-layer state init')
  call bind_b110_default_mvg_provider(analytic_ext,p_ext,STEP)
  call bind_b110_default_mvg_provider(analytic_default,p_default,STEP)
  call bind_b110_generated_mvg_provider(table,state,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK,'two-layer provider bind')

  theta_err=0.0_real64
  cap_err=0.0_real64
  logk_err=0.0_real64

  do j=1,NS
    frac=real(j-1,real64)/real(NS-1,real64)
    exponent=7.0_real64-15.0_real64*frac
    h=-10.0_real64**exponent
    call analytic_ext%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dt)
    do i=1,NLAY
      theta_err(i)=max(theta_err(i),abs(tt(i)-ta(i)))
      cap_err(i)=max(cap_err(i),abs(ct(i)-ca(i)))
      e=abs(log10(kt(i))-log10(ka(i)))
      logk_err(i)=max(logk_err(i),e)
      call require(dt(i)==0.0_real64,'K0 derivative slot')
    end do
  end do

  h=1.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call table%evaluate(h,tt,kt,ct,dt)
  call require(abs(kt(1)-832.4163_real64)<2.0e-11_real64,'top saturated KSATEXM')
  call require(abs(kt(2)-227.61759999999998_real64)<2.0e-11_real64,'lower saturated KSATEXM')
  call require(maxval(abs(kt-ka))<2.0e-11_real64,'two-layer saturated oracle')

  h=-5.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call analytic_default%evaluate(h,tt,kt,ct,dt)
  call require(all(ka==kt),'two-layer extension exact noop below threshold')

  do i=1,NLAY
    write(*,'(a,i0,a,es24.16)') 'TABHYD_KSATEXM_LAYER=',i,' THETA_MAX_ABS=',theta_err(i)
    write(*,'(a,i0,a,es24.16)') 'TABHYD_KSATEXM_LAYER=',i,' CAPACITY_MAX_ABS=',cap_err(i)
    write(*,'(a,i0,a,es24.16)') 'TABHYD_KSATEXM_LAYER=',i,' LOG10K_MAX_ABS=',logk_err(i)
    call require(theta_err(i)<=1.0e-4_real64,'two-layer theta limit')
    call require(cap_err(i)<=1.0e-4_real64,'two-layer capacity limit')
    call require(logk_err(i)<=5.0e-4_real64,'two-layer conductivity limit')
  end do

  write(*,'(a)') 'TABHYD_KSATEXM_READSWAP_THRESHOLD_RECONSTRUCTION=PASS'
  write(*,'(a)') 'TABHYD-KSATEXM CANDIDATE-C TWO-LAYER GATE PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'TABHYD_KSATEXM_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_tabhyd_ksatexm_hupsel_two_layer
