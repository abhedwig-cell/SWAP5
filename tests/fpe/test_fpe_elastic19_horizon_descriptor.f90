program test_fpe_elastic19_horizon_descriptor
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT, &
       FMR_ELAS_REGIME_PEAT, FMR_ELAS_REGIME_UNKNOWN
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK, &
       FMR_ELAS_ASSEMBLY_PRIOR_REJECTED
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: &
       fmr_elastic_storage_retention_t, fmr_build_elastic_storage_horizon_descriptor, &
       FMR_ELAS_DESCRIPTOR_OK, FMR_ELAS_DESCRIPTOR_INVALID_GEOMETRY, &
       FMR_ELAS_DESCRIPTOR_INVALID_SOURCE, FMR_ELAS_DESCRIPTOR_INVALID_RETENTION
  implicit none

  type(fmr_elastic_storage_retention_t) :: b01, badret
  type(fmr_elastic_storage_horizon_t) :: h(1), manual(1)
  type(fmr_elastic_storage_mapping_diagnostics_t) :: mdiag
  type(fmr_elastic_storage_assembly_diagnostics_t) :: adiag
  type(fmr_b110_physical_parameters_t) :: base, out
  type(fmr_elastic_storage_descriptor_t), allocatable :: desc(:)
  integer, allocatable :: owner(:)
  integer :: status
  real(real64) :: nanv
  integer(int64) :: bits_a, bits_b

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)
  b01=fmr_elastic_storage_retention_t(0.02000000_real64,0.42749391_real64, &
       0.02165898_real64,1.73473668_real64)

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64, &
       .true.,5.0_real64,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_OK,'A1 status')
  call req(abs(h(1)%theta_ref_cm3_cm3-0.22929575043577552_real64)<1.0e-15_real64,'A1 theta')
  call req(h(1)%regime==FMR_ELAS_REGIME_MINERAL,'A2 mineral')
  write(*,'(A)')'F_PE_ELASTIC19_A1_RETENTION=PASS'
  write(*,'(A)')'F_PE_ELASTIC19_A2_MINERAL=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,0.8_real64, &
       .true.,20.0_real64,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_OK.and.h(1)%regime==FMR_ELAS_REGIME_ORGANIC_RICH_NONPEAT,'A3 organic')
  write(*,'(A)')'F_PE_ELASTIC19_A3_ORGANIC=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,0.3_real64, &
       .true.,5.0_real64,.true.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_OK.and.h(1)%regime==FMR_ELAS_REGIME_PEAT,'A4 peat')
  write(*,'(A)')'F_PE_ELASTIC19_A4_PEAT=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.2_real64, &
       .false.,0.0_real64,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_OK.and.h(1)%regime==FMR_ELAS_REGIME_UNKNOWN,'A5 unknown')
  write(*,'(A)')'F_PE_ELASTIC19_A5_UNKNOWN=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(-0.1_real64,0.5_real64,1.4_real64,.true.,5.0_real64,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_INVALID_GEOMETRY,'A6 geometry')
  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,-1.0_real64,.true.,5.0_real64,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_INVALID_SOURCE,'A6 density')
  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.4_real64,.true.,nanv,.false.,b01,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_INVALID_SOURCE,'A6 organic')
  badret=b01; badret%npar=1.0_real64
  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.4_real64,.true.,5.0_real64,.false.,badret,h(1),status)
  call req(status==FMR_ELAS_DESCRIPTOR_INVALID_RETENTION,'A6 retention')
  write(*,'(A)')'F_PE_ELASTIC19_A6_FAIL_CLOSED=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64,.true.,5.0_real64,.false.,b01,h(1),status)
  bits_a=transfer(h(1)%top_depth_m,bits_a); bits_b=transfer(0.0_real64,bits_b)
  call req(bits_a==bits_b,'A7 top bits')
  bits_a=transfer(h(1)%rho_dry_g_cm3,bits_a); bits_b=transfer(1.45_real64,bits_b)
  call req(bits_a==bits_b,'A7 density bits')
  write(*,'(A)')'F_PE_ELASTIC19_A7_BIT_IDENTITY=PASS'

  manual=h
  call fmr_map_elastic_storage_horizons_to_nodes(h,[0.25_real64],[0.5_real64],desc,owner,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK,'A8 map')
  call init_base(base)
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,out,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_OK,'A8 assembly')
  write(*,'(A)')'F_PE_ELASTIC19_A8_COMPOSITION=PASS'

  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,0.3_real64,.true.,60.0_real64,.true.,b01,h(1),status)
  call fmr_map_elastic_storage_horizons_to_nodes(h,[0.25_real64],[0.5_real64],desc,owner,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK.and.desc(1)%regime==FMR_ELAS_REGIME_PEAT,'A9 peat map')
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,out,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED,'A9 peat reject')
  write(*,'(A)')'F_PE_ELASTIC19_A9_PEAT_DOWNSTREAM_REJECT=PASS'
  write(*,'(A)')'F_PE_ELASTIC19=PASS'
contains
  subroutine init_base(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    p%active_nodes=1
    allocate(p%cofgen(24,1)); p%cofgen=0.0_real64
    p%cofgen(1,:)=0.05_real64;p%cofgen(2,:)=0.45_real64
    p%elasticity_active=.false.;p%prepared_default_mvg_available=.false.
  end subroutine init_base
  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC19_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic19_horizon_descriptor
