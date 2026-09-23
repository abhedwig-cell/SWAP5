program test_ftab03_ksatexm_generated_provider
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  implicit none
  integer, parameter :: N=2, NP=11
  real(real64), parameter :: STEP=4.0e-2_real64
  real(real64), parameter :: probes(NP)=[-1.0e5_real64,-100.0_real64,-5.0_real64,-2.0_real64,-1.0_real64, &
       -0.1_real64,-0.01_real64,-0.001_real64,-1.0e-8_real64,0.0_real64,1.0_real64]
  real(real64) :: cof(24,N), h(N),ta(N),ka(N),ca(N),da(N),tt(N),kt(N),ct(N),dt(N)
  real(real64) :: theta_max,c_max,logk_max
  integer :: j,i,status
  type(b110_default_mvg_parameters_t), target :: p
  type(b110_default_mvg_provider_t) :: analytic
  type(b110_generated_mvg_table_state_t), target :: state
  type(b110_generated_mvg_provider_t) :: table

  cof=0.0_real64
  call set_node(1,0.02_real64,0.433878_real64,0.021645_real64,1.34877_real64,7.202077_real64, &
       83.24164_real64,832.4163_real64,0.9962891879895563_real64,36.025513440889625_real64)
  call set_node(2,0.02_real64,0.387064_real64,0.016083_real64,1.524418_real64,2.439662_real64, &
       22.76176_real64,227.6176_real64,0.9981816467911503_real64,15.814441314772257_real64)

  call initialize_b110_default_mvg_parameters(p,cof,enable_ksatexm_extension=.true.)
  call bind_b110_default_mvg_provider(analytic,p,STEP)
  call initialize_b110_generated_mvg_table_state(state,p,status)
  call require(status==F_TAB02_STATE_OK,'state init')
  call bind_b110_generated_mvg_provider(table,state,STEP,status)
  call require(status==F_TAB02_PROVIDER_OK .and. table%ready(),'provider bind')
  call require(table%context_compatible(STEP),'provider context compatible')
  call require(.not.table%context_compatible(2.0_real64*STEP),'provider context mismatch fails closed')

  theta_max=0.0_real64; c_max=0.0_real64; logk_max=0.0_real64
  do j=1,NP
    h=probes(j)
    call analytic%evaluate(h,ta,ka,ca,da)
    call table%evaluate(h,tt,kt,ct,dt)
    theta_max=max(theta_max,maxval(abs(tt-ta)))
    c_max=max(c_max,maxval(abs(ct-ca)))
    do i=1,N
      logk_max=max(logk_max,abs(log10(kt(i))-log10(ka(i))))
    end do
    call require(all(dt==0.0_real64),'K0 derivative slot zero')
    if (probes(j)==-1.0_real64 .or. probes(j)>=0.0_real64) then
      call require(maxval(abs(kt-ka))<=1.0e-8_real64,'exact active F-SI39 provider oracle')
    end if
  end do
  call require(theta_max<=7.0e-5_real64,'theta provider envelope')
  call require(c_max<=7.0e-5_real64,'capacity provider envelope')
  call require(logk_max<=5.0e-4_real64,'K provider envelope')

  write(*,'(a,es24.16)') 'F_TAB03_PROVIDER_THETA_MAX_ABS=',theta_max
  write(*,'(a,es24.16)') 'F_TAB03_PROVIDER_CAPACITY_MAX_ABS=',c_max
  write(*,'(a,es24.16)') 'F_TAB03_PROVIDER_LOG10K_MAX_ABS=',logk_max
  write(*,'(a)') 'F_TAB03_PROVIDER_EXACT_FSI39_SPECIAL_POINTS=PASS'
  write(*,'(a)') 'F_TAB03_PROVIDER_K0_DERIVATIVE_SLOT_ZERO=PASS'
  write(*,'(a)') 'F_TAB03_PROVIDER_CONTEXT_GATE=PASS'
  write(*,'(a)') 'F-TAB03 TYPED PROVIDER GATE PASS'
contains
  subroutine set_node(node,ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr)
    integer,intent(in)::node
    real(real64),intent(in)::ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr
    cof(1,node)=ores; cof(2,node)=osat; cof(3,node)=ksatfit; cof(4,node)=alpha
    cof(5,node)=lexp; cof(6,node)=npar; cof(7,node)=1.0_real64-1.0_real64/npar
    cof(8,node)=alpha; cof(9,node)=0.0_real64
    cof(10,node)=ksatexm; cof(11,node)=relsatthr; cof(12,node)=ksatthr
  end subroutine set_node
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB03_PROVIDER_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab03_ksatexm_generated_provider
