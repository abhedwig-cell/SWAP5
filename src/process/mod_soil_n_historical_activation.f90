! Explicit historical Soil-N selector boundary; no new state owner or implicit defaults.
module mod_soil_n_historical_activation
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t,reactive_state_t, &
   reactive_parameters_valid,initialize_reactive
 use mod_soil_n_pool_state,only:soil_n_pool_state_t,initialize_soil_n_pool_state,SOIL_N_OK
 use mod_b111_soil_n_storage_conversion,only:b111_soil_n_mass_from_concentrations,B111_NSTORE_OK
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 implicit none
 private
 integer,parameter,public::N_ACTIVATION_OK=0,N_ACTIVATION_INVALID=1,N_ACTIVATION_UNSUPPORTED=2
 type,public::soil_n_historical_selection_t
   integer::swcropsnm=-1
   integer::sw_wofost=-1
   logical::source_parameters_complete=.false.
 end type
 type,public::soil_n_historical_initial_t
   real(real64)::fom_kg_m3(8)=0d0,bio_kg_m3=0d0,hum_kg_m3=0d0
   real(real64)::cnh4_kg_m3=0d0,cno3_kg_m3=0d0
 end type
 type,public::soil_n_historical_rates_t
   real(real64)::temp_ref=0d0,sorpcoef=0d0,ratecon_nitrif_ref=0d0,ratecon_denitr_ref=0d0
   real(real64)::wfpscrit=0d0,wfpscrit2=0d0,cdissi_half=0d0
   real(real64)::tcsf_n=0d0,lai_crit_nupt=0d0,depth_m=0d0
   real(real64)::nh4_lat=0d0,no3_lat=0d0,nh4_seep=0d0,no3_seep=0d0,nh4_top=0d0,no3_top=0d0
 end type
 public::activate_soil_n_historical,build_historical_soil_n_inventory,bind_historical_soil_n_rates
 public::initialize_historical_soil_n_complete,bind_historical_organic_source_profile
contains
 ! SWAP 4.3.1 wofost_soil_parameters.f90 lines 18-61, executable
 ! source archive SWAP431_B111_AUTHORITY; no fixture/default inference.
 subroutine bind_historical_organic_source_profile(template,parameter,status)
   type(reactive_parameters_t),intent(in)::template
   type(reactive_parameters_t),intent(out)::parameter
   integer,intent(out)::status
   real(real64),parameter::year=365.2425d0,asfa_min=.04d0,asfa_max=.28d0
   real(real64),parameter::asfa(8)=[asfa_min,asfa_min,asfa_max,asfa_max, &
                                    asfa_min,asfa_min,asfa_max,asfa_max]
   parameter=reactive_parameters_t();status=N_ACTIVATION_INVALID
   if(.not.reactive_parameters_valid(template))return
   parameter=template
   parameter%mineral%inventory%nfrac_fom=[.06d0,.002d0,.06d0,.002d0, &
                                            .06d0,.002d0,.06d0,.002d0]
   parameter%mineral%inventory%nfrac_biomass=.58d0/10d0
   parameter%mineral%inventory%nfrac_humus=.58d0/14d0
   parameter%organic_reference%ratecon_fom=[3d0/year,3d0/year,3d0/year,3d0/year, &
       .3d0/year,.3d0/year,.3d0/year,.3d0/year]
   parameter%organic_reference%ratecon_bio=.66d0/year
   parameter%organic_reference%ratecon_hum=.02d0/year
   parameter%organic_reference%asfa_fom_bio=asfa*.46d0
   parameter%organic_reference%asfa_fom_hum=asfa*.54d0
   parameter%organic_reference%asfa_bio=.46d0*.2d0
   parameter%organic_reference%asfa_hum=.54d0*.2d0
   parameter%cfrac_fom=[.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0,.45d0]
   parameter%cfrac_biomass=.58d0;parameter%cfrac_humus=.58d0
   if(.not.reactive_parameters_valid(parameter))then
      parameter=reactive_parameters_t();return
   end if
   status=N_ACTIVATION_OK
 end subroutine
 subroutine initialize_historical_soil_n_complete(selection,rates,initial,template,id,clock,wfrac, &
       owner,parameters,tcsf,lai,status)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(soil_n_historical_rates_t),intent(in)::rates
   type(soil_n_historical_initial_t),intent(in)::initial
   type(reactive_parameters_t),intent(in)::template
   integer(int64),intent(in)::id
   real(real64),intent(in)::clock,wfrac
   type(reactive_state_t),intent(out)::owner
   type(reactive_parameters_t),intent(out)::parameters
   real(real64),intent(out)::tcsf,lai
   integer,intent(out)::status
   type(soil_n_pool_state_t)::pools
   integer::code
   owner=reactive_state_t();parameters=reactive_parameters_t()
   tcsf=0d0;lai=0d0;status=N_ACTIVATION_UNSUPPORTED
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1)return
   status=N_ACTIVATION_INVALID
   if(.not.selection%source_parameters_complete)return
   call bind_historical_soil_n_rates(rates,template,parameters,tcsf,lai,code)
   if(code/=N_ACTIVATION_OK)goto 900
   call build_historical_soil_n_inventory(initial,parameters,wfrac,pools,code)
   if(code/=N_ACTIVATION_OK)goto 900
   call activate_soil_n_historical(selection,parameters,pools,id,clock,wfrac,owner,code)
   if(code/=N_ACTIVATION_OK)goto 900
   status=N_ACTIVATION_OK
   return
900 continue
   owner=reactive_state_t();parameters=reactive_parameters_t()
   tcsf=0d0;lai=0d0
 end subroutine
 subroutine bind_historical_soil_n_rates(source,template,parameter,root_tcsf,lai_crit,status)
   type(soil_n_historical_rates_t),intent(in)::source
   type(reactive_parameters_t),intent(in)::template
   type(reactive_parameters_t),intent(out)::parameter
   real(real64),intent(out)::root_tcsf,lai_crit
   integer,intent(out)::status
   real(real64)::v(16)
   parameter=reactive_parameters_t();root_tcsf=0d0;lai_crit=0d0;status=N_ACTIVATION_INVALID
   v=[source%temp_ref,source%sorpcoef,source%ratecon_nitrif_ref,source%ratecon_denitr_ref, &
     source%wfpscrit,source%wfpscrit2,source%cdissi_half,source%tcsf_n,source%lai_crit_nupt, &
     source%depth_m,source%nh4_lat,source%no3_lat,source%nh4_seep,source%no3_seep,source%nh4_top,source%no3_top]
   if(.not.all(ieee_is_finite(v)).or.any(v<0d0))return
   if(source%temp_ref>60d0.or.source%sorpcoef>1d0)return
   if(source%ratecon_nitrif_ref>1d0.or.source%ratecon_denitr_ref>1d0)return
   if(source%wfpscrit<.05d0.or.source%wfpscrit>.95d0.or.source%wfpscrit2>.95d0)return
   if(source%cdissi_half>1000d0.or.source%tcsf_n>1d0.or.source%lai_crit_nupt>10d0)return
   if(source%depth_m<1d-3.or.source%depth_m>100d0)return
   if(any(v(11:16)>1d6))return
   ! Top concentrations bind to the same immutable mineral owner. Only an
   ! explicitly admitted accepted-water surface route may deliver their flux.
   if(.not.reactive_parameters_valid(template))return
   if(abs(template%mineral%inventory%depth_m-source%depth_m)>1d-12)return
   parameter=template
   parameter%mineral%sorption=source%sorpcoef
   parameter%mineral%c_lateral=[source%nh4_lat,source%no3_lat]
   parameter%mineral%c_bottom=[source%nh4_seep,source%no3_seep]
   parameter%mineral%c_top=[source%nh4_top,source%no3_top]
   parameter%environment%temperature_reference_c=source%temp_ref
   parameter%environment%nitrification_ref_per_day=source%ratecon_nitrif_ref
   parameter%environment%denitrification_ref_per_day=source%ratecon_denitr_ref
   parameter%wfpscrit=source%wfpscrit
   parameter%environment%wfpscrit2=source%wfpscrit2
   parameter%environment%cdissi_half_kg_m2=source%cdissi_half
   if(.not.reactive_parameters_valid(parameter))then
     parameter=reactive_parameters_t()
     return
   end if
   root_tcsf=source%tcsf_n;lai_crit=source%lai_crit_nupt;status=N_ACTIVATION_OK
 end subroutine
 subroutine build_historical_soil_n_inventory(source,p,wfrac,pools,status)
   type(soil_n_historical_initial_t),intent(in)::source
   type(reactive_parameters_t),intent(in)::p
   real(real64),intent(in)::wfrac
   type(soil_n_pool_state_t),intent(out)::pools
   integer,intent(out)::status
   real(real64)::nh4,no3
   integer::code
   pools=soil_n_pool_state_t();status=N_ACTIVATION_INVALID
   if(.not.reactive_parameters_valid(p))return
   if(size(p%mineral%inventory%nfrac_fom)/=8)return
   if(.not.ieee_is_finite(wfrac))return
   if(.not.all(ieee_is_finite([source%fom_kg_m3,source%bio_kg_m3,source%hum_kg_m3, &
      source%cnh4_kg_m3,source%cno3_kg_m3])))return
   if(minval(source%fom_kg_m3)<0d0.or.min(source%bio_kg_m3,source%hum_kg_m3, &
       source%cnh4_kg_m3,source%cno3_kg_m3)<0d0)return
   if(maxval(source%fom_kg_m3)>1000d0.or.max(source%bio_kg_m3,source%hum_kg_m3, &
       source%cnh4_kg_m3,source%cno3_kg_m3)>1000d0)return
   call b111_soil_n_mass_from_concentrations(p%mineral%inventory%depth_m,wfrac, &
      p%mineral%drybd,p%mineral%sorption,source%cnh4_kg_m3,source%cno3_kg_m3,nh4,no3,code)
   if(code/=B111_NSTORE_OK)return
   call initialize_soil_n_pool_state(p%mineral%inventory,source%fom_kg_m3,source%bio_kg_m3, &
      source%hum_kg_m3,nh4,no3,pools,code)
   if(code/=SOIL_N_OK)then
     pools=soil_n_pool_state_t()
     return
   end if
   status=N_ACTIVATION_OK
 end subroutine
 subroutine activate_soil_n_historical(selection,parameters,pools,identity,clock,theta,owner,status)
   type(soil_n_historical_selection_t),intent(in)::selection
   type(reactive_parameters_t),intent(in)::parameters
   type(soil_n_pool_state_t),intent(in)::pools
   integer(int64),intent(in)::identity
   real(real64),intent(in)::clock,theta
   type(reactive_state_t),intent(out)::owner
   integer,intent(out)::status
   integer::code
   owner=reactive_state_t()
   status=N_ACTIVATION_UNSUPPORTED
   ! This is an opt-in source profile, never a replacement for standard WOFOST81.
   if(selection%swcropsnm/=1.or.selection%sw_wofost/=1)return
   status=N_ACTIVATION_INVALID
   ! An incomplete historical project must not acquire arbitrary fixture defaults.
   if(.not.selection%source_parameters_complete)return
   if(.not.parameters%enabled.or..not.reactive_parameters_valid(parameters))return
   if(.not.ieee_is_finite(clock).or..not.ieee_is_finite(theta))return
   if(identity<=0_int64.or.identity>100000000_int64)return
   call initialize_reactive(parameters,identity,clock,theta,pools,owner,code)
   if(code/=MINERAL_OK)then
     owner=reactive_state_t()
     return
   end if
   status=N_ACTIVATION_OK
 end subroutine
end module
