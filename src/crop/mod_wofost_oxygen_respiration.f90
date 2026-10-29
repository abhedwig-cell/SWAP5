! Source assimilation() oxygen respiration publication, before water stress.
! The existing WOFOST owner/view and prepared assimilation remain authoritative.
module mod_wofost_oxygen_respiration
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_wofost_rate_parameters,only:wofost_rate_parameter_bundle_t,wofost_rate_scalar_parameters_t
 use mod_wofost_one_day_rate_state_view,only:wofost_one_day_rate_state_view_t,WOFOST_RATE_STATE_VIEW_OK
 use mod_wofost_prepare_assimilation,only:wofost_prepare_assimilation_result_t
 implicit none
 private
 integer,parameter,public::WOFOST_OXYGEN_RESPIRATION_OK=0,WOFOST_OXYGEN_RESPIRATION_INVALID=1
 type,public::wofost_oxygen_respiration_t
  real(real64)::root_q10=0d0,root_maintenance_coefficient=0d0,senescence_factor=0d0,maximum_respiration_factor=0d0
 end type
 public::prepare_wofost_oxygen_respiration
contains
 subroutine prepare_wofost_oxygen_respiration(view,parameters,assimilation,average_temperature_c, &
      regrowth_delay_days,result,status)
  type(wofost_one_day_rate_state_view_t),intent(in)::view
  type(wofost_rate_parameter_bundle_t),intent(in)::parameters
  type(wofost_prepare_assimilation_result_t),intent(in)::assimilation
  real(real64),intent(in)::average_temperature_c
  integer,intent(in)::regrowth_delay_days
  type(wofost_oxygen_respiration_t),intent(out)::result
  integer,intent(out)::status
  type(wofost_rate_scalar_parameters_t)::s
  type(wofost_oxygen_respiration_t)::candidate
  real(real64)::rmres,teff,mres,asrc,fr,fl,fs,fo,help,cvf,froots,rg_roots,rm_roots,pgass
  integer::code
  result=wofost_oxygen_respiration_t();status=WOFOST_OXYGEN_RESPIRATION_INVALID
  if(view%validate()/=WOFOST_RATE_STATE_VIEW_OK.or..not.parameters%ready())return
  if(.not.ieee_is_finite(average_temperature_c).or..not.ieee_is_finite(assimilation%actual_pgass))return
  if(average_temperature_c< -100d0.or.average_temperature_c>100d0.or.assimilation%actual_pgass<0d0)return
  if(regrowth_delay_days<0)return
  s=parameters%scalar_view()
  if(.not.s%grass_development.and.regrowth_delay_days/=0)return
  candidate%root_q10=s%respiration_temperature_q10
  candidate%root_maintenance_coefficient=s%maintenance_respiration_root*32d0/30d0
  call parameters%evaluate_maintenance_respiration_factor(view%development_stage,candidate%senescence_factor,code)
  if(code/=0)return
  candidate%maximum_respiration_factor=1d0
  if(.not.(s%grass_development.and.regrowth_delay_days>0))then
   pgass=assimilation%actual_pgass
   rmres=(s%maintenance_respiration_root*view%actual_root_biomass+ &
     s%maintenance_respiration_leaf*view%living_leaf_biomass+ &
     s%maintenance_respiration_stem*view%actual_stem_biomass+ &
     s%maintenance_respiration_storage*view%actual_storage_biomass)*candidate%senescence_factor
   teff=s%respiration_temperature_q10**((average_temperature_c-25d0)/10d0)
   mres=min(pgass,rmres*teff);asrc=pgass-mres
   call parameters%evaluate_root_partition_fraction(view%development_stage,fr,code)
   if(code/=0)return
   call parameters%evaluate_leaf_partition_fraction(view%development_stage,fl,code)
   if(code/=0)return
   call parameters%evaluate_stem_partition_fraction(view%development_stage,fs,code)
   if(code/=0)return
   call parameters%evaluate_storage_partition_fraction(view%development_stage,fo,code)
   if(code/=0)return
   help=0d0
   if(s%conversion_efficiency_storage>0d0)help=fo/s%conversion_efficiency_storage
   cvf=(fl/s%conversion_efficiency_leaf+fs/s%conversion_efficiency_stem+help)*(1d0-fr)+fr/s%conversion_efficiency_root
   if(cvf<=0d0)return
   cvf=1d0/cvf
   froots=(fr/s%conversion_efficiency_root)*cvf
   rg_roots=froots*(1d0-cvf)*asrc
   rm_roots=min(froots*(1d0-cvf)*pgass, &
     s%maintenance_respiration_root*view%actual_root_biomass*candidate%senescence_factor*teff)
   if(rm_roots>0d0)candidate%maximum_respiration_factor=(rg_roots+rm_roots)/rm_roots
  end if
  if(.not.all(ieee_is_finite([candidate%root_q10,candidate%root_maintenance_coefficient, &
    candidate%senescence_factor,candidate%maximum_respiration_factor])))return
  result=candidate;status=WOFOST_OXYGEN_RESPIRATION_OK
 end subroutine
end module
