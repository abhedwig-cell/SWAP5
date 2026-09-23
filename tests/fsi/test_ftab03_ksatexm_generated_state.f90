program test_ftab03_ksatexm_generated_state
  use, intrinsic :: iso_fortran_env, only: error_unit, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, evaluate_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  implicit none

  integer, parameter :: N=2, NLOG=2401
  real(real64), parameter :: THETA_LIMIT=7.0e-5_real64
  real(real64), parameter :: CAPACITY_LIMIT=7.0e-5_real64
  real(real64), parameter :: LOGK_LIMIT=5.0e-4_real64
  real(real64), parameter :: SPECIAL_K_LIMIT=1.0e-8_real64
  real(real64) :: cof(24,N), h(N), ta(N),ka(N),ca(N),da(N), tt(N),kt(N),ct(N)
  real(real64) :: theta_max, c_max, logk_max, frac, expo
  real(real64) :: special_lower_analytic, special_lower_table, special_upper_abs
  integer :: i,j,status
  type(b110_default_mvg_parameters_t), target :: p_default, p_ext
  type(b110_default_mvg_provider_t) :: a_default, a_ext
  type(b110_generated_mvg_table_state_t) :: s_default, s_ext

  cof=0.0_real64
  ! Exact M1-C3 Hupsel upper layer plus the historical hthr=-2 derived
  ! F-SI39 threshold state.
  call set_node(1, 0.02_real64, 0.433878_real64, 0.021645_real64, 1.34877_real64, &
       7.202077_real64, 83.24164_real64, 832.4163_real64, &
       0.9962891879895563_real64, 36.025513440889625_real64)
  ! Exact M1-C3 Hupsel lower layer / admitted F-SI39 oracle row.
  call set_node(2, 0.02_real64, 0.387064_real64, 0.016083_real64, 1.524418_real64, &
       2.439662_real64, 22.76176_real64, 227.6176_real64, &
       0.9981816467911503_real64, 15.814441314772257_real64)

  call initialize_b110_default_mvg_parameters(p_default,cof)
  call initialize_b110_default_mvg_parameters(p_ext,cof,enable_ksatexm_extension=.true.)
  call bind_b110_default_mvg_provider(a_default,p_default,1.0_real64)
  call bind_b110_default_mvg_provider(a_ext,p_ext,1.0_real64)

  call initialize_b110_generated_mvg_table_state(s_default,p_default,status)
  call require(status==F_TAB02_STATE_OK,'default generated state remains supported')
  call initialize_b110_generated_mvg_table_state(s_ext,p_ext,status)
  if(status/=F_TAB02_STATE_OK) write(error_unit,'(a,i0)') 'F_TAB03_INIT_STATUS=',status
  call require(status==F_TAB02_STATE_OK,'KSATEXM generated state initializes')
  call require(s_default%matches(p_default),'default state matches default authority')
  call require(.not.s_default%matches(p_ext),'default state rejects enabled authority')
  call require(s_ext%matches(p_ext),'enabled state matches enabled authority')
  call require(.not.s_ext%matches(p_default),'enabled state rejects default authority')

  theta_max=0.0_real64
  c_max=0.0_real64
  logk_max=0.0_real64
  do j=1,NLOG
    frac=real(j-1,real64)/real(NLOG-1,real64)
    expo=7.0_real64-19.0_real64*frac
    h=-10.0_real64**expo
    call a_ext%evaluate(h,ta,ka,ca,da)
    call evaluate_b110_generated_mvg_table_state(s_ext,h,tt,kt,ct,status)
    call require(status==F_TAB02_STATE_OK,'dense enabled evaluation')
    theta_max=max(theta_max,maxval(abs(tt-ta)))
    c_max=max(c_max,maxval(abs(ct-ca)))
    do i=1,N
      logk_max=max(logk_max,abs(log10(kt(i))-log10(ka(i))))
    end do
  end do

  ! Saturated/positive head must return exact F-SI39 terminal conductivity.
  h=1.0_real64
  call a_ext%evaluate(h,ta,ka,ca,da)
  call evaluate_b110_generated_mvg_table_state(s_ext,h,tt,kt,ct,status)
  call require(status==F_TAB02_STATE_OK,'positive-head evaluation')
  call require(abs(kt(1)-832.4163_real64)<=SPECIAL_K_LIMIT,'upper saturated KSATEXM')
  call require(abs(kt(2)-227.6176_real64)<=SPECIAL_K_LIMIT,'lower saturated KSATEXM')
  call require(maxval(abs(kt-ka))<=SPECIAL_K_LIMIT,'terminal analytical identity')

  ! Exact admitted lower-layer F-SI39 h=-1 cm oracle.
  h=-1.0_real64
  call a_ext%evaluate(h,ta,ka,ca,da)
  special_lower_analytic=ka(2)
  call require(abs(special_lower_analytic-153.81975964948478_real64)<=2.0e-11_real64, &
       'canonical lower h=-1 oracle')
  call evaluate_b110_generated_mvg_table_state(s_ext,h,tt,kt,ct,status)
  call require(status==F_TAB02_STATE_OK,'h=-1 generated evaluation')
  special_lower_table=kt(2)
  special_upper_abs=abs(kt(1)-ka(1))
  write(error_unit,'(a,es24.16)') 'F_TAB03_DIAG_LOWER_HM1_ANALYTIC_K=',special_lower_analytic
  write(error_unit,'(a,es24.16)') 'F_TAB03_DIAG_LOWER_HM1_TABLE_K=',special_lower_table
  write(error_unit,'(a,es24.16)') 'F_TAB03_DIAG_LOWER_HM1_ABS_K=',abs(special_lower_table-special_lower_analytic)
  write(error_unit,'(a,es24.16)') 'F_TAB03_DIAG_UPPER_HM1_ABS_K=',special_upper_abs
  call require(abs(special_lower_table-special_lower_analytic)<=SPECIAL_K_LIMIT, &
       'lower h=-1 preregistered generated K oracle')
  call require(special_upper_abs<=SPECIAL_K_LIMIT,'upper h=-1 preregistered generated K oracle')

  ! Below the threshold, F-SI39 is an exact no-op in the analytical authority.
  h=-5.0_real64
  call a_default%evaluate(h,ta,ka,ca,da)
  call a_ext%evaluate(h,tt,kt,ct,da)
  call require(all(ka==kt),'canonical below-threshold KSATEXM no-op')
  call evaluate_b110_generated_mvg_table_state(s_ext,h,tt,kt,ct,status)
  call require(status==F_TAB02_STATE_OK,'below-threshold generated evaluation')
  call a_ext%evaluate(h,ta,ka,ca,da)
  do i=1,N
    call require(abs(log10(kt(i))-log10(ka(i)))<=LOGK_LIMIT, &
         'generated below-threshold K within frozen table fidelity')
  end do

  call require(theta_max<=THETA_LIMIT,'theta dense qualification')
  call require(c_max<=CAPACITY_LIMIT,'capacity dense qualification')
  call require(logk_max<=LOGK_LIMIT,'logK dense qualification')

  write(*,'(a,es24.16)') 'F_TAB03_THETA_MAX_ABS=',theta_max
  write(*,'(a,es24.16)') 'F_TAB03_CAPACITY_MAX_ABS=',c_max
  write(*,'(a,es24.16)') 'F_TAB03_LOG10K_MAX_ABS=',logk_max
  write(*,'(a,es24.16)') 'F_TAB03_LOWER_HM1_ANALYTIC_K=',special_lower_analytic
  write(*,'(a,es24.16)') 'F_TAB03_LOWER_HM1_TABLE_K=',special_lower_table
  write(*,'(a,es24.16)') 'F_TAB03_LOWER_HM1_ABS_K=',abs(special_lower_table-special_lower_analytic)
  write(*,'(a,es24.16)') 'F_TAB03_UPPER_HM1_ABS_K=',special_upper_abs
  write(*,'(a)') 'F_TAB03_TERMINAL_KSATEXM=PASS'
  write(*,'(a)') 'F_TAB03_STATE_AUTHORITY_IDENTITY=PASS'
  write(*,'(a)') 'F-TAB03 KSATEXM GENERATED STATE GATE PASS'

contains
  subroutine set_node(node,ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr)
    integer,intent(in)::node
    real(real64),intent(in)::ores,osat,alpha,npar,lexp,ksatfit,ksatexm,relsatthr,ksatthr
    cof(1,node)=ores
    cof(2,node)=osat
    cof(3,node)=ksatfit
    cof(4,node)=alpha
    cof(5,node)=lexp
    cof(6,node)=npar
    cof(7,node)=1.0_real64-1.0_real64/npar
    cof(8,node)=alpha
    cof(9,node)=0.0_real64
    cof(10,node)=ksatexm
    cof(11,node)=relsatthr
    cof(12,node)=ksatthr
  end subroutine set_node

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(error_unit,'(a,1x,a)') 'F_TAB03_GATE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ftab03_ksatexm_generated_state
