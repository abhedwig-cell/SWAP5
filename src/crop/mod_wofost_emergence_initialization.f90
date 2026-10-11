module mod_wofost_emergence_initialization
  use iso_fortran_env, only: real64
  use ieee_arithmetic, only: ieee_is_finite
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  implicit none
  private
  integer, parameter, public :: WOFOST_EMERGENCE_INIT_OK=0, WOFOST_EMERGENCE_INIT_INVALID=1
  public :: initialize_wofost_emergence_owner
contains
  ! Stateless construction of the existing physical owner. B111
  ! initialize_wofost arithmetic order is preserved; no physical publication.
  subroutine initialize_wofost_emergence_owner(tdwi,parameters,owner,status)
    real(real64), intent(in) :: tdwi
    type(wofost_rate_parameter_bundle_t), intent(in) :: parameters
    type(wofost_crop_owner_state_t), intent(out) :: owner
    integer, intent(out) :: status
    type(wofost_crop_owner_state_t) :: candidate
    real(real64) :: fr,fl,fs,fo,sla,tadw
    integer :: s
    owner=wofost_crop_owner_state_t();status=WOFOST_EMERGENCE_INIT_INVALID
    if(.not.ieee_is_finite(tdwi)) return
    if(tdwi<0.0_real64.or.tdwi>10000.0_real64.or..not.parameters%ready()) return
    call parameters%evaluate_specific_leaf_area(0.0_real64,sla,s)
    if(s/=WOFOST_RATE_PARAMETER_OK) return
    call parameters%evaluate_root_partition_fraction(0.0_real64,fr,s)
    if(s/=WOFOST_RATE_PARAMETER_OK) return
    call parameters%evaluate_leaf_partition_fraction(0.0_real64,fl,s)
    if(s/=WOFOST_RATE_PARAMETER_OK) return
    call parameters%evaluate_stem_partition_fraction(0.0_real64,fs,s)
    if(s/=WOFOST_RATE_PARAMETER_OK) return
    call parameters%evaluate_storage_partition_fraction(0.0_real64,fo,s)
    if(s/=WOFOST_RATE_PARAMETER_OK) return
    if(.not.all(ieee_is_finite([fr,fl,fs,fo,sla]))) return
    if(any([fr,fl,fs,fo]<0.0_real64).or.any([fr,fl,fs,fo]>1.0_real64).or.sla<0.0_real64) return
    if(abs(fl+fs+fo-1.0_real64)>64.0_real64*epsilon(1.0_real64)) return
    candidate%crop_emerged=.true.;candidate%development_stage=0.0_real64
    allocate(candidate%biomass,candidate%evolution_continuation)
    ! Saturated-LAI carryover belongs to subsequent structural evolution.
    ! No carryover exists at emergence; retain the existing optional absence.
    allocate(candidate%biomass%leaf_biomass(1),candidate%biomass%specific_leaf_area(1), &
         candidate%biomass%leaf_age(1))
    candidate%biomass%root_biomass=fr*tdwi
    tadw=(1.0_real64-fr)*tdwi
    candidate%biomass%stem_biomass=fs*tadw
    candidate%biomass%leaf_biomass(1)=fl*tadw
    candidate%biomass%storage_biomass=fo*tadw
    candidate%biomass%specific_leaf_area(1)=sla
    candidate%biomass%leaf_age(1)=0.0_real64
    candidate%biomass%exponential_leaf_area_index=candidate%biomass%leaf_biomass(1)*sla
    if(candidate%validate()/=WOFOST_CROP_OWNER_OK) return
    owner=candidate;status=WOFOST_EMERGENCE_INIT_OK
  end subroutine
end module
