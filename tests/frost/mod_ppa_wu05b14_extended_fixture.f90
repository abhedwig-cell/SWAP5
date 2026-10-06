module mod_ppa_wu05b14_extended_fixture
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_drainage_response_binding,only:fmr_drainage_response_level_parameters_t, &
      fmr_drainage_response_level_control_t,FMR_DRAIN_VARIANT_EXTENDED_SIGNED
 use mod_drainage_extended_exchange,only:EXT_DRAIN_TUBE,EXT_DRAIN_OPEN_CHANNEL,EXT_DRAIN_TOP_NONE
 implicit none
 private
 public::setup_b14_levels,b14_extended_rate_oracle,b14_initial_heads,b14_kind
contains
 pure integer function b14_kind(configuration) result(k)
  integer,intent(in)::configuration
  k=EXT_DRAIN_TUBE
  if(configuration>2)k=EXT_DRAIN_OPEN_CHANNEL
 end function
 pure function b14_initial_heads(configuration,low_air) result(heads)
  integer,intent(in)::configuration
  logical,intent(in)::low_air
  real(real64)::heads(2)
  heads=[-3._real64,-4._real64]
  if(low_air)heads(2)=-3._real64
  if(mod(configuration,2)==0)then
   heads(2)=-1._real64
   if(low_air)heads(2)=0._real64
  end if
 end function
 pure real(real64) function b14_extended_rate_oracle(kind,gwl,pond,head,bottom) result(q)
  integer,intent(in)::kind
  real(real64),intent(in)::gwl,pond,head,bottom
  real(real64)::level,effective,resistance,entry,wet,depth
  q=0._real64
  if(.not.(head<1000._real64.or.gwl<1000._real64))return
  if(.not.(gwl>bottom+.001_real64.or.head>bottom+.001_real64))return
  level=bottom
  if(head>bottom+.001_real64)level=head
  effective=gwl-level
  if(gwl>-.1_real64)effective=effective+pond
  if(effective<0._real64.and.gwl<bottom-100._real64)effective=bottom-100._real64-level
  resistance=200._real64;entry=.2_real64
  if(effective<=0._real64)then
   resistance=300._real64;entry=.4_real64
  end if
  if(kind==EXT_DRAIN_OPEN_CHANNEL)then
   wet=12._real64
   if(head>bottom+.001_real64)then
    depth=head-bottom
    wet=wet+2._real64*depth*sqrt(1._real64+1._real64/4._real64)
   end if
   resistance=resistance+entry*200._real64/wet
  end if
  q=effective/resistance
 end function
 subroutine setup_b14_levels(configuration,heads,bottom,levels,controls)
  integer,intent(in)::configuration
  real(real64),intent(in)::heads(2),bottom
  type(fmr_drainage_response_level_parameters_t),allocatable,intent(out)::levels(:)
  type(fmr_drainage_response_level_control_t),allocatable,intent(out)::controls(:)
  allocate(levels(1),controls(1))
  levels(1)%variant=FMR_DRAIN_VARIANT_EXTENDED_SIGNED
  levels(1)%extended%zbotdr_cm=bottom
  levels(1)%extended%drain_type=b14_kind(configuration)
  levels(1)%extended%spacing_cm=200._real64
  levels(1)%extended%rdrain_day=200._real64
  levels(1)%extended%rinfi_day=300._real64
  levels(1)%extended%rentry_day=.2_real64
  levels(1)%extended%rexit_day=.4_real64
  levels(1)%extended%gwlinf_cm=bottom-100._real64
  levels(1)%extended%pondmx_cm=1000._real64
  levels(1)%extended%highest_level=.false.
  levels(1)%extended%highest_surface_mode=EXT_DRAIN_TOP_NONE
  levels(1)%extended%width_cm=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%extended%talud=ieee_value(0._real64,ieee_quiet_nan)
  if(b14_kind(configuration)==EXT_DRAIN_OPEN_CHANNEL)then
   levels(1)%extended%width_cm=12._real64
   levels(1)%extended%talud=2._real64
  end if
  levels(1)%extended%rsurfdeep_day=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%extended%rsurfshallow_day=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%extended%interflow_coefficient=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%extended%interflow_exponent=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%linear%drainage_resistance=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%empirical%coefficient=ieee_value(0._real64,ieee_quiet_nan)
  levels(1)%empirical%exponent=ieee_value(0._real64,ieee_quiet_nan)
  controls(1)%resolved_surface_water_head_supplied=.true.
  controls(1)%resolved_surface_water_head_cm=heads(2)
  controls(1)%drain_head=ieee_value(0._real64,ieee_quiet_nan)
 end subroutine
end module

