program test_swap431_annual_idsl01_source_envelope
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: construct_wofost_rate_table, WOFOST_RATE_TABLE_OK
  use mod_wofost_rate_parameters
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  use mod_wofost_prepare_assimilation, only: wofost_prepare_assimilation_result_t
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t, wofost_one_day_rate_packet_t
  use mod_wofost_finalize_rates
  implicit none

  type(wofost_rate_scalar_parameters_t) :: s
  type(wofost_rate_parameter_tables_t) :: t
  type(wofost_rate_parameter_bundle_t) :: p
  type(wofost_one_day_rate_state_view_t) :: state
  type(wofost_prepare_assimilation_result_t) :: prepared
  type(wofost_accepted_window_aggregates_t) :: agg
  type(wofost_finalize_rate_forcing_t) :: forcing
  type(wofost_one_day_rate_packet_t) :: rates
  integer :: status
  real(real64), parameter :: tol=1.0e-12_real64

  call configure_common(s,t)
  state%actual_root_biomass=10.0_real64
  state%actual_stem_biomass=10.0_real64
  state%actual_storage_biomass=0.0_real64
  state%living_leaf_biomass=10.0_real64
  state%actual_leaf_area_index=1.0_real64
  state%exponential_leaf_area_index=1.0_real64
  prepared%actual_pgass=10.0_real64
  agg%actual_root_uptake=1.0_real64
  agg%potential_transpiration=1.0_real64
  forcing%average_temperature=20.0_real64

  ! IDSL0: pinned B1.11 DVR=DTSUM/TSUMEA before anthesis, independent of daylength.
  s%development_daylength_mode=0
  s%daylength_upper_hours=99.0_real64
  s%daylength_lower_hours=-99.0_real64
  call construct_wofost_rate_parameter_bundle(s,t,p,status)
  if(status/=WOFOST_RATE_PARAMETER_OK) error stop 1
  state%development_stage=0.5_real64
  forcing%photoperiodic_daylength_hours=0.0_real64
  call finalize_wofost_one_day_rates(state,p,prepared,agg,forcing,rates,status)
  if(status/=WOFOST_FINALIZE_RATES_OK) error stop 2
  if(abs(rates%temperature_sum_increment-20.0_real64)>tol) error stop 3
  if(abs(rates%development_rate-0.2_real64)>tol) error stop 4

  ! IDSL1 source clamp at/below DLC => zero.
  s%development_daylength_mode=1
  s%daylength_lower_hours=8.0_real64
  s%daylength_upper_hours=16.0_real64
  call construct_wofost_rate_parameter_bundle(s,t,p,status)
  if(status/=WOFOST_RATE_PARAMETER_OK) error stop 5
  forcing%photoperiodic_daylength_hours=8.0_real64
  call finalize_wofost_one_day_rates(state,p,prepared,agg,forcing,rates,status)
  if(status/=WOFOST_FINALIZE_RATES_OK.or.abs(rates%development_rate)>tol) error stop 6

  ! Interior: DVRED=(12-8)/(16-8)=0.5.
  forcing%photoperiodic_daylength_hours=12.0_real64
  call finalize_wofost_one_day_rates(state,p,prepared,agg,forcing,rates,status)
  if(status/=WOFOST_FINALIZE_RATES_OK) error stop 7
  if(abs(rates%development_rate-0.1_real64)>tol) error stop 8

  ! At/above DLO => full temperature development.
  forcing%photoperiodic_daylength_hours=16.0_real64
  call finalize_wofost_one_day_rates(state,p,prepared,agg,forcing,rates,status)
  if(status/=WOFOST_FINALIZE_RATES_OK.or.abs(rates%development_rate-0.2_real64)>tol) error stop 9

  ! Generative source branch ignores daylength: DVR=DTSUM/TSUMAM.
  state%development_stage=1.2_real64
  forcing%photoperiodic_daylength_hours=8.0_real64
  call finalize_wofost_one_day_rates(state,p,prepared,agg,forcing,rates,status)
  if(status/=WOFOST_FINALIZE_RATES_OK) error stop 10
  if(abs(rates%development_rate-0.1_real64)>tol) error stop 11

  ! Parameter validator must still reject IDSL2 on the admitted classic path;
  ! vernalisation is being integrated separately and must not silently widen IDSL0/1.
  s%development_daylength_mode=2
  call construct_wofost_rate_parameter_bundle(s,t,p,status)
  if(status/=WOFOST_RATE_PARAMETER_INVALID_IDSL) error stop 12

  print '(a)','SW431_CROP_ANNUAL_IDSL01_SOURCE_ENVELOPE=PASS'

contains

  subroutine configure_common(s,t)
    type(wofost_rate_scalar_parameters_t), intent(out) :: s
    type(wofost_rate_parameter_tables_t), intent(out) :: t
    integer :: rc

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
    s%maximum_relative_lai_growth_rate=0.0_real64

    call make([0.0_real64,40.0_real64],[0.0_real64,40.0_real64],t%temperature_sum_increment)
    call make([0.0_real64,2.0_real64],[10.0_real64,10.0_real64],t%maximum_assimilation)
    call make([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],t%daytime_temperature_factor)
    call make([-10.0_real64,20.0_real64],[1.0_real64,1.0_real64],t%minimum_temperature_factor)
    call make([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],t%maintenance_respiration_factor)
    call make([0.0_real64,2.0_real64],[0.25_real64,0.25_real64],t%root_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%leaf_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%stem_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%storage_partition_fraction)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%relative_root_death_rate)
    call make([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%relative_stem_death_rate)
    call make([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%specific_leaf_area)
  end subroutine configure_common

  subroutine make(x,y,table)
    real(real64), intent(in) :: x(:),y(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer :: rc
    call construct_wofost_rate_table(x,y,table,rc)
    if(rc/=WOFOST_RATE_TABLE_OK) error stop 99
  end subroutine make

end program
