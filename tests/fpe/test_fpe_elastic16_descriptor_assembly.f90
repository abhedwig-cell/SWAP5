program test_fpe_elastic16_descriptor_assembly
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_prior_policy, only: fmr_elastic_storage_prior_t, &
       materialize_fmr_elastic_storage_prior, FMR_ELAS_PRIOR_OK, FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_PEAT
  use mod_fmr_elastic_storage_prior_application_binding, only: &
       fmr_elastic_storage_prior_binding_diagnostics_t, fmr_bind_generated_elastic_storage_priors, &
       FMR_ELAS_PRIOR_BIND_OK, FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, &
       FMR_ELAS_ASSEMBLY_OK, FMR_ELAS_ASSEMBLY_INACTIVE, FMR_ELAS_ASSEMBLY_INVALID_SHAPE, &
       FMR_ELAS_ASSEMBLY_PRIOR_REJECTED, FMR_ELAS_ASSEMBLY_BIND_REJECTED
  implicit none

  type(fmr_b110_physical_parameters_t) :: base, assembled, manual, conflict
  type(fmr_elastic_storage_descriptor_t) :: descriptors(3), bad(3)
  type(fmr_elastic_storage_assembly_diagnostics_t) :: diag
  type(fmr_elastic_storage_prior_t) :: priors(3)
  type(fmr_elastic_storage_prior_binding_diagnostics_t) :: bind_diag
  integer :: i, pstat

  call init_base(base)
  call init_descriptors(descriptors)

  ! A1: inactive request is exact identity and ignores descriptor validity.
  bad = descriptors
  bad(2)%rho_dry_g_cm3 = -1.0_real64
  call fmr_assemble_generated_elastic_storage(base,.false.,bad,assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_INACTIVE,'A1 status')
  call require(.not.assembled%elasticity_active,'A1 inactive')
  call require(all(assembled%cofgen==base%cofgen),'A1 identity')
  write(*,'(A)')'F_PE_ELASTIC16_A1_DEFAULT_OFF=PASS'

  ! A2 + A6: exact identity with explicit manual ELASTIC14 + ELASTIC15 composition.
  do i=1,3
    call materialize_fmr_elastic_storage_prior(descriptors(i)%rho_dry_g_cm3,descriptors(i)%theta_ref_cm3_cm3, &
         descriptors(i)%regime,priors(i),pstat)
    call require(pstat==FMR_ELAS_PRIOR_OK.and.priors(i)%available,'A2 prior fixture')
  end do
  base%prepared_default_mvg_available=.true.
  call fmr_bind_generated_elastic_storage_priors(base,.true.,priors,manual,bind_diag)
  call require(bind_diag%status==FMR_ELAS_PRIOR_BIND_OK,'A2 manual bind')

  call fmr_assemble_generated_elastic_storage(base,.true.,descriptors,assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_OK.and.diag%generated_prior_applied,'A2 assembly status')
  call require(all(assembled%cofgen==manual%cofgen),'A2 cofgen identity')
  call require(assembled%elasticity_active.eqv.manual%elasticity_active,'A2 activation identity')
  call require(assembled%prepared_default_mvg_available.eqv.manual%prepared_default_mvg_available,'A2 cache identity')
  call require(diag%prepared_cache_invalidated,'A6 cache diagnostic')
  write(*,'(A)')'F_PE_ELASTIC16_A2_MANUAL_COMPOSITION_IDENTITY=PASS'
  write(*,'(A)')'F_PE_ELASTIC16_A6_CACHE_INVALIDATION=PASS'

  ! A3: descriptor/materialization failure is atomic.
  bad=descriptors
  bad(2)%regime=FMR_ELAS_REGIME_PEAT
  call fmr_assemble_generated_elastic_storage(base,.true.,bad,assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED.and.diag%failed_node==2,'A3 peat')
  call require(all(assembled%cofgen==base%cofgen).and.(assembled%elasticity_active.eqv.base%elasticity_active),'A3 atomic peat')

  bad=descriptors
  bad(3)%rho_dry_g_cm3=-0.1_real64
  call fmr_assemble_generated_elastic_storage(base,.true.,bad,assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED.and.diag%failed_node==3,'A3 invalid density')
  call require(all(assembled%cofgen==base%cofgen),'A3 atomic density')
  write(*,'(A)')'F_PE_ELASTIC16_A3_DESCRIPTOR_FAIL_CLOSED=PASS'

  ! A4: shape/count failure.
  call fmr_assemble_generated_elastic_storage(base,.true.,descriptors(1:2),assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_INVALID_SHAPE,'A4 count')
  call require(all(assembled%cofgen==base%cofgen),'A4 identity')
  write(*,'(A)')'F_PE_ELASTIC16_A4_SHAPE_FAIL_CLOSED=PASS'

  ! A5: explicit/user ELAS conflict is surfaced from ELASTIC15 and preserved.
  conflict=base
  conflict%prepared_default_mvg_available=.false.
  conflict%elasticity_active=.true.
  conflict%cofgen(24,:)=1.0e-6_real64
  call fmr_assemble_generated_elastic_storage(conflict,.true.,descriptors,assembled,diag)
  call require(diag%status==FMR_ELAS_ASSEMBLY_BIND_REJECTED,'A5 assembly status')
  call require(diag%binding_status==FMR_ELAS_PRIOR_BIND_EXPLICIT_ELAS_CONFLICT,'A5 bind status')
  call require(assembled%elasticity_active.and.all(assembled%cofgen(24,:)==conflict%cofgen(24,:)),'A5 preserved')
  write(*,'(A)')'F_PE_ELASTIC16_A5_EXPLICIT_CONFLICT=PASS'

  write(*,'(A)')'F_PE_ELASTIC16_ASSEMBLY_ORACLE=PASS'

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

  subroutine init_descriptors(d)
    type(fmr_elastic_storage_descriptor_t), intent(out) :: d(3)
    integer :: j
    do j=1,3
      d(j)%rho_dry_g_cm3=1.40_real64+0.02_real64*real(j,real64)
      d(j)%theta_ref_cm3_cm3=0.34_real64+0.01_real64*real(j,real64)
      d(j)%regime=FMR_ELAS_REGIME_MINERAL
    end do
  end subroutine init_descriptors

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC16_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic16_descriptor_assembly
