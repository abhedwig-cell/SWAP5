! Single-worker research bridge: capture actual native heat inputs before water trial.
module mod_native_feedback_context
 use iso_fortran_env,only:real64
 use mod_soil_temperature_contract
 implicit none
 type,public::native_feedback_context_t
  logical::ready=.false.
  real(real64)::t0=0d0,t1=0d0
  type(soil_temperature_parameters_t)::parameters
  type(soil_temperature_numerical_config_t)::numerical
  type(soil_temperature_forcing_t)::forcing
  real(real64),allocatable::matrix_temperature(:)
 end type
 type(native_feedback_context_t),save,public::native_feedback_context
 public::capture_native_feedback_context
contains
 subroutine capture_native_feedback_context(p,num,f,state,t0,t1)
  type(soil_temperature_parameters_t),intent(in)::p
  type(soil_temperature_numerical_config_t),intent(in)::num
  type(soil_temperature_forcing_t),intent(in)::f
  type(soil_temperature_state_t),intent(in)::state
  real(real64),intent(in)::t0,t1
  integer::status
  native_feedback_context%ready=.false.
  call copy_soil_temperature_profile(state,native_feedback_context%matrix_temperature,status)
  if(status/=SOIL_TEMP_OK)return
  native_feedback_context%parameters=p;native_feedback_context%numerical=num;native_feedback_context%forcing=f
  native_feedback_context%t0=t0;native_feedback_context%t1=t1;native_feedback_context%ready=.true.
 end subroutine
end module
