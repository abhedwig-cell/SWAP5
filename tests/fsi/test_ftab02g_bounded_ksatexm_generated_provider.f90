program test_ftab02g_bounded_ksatexm_generated_provider
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK, F_TAB02_STATE_UNSUPPORTED_KSATEXM
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  implicit none

  integer, parameter :: N=2, NSAMPLE=1801
  real(real64), parameter :: STEP=4.0e-2_real64
  real(real64) :: cof(42,N), bad(42,N), h(N)
  real(real64) :: ta(N),ka(N),ca(N),da(N), tb(N),kb(N),cb(N),db(N)
  real(real64) :: tt(N),kt(N),ct(N),dt(N)
  real(real64) :: frac, exponent, theta_err, c_err, logk_err, krel_err
  real(real64) :: hp, hm, scale
  integer :: i,j,status
  type(b110_default_mvg_parameters_t), target :: p_ext,p_base,p_bad
  type(b110_default_mvg_provider_t) :: analytic_ext,analytic_base
  type(b110_generated_mvg_table_state_t), target :: state,bad_state
  type(b110_generated_mvg_provider_t) :: generated

  cof=0.0_real64
  call set_hupsel_upper(1)
  call set_hupsel_lower(2)

  call initialize_b110_default_mvg_parameters(p_ext,cof,enable_ksatexm_extension=.true.)
  call initialize_b110_default_mvg_parameters(p_base,cof,enable_ksatexm_extension=.false.)
  call bind_b110_default_mvg_provider(analytic_ext,p_ext,STEP)
  call bind_b110_default_mvg_provider(analytic_base,p_base,STEP)

  call initialize_b110_generated_mvg_table_state(state,p_ext,status)
  call require(status==F_TAB02_STATE_OK,'bounded Hupsel KSATEXM generated-state init')
  call require(state%ready(),'bounded Hupsel KSATEXM generated-state ready')
  call bind_b110_generated_mvg_provider(generated,state,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK .and. generated%ready(),'bounded Hupsel generated provider bind')

  theta_err=0.0_real64
  c_err=0.0_real64
  logk_err=0.0_real64
  krel_err=0.0_real64
  do j=1,NSAMPLE
    frac=real(j-1,real64)/real(NSAMPLE-1,real64)
    exponent=7.0_real64-15.0_real64*frac
    h=-10.0_real64**exponent
    call analytic_ext%evaluate(h,ta,ka,ca,da)
    call generated%evaluate(h,tt,kt,ct,dt)
    theta_err=max(theta_err,maxval(abs(tt-ta)))
    c_err=max(c_err,maxval(abs(ct-ca)))
    do i=1,N
      logk_err=max(logk_err,abs(log10(max(kt(i),1.0e-300_real64))-log10(max(ka(i),1.0e-300_real64))))
      krel_err=max(krel_err,abs(kt(i)-ka(i))/max(abs(ka(i)),1.0e-12_real64))
    end do
    call require(all(dt==0.0_real64),'K0 derivative slot')
  end do

  ! Exercise the exact floating neighborhood that distinguishes strict
  ! F-SI39 source-state ownership from a tolerance-based branch switch.
  hm=-2.0_real64
  do j=1,160
    hp=hm
    do i=1,j
      hp=nearest(hp,1.0_real64)
    end do
    h=hp
    call analytic_ext%evaluate(h,ta,ka,ca,da)
    call analytic_base%evaluate(h,tb,kb,cb,db)
    call generated%evaluate(h,tt,kt,ct,dt)
    do i=1,N
      scale=max(abs(ka(i)),1.0e-12_real64)
      krel_err=max(krel_err,abs(kt(i)-ka(i))/scale)
    end do
  end do

  call require(theta_err<=1.0e-4_real64,'theta gate')
  call require(c_err<=1.0e-4_real64,'capacity gate')
  call require(logk_err<=5.0e-4_real64,'log10K gate')
  call require(krel_err<=1.0e-4_real64,'KSATEXM relative K gate')

  h=0.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call generated%evaluate(h,tt,kt,ct,dt)
  call require(all(kt==ka),'saturated KSATEXM identity')

  h=-5.0_real64
  call analytic_ext%evaluate(h,ta,ka,ca,da)
  call analytic_base%evaluate(h,tb,kb,cb,db)
  call require(all(ka==kb),'analytical below-threshold no-op')
  call generated%evaluate(h,tt,kt,ct,dt)
  call require(maxval(abs(kt-ka))<=1.0e-3_real64,'generated below-threshold fidelity')

  bad=cof
  bad(4,1)=bad(4,1)*(1.0_real64+1.0e-8_real64)
  call initialize_b110_default_mvg_parameters(p_bad,bad,enable_ksatexm_extension=.true.)
  call initialize_b110_generated_mvg_table_state(bad_state,p_bad,status)
  call require(status==F_TAB02_STATE_UNSUPPORTED_KSATEXM,'neighboring KSATEXM profile fails closed')

  write(*,'(a,es24.16)') 'F_TAB02_G_THETA_MAX_ABS=',theta_err
  write(*,'(a,es24.16)') 'F_TAB02_G_CAPACITY_MAX_ABS=',c_err
  write(*,'(a,es24.16)') 'F_TAB02_G_LOG10K_MAX_ABS=',logk_err
  write(*,'(a,es24.16)') 'F_TAB02_G_K_MAX_REL=',krel_err
  write(*,'(a)') 'F_TAB02_G_SATURATED_KSATEXM=PASS'
  write(*,'(a)') 'F_TAB02_G_FLOATING_THRESHOLD_NEIGHBORHOOD=PASS'
  write(*,'(a)') 'F_TAB02_G_NEIGHBOR_PROFILE_FAIL_CLOSED=PASS'
  write(*,'(a)') 'F-TAB02-G BOUNDED F-SI39 GENERATED PROVIDER GATE PASS'

contains

  subroutine set_hupsel_upper(node)
    integer,intent(in)::node
    cof(1,node)=0.02_real64
    cof(2,node)=0.433878_real64
    cof(3,node)=83.24164_real64
    cof(4,node)=0.021645_real64
    cof(5,node)=7.202077_real64
    cof(6,node)=1.34877_real64
    cof(7,node)=1.0_real64-1.0_real64/cof(6,node)
    cof(8,node)=0.021645_real64
    cof(9,node)=0.0_real64
    cof(10,node)=832.4163_real64
    ! Exact admitted F-SI39 Hupsel threshold authority; do not rederive algebraically.
    cof(11,node)=0.99628918798955624_real64
    cof(12,node)=36.025513440889291_real64
  end subroutine set_hupsel_upper

  subroutine set_hupsel_lower(node)
    integer,intent(in)::node
    cof(1,node)=0.02_real64
    cof(2,node)=0.3870640000000001_real64
    cof(3,node)=22.76176_real64
    cof(4,node)=0.016083_real64
    cof(5,node)=2.4396619999999993_real64
    cof(6,node)=1.524418_real64
    cof(7,node)=1.0_real64-1.0_real64/cof(6,node)
    cof(8,node)=0.016083_real64
    cof(9,node)=0.0_real64
    cof(10,node)=227.61759999999998_real64
    ! Exact admitted F-SI39 Hupsel threshold authority; do not rederive algebraically.
    cof(11,node)=0.9981816467911503_real64
    cof(12,node)=15.814441314772257_real64
  end subroutine set_hupsel_lower

  subroutine derive_fsi39_threshold(node)
    integer,intent(in)::node
    real(real64)::m,se,term1
    m=1.0_real64-1.0_real64/cof(6,node)
    se=(1.0_real64+abs(cof(4,node)*(-2.0_real64))**cof(6,node))**(-m)
    term1=(1.0_real64-se**(1.0_real64/m))**m
    cof(11,node)=se
    cof(12,node)=cof(3,node)*se**cof(5,node)*(1.0_real64-term1)*(1.0_real64-term1)
  end subroutine derive_fsi39_threshold

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB02_G_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab02g_bounded_ksatexm_generated_provider
