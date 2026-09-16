program test_wofost81_one_day_candidate_integration
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table
  use mod_wofost_rate_parameters, only: wofost_rate_scalar_parameters_t, &
       wofost_rate_parameter_tables_t, wofost_rate_parameter_bundle_t, &
       construct_wofost_rate_parameter_bundle, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t
  use mod_wofost81_daily_parameter_contract
  use mod_wofost81_n_owner_state, only: initialize_wofost81_n_owner_state, WOFOST81_N_OWNER_OK
  use mod_wofost81_crop_owner_state, only: wofost81_crop_owner_state_t, WOFOST81_CROP_OWNER_OK
  use mod_wofost81_one_day_candidate
  use MOD_wofost81_nitrogen, only: WOFOST81_n_flux
  implicit none

  type(wofost81_crop_owner_state_t) :: committed, candidate, rejected_candidate
  type(wofost81_one_day_prepared_candidate_t) :: prepared
  type(wofost81_daily_parameter_contract_t) :: p81
  type(wofost_rate_parameter_bundle_t) :: common
  type(wofost_one_day_forcing_t) :: forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates
  type(wofost_one_day_update_parameters_t) :: updatep
  type(WOFOST81_n_flux) :: flux
  real(real64) :: root0, stem0, storage0, leaf0, nlv0, initial0
  integer :: status

  call configure_common(common)
  call configure_p81(p81)
  call configure_owner(committed,p81,status)
  call require(status == WOFOST81_N_OWNER_OK, 'N owner initialization')

  committed%nitrogen%value%namountlv = committed%nitrogen%value%namountlv - 1.0_real64
  committed%nitrogen%value%initial_total = committed%nitrogen%value%initial_total - 1.0_real64
  call require(committed%validate() == WOFOST81_CROP_OWNER_OK, 'deficient committed owner valid')

  root0 = committed%crop%biomass%root_biomass
  stem0 = committed%crop%biomass%stem_biomass
  storage0 = committed%crop%biomass%storage_biomass
  leaf0 = committed%crop%biomass%living_leaf_biomass()
  nlv0 = committed%nitrogen%value%namountlv
  initial0 = committed%nitrogen%value%initial_total

  forcing%minimum_temperature = 3.0_real64
  forcing%average_temperature = 10.0_real64
  forcing%daytime_average_temperature = 15.0_real64
  forcing%global_radiation = 0.0_real64
  forcing%daylength_hours = 12.0_real64
  forcing%photoperiodic_daylength_hours = 12.0_real64
  forcing%co2_efficiency_factor = 1.0_real64
  forcing%co2_amax_factor = 1.0_real64
  aggregates%actual_root_uptake = 5.0_real64
  aggregates%potential_transpiration = 5.0_real64
  updatep%development_stage_end = 2.0_real64
  updatep%leaf_lifespan = 100.0_real64

  call prepare_wofost81_one_day_candidate(committed,forcing,0.0_real64,1.0_real64,common,p81, &
       updatep,aggregates,0.0_real64,0.0_real64,.false.,prepared,status)
  call require(status == WOFOST81_DAY_OK .and. prepared%ready .and. prepared%active, &
       'actual repository prepare')

  call require(same_bits(committed%crop%biomass%root_biomass,root0), 'prepare no root leak')
  call require(same_bits(committed%crop%biomass%stem_biomass,stem0), 'prepare no stem leak')
  call require(same_bits(committed%crop%biomass%storage_biomass,storage0), 'prepare no storage leak')
  call require(same_bits(committed%crop%biomass%living_leaf_biomass(),leaf0), 'prepare no leaf leak')
  call require(same_bits(committed%nitrogen%value%namountlv,nlv0), 'prepare no N leak')
  call require(same_bits(committed%nitrogen%value%initial_total,initial0), 'prepare no N ledger leak')

  call require(abs(prepared%drrt - 2.0_real64) < 1.0e-13_real64, 'actual root death')
  call require(abs(prepared%drst - 2.0_real64) < 1.0e-13_real64, 'actual stem death')
  call require(abs(prepared%grrt) < 1.0e-13_real64, 'gross root reconstruction zero')
  call require(abs(prepared%grst) < 1.0e-13_real64, 'gross stem reconstruction zero')
  call require(abs(prepared%grlv) < 1.0e-13_real64, 'gross leaf zero')
  call require(abs(prepared%grso) < 1.0e-13_real64, 'gross storage zero')
  call require(prepared%nitrogen_request%soil_request > 0.0_real64, 'deficient crop requests N')

  call apply_wofost81_one_day_n_supply(prepared,p81,-1.0_real64,rejected_candidate,flux,status)
  call require(status == WOFOST81_DAY_INVALID_SUPPLY, 'negative supply fail closed')
  call require(same_bits(committed%nitrogen%value%namountlv,nlv0), 'rejection no N leak')
  call require(same_bits(committed%crop%biomass%root_biomass,root0), 'rejection no crop leak')

  call apply_wofost81_one_day_n_supply(prepared,p81,prepared%nitrogen_request%soil_request, &
       candidate,flux,status)
  call require(status == WOFOST81_DAY_OK, 'actual repository apply supply')
  call require(candidate%validate() == WOFOST81_CROP_OWNER_OK, 'final candidate valid')
  call require(candidate%nitrogen%validate() == WOFOST81_N_OWNER_OK, 'final N balance')
  call require(candidate%nitrogen%value%nuptake_total > 0.0_real64, 'N uptake recorded')
  call require(abs(candidate%crop%biomass%root_biomass - 98.0_real64) < 1.0e-13_real64, &
       'actual root net death')
  call require(abs(candidate%crop%biomass%stem_biomass - 198.0_real64) < 1.0e-13_real64, &
       'actual stem net death')
  call require(abs(candidate%crop%development_stage - 0.51_real64) < 1.0e-13_real64, &
       'actual DVS increment')

  call require(same_bits(committed%crop%biomass%root_biomass,root0), 'success no root leak')
  call require(same_bits(committed%nitrogen%value%namountlv,nlv0), 'success no N leak')
  call require(same_bits(committed%nitrogen%value%nuptake_total,0.0_real64), 'success no uptake leak')

  print '(A)', 'F_WOF_PP02_REPOSITORY_INTEGRATION_PASS'
contains
  subroutine configure_common(bundle)
    type(wofost_rate_parameter_bundle_t), intent(out) :: bundle
    type(wofost_rate_scalar_parameters_t) :: s
    type(wofost_rate_parameter_tables_t) :: t
    integer :: rc
    s%development_daylength_mode = 0
    s%vegetative_temperature_sum_required = 1000.0_real64
    s%generative_temperature_sum_required = 1000.0_real64
    s%diffuse_extinction_coefficient = 0.5_real64
    s%initial_light_use_efficiency = 0.4_real64
    s%co2_to_dry_matter_fraction = 0.7_real64
    s%attainable_yield_multiplier = 1.0_real64
    s%conversion_efficiency_root = 0.7_real64
    s%conversion_efficiency_stem = 0.7_real64
    s%conversion_efficiency_leaf = 0.7_real64
    s%conversion_efficiency_storage = 0.7_real64
    s%respiration_temperature_q10 = 2.0_real64
    s%maintenance_respiration_root = 0.01_real64
    s%maintenance_respiration_leaf = 0.01_real64
    s%maintenance_respiration_stem = 0.01_real64
    s%maintenance_respiration_storage = 0.01_real64
    s%maximum_leaf_relative_death_rate = 0.03_real64
    s%leaf_age_base_temperature = 0.0_real64
    s%maximum_relative_lai_growth_rate = 0.008_real64
    call make_table([0.0_real64,40.0_real64],[10.0_real64,10.0_real64],t%temperature_sum_increment)
    call make_table([0.0_real64,2.0_real64],[35.0_real64,35.0_real64],t%maximum_assimilation)
    call make_table([0.0_real64,40.0_real64],[1.0_real64,1.0_real64],t%daytime_temperature_factor)
    call make_table([-10.0_real64,20.0_real64],[1.0_real64,1.0_real64],t%minimum_temperature_factor)
    call make_table([0.0_real64,2.0_real64],[1.0_real64,1.0_real64],t%maintenance_respiration_factor)
    call make_table([0.0_real64,2.0_real64],[0.2_real64,0.2_real64],t%root_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%leaf_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],t%stem_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.0_real64,0.0_real64],t%storage_partition_fraction)
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%relative_root_death_rate)
    call make_table([0.0_real64,2.0_real64],[0.01_real64,0.01_real64],t%relative_stem_death_rate)
    call make_table([0.0_real64,2.0_real64],[0.02_real64,0.02_real64],t%specific_leaf_area)
    call construct_wofost_rate_parameter_bundle(s,t,bundle,rc)
    call require(rc == WOFOST_RATE_PARAMETER_OK, 'common parameter constructor')
    call require(bundle%ready(), 'common parameter bundle ready')
  end subroutine

  subroutine make_table(x,y,table)
    real(real64), intent(in) :: x(:), y(:)
    type(wofost_rate_table_t), intent(out) :: table
    integer :: rc
    call construct_wofost_rate_table(x,y,table,rc)
    call require(rc == 0, 'table construction')
  end subroutine

  subroutine configure_p81(p)
    type(wofost81_daily_parameter_contract_t), intent(out) :: p
    p%base%assimilation%amax_lnb = 0.0_real64
    p%base%assimilation%amax_ref = 35.0_real64
    p%base%assimilation%amax_slp = 3.24_real64
    p%base%assimilation%kn = 0.4_real64
    p%base%nitrogen%nmaxst_fr = 0.5_real64
    p%base%nitrogen%nmaxrt_fr = 0.5_real64
    p%base%nitrogen%nmaxso = 0.0176_real64
    p%base%nitrogen%nresidlv = 0.004_real64
    p%base%nitrogen%nresidst = 0.002_real64
    p%base%nitrogen%nresidrt = 0.002_real64
    p%base%nitrogen%tcnt = 10.0_real64
    p%base%nitrogen%nfix_fr = 0.0_real64
    p%base%nitrogen%rnuptakemax = 100.0_real64
    p%base%nitrogen%dvs_n_transl = 0.8_real64
    p%base%nitrogen%rgrlai_min = 0.004_real64
    call make_table([0.0_real64,40.0_real64],[0.4_real64,0.4_real64],p%tables%light_use_efficiency)
    call make_table([0.0_real64,2.0_real64],[0.5_real64,0.5_real64],p%tables%diffuse_extinction_coefficient)
    call make_table([0.0_real64,2.0_real64],[0.04_real64,0.04_real64],p%tables%maximum_leaf_n_concentration)
    call make_table([0.0_real64,3.0_real64],[1.0_real64,1.0_real64],p%tables%leaf_ageing_n_stress_multiplier)
    call require(p%validate() == WOFOST81_DAILY_PARAMETER_OK, 'WOFOST81 parameter bundle')
  end subroutine

  subroutine configure_owner(owner,p,status)
    type(wofost81_crop_owner_state_t), intent(out) :: owner
    type(wofost81_daily_parameter_contract_t), intent(in) :: p
    integer, intent(out) :: status
    owner%crop%crop_emerged = .true.
    owner%crop%development_stage = 0.5_real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass = 100.0_real64
    owner%crop%biomass%stem_biomass = 200.0_real64
    owner%crop%biomass%storage_biomass = 50.0_real64
    owner%crop%biomass%leaf_biomass = [100.0_real64,100.0_real64]
    owner%crop%biomass%specific_leaf_area = [0.02_real64,0.02_real64]
    owner%crop%biomass%leaf_age = [1.0_real64,2.0_real64]
    owner%crop%biomass%exponential_leaf_area_index = 4.0_real64
    call initialize_wofost81_n_owner_state(200.0_real64,200.0_real64,100.0_real64,0.04_real64, &
         p%base%nitrogen,owner%nitrogen,status)
  end subroutine

  pure logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = transfer(a,0_int64) == transfer(b,0_int64)
  end function

  subroutine require(ok,label)
    logical, intent(in) :: ok
    character(len=*), intent(in) :: label
    if (.not. ok) then
      print '(A)', trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
