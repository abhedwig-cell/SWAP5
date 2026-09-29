program test_fpe_elastic18_grid_normalization
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_swap_grid_normalization, only: &
       fmr_elastic_storage_grid_diagnostics_t, fmr_normalize_swap_grid_cm, &
       FMR_ELAS_GRID_OK, FMR_ELAS_GRID_INVALID_SHAPE, FMR_ELAS_GRID_INVALID_VALUE, &
       FMR_ELAS_GRID_INCONSISTENT_GEOMETRY
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK, FMR_ELAS_MAP_NODE_STRADDLES
  use mod_fmr_elastic_storage_descriptor_assembly, only: fmr_elastic_storage_descriptor_t
  use mod_fmr_elastic_storage_prior_policy, only: FMR_ELAS_REGIME_MINERAL
  implicit none

  real(real64), allocatable :: depth(:), thick(:)
  integer, allocatable :: owner(:)
  type(fmr_elastic_storage_grid_diagnostics_t) :: gdiag
  type(fmr_elastic_storage_mapping_diagnostics_t) :: mdiag
  type(fmr_elastic_storage_descriptor_t), allocatable :: descriptors(:)
  type(fmr_elastic_storage_horizon_t) :: horizons(2)
  real(real64) :: nanv

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)

  call fmr_normalize_swap_grid_cm([-12.5_real64,-37.5_real64,-62.5_real64,-87.5_real64], &
       [25.0_real64,25.0_real64,25.0_real64,25.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_OK.and.gdiag%geometry_valid,'A1 status')
  call require(all(depth==[0.125_real64,0.375_real64,0.625_real64,0.875_real64]),'A1 depth')
  call require(all(thick==0.25_real64),'A1 thickness')
  write(*,'(A)')'F_PE_ELASTIC18_A1_UNIFORM_GRID=PASS'

  call fmr_normalize_swap_grid_cm([-5.0_real64,-20.0_real64,-55.0_real64], &
       [10.0_real64,20.0_real64,50.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_OK,'A2 status')
  call require(all(depth==[0.05_real64,0.20_real64,0.55_real64]),'A2 depth')
  call require(all(thick==[0.10_real64,0.20_real64,0.50_real64]),'A2 thickness')
  write(*,'(A)')'F_PE_ELASTIC18_A2_HETEROGENEOUS_GRID=PASS'

  call fmr_normalize_swap_grid_cm([5.0_real64],[10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INVALID_VALUE.and.gdiag%failed_node==1,'A3 positive z')
  call fmr_normalize_swap_grid_cm([nanv],[10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INVALID_VALUE,'A3 nan z')
  call fmr_normalize_swap_grid_cm([-5.0_real64],[0.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INVALID_VALUE,'A3 zero dz')
  call fmr_normalize_swap_grid_cm([-5.0_real64,-15.0_real64],[10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INVALID_SHAPE,'A3 shape')
  write(*,'(A)')'F_PE_ELASTIC18_A3_VALUE_FAIL_CLOSED=PASS'

  call fmr_normalize_swap_grid_cm([-5.0_real64,-16.0_real64],[10.0_real64,10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INCONSISTENT_GEOMETRY.and.gdiag%failed_node==2,'A4 gap centre')
  call fmr_normalize_swap_grid_cm([-5.0_real64,-14.0_real64],[10.0_real64,10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INCONSISTENT_GEOMETRY,'A4 overlap centre')
  call fmr_normalize_swap_grid_cm([-15.0_real64,-5.0_real64],[10.0_real64,10.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INCONSISTENT_GEOMETRY,'A4 reordered')
  write(*,'(A)')'F_PE_ELASTIC18_A4_GEOMETRY_FAIL_CLOSED=PASS'

  horizons(1)=fmr_elastic_storage_horizon_t(0.0_real64,0.5_real64,1.5_real64,0.34_real64,FMR_ELAS_REGIME_MINERAL)
  horizons(2)=fmr_elastic_storage_horizon_t(0.5_real64,1.0_real64,1.3_real64,0.42_real64,FMR_ELAS_REGIME_MINERAL)
  call fmr_normalize_swap_grid_cm([-25.0_real64,-75.0_real64],[50.0_real64,50.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_OK,'A5 normalize')
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,depth,thick,descriptors,owner,mdiag)
  call require(mdiag%status==FMR_ELAS_MAP_OK.and.all(owner==[1,2]),'A5 map')
  write(*,'(A)')'F_PE_ELASTIC18_A5_ELASTIC17_COMPOSITION=PASS'

  call fmr_normalize_swap_grid_cm([-50.0_real64],[40.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_INCONSISTENT_GEOMETRY,'A6 raw inconsistency protected')
  call fmr_normalize_swap_grid_cm([-50.0_real64],[100.0_real64],depth,thick,gdiag)
  call require(gdiag%status==FMR_ELAS_GRID_OK,'A6 normalize straddle grid')
  call fmr_map_elastic_storage_horizons_to_nodes(horizons,depth,thick,descriptors,owner,mdiag)
  call require(mdiag%status==FMR_ELAS_MAP_NODE_STRADDLES,'A6 straddle preserved')
  write(*,'(A)')'F_PE_ELASTIC18_A6_STRADDLE_PRESERVED=PASS'

  write(*,'(A)')'F_PE_ELASTIC18_GRID_ORACLE=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC18_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic18_grid_normalization
