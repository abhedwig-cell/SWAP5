program test_swap431_rootgrow_biomass
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_crop_root_depth_biomass
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t
  implicit none

  type(wofost_rate_table_t) :: table
  type(crop_root_depth_biomass_result_t) :: result
  type(wofost_crop_owner_state_t) :: owner
  integer :: status
  logical :: available
  real(real64), parameter :: tol=1.0e-12_real64

  call construct_wofost_rate_table([0.0_real64,100.0_real64,300.0_real64], &
       [10.0_real64,50.0_real64,150.0_real64],table,status)
  if(status/=WOFOST_RATE_TABLE_OK) error stop 1

  ! Literal B1.11 SWRD3: RDM=min(RDMAX,AFGEN(RLWTB,WRTMAX));
  ! RD=min(AFGEN(RLWTB,WRT),RDM); RDPOT likewise with WRTPOT.
  call evaluate_crop_root_depth_biomass(table,120.0_real64,300.0_real64,50.0_real64,200.0_real64,result,status)
  if(status/=CROP_ROOT_DEPTH_BIOMASS_OK) error stop 2
  if(abs(result%maximum_root_depth_cm-120.0_real64)>tol) error stop 3
  if(abs(result%actual_root_depth_cm-30.0_real64)>tol) error stop 4
  if(abs(result%potential_root_depth_cm-100.0_real64)>tol) error stop 5

  ! Crop maximum can be tighter than the soil limit.
  call evaluate_crop_root_depth_biomass(table,500.0_real64,100.0_real64,300.0_real64,300.0_real64,result,status)
  if(status/=CROP_ROOT_DEPTH_BIOMASS_OK) error stop 6
  if(abs(result%maximum_root_depth_cm-50.0_real64)>tol) error stop 7
  if(abs(result%actual_root_depth_cm-50.0_real64)>tol.or.abs(result%potential_root_depth_cm-50.0_real64)>tol) error stop 8

  ! Actual biomass must come from the primary crop owner. Potential biomass is
  ! deliberately external because B1.11 keeps WRT and WRTPOT as distinct trajectories.
  owner%crop_emerged=.true.
  allocate(owner%biomass)
  owner%biomass%root_biomass=50.0_real64
  owner%biomass%stem_biomass=0.0_real64
  owner%biomass%storage_biomass=0.0_real64
  owner%biomass%exponential_leaf_area_index=0.0_real64
  if(owner%validate()/=WOFOST_CROP_OWNER_OK) error stop 9
  call owner%derive_biomass_root_depth(table,120.0_real64,300.0_real64,200.0_real64,result,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or..not.available) error stop 10
  if(abs(result%actual_root_depth_cm-30.0_real64)>tol.or.abs(result%potential_root_depth_cm-100.0_real64)>tol) error stop 11

  owner%crop_emerged=.false.
  deallocate(owner%biomass)
  call owner%derive_biomass_root_depth(table,120.0_real64,300.0_real64,200.0_real64,result,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or.available) error stop 12

  print '(a)','SW431_CROP_ROOTGROW_BIOMASS_COMPONENT=PASS'
end program
