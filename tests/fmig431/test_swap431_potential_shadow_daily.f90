program test_swap431_potential_shadow_daily
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  use mod_wofost_crop_owner_state
  use mod_wofost_potential_shadow_state
  use mod_wofost_potential_shadow_daily
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, wofost_one_day_update_parameters_t
  implicit none

  type(wofost_rate_scalar_parameters_t) :: s
  type(wofost_rate_parameter_tables_t) :: t
  type(wofost_rate_parameter_bundle_t) :: p
  type(wofost_crop_owner_state_t) :: actual
  type(wofost_potential_shadow_state_t) :: shadow
  type(wofost_one_day_forcing_t) :: f
  type(wofost_one_day_update_parameters_t) :: u
  type(wofost_potential_daily_result_t) :: full, attainable
  integer :: status
  real(real64), parameter :: tol=1.0e-11_real64
  real(real64) :: actual_wrt0, actual_dvs0, actual_tsum0

  call configure_parameters(s,t)
  call construct_wofost_rate_parameter_bundle(s,t,p,status)
  if(status/=WOFOST_RATE_PARAMETER_OK) error stop 1

  actual%crop_emerged=.true.
  actual%development_stage=0.25_real64
  allocate(actual%biomass,actual%evolution_continuation)
  actual%biomass%root_biomass=20.0_real64
  actual%biomass%stem_biomass=20.0_real64
  actual%biomass%storage_biomass=0.0_real64
  actual%biomass%exponential_leaf_area_index=1.0_real64
  actual%biomass%leaf_biomass=[20.0_real64]
  actual%biomass%specific_leaf_area=[0.02_real64]
  actual%biomass%leaf_age=[1.0_real64]
  actual%evolution_continuation%temperature_sum=25.0_real64
  actual%evolution_continuation%minimum_temperature_history=10.0_real64
  actual%evolution_continuation%minimum_temperature_history_count=7
  actual%evolution_continuation%anthesis_reached=.false.
  if(actual%validate()/=WOFOST_CROP_OWNER_OK) error stop 2

  call initialize_wofost_potential_shadow_from_actual(actual,shadow,status)
  if(status/=WOFOST_POTENTIAL_SHADOW_OK) error stop 3
  shadow%biomass%root_biomass=30.0_real64

  actual_wrt0=actual%biomass%root_biomass
  actual_dvs0=actual%development_stage
  actual_tsum0=actual%evolution_continuation%temperature_sum

  f%minimum_temperature=10.0_real64
  f%average_temperature=20.0_real64
  f%daytime_average_temperature=20.0_real64
  f%global_radiation=1.0e6_real64
  f%daylength_hours=12.0_real64
  f%photoperiodic_daylength_hours=12.0_real64
  f%sinld=0.5_real64
  f%cosld=0.4_real64
  f%diffuse_perpendicular_radiation=100.0_real64
  f%daily_sine_solar_elevation_integral=10000.0_real64
  f%co2_efficiency_factor=1.0_real64
  f%co2_amax_factor=1.0_real64
  u%development_stage_end=2.0_real64
  u%leaf_lifespan=100.0_real64

  call evaluate_wofost_potential_shadow_day(actual,shadow,f,100.0_real64,101.0_real64, &
       0.0_real64,0.0_real64,p,u,1.0_real64,full,status)
  if(status/=WOFOST_POTENTIAL_DAILY_OK) error stop 4
  if(full%potential_pgass<=0.0_real64) error stop 5
  if(full%gross_root_growth_rate<=0.0_real64) error stop 6
  if(full%potential_root_biomass<=shadow%root_biomass()) error stop 7

  ! SWPOTRELMF=2 is represented by passing RELMF into the same source
  ! assimilation physics. Lower RELMF must reduce potential growth.
  call evaluate_wofost_potential_shadow_day(actual,shadow,f,100.0_real64,101.0_real64, &
       0.0_real64,0.0_real64,p,u,0.5_real64,attainable,status)
  if(status/=WOFOST_POTENTIAL_DAILY_OK) error stop 8
  if(attainable%potential_pgass>=full%potential_pgass) error stop 9
  if(attainable%gross_root_growth_rate>=full%gross_root_growth_rate) error stop 10
  if(attainable%potential_root_biomass>=full%potential_root_biomass) error stop 11

  ! Potential trial must not mutate primary actual crop state or shared phenology.
  if(abs(actual%biomass%root_biomass-actual_wrt0)>tol) error stop 12
  if(abs(actual%development_stage-actual_dvs0)>tol) error stop 13
  if(abs(actual%evolution_continuation%temperature_sum-actual_tsum0)>tol) error stop 14

  print '(a)','SW431_CROP_POTENTIAL_SHADOW_DAILY=PASS'

contains

  subroutine configure_parameters(s,t)
    type(wofost_rate_scalar_parameters_t), intent(out) :: s
    type(wofost_rate_parameter_tables_t), intent(out) :: t
    s%development_daylength_mode=0
    s%vegetative_temperature_sum_required=100.0_real64
    s%generative_temperature_sum_required=200.0_real64
    s%diffuse_extinction_coefficient=0.5_real64
    s%initial_light_use_efficiency=0.4_real64
    s%co2_to_dry_matter_fraction=0.4_real64
    s%attainable_yield_multiplier=1.0_real64
    s%conversion_efficiency_root=1.0_real64
    s%conversion_efficiency_stem=1.0_real64
    s%conversion_efficiency_leaf=1.0_real64
    s%conversion_efficiency_storage=1.0_real64
    s%respiration_temperature_q10=2.0_real64
    s%maintenance_respiration_root=0.0_real64
    s%maintenance_respiration_leaf=0.0_real64
    s%maintenance_respiration_stem=0.0_real64
    s%maintenance_respiration_storage=0.0_real64
    s%maximum_leaf_relative_death_rate=0.0_real64
    s%leaf_age_base_temperature=0.0_real64
    s%maximum_relative_lai_growth_rate=0.01_real64

    call make([0.0_real64,40.0_real64],[0.0_real64,40.0_real64],t%temperature_sum_increment)
    call make([0.0_real64,2.0_real64],[20.0_real64,20.0_real64],t%maximum_assimilation)
    call make([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],t%daytime_temperature_factor)
    call make([-20.0_real64,20.0_real64],[1.0_real64,1.0_real64],t%minimum_temperature_factor)
    call make([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],t%maintenance_respiration_factor)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%root_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%leaf_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%stem_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%storage_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],t%relative_root_death_rate)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%relative_stem_death_rate)
    call make([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%specific_leaf_area)
  end subroutine configure_parameters

  subroutine make(x,y,table)
    real(real64), intent(in) :: x(:),y(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer :: rc
    call construct_wofost_rate_table(x,y,table,rc)
    if(rc/=WOFOST_RATE_TABLE_OK) error stop 99
  end subroutine make
end program
