program test_fpe_elastic18_swap_grid
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_fmr_elastic_storage_swap_grid_normalization, only: &
       fmr_elastic_storage_grid_diagnostics_t, fmr_normalize_swap_grid_geometry, &
       FMR_ELAS_GRID_OK, FMR_ELAS_GRID_INVALID_SHAPE, FMR_ELAS_GRID_INVALID_VALUE, FMR_ELAS_GRID_NONCONTIGUOUS
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: fmr_elastic_storage_descriptor_t
  use mod_fmr_elastic_storage_prior_policy, only: FMR_ELAS_REGIME_MINERAL
  implicit none

  real(real64), allocatable :: depth(:), thick(:)
  type(fmr_elastic_storage_grid_diagnostics_t) :: diag
  type(fmr_elastic_storage_horizon_t) :: h(2)
  type(fmr_elastic_storage_mapping_diagnostics_t) :: mdiag
  type(fmr_elastic_storage_descriptor_t), allocatable :: desc(:)
  integer, allocatable :: owner(:)
  real(real64) :: nanv

  nanv=ieee_value(0.0_real64,ieee_quiet_nan)

  call fmr_normalize_swap_grid_geometry( &
       [-25.0_real64,-75.0_real64,-150.0_real64,-250.0_real64], &
       [50.0_real64,50.0_real64,100.0_real64,100.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_OK.and.diag%geometry_complete,'A1 status')
  call req(all(depth==[0.25_real64,0.75_real64,1.50_real64,2.50_real64]),'A1 depth')
  call req(all(thick==[0.50_real64,0.50_real64,1.00_real64,1.00_real64]),'A1 thick')
  write(*,'(A)')'F_PE_ELASTIC18_A1_CANONICAL_GRID=PASS'

  call fmr_normalize_swap_grid_geometry([-10.0_real64,-35.0_real64,-80.0_real64], &
       [20.0_real64,30.0_real64,60.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_OK,'A2 heterogeneous')
  call req(all(depth==[0.10_real64,0.35_real64,0.80_real64]),'A2 depth')
  write(*,'(A)')'F_PE_ELASTIC18_A2_HETEROGENEOUS=PASS'

  call fmr_normalize_swap_grid_geometry([1.0_real64],[10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_INVALID_VALUE.and..not.allocated(depth),'A3 above surface')
  write(*,'(A)')'F_PE_ELASTIC18_A3_SIGN_FAIL_CLOSED=PASS'

  call fmr_normalize_swap_grid_geometry([nanv],[10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_INVALID_VALUE,'A4 nan')
  call fmr_normalize_swap_grid_geometry([-5.0_real64],[0.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_INVALID_VALUE,'A4 zero thickness')
  call fmr_normalize_swap_grid_geometry([-5.0_real64],[-10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_INVALID_VALUE,'A4 negative thickness')
  call fmr_normalize_swap_grid_geometry([-5.0_real64,-15.0_real64],[10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_INVALID_SHAPE,'A4 shape mismatch')
  write(*,'(A)')'F_PE_ELASTIC18_A4_VALUE_FAIL_CLOSED=PASS'

  call fmr_normalize_swap_grid_geometry([-5.0_real64,-20.0_real64],[10.0_real64,10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_NONCONTIGUOUS,'A5 gap')
  call fmr_normalize_swap_grid_geometry([-5.0_real64,-14.0_real64],[10.0_real64,10.0_real64],depth,thick,diag)
  call req(diag%status==FMR_ELAS_GRID_NONCONTIGUOUS,'A5 overlap')
  write(*,'(A)')'F_PE_ELASTIC18_A5_CONTIGUITY_FAIL_CLOSED=PASS'

  call fmr_normalize_swap_grid_geometry([-25.0_real64,-75.0_real64],[50.0_real64,50.0_real64],depth,thick,diag)
  h(1)=fmr_elastic_storage_horizon_t(0.0_real64,0.5_real64,1.5_real64,0.34_real64,FMR_ELAS_REGIME_MINERAL)
  h(2)=fmr_elastic_storage_horizon_t(0.5_real64,1.0_real64,1.3_real64,0.42_real64,FMR_ELAS_REGIME_MINERAL)
  call fmr_map_elastic_storage_horizons_to_nodes(h,depth,thick,desc,owner,mdiag)
  call req(mdiag%status==FMR_ELAS_MAP_OK.and.all(owner==[1,2]),'A6 composition')
  write(*,'(A)')'F_PE_ELASTIC18_A6_ELASTIC17_COMPOSITION=PASS'
  write(*,'(A)')'F_PE_ELASTIC18=PASS'
contains
  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC18_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req
end program test_fpe_elastic18_swap_grid
