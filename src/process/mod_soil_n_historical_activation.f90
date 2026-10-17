! Explicit historical Soil-N selector boundary; no new state owner or implicit defaults.
module mod_soil_n_historical_activation
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_reactive_owner,only:reactive_parameters_t,reactive_state_t, &
   reactive_parameters_valid,initialize_reactive
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_b111_soil_n_mineral_owner,only:MINERAL_OK
 implicit none
 private
 integer,parameter,public::N_ACTIVATION_OK=0,N_ACTIVATION_INVALID=1,N_ACTIVATION_UNSUPPORTED=2
 type,public::soil_n_historical_selection_t
   integer::swcropsnm=-1
   integer::sw_wofost=-1
   logical::source_parameters_complete=.false.
 end type
 public::activate_soil_n_historical
contains
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
