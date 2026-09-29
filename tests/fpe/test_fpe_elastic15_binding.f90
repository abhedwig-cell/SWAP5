program test_fpe_elastic15_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_PEAT, FMR_ELAS_DOMAIN_IN, FMR_ELAS_DOMAIN_OUT
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK, FMR_ELAS_PRIOR_BIND_INACTIVE, FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT, &
       FMR_ELAS_PRIOR_BIND_INVALID_SHAPE, FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED
  implicit none

  type(fmr_b110_physical_parameters_t) :: base, bound, conflict
  type(fmr_elastic_storage_prior_t) :: priors(3), bad_priors(3)
  type(fmr_elastic_storage_prior_binding_diagnostics_t) :: diag
  real(real64) :: nanv
  integer :: i

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)
  call init_base(base)
  call init_priors(priors)

  call fmr_bind_generated_elastic_storage_priors(base,.false.,priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_INACTIVE,'A1 status')
  call require(.not.bound%elasticity_active,'A1 inactive')
  call require(all(bound%cofgen==base%cofgen),'A1 row identity')
  call require(bound%prepared_default_mvg_available.eqv.base%prepared_default_mvg_available,'A1 cache identity')
  write(*,'(A)')'F_PE_ELASTIC15_A1_DEFAULT_OFF=PASS'

  base%prepared_default_mvg_available=.true.
  call fmr_bind_generated_elastic_storage_priors(base,.true.,priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_OK.and.diag%generated_prior_applied,'A2 status')
  call require(bound%elasticity_active,'A2 active')
  do i=1,3
    call require(bound%cofgen(24,i)==priors(i)%value_cm_inv,'A2 node local')
  end do
  call require(.not.bound%prepared_default_mvg_available.and.diag%prepared_cache_invalidated,'A5 cache invalidated')
  call require(all(bound%cofgen(1:23,:)==base%cofgen(1:23,:)),'A2 unrelated rows')
  write(*,'(A)')'F_PE_ELASTIC15_A2_HETEROGENEOUS_BINDING=PASS'
  write(*,'(A)')'F_PE_ELASTIC15_A5_CACHE_INVALIDATION=PASS'

  conflict=base
  conflict%elasticity_active=.true.
  conflict%cofgen(24,:)=1.0e-6_real64
  call fmr_bind_generated_elastic_storage_priors(conflict,.true.,priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT,'A3 active conflict')
  call require(bound%elasticity_active.and.all(bound%cofgen(24,:)==conflict%cofgen(24,:)),'A3 active preserved')

  conflict=base
  conflict%prepared_default_mvg_available=.false.
  conflict%cofgen(24,2)=2.0e-6_real64
  call fmr_bind_generated_elastic_storage_priors(conflict,.true.,priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT.and.diag%failed_node==2,'A3 dormant conflict')
  call require(.not.bound%elasticity_active.and.bound%cofgen(24,2)==2.0e-6_real64,'A3 dormant preserved')
  write(*,'(A)')'F_PE_ELASTIC15_A3_EXPLICIT_CONFLICT=PASS'

  bad_priors=priors
  bad_priors(2)%available=.false.
  call fmr_bind_generated_elastic_storage_priors(base,.true.,bad_priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED.and.diag%failed_node==2,'A4 unavailable')

  bad_priors=priors
  bad_priors(2)%regime=FMR_ELAS_REGIME_PEAT
  call fmr_bind_generated_elastic_storage_priors(base,.true.,bad_priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED.and.diag%failed_node==2,'A4 peat')

  bad_priors=priors
  bad_priors(2)%domain_class=FMR_ELAS_DOMAIN_OUT
  call fmr_bind_generated_elastic_storage_priors(base,.true.,bad_priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED.and.diag%failed_node==2,'A4 domain')

  bad_priors=priors
  bad_priors(2)%value_cm_inv=nanv
  call fmr_bind_generated_elastic_storage_priors(base,.true.,bad_priors,bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_PRIOR_REJECTED.and.diag%failed_node==2,'A4 nan')

  call fmr_bind_generated_elastic_storage_priors(base,.true.,priors(1:2),bound,diag)
  call require(diag%status==FMR_ELAS_PRIOR_BIND_INVALID_SHAPE,'A4 count')
  call require(.not.bound%elasticity_active.and.all(bound%cofgen==base%cofgen),'A4 atomic')
  write(*,'(A)')'F_PE_ELASTIC15_A4_FAIL_CLOSED=PASS'

  write(*,'(A)')'F_PE_ELASTIC15_BINDING_ORACLE=PASS'

contains

  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    p%active_nodes=3
    allocate(p%cofgen(24,3))
    p%cofgen=0.0_real64
    p%cofgen(1,:)=0.05_real64
    p%cofgen(2,:)=0.45_real64
    p%elasticity_active=.false.
    p%prepared_default_mvg_available=.false.
  end subroutine init_base

  subroutine init_priors(p)
    type(fmr_elastic_storage_prior_t), intent(out) :: p(3)
    integer :: j
    do j=1,3
      p(j)%available=.true.
      p(j)%regime=FMR_ELAS_REGIME_MINERAL
      p(j)%domain_class=FMR_ELAS_DOMAIN_IN
      p(j)%value_cm_inv=real(j,real64)*1.0e-6_real64
      p(j)%lower_cm_inv=p(j)%value_cm_inv/2.123968031921196_real64
      p(j)%upper_cm_inv=p(j)%value_cm_inv*2.123968031921196_real64
    end do
  end subroutine init_priors

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC15_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic15_binding
