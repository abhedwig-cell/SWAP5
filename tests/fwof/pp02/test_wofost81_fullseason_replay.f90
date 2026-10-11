program test_wofost81_fullseason_replay
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_wofost_rate_table, only: wofost_rate_table_t, construct_wofost_rate_table
  use mod_wofost_rate_parameters, only: wofost_rate_scalar_parameters_t, wofost_rate_parameter_tables_t, &
       wofost_rate_parameter_bundle_t, construct_wofost_rate_parameter_bundle, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t
  use mod_wofost81_daily_parameter_contract, only: wofost81_daily_parameter_contract_t, WOFOST81_DAILY_PARAMETER_OK
  use mod_wofost81_crop_owner_state, only: wofost81_crop_owner_state_t, WOFOST81_CROP_OWNER_OK
  use mod_wofost81_n_owner_state, only: initialize_wofost81_n_owner_state, WOFOST81_N_OWNER_OK
  use mod_wofost81_one_day_candidate, only: wofost81_one_day_prepared_candidate_t, &
       prepare_wofost81_one_day_candidate, apply_wofost81_one_day_n_supply, WOFOST81_DAY_OK
  use MOD_wofost81_nitrogen, only: WOFOST81_n_flux
  implicit none
  character(len=1024) :: data_path, output_path
  integer :: u, out, ios, case_id, day, previous_case, status
  real(real64) :: tmin,tav,tavd,rad,dayl,daylp,sinld,cosld,difpp,dsinbe,tmnr_trace,fco2eff,fco2amax
  type(wofost_rate_parameter_bundle_t) :: common
  type(wofost81_daily_parameter_contract_t) :: p81
  type(wofost81_crop_owner_state_t) :: committed, candidate
  type(wofost81_one_day_prepared_candidate_t) :: prepared
  type(wofost_one_day_forcing_t) :: forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates
  type(wofost_one_day_update_parameters_t) :: updatep
  type(WOFOST81_n_flux) :: flux
  real(real64) :: dead_leaf=0._real64, dead_root=0._real64, dead_stem=0._real64

  call get_command_argument(1,data_path)
  call get_command_argument(2,output_path)
  if (len_trim(data_path)==0 .or. len_trim(output_path)==0) error stop 'usage: replay forcing.dat output.csv'
  call configure_common(common)
  call configure_p81(p81)
  updatep%development_stage_end=2._real64
  updatep%leaf_lifespan=25._real64
  aggregates%actual_root_uptake=1._real64
  aggregates%potential_transpiration=1._real64

  open(newunit=u,file=trim(data_path),status='old',action='read')
  open(newunit=out,file=trim(output_path),status='replace',action='write')
  write(out,'(a)') 'CASE,DAY,DVS,LAI,NamountLV,NamountRT,NamountSO,NamountST,NuptakeTotal,TAGP,TWLV,TWRT,TWSO,TWST'
  previous_case=-1

  do
    read(u,*,iostat=ios) case_id,day,tmin,tav,tavd,rad,dayl,daylp,sinld,cosld,difpp,dsinbe,tmnr_trace,fco2eff,fco2amax
    if (ios<0) exit
    if (ios/=0) error stop 'forcing parse failure'

    if (case_id/=previous_case) then
      call initialize_owner(committed,p81,status)
      if(status/=WOFOST81_N_OWNER_OK) error stop 'owner initialization failure'
      dead_leaf=0._real64
      dead_root=0._real64
      dead_stem=0._real64
      previous_case=case_id
      ! PP01 proved the PCSE state on emergence day is the committed initial
      ! state. Donor POST on that same date is the next PCSE state. Therefore
      ! output state 1 before consuming forcing transition 1.
      call emit_state(out,case_id,1,committed,dead_leaf,dead_root,dead_stem)
    end if

    forcing=wofost_one_day_forcing_t()
    forcing%minimum_temperature=tmin
    forcing%average_temperature=tav
    forcing%daytime_average_temperature=tavd
    forcing%global_radiation=rad
    forcing%daylength_hours=dayl
    forcing%photoperiodic_daylength_hours=daylp
    forcing%sinld=sinld
    forcing%cosld=cosld
    forcing%diffuse_perpendicular_radiation=difpp
    forcing%daily_sine_solar_elevation_integral=dsinbe
    forcing%co2_efficiency_factor=fco2eff
    forcing%co2_amax_factor=fco2amax

    call prepare_wofost81_one_day_candidate(committed,forcing,real(day-1,real64),real(day,real64),common,p81, &
         updatep,aggregates,0._real64,0._real64,.true.,prepared,status)
    if(status/=WOFOST81_DAY_OK) then
      write(*,'(a,2(i0,1x),i0)') 'PREPARE_FAIL case day status ',case_id,day,status
      error stop 'prepare failure'
    end if
    call apply_wofost81_one_day_n_supply(prepared,p81,prepared%nitrogen_request%soil_request,candidate,flux,status)
    if(status/=WOFOST81_DAY_OK) then
      write(*,'(a,2(i0,1x),i0)') 'APPLY_FAIL case day status ',case_id,day,status
      error stop 'N apply failure'
    end if

    dead_leaf=dead_leaf+prepared%drlv
    dead_root=dead_root+prepared%drrt
    dead_stem=dead_stem+prepared%drst
    committed=candidate
    call emit_state(out,case_id,day+1,committed,dead_leaf,dead_root,dead_stem)
    if(tmnr_trace < -1.e100_real64) error stop 'unreachable trace guard'
  end do

  close(u)
  close(out)
  print '(a)', 'F_WOF_PP02_FULLSEASON_REPLAY_EXECUTION_PASS'
contains
  subroutine emit_state(unit_id,id,output_day,owner,dead_lv,dead_rt,dead_st)
    integer,intent(in)::unit_id,id,output_day
    type(wofost81_crop_owner_state_t),intent(in)::owner
    real(real64),intent(in)::dead_lv,dead_rt,dead_st
    real(real64)::lai,wlv,twlv,twrt,twst,twso,tagp
    integer::owner_status
    call owner%crop%derive_actual_leaf_area_index(0._real64,0._real64,lai,owner_status)
    if(owner_status/=WOFOST81_CROP_OWNER_OK) error stop 'LAI derivation failure'
    wlv=owner%crop%biomass%living_leaf_biomass()
    twlv=wlv+dead_lv
    twrt=owner%crop%biomass%root_biomass+dead_rt
    twst=owner%crop%biomass%stem_biomass+dead_st
    twso=owner%crop%biomass%storage_biomass
    tagp=twlv+twst+twso
    write(unit_id,'(i0,",",i0,12(",",es24.16))') id,output_day,owner%crop%development_stage,lai, &
         owner%nitrogen%value%namountlv,owner%nitrogen%value%namountrt,owner%nitrogen%value%namountso, &
         owner%nitrogen%value%namountst,owner%nitrogen%value%nuptake_total,tagp,twlv,twrt,twso,twst
  end subroutine emit_state

  subroutine configure_common(bundle)
    type(wofost_rate_parameter_bundle_t),intent(out)::bundle
    type(wofost_rate_scalar_parameters_t)::s
    type(wofost_rate_parameter_tables_t)::t
    integer::rc
    s%development_daylength_mode=0
    s%vegetative_temperature_sum_required=800._real64
    s%generative_temperature_sum_required=750._real64
    s%diffuse_extinction_coefficient=.44_real64
    s%initial_light_use_efficiency=.4_real64
    s%co2_to_dry_matter_fraction=.4_real64
    s%attainable_yield_multiplier=1._real64
    s%conversion_efficiency_root=.72_real64
    s%conversion_efficiency_stem=.69_real64
    s%conversion_efficiency_leaf=.72_real64
    s%conversion_efficiency_storage=.74_real64
    s%respiration_temperature_q10=2._real64
    s%maintenance_respiration_root=.01_real64
    s%maintenance_respiration_leaf=.03_real64
    s%maintenance_respiration_stem=.015_real64
    s%maintenance_respiration_storage=.01_real64
    s%maximum_leaf_relative_death_rate=.03_real64
    s%leaf_age_base_temperature=0._real64
    s%maximum_relative_lai_growth_rate=.0075_real64
    call make_table([0._real64,35._real64,45._real64],[0._real64,35._real64,35._real64],t%temperature_sum_increment)
    call make_table([0._real64,2._real64],[35._real64,35._real64],t%maximum_assimilation)
    call make_table([0._real64,10._real64,30._real64,35._real64],[0._real64,1._real64,1._real64,0._real64],t%daytime_temperature_factor)
    call make_table([0._real64,3._real64],[0._real64,1._real64],t%minimum_temperature_factor)
    call make_table([0._real64,2._real64],[1._real64,1._real64],t%maintenance_respiration_factor)
    call make_table([0._real64,.4_real64,1._real64,2._real64],[.6_real64,.55_real64,0._real64,0._real64],t%root_partition_fraction)
    call make_table([0._real64,.33_real64,.8_real64,1._real64,1.01_real64,2._real64], &
         [1._real64,1._real64,.4_real64,.1_real64,0._real64,0._real64],t%leaf_partition_fraction)
    call make_table([0._real64,.33_real64,.8_real64,1._real64,1.01_real64,2._real64], &
         [0._real64,0._real64,.6_real64,.9_real64,.15_real64,0._real64],t%stem_partition_fraction)
    call make_table([0._real64,.8_real64,1._real64,1.01_real64,2._real64], &
         [0._real64,0._real64,0._real64,.85_real64,1._real64],t%storage_partition_fraction)
    call make_table([0._real64,1.5_real64,1.51_real64,2._real64], &
         [0._real64,0._real64,.02_real64,.02_real64],t%relative_root_death_rate)
    call make_table([0._real64,1.5_real64,1.51_real64,2._real64], &
         [0._real64,0._real64,.02_real64,.02_real64],t%relative_stem_death_rate)
    call make_table([0._real64,.3_real64,.9_real64,1.45_real64,2._real64], &
         [.002_real64,.0035_real64,.0025_real64,.0022_real64,.0022_real64],t%specific_leaf_area)
    call construct_wofost_rate_parameter_bundle(s,t,bundle,rc)
    if(rc/=WOFOST_RATE_PARAMETER_OK) error stop 'common bundle construction failure'
    if(.not.bundle%ready()) error stop 'common bundle invalid'
  end subroutine configure_common

  subroutine configure_p81(p)
    type(wofost81_daily_parameter_contract_t),intent(out)::p
    p%base%assimilation%amax_lnb=0._real64
    p%base%assimilation%amax_ref=35._real64
    p%base%assimilation%amax_slp=3.24_real64
    p%base%assimilation%kn=.4_real64
    p%base%nitrogen%nmaxst_fr=.5_real64
    p%base%nitrogen%nmaxrt_fr=.5_real64
    p%base%nitrogen%nmaxso=.0176_real64
    p%base%nitrogen%nresidlv=.0047_real64
    p%base%nitrogen%nresidst=.0023_real64
    p%base%nitrogen%nresidrt=.0023_real64
    p%base%nitrogen%tcnt=10._real64
    p%base%nitrogen%nfix_fr=0._real64
    p%base%nitrogen%rnuptakemax=7.2_real64
    p%base%nitrogen%dvs_n_transl=.8_real64
    p%base%nitrogen%rgrlai_min=.004_real64
    call make_table([0._real64,40._real64],[.4_real64,.4_real64],p%tables%light_use_efficiency)
    call make_table([0._real64,2._real64],[.44_real64,.44_real64],p%tables%diffuse_extinction_coefficient)
    call make_table([0._real64,.4_real64,.7_real64,1._real64,2._real64,2.1_real64], &
         [.06_real64,.04_real64,.03_real64,.02_real64,.016_real64,.016_real64],p%tables%maximum_leaf_n_concentration)
    call make_table([0._real64,1.1_real64,1.5_real64,2._real64,2.5_real64], &
         [1._real64,1._real64,1.4_real64,1.5_real64,1.5_real64],p%tables%leaf_ageing_n_stress_multiplier)
    if(p%validate()/=WOFOST81_DAILY_PARAMETER_OK) error stop 'WOFOST81 bundle invalid'
  end subroutine configure_p81

  subroutine initialize_owner(owner,p,status)
    type(wofost81_crop_owner_state_t),intent(out)::owner
    type(wofost81_daily_parameter_contract_t),intent(in)::p
    integer,intent(out)::status
    owner=wofost81_crop_owner_state_t()
    owner%crop%crop_emerged=.true.
    owner%crop%development_stage=0._real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass=36._real64
    owner%crop%biomass%stem_biomass=0._real64
    owner%crop%biomass%storage_biomass=0._real64
    owner%crop%biomass%leaf_biomass=[24._real64]
    owner%crop%biomass%specific_leaf_area=[.002_real64]
    owner%crop%biomass%leaf_age=[0._real64]
    owner%crop%biomass%exponential_leaf_area_index=.048_real64
    call initialize_wofost81_n_owner_state(24._real64,0._real64,36._real64,.06_real64,p%base%nitrogen,owner%nitrogen,status)
    if(status/=WOFOST81_N_OWNER_OK) return
    if(owner%validate()/=WOFOST81_CROP_OWNER_OK) error stop 'initial composite owner invalid'
  end subroutine initialize_owner

  subroutine make_table(x,y,table)
    real(real64),intent(in)::x(:),y(:)
    type(wofost_rate_table_t),intent(out)::table
    integer::rc
    call construct_wofost_rate_table(x,y,table,rc)
    if(rc/=0) error stop 'table construction failure'
  end subroutine make_table
end program test_wofost81_fullseason_replay
