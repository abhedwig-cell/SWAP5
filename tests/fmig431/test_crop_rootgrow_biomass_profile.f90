program test_crop_rootgrow_biomass_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_actual_biomass_state, only: wofost_actual_biomass_state_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  implicit none
  type(wofost_rate_table_t) :: depth_table,density_table
  type(wofost_crop_owner_state_t) :: owner
  type(crop_root_uptake_input_t) :: input
  real(real64) :: zbot(4)
  integer :: status
  logical :: available

  zbot=[-10.0_real64,-20.0_real64,-30.0_real64,-40.0_real64]
  call construct_wofost_rate_table([0.0_real64,100.0_real64,300.0_real64], &
       [10.0_real64,30.0_real64,90.0_real64],depth_table,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 1
  call construct_wofost_rate_table([0.0_real64,0.5_real64,1.0_real64], &
       [2.0_real64,1.0_real64,0.0_real64],density_table,status)
  if(status/=WOFOST_RATE_TABLE_OK)error stop 2

  owner%crop_emerged=.true.
  allocate(owner%biomass)
  owner%biomass=wofost_actual_biomass_state_t()
  owner%biomass%root_biomass=50.0_real64
  call owner%derive_biomass_root_uptake_input(depth_table,density_table,40.0_real64,zbot,input,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or..not.available)error stop 3
  if(input%rooted_nodes/=2)error stop 4
  if(maxval(abs(input%cumulative_root_fraction-[0.0_real64,0.75_real64,1.0_real64]))>1.0e-12_real64)error stop 5

  owner%biomass%root_biomass=300.0_real64
  call owner%derive_biomass_root_uptake_input(depth_table,density_table,30.0_real64,zbot,input,available,status)
  if(status/=WOFOST_CROP_OWNER_OK.or.input%rooted_nodes/=3)error stop 6
  if(maxval(abs(input%cumulative_root_fraction-[0.0_real64,5.0_real64/9.0_real64,8.0_real64/9.0_real64,1.0_real64]))>1.0e-12_real64)error stop 7

  print '(a)','SW431_CROP_ROOTGROW_BIOMASS_PROFILE=PASS'
end program
