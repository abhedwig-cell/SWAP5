module mod_wofost81_rate_correction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_one_day_rate_state_view, only: wofost_one_day_rate_state_view_t
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_rate_packet_t
  use mod_wofost81_daily_parameter_contract, only: wofost81_daily_parameter_contract_t, WOFOST81_DAILY_PARAMETER_OK
  use mod_wofost81_n_owner_state, only: wofost81_n_owner_state_t, WOFOST81_N_OWNER_OK
  use MOD_wofost81_n_stress, only: compute_wofost81_n_stress, WOFNSTR81_OK
  implicit none
  private
  integer, parameter, public :: WOFOST81_RATE_CORRECTION_OK=0, WOFOST81_RATE_CORRECTION_INVALID_STATE=1, &
       WOFOST81_RATE_CORRECTION_INVALID_PARAMETERS=2, WOFOST81_RATE_CORRECTION_INVALID_N_STATE=3, &
       WOFOST81_RATE_CORRECTION_INVALID_LEAF_COHORTS=4, WOFOST81_RATE_CORRECTION_INVALID_BASE_RATES=5, &
       WOFOST81_RATE_CORRECTION_N_STRESS_FAILURE=6, WOFOST81_RATE_CORRECTION_PARAMETER_EVALUATION=7, &
       WOFOST81_RATE_CORRECTION_INVALID_RESULT=8
  type, public :: wofost81_rate_correction_diagnostics_t
    real(real64) :: maximum_leaf_n_concentration=0, nstress_index_dlv=1, leaf_ageing_n_stress_multiplier=1
    real(real64) :: rfrgrl=1, aged_leaf_biomass=0, ageing_leaf_death_rate=0, base_leaf_stress_death_rate=0
    real(real64) :: combined_leaf_death_rate=0
    logical :: juvenile_lai_n_stress_applied=.false.
  end type
  public :: correct_wofost81_leaf_rates
contains
  subroutine correct_wofost81_leaf_rates(state_view,leaf_biomass,leaf_age,leaf_lifespan,day_length_days, &
       maximum_relative_lai_growth_rate,nitrogen_stress_active,parameters,nitrogen,base_rates, &
       corrected_rates,diagnostics,status)
    type(wofost_one_day_rate_state_view_t),intent(in)::state_view
    real(real64),intent(in)::leaf_biomass(:),leaf_age(:),leaf_lifespan,day_length_days,maximum_relative_lai_growth_rate
    logical,intent(in)::nitrogen_stress_active
    type(wofost81_daily_parameter_contract_t),intent(in)::parameters
    type(wofost81_n_owner_state_t),intent(in)::nitrogen
    type(wofost_one_day_rate_packet_t),intent(in)::base_rates
    type(wofost_one_day_rate_packet_t),intent(out)::corrected_rates
    type(wofost81_rate_correction_diagnostics_t),intent(out)::diagnostics
    integer,intent(out)::status
    real(real64)::nmaxlv,nstress_index,rfrgrl,nsllv,aged_mass,dalv,corrected_glaiex
    integer::i,kernel_status,parameter_status
    corrected_rates=base_rates; diagnostics=wofost81_rate_correction_diagnostics_t()
    status=WOFOST81_RATE_CORRECTION_INVALID_STATE; if(.not.valid_state_view(state_view)) return
    status=WOFOST81_RATE_CORRECTION_INVALID_PARAMETERS
    if(parameters%validate()/=WOFOST81_DAILY_PARAMETER_OK) return
    if(.not.ieee_is_finite(maximum_relative_lai_growth_rate).or.maximum_relative_lai_growth_rate<=0) return
    status=WOFOST81_RATE_CORRECTION_INVALID_N_STATE; if(nitrogen%validate()/=WOFOST81_N_OWNER_OK) return
    status=WOFOST81_RATE_CORRECTION_INVALID_LEAF_COHORTS
    if(.not.valid_leaf_cohorts(leaf_biomass,leaf_age,leaf_lifespan,day_length_days,state_view%living_leaf_biomass)) return
    status=WOFOST81_RATE_CORRECTION_INVALID_BASE_RATES; if(.not.valid_base_rates(base_rates)) return
    call parameters%evaluate_maximum_leaf_n_concentration(state_view%development_stage,nmaxlv,parameter_status)
    if(parameter_status/=WOFOST81_DAILY_PARAMETER_OK) then; status=WOFOST81_RATE_CORRECTION_PARAMETER_EVALUATION; return; endif
    nstress_index=1; rfrgrl=1; nsllv=1
    if(nitrogen_stress_active) then
      call compute_wofost81_n_stress(nmaxlv,parameters%base%nitrogen%nmaxst_fr,parameters%base%nitrogen%nmaxso, &
           maximum_relative_lai_growth_rate,parameters%base%nitrogen%rgrlai_min,state_view%living_leaf_biomass, &
           state_view%actual_stem_biomass,state_view%actual_storage_biomass,nitrogen%value%namountlv, &
           nitrogen%value%namountst,nitrogen%value%namountso,nstress_index,rfrgrl,kernel_status)
      if(kernel_status/=WOFNSTR81_OK) then; status=WOFOST81_RATE_CORRECTION_N_STRESS_FAILURE; return; endif
      call parameters%evaluate_leaf_ageing_n_stress_multiplier(nstress_index,nsllv,parameter_status)
      if(parameter_status/=WOFOST81_DAILY_PARAMETER_OK) then; status=WOFOST81_RATE_CORRECTION_PARAMETER_EVALUATION; return; endif
    endif
    aged_mass=0
    do i=1,size(leaf_biomass); if(leaf_age(i)>leaf_lifespan) aged_mass=aged_mass+leaf_biomass(i); enddo
    dalv=min(aged_mass*nsllv,state_view%living_leaf_biomass)/day_length_days
    corrected_rates%leaf_stress_death_rate=max(base_rates%leaf_stress_death_rate,dalv)
    if(base_rates%lai_exponential_rate_recomputed.and.state_view%development_stage<0.2_real64.and. &
       state_view%actual_leaf_area_index<0.75_real64) then
      corrected_glaiex=base_rates%lai_exponential_growth_rate*rfrgrl
      corrected_rates%lai_exponential_growth_rate=corrected_glaiex
      if(base_rates%leaf_growth_rate>0) corrected_rates%youngest_specific_leaf_area= &
           min(base_rates%youngest_specific_leaf_area,corrected_glaiex/base_rates%leaf_growth_rate)
      diagnostics%juvenile_lai_n_stress_applied=nitrogen_stress_active
    endif
    diagnostics%maximum_leaf_n_concentration=nmaxlv; diagnostics%nstress_index_dlv=nstress_index
    diagnostics%leaf_ageing_n_stress_multiplier=nsllv; diagnostics%rfrgrl=rfrgrl
    diagnostics%aged_leaf_biomass=aged_mass; diagnostics%ageing_leaf_death_rate=dalv
    diagnostics%base_leaf_stress_death_rate=base_rates%leaf_stress_death_rate
    diagnostics%combined_leaf_death_rate=corrected_rates%leaf_stress_death_rate
    status=WOFOST81_RATE_CORRECTION_INVALID_RESULT
    if(.not.valid_base_rates(corrected_rates)) return
    if(.not.all(ieee_is_finite([nmaxlv,nstress_index,nsllv,rfrgrl,aged_mass,dalv]))) return
    status=WOFOST81_RATE_CORRECTION_OK
  end subroutine
  pure logical function valid_state_view(s) result(v)
    type(wofost_one_day_rate_state_view_t),intent(in)::s; real(real64)::x(7)
    x=[s%development_stage,s%actual_root_biomass,s%actual_stem_biomass,s%actual_storage_biomass,s%living_leaf_biomass, &
       s%actual_leaf_area_index,s%exponential_leaf_area_index]; v=all(ieee_is_finite(x)).and.all(x>=0)
  end function
  pure logical function valid_leaf_cohorts(b,a,span,dt,wlv) result(v)
    real(real64),intent(in)::b(:),a(:),span,dt,wlv; real(real64)::tol
    v=.false.; if(size(b)/=size(a)) return; if(.not.all(ieee_is_finite(b)).or..not.all(ieee_is_finite(a))) return
    if(any(b<0).or.any(a<0).or..not.ieee_is_finite(span).or.span<0.or..not.ieee_is_finite(dt).or.dt<=0) return
    tol=2048*epsilon(1._real64)*max(1._real64,wlv); if(abs(sum(b)-wlv)>tol) return; v=.true.
  end function
  pure logical function valid_base_rates(r) result(v)
    type(wofost_one_day_rate_packet_t),intent(in)::r; real(real64)::x(11)
    x=[r%temperature_sum_increment,r%development_rate,r%root_net_growth_rate,r%stem_net_growth_rate, &
       r%storage_net_growth_rate,r%leaf_growth_rate,r%leaf_stress_death_rate,r%leaf_age_increment, &
       r%youngest_specific_leaf_area,r%lai_exponential_growth_rate,r%relative_transpiration_used]
    v=all(ieee_is_finite(x)); if(.not.v)return
    v=r%temperature_sum_increment>=0.and.r%development_rate>=0.and.r%leaf_growth_rate>=0.and. &
      r%leaf_stress_death_rate>=0.and.r%leaf_age_increment>=0.and.r%youngest_specific_leaf_area>=0.and. &
      r%lai_exponential_growth_rate>=0.and.r%relative_transpiration_used>=0.and.r%relative_transpiration_used<=1
  end function
end module mod_wofost81_rate_correction
