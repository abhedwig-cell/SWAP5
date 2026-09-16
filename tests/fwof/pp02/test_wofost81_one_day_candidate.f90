program test_wofost81_one_day_candidate
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_wofost_rate_table, only: construct_wofost_rate_table
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t
  use mod_wofost81_daily_parameter_contract
  use mod_wofost81_n_owner_state, only: initialize_wofost81_n_owner_state, WOFOST81_N_OWNER_OK
  use mod_wofost81_crop_owner_state, only: wofost81_crop_owner_state_t, WOFOST81_CROP_OWNER_OK
  use mod_wofost81_one_day_candidate
  use MOD_wofost81_nitrogen, only: WOFOST81_n_flux
  implicit none

  type(wofost81_crop_owner_state_t) :: committed, candidate, failed_candidate
  type(wofost81_one_day_prepared_candidate_t) :: prepared
  type(wofost81_daily_parameter_contract_t) :: p81
  type(wofost_rate_parameter_bundle_t) :: common
  type(wofost_one_day_forcing_t) :: forcing
  type(wofost_accepted_window_aggregates_t) :: aggregates
  type(wofost_one_day_update_parameters_t) :: updatep
  type(WOFOST81_n_flux) :: flux
  real(real64) :: nlv_before, root_before, stem_before, storage_before, wlv_before
  integer :: status

  call configure_parameters(p81)
  call configure_committed(committed,p81,status)
  call check(status==WOFOST81_N_OWNER_OK,'N init')
  call check(committed%validate()==WOFOST81_CROP_OWNER_OK,'committed valid')
  root_before=committed%crop%biomass%root_biomass
  stem_before=committed%crop%biomass%stem_biomass
  storage_before=committed%crop%biomass%storage_biomass
  wlv_before=committed%crop%biomass%living_leaf_biomass()
  nlv_before=committed%nitrogen%value%namountlv

  forcing%minimum_temperature=3._real64
  forcing%average_temperature=10._real64
  forcing%daytime_average_temperature=15._real64
  forcing%global_radiation=0._real64
  forcing%daylength_hours=12._real64
  forcing%photoperiodic_daylength_hours=12._real64
  forcing%co2_efficiency_factor=1._real64
  forcing%co2_amax_factor=1._real64
  aggregates%actual_root_uptake=5._real64
  aggregates%potential_transpiration=5._real64
  updatep%development_stage_end=2._real64
  updatep%leaf_lifespan=100._real64

  call prepare_wofost81_one_day_candidate(committed,forcing,0._real64,1._real64,common,p81, &
       updatep,aggregates,0._real64,0._real64,.false.,prepared,status)
  call check(status==WOFOST81_DAY_OK.and.prepared%ready.and.prepared%active,'prepare candidate')

  ! Committed state must remain bit-for-bit unchanged by candidate preparation.
  call check(same_bits(committed%crop%biomass%root_biomass,root_before),'prepare no root leak')
  call check(same_bits(committed%crop%biomass%stem_biomass,stem_before),'prepare no stem leak')
  call check(same_bits(committed%crop%biomass%storage_biomass,storage_before),'prepare no storage leak')
  call check(same_bits(committed%crop%biomass%living_leaf_biomass(),wlv_before),'prepare no leaf leak')
  call check(same_bits(committed%nitrogen%value%namountlv,nlv_before),'prepare no N leak')
  call check(same_bits(committed%nitrogen%value%nuptake_total,0._real64),'prepare no uptake leak')

  ! Gross/death reconstruction must invert the common net-growth rates exactly.
  call check(abs(prepared%drrt-2._real64)<1e-14_real64,'root death reconstruction')
  call check(abs(prepared%drst-2._real64)<1e-14_real64,'stem death reconstruction')
  call check(abs(prepared%grrt-6._real64)<1e-14_real64,'gross root reconstruction')
  call check(abs(prepared%grst-10._real64)<1e-14_real64,'gross stem reconstruction')
  call check(abs(prepared%grlv-6._real64)<1e-14_real64,'gross leaf binding')
  call check(abs(prepared%grso-3._real64)<1e-14_real64,'gross storage binding')
  call check(prepared%nitrogen_request%soil_request>0._real64,'N request prepared')

  ! Invalid external supply rejects the apply phase without mutating committed state.
  call apply_wofost81_one_day_n_supply(prepared,p81,-1._real64,failed_candidate,flux,status)
  call check(status==WOFOST81_DAY_INVALID_SUPPLY,'invalid supply rejected')
  call check(same_bits(committed%crop%biomass%root_biomass,root_before),'failed apply no crop leak')
  call check(same_bits(committed%nitrogen%value%namountlv,nlv_before),'failed apply no N leak')
  call check(same_bits(committed%nitrogen%value%nuptake_total,0._real64),'failed apply no uptake leak')

  ! Non-limiting external N supply finalizes the candidate only.
  call apply_wofost81_one_day_n_supply(prepared,p81,prepared%nitrogen_request%soil_request,candidate,flux,status)
  call check(status==WOFOST81_DAY_OK,'apply supplied N')
  call check(candidate%validate()==WOFOST81_CROP_OWNER_OK,'final candidate valid')
  call check(abs(candidate%crop%biomass%root_biomass-104._real64)<1e-14_real64,'candidate root update')
  call check(abs(candidate%crop%biomass%stem_biomass-208._real64)<1e-14_real64,'candidate stem update')
  call check(abs(candidate%crop%biomass%storage_biomass-53._real64)<1e-14_real64,'candidate storage update')
  call check(abs(candidate%crop%development_stage-.55_real64)<1e-14_real64,'candidate DVS update')
  call check(candidate%nitrogen%value%nuptake_total>0._real64,'candidate N uptake')
  call check(candidate%nitrogen%validate()==WOFOST81_N_OWNER_OK,'candidate N balance')

  ! Even after a successful candidate build, committed state is still untouched until an external commit.
  call check(same_bits(committed%crop%biomass%root_biomass,root_before),'success path no root leak')
  call check(same_bits(committed%nitrogen%value%namountlv,nlv_before),'success path no N leak')
  call check(same_bits(committed%nitrogen%value%nuptake_total,0._real64),'success path no uptake leak')

  print '(A)','F_WOF_PP02_ONE_DAY_CANDIDATE_PASS'
contains
  subroutine configure_parameters(p)
    type(wofost81_daily_parameter_contract_t),intent(out)::p
    integer::s
    p%base%assimilation%amax_lnb=0._real64
    p%base%assimilation%amax_ref=35._real64
    p%base%assimilation%amax_slp=3.24_real64
    p%base%assimilation%kn=.4_real64
    p%base%nitrogen%nmaxst_fr=.5_real64
    p%base%nitrogen%nmaxrt_fr=.5_real64
    p%base%nitrogen%nmaxso=.0176_real64
    p%base%nitrogen%nresidlv=.004_real64
    p%base%nitrogen%nresidst=.002_real64
    p%base%nitrogen%nresidrt=.002_real64
    p%base%nitrogen%tcnt=10._real64
    p%base%nitrogen%nfix_fr=0._real64
    p%base%nitrogen%rnuptakemax=100._real64
    p%base%nitrogen%dvs_n_transl=.8_real64
    p%base%nitrogen%rgrlai_min=.004_real64
    call construct_wofost_rate_table([0._real64,40._real64],[.4_real64,.4_real64], &
         p%tables%light_use_efficiency,s)
    call check(s==0,'EFF table')
    call construct_wofost_rate_table([0._real64,2._real64],[.5_real64,.5_real64], &
         p%tables%diffuse_extinction_coefficient,s)
    call check(s==0,'KDIF table')
    call construct_wofost_rate_table([0._real64,2._real64],[.04_real64,.04_real64], &
         p%tables%maximum_leaf_n_concentration,s)
    call check(s==0,'NMAXLV table')
    call construct_wofost_rate_table([0._real64,3._real64],[1._real64,1._real64], &
         p%tables%leaf_ageing_n_stress_multiplier,s)
    call check(s==0,'NSLLV table')
    call check(p%validate()==WOFOST81_DAILY_PARAMETER_OK,'P81 valid')
  end subroutine

  subroutine configure_committed(owner,p,status)
    type(wofost81_crop_owner_state_t),intent(out)::owner
    type(wofost81_daily_parameter_contract_t),intent(in)::p
    integer,intent(out)::status
    owner%crop%crop_emerged=.true.
    owner%crop%development_stage=.5_real64
    allocate(owner%crop%biomass,owner%crop%evolution_continuation)
    owner%crop%biomass%root_biomass=100._real64
    owner%crop%biomass%stem_biomass=200._real64
    owner%crop%biomass%storage_biomass=50._real64
    owner%crop%biomass%leaf_biomass=[100._real64,100._real64]
    owner%crop%biomass%specific_leaf_area=[.02_real64,.02_real64]
    owner%crop%biomass%leaf_age=[1._real64,2._real64]
    owner%crop%biomass%exponential_leaf_area_index=4._real64
    call initialize_wofost81_n_owner_state(200._real64,200._real64,100._real64,.04_real64, &
         p%base%nitrogen,owner%nitrogen,status)
  end subroutine


  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    equal = transfer(a,0_int64) == transfer(b,0_int64)
  end function

  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    endif
  end subroutine
end program
