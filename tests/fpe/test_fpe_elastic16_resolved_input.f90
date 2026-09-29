program test_fpe_elastic16_resolved_input
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       materialize_fmr_elastic_storage_prior, FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_PEAT
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK
  use mod_fmr_elastic_storage_resolved_input_adapter, only: &
       fmr_elastic_storage_input_diagnostics_t, fmr_apply_resolved_elastic_storage_inputs, &
       FMR_ELAS_INPUT_OK, FMR_ELAS_INPUT_INACTIVE, FMR_ELAS_INPUT_INVALID_SHAPE, &
       FMR_ELAS_INPUT_PRIOR_REJECTED, FMR_ELAS_INPUT_BINDING_REJECTED
  implicit none

  type(fmr_b110_physical_parameters_t) :: base, via_adapter, via_direct, conflict
  type(fmr_elastic_storage_prior_t) :: priors(3)
  type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
  type(fmr_elastic_storage_input_diagnostics_t) :: diag
  real(real64) :: rho(3), theta(3), nanv
  integer :: regime(3), i, st

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)
  call init_base(base)
  rho=[1.40_real64,1.45_real64,1.50_real64]
  theta=[0.34_real64,0.36_real64,0.38_real64]
  regime=FMR_ELAS_REGIME_MINERAL

  call fmr_apply_resolved_elastic_storage_inputs(base,.false.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_INACTIVE,'A1 status')
  call require(all(via_adapter%cofgen==base%cofgen),'A1 identity')
  call require(via_adapter%elasticity_active.eqv.base%elasticity_active,'A1 active identity')
  call require(.not.diag%priors_materialized.and..not.diag%binding_applied,'A1 no calls')
  write(*,'(A)')'F_PE_ELASTIC16_A1_DEFAULT_OFF=PASS'

  do i=1,3
    call materialize_fmr_elastic_storage_prior(rho(i),theta(i),regime(i),priors(i),st)
    call require(st==FMR_ELAS_PRIOR_OK.and.priors(i)%available,'A2 direct prior')
  end do
  call fmr_bind_generated_elastic_storage_priors(base,.true.,priors,via_direct,bind_diag)
  call require(bind_diag%status==FMR_ELAS_PRIOR_BIND_OK,'A2 direct bind')
  call fmr_apply_resolved_elastic_storage_inputs(base,.true.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_OK.and.diag%binding_applied,'A2 adapter status')
  call require(all(via_adapter%cofgen==via_direct%cofgen),'A2 exact composition')
  call require(via_adapter%elasticity_active.eqv.via_direct%elasticity_active,'A2 active')
  write(*,'(A)')'F_PE_ELASTIC16_A2_COMPOSITION_IDENTITY=PASS'

  conflict=base
  conflict%elasticity_active=.true.
  conflict%cofgen(24,:)=1.0e-6_real64
  call fmr_apply_resolved_elastic_storage_inputs(conflict,.true.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_BINDING_REJECTED,'A3 conflict status')
  call require(all(via_adapter%cofgen==conflict%cofgen).and.via_adapter%elasticity_active,'A3 preserved')
  write(*,'(A)')'F_PE_ELASTIC16_A3_EXPLICIT_CONFLICT=PASS'

  regime=FMR_ELAS_REGIME_MINERAL
  regime(2)=FMR_ELAS_REGIME_PEAT
  call fmr_apply_resolved_elastic_storage_inputs(base,.true.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_PRIOR_REJECTED.and.diag%failed_node==2,'A4 peat')
  call require(all(via_adapter%cofgen==base%cofgen).and..not.via_adapter%elasticity_active,'A4 atomic')
  write(*,'(A)')'F_PE_ELASTIC16_A4_MIXED_FAIL_CLOSED=PASS'

  regime=FMR_ELAS_REGIME_MINERAL
  call fmr_apply_resolved_elastic_storage_inputs(base,.true.,rho(1:2),theta(1:2),regime(1:2),via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_INVALID_SHAPE,'A5 shape')

  rho=[1.40_real64,nanv,1.50_real64]
  call fmr_apply_resolved_elastic_storage_inputs(base,.true.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_PRIOR_REJECTED.and.diag%failed_node==2,'A5 nan')

  rho=[1.40_real64,10.0_real64,1.50_real64]
  call fmr_apply_resolved_elastic_storage_inputs(base,.true.,rho,theta,regime,via_adapter,diag)
  call require(diag%status==FMR_ELAS_INPUT_PRIOR_REJECTED.and.diag%failed_node==2,'A5 domain')
  write(*,'(A)')'F_PE_ELASTIC16_A5_INPUT_FAIL_CLOSED=PASS'

  write(*,'(A)')'F_PE_ELASTIC16_ADAPTER_ORACLE=PASS'

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

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC16_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic16_resolved_input
