program test_fpe_elastic17_layer_node_mapping
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_prior_policy, only: &
       FMR_ELAS_REGIME_MINERAL, FMR_ELAS_REGIME_PEAT
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK, FMR_ELAS_ASSEMBLY_PRIOR_REJECTED
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, &
       FMR_ELAS_MAP_OK, FMR_ELAS_MAP_INVALID_HORIZON, FMR_ELAS_MAP_INVALID_NODE, &
       FMR_ELAS_MAP_NODE_NOT_COVERED, FMR_ELAS_MAP_NODE_STRADDLES
  implicit none

  type(fmr_elastic_storage_horizon_t) :: h1(1), h2(2), badh(2)
  type(fmr_elastic_storage_descriptor_t), allocatable :: mapped(:), manual(:)
  type(fmr_elastic_storage_mapping_diagnostics_t) :: diag
  type(fmr_elastic_storage_assembly_diagnostics_t) :: adiag
  type(fmr_b110_physical_parameters_t) :: base, from_map, from_manual
  integer, allocatable :: owner(:)
  real(real64) :: depth4(4), thick4(4), depth2(2), thick2(2), nanv
  integer :: i

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)

  h1(1)=fmr_elastic_storage_horizon_t(0.0_real64,1.0_real64,1.45_real64,0.36_real64,FMR_ELAS_REGIME_MINERAL)
  depth4=[0.125_real64,0.375_real64,0.625_real64,0.875_real64]
  thick4=0.25_real64
  call fmr_map_elastic_storage_horizons_to_nodes(h1,depth4,thick4,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_OK.and.diag%mapping_complete,'A1 status')
  call require(size(mapped)==4.and.all(owner==1),'A1 owner')
  do i=1,4
    call require(mapped(i)%rho_dry_g_cm3==h1(1)%rho_dry_g_cm3,'A1 rho')
    call require(mapped(i)%theta_ref_cm3_cm3==h1(1)%theta_ref_cm3_cm3,'A1 theta')
    call require(mapped(i)%regime==h1(1)%regime,'A1 regime')
  end do
  write(*,'(A)')'F_PE_ELASTIC17_A1_SINGLE_HORIZON=PASS'

  h2(1)=fmr_elastic_storage_horizon_t(0.0_real64,0.5_real64,1.50_real64,0.34_real64,FMR_ELAS_REGIME_MINERAL)
  h2(2)=fmr_elastic_storage_horizon_t(0.5_real64,1.0_real64,1.30_real64,0.42_real64,FMR_ELAS_REGIME_MINERAL)
  depth2=[0.25_real64,0.75_real64]
  thick2=[0.5_real64,0.5_real64]
  call fmr_map_elastic_storage_horizons_to_nodes(h2,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_OK.and.all(owner==[1,2]),'A2 owner')
  call require(mapped(1)%rho_dry_g_cm3==h2(1)%rho_dry_g_cm3.and.mapped(2)%rho_dry_g_cm3==h2(2)%rho_dry_g_cm3,'A2 rho')
  write(*,'(A)')'F_PE_ELASTIC17_A2_ALIGNED_BOUNDARY=PASS'

  call fmr_map_elastic_storage_horizons_to_nodes(h2,[0.50_real64],[0.40_real64],mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_NODE_STRADDLES.and.diag%failed_node==1,'A3 straddle')
  call require(.not.allocated(mapped).and..not.allocated(owner),'A3 atomic')
  write(*,'(A)')'F_PE_ELASTIC17_A3_STRADDLE_FAIL_CLOSED=PASS'

  badh=h2
  badh(2)%top_depth_m=0.60_real64
  call fmr_map_elastic_storage_horizons_to_nodes(badh,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_INVALID_HORIZON.and.diag%failed_horizon==2,'A4 gap')
  badh=h2
  badh(2)%top_depth_m=0.40_real64
  call fmr_map_elastic_storage_horizons_to_nodes(badh,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_INVALID_HORIZON,'A4 overlap')
  badh=h2
  badh(1)%bottom_depth_m=0.0_real64
  call fmr_map_elastic_storage_horizons_to_nodes(badh,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_INVALID_HORIZON.and.diag%failed_horizon==1,'A4 zero')
  write(*,'(A)')'F_PE_ELASTIC17_A4_HORIZON_VALIDATION=PASS'

  call fmr_map_elastic_storage_horizons_to_nodes(h2,[1.10_real64],[0.10_real64],mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_NODE_NOT_COVERED,'A5 outside')
  write(*,'(A)')'F_PE_ELASTIC17_A5_COVERAGE_FAIL_CLOSED=PASS'

  call fmr_map_elastic_storage_horizons_to_nodes(h2,[nanv],[0.10_real64],mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_INVALID_NODE,'A6 nan node')
  badh=h2
  badh(1)%rho_dry_g_cm3=nanv
  call fmr_map_elastic_storage_horizons_to_nodes(badh,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_INVALID_HORIZON,'A6 nan horizon')
  write(*,'(A)')'F_PE_ELASTIC17_A6_NONFINITE_FAIL_CLOSED=PASS'

  call fmr_map_elastic_storage_horizons_to_nodes(h2,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_OK,'A7 remap')
  call require(transfer(mapped(1)%rho_dry_g_cm3,0_8)==transfer(h2(1)%rho_dry_g_cm3,0_8),'A7 rho bits')
  call require(transfer(mapped(2)%theta_ref_cm3_cm3,0_8)==transfer(h2(2)%theta_ref_cm3_cm3,0_8),'A7 theta bits')
  write(*,'(A)')'F_PE_ELASTIC17_A7_DESCRIPTOR_BIT_IDENTITY=PASS'

  call init_base(base,2)
  allocate(manual(2))
  do i=1,2
    manual(i)%rho_dry_g_cm3=h2(i)%rho_dry_g_cm3
    manual(i)%theta_ref_cm3_cm3=h2(i)%theta_ref_cm3_cm3
    manual(i)%regime=h2(i)%regime
  end do
  call fmr_assemble_generated_elastic_storage(base,.true.,mapped,from_map,adiag)
  call require(adiag%status==FMR_ELAS_ASSEMBLY_OK,'A8 mapped assembly')
  call fmr_assemble_generated_elastic_storage(base,.true.,manual,from_manual,adiag)
  call require(adiag%status==FMR_ELAS_ASSEMBLY_OK,'A8 manual assembly')
  call require(all(from_map%cofgen==from_manual%cofgen),'A8 composition cofgen')
  call require(from_map%elasticity_active.eqv.from_manual%elasticity_active,'A8 composition active')
  write(*,'(A)')'F_PE_ELASTIC17_A8_ELASTIC16_COMPOSITION=PASS'

  h2(2)%regime=FMR_ELAS_REGIME_PEAT
  call fmr_map_elastic_storage_horizons_to_nodes(h2,depth2,thick2,mapped,owner,diag)
  call require(diag%status==FMR_ELAS_MAP_OK.and.mapped(2)%regime==FMR_ELAS_REGIME_PEAT,'A9 faithful peat map')
  call fmr_assemble_generated_elastic_storage(base,.true.,mapped,from_map,adiag)
  call require(adiag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED.and.adiag%failed_node==2,'A9 downstream reject')
  write(*,'(A)')'F_PE_ELASTIC17_A9_PEAT_PRESERVED_AND_REJECTED=PASS'

  write(*,'(A)')'F_PE_ELASTIC17_MAPPING_ORACLE=PASS'

contains

  subroutine init_base(p,n)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer,intent(in)::n
    p%active_nodes=n
    allocate(p%cofgen(24,n))
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
      write(*,'(A,1X,A)')'F_PE_ELASTIC17_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic17_layer_node_mapping
