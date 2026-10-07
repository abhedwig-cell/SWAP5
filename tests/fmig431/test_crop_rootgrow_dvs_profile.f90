program test_crop_rootgrow_dvs_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t, validate_crop_root_uptake_input, CROP_ROOT_INPUT_OK
  implicit none

  type(wofost_rate_table_t) :: depth_table, density_table
  type(wofost_crop_owner_state_t) :: owner
  type(crop_root_uptake_input_t) :: input
  real(real64) :: zbot(4)
  integer :: status
  logical :: available

  zbot = [-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  call construct_wofost_rate_table([0.0_real64,1.0_real64,2.0_real64], &
       [10.0_real64,20.0_real64,50.0_real64], depth_table, status)
  if (status /= WOFOST_RATE_TABLE_OK) error stop 1
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [2.0_real64,1.0_real64,0.0_real64], density_table, status)
  if (status /= WOFOST_RATE_TABLE_OK) error stop 2

  owner%crop_emerged = .true.
  owner%development_stage = 0.5_real64
  allocate(owner%biomass)
  owner%biomass = wofost_actual_biomass_state_t()
  if (owner%validate() /= WOFOST_CROP_OWNER_OK) error stop 3

  call owner%derive_dvs_root_uptake_input(depth_table,density_table,40.0_real64,zbot,input,available,status)
  if (status /= WOFOST_CROP_OWNER_OK .or. .not.available) error stop 4
  if (input%rooted_nodes /= 2 .or. size(input%cumulative_root_fraction) /= 3) error stop 5
  if (maxval(abs(input%cumulative_root_fraction-[0.0_real64,0.75_real64,1.0_real64])) > 1.0e-12_real64) error stop 6
  call validate_crop_root_uptake_input(input,4,status)
  if (status /= CROP_ROOT_INPUT_OK) error stop 7
  if (input%potential_transpiration /= 0.0_real64) error stop 8

  owner%development_stage = 1.0_real64
  call owner%derive_dvs_root_uptake_input(depth_table,density_table,40.0_real64,zbot,input,available,status)
  if (status /= WOFOST_CROP_OWNER_OK .or. input%rooted_nodes /= 2) error stop 9

  owner%development_stage = 2.0_real64
  call owner%derive_dvs_root_uptake_input(depth_table,density_table,30.0_real64,zbot,input,available,status)
  if (status /= WOFOST_CROP_OWNER_OK .or. input%rooted_nodes /= 3) error stop 10
  if (maxval(abs(input%cumulative_root_fraction - &
      [0.0_real64,5.0_real64/9.0_real64,8.0_real64/9.0_real64,1.0_real64])) > 1.0e-12_real64) error stop 11

  print '(a)','SW431_CROP_ROOTGROW_DVS_PROFILE=PASS'
end program
