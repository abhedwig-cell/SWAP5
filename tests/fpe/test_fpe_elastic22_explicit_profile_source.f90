program test_fpe_elastic22_explicit_profile_source
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_explicit_profile_source, only: &
       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_profile_source_diagnostics_t, &
       fmr_build_explicit_bro_profile_horizons, &
       FMR_ELAS_PROFILE_SOURCE_OK, FMR_ELAS_PROFILE_SOURCE_INVALID_REQUEST, &
       FMR_ELAS_PROFILE_SOURCE_NOT_FOUND, FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE, &
       FMR_ELAS_PROFILE_SOURCE_BLOCK_REJECTED, FMR_ELAS_PROFILE_SOURCE_DESCRIPTOR_REJECTED
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK, FMR_ELAS_ASSEMBLY_PRIOR_REJECTED
  implicit none

  type(fmr_elastic_storage_bro_horizon_row_t) :: rows(5), bad(5)
  type(fmr_elastic_storage_horizon_t), allocatable :: horizons(:)
  type(fmr_elastic_storage_descriptor_t), allocatable :: desc(:)
  type(fmr_elastic_storage_profile_source_diagnostics_t) :: diag
  type(fmr_elastic_storage_mapping_diagnostics_t) :: mdiag
  type(fmr_elastic_storage_assembly_diagnostics_t) :: adiag
  type(fmr_b110_physical_parameters_t) :: base, bound
  integer, allocatable :: layers(:), catalog(:), owners(:)
  integer(int64) :: ba, bb

  call init_rows(rows)

  call fmr_build_explicit_bro_profile_horizons(rows,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_OK.and.diag%selected_rows==2,'A1 status')
  call req(size(horizons)==2.and.all(layers==[1,2]),'A1 layers')
  call req(all(catalog==[1,19]),'A1 catalog')
  call req(horizons(1)%top_depth_m==0.0_real64.and.horizons(2)%bottom_depth_m==1.0_real64,'A1 geometry')
  write(*,'(A)')'F_PE_ELASTIC22_A1_EXPLICIT_PROFILE_SELECTION=PASS'

  ba=transfer(horizons(1)%rho_dry_g_cm3,ba);bb=transfer(rows(2)%rho_dry_g_cm3,bb)
  call req(ba==bb,'A2 rho1 bits')
  ba=transfer(horizons(2)%rho_dry_g_cm3,ba);bb=transfer(rows(4)%rho_dry_g_cm3,bb)
  call req(ba==bb,'A2 rho2 bits')
  write(*,'(A)')'F_PE_ELASTIC22_A2_SOURCE_IDENTITY=PASS'

  call req(catalog(1)==1.and.catalog(2)==19,'A3 catalog exact')
  call req(horizons(1)%theta_ref_cm3_cm3>0.0_real64.and.horizons(2)%theta_ref_cm3_cm3>0.0_real64,'A3 theta')
  write(*,'(A)')'F_PE_ELASTIC22_A3_NESTED_COMPOSITION=PASS'

  call fmr_build_explicit_bro_profile_horizons(rows,999,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_NOT_FOUND,'A4 not found')
  call req(.not.allocated(horizons),'A4 atomic')
  write(*,'(A)')'F_PE_ELASTIC22_A4_NOT_FOUND=PASS'

  call fmr_build_explicit_bro_profile_horizons(rows,0,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_INVALID_REQUEST,'A5 invalid request')
  write(*,'(A)')'F_PE_ELASTIC22_A5_INVALID_REQUEST=PASS'

  bad=rows
  bad(2)%layer_number=2
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE,'A6 first not1')
  bad=rows
  bad(4)%layer_number=3
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE,'A6 gap layer')
  bad=rows
  bad(4)%top_depth_m=0.55_real64
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_INVALID_STRUCTURE,'A6 geom gap')
  write(*,'(A)')'F_PE_ELASTIC22_A6_STRUCTURE_FAIL_CLOSED=PASS'

  bad=rows
  bad(4)%staringseriesblock=999
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_BLOCK_REJECTED.and.diag%failed_layer_number==2,'A7 block')
  call req(.not.allocated(horizons),'A7 block atomic')
  bad=rows
  bad(4)%rho_dry_g_cm3=-1.0_real64
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_DESCRIPTOR_REJECTED.and.diag%failed_layer_number==2,'A7 descriptor')
  write(*,'(A)')'F_PE_ELASTIC22_A7_NESTED_FAIL_CLOSED=PASS'

  call fmr_build_explicit_bro_profile_horizons(rows,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_OK,'A8 source')
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,[0.25_real64,0.75_real64],[0.5_real64,0.5_real64], &
       desc,owners,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK.and.all(owners==[1,2]),'A8 map')
  call init_base(base,2)
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,bound,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_OK.and.bound%elasticity_active,'A8 assemble')
  write(*,'(A)')'F_PE_ELASTIC22_A8_DOWNSTREAM_COMPOSITION=PASS'

  bad=rows
  bad(4)%peat_type_present=.true.
  call fmr_build_explicit_bro_profile_horizons(bad,101,horizons,layers,catalog,diag)
  call req(diag%status==FMR_ELAS_PROFILE_SOURCE_OK,'A9 peat source')
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,[0.25_real64,0.75_real64],[0.5_real64,0.5_real64], &
       desc,owners,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK,'A9 map')
  call fmr_assemble_generated_elastic_storage(base,.true.,desc,bound,adiag)
  call req(adiag%status==FMR_ELAS_ASSEMBLY_PRIOR_REJECTED.and.adiag%failed_node==2,'A9 peat reject')
  write(*,'(A)')'F_PE_ELASTIC22_A9_PEAT_PRESERVED=PASS'

  write(*,'(A)')'F_PE_ELASTIC22=PASS'

contains

  subroutine init_rows(r)
    type(fmr_elastic_storage_bro_horizon_row_t),intent(out)::r(5)
    r(1)=fmr_elastic_storage_bro_horizon_row_t(202,1,0.0_real64,0.4_real64,102,1.40_real64,.true.,2.0_real64,.false.)
    r(2)=fmr_elastic_storage_bro_horizon_row_t(101,1,0.0_real64,0.5_real64,101,1.45_real64,.true.,2.0_real64,.false.)
    r(3)=fmr_elastic_storage_bro_horizon_row_t(202,2,0.4_real64,1.0_real64,202,1.35_real64,.true.,3.0_real64,.false.)
    r(4)=fmr_elastic_storage_bro_horizon_row_t(101,2,0.5_real64,1.0_real64,201,1.30_real64,.true.,3.0_real64,.false.)
    r(5)=fmr_elastic_storage_bro_horizon_row_t(303,1,0.0_real64,1.0_real64,103,1.50_real64,.true.,1.0_real64,.false.)
  end subroutine init_rows

  subroutine init_base(p,n)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::n
    p%active_nodes=n
    allocate(p%cofgen(24,n))
    p%cofgen=0.0_real64
    p%cofgen(1,:)=0.05_real64
    p%cofgen(2,:)=0.45_real64
    p%elasticity_active=.false.
    p%prepared_default_mvg_available=.false.
  end subroutine init_base

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC22_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic22_explicit_profile_source
