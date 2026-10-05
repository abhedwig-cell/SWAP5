module mod_ppa_wu05b13_empirical_fixture
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_drainage_response_binding,only:fmr_drainage_response_level_parameters_t, &
      fmr_drainage_response_level_control_t,FMR_DRAIN_VARIANT_LINEAR,FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW
 implicit none
 private
 public::setup_b13_levels,b13_empirical_rate_oracle,b13_exponent,b13_level_count
contains
 pure integer function b13_level_count(configuration) result(n)
  integer,intent(in)::configuration
  n=1
  if(configuration>3)n=2
 end function
 pure real(real64) function b13_exponent(configuration) result(p)
  integer,intent(in)::configuration
  real(real64),parameter::powers(3)=[.1_real64,.5_real64,1._real64]
  p=powers(mod(configuration-1,3)+1)
 end function
 pure real(real64) function b13_empirical_rate_oracle(c,p,gwl,head) result(q)
  real(real64),intent(in)::c,p,gwl,head
  q=0._real64
  if(gwl>head)q=c*(gwl-head)**p
 end function
 subroutine setup_b13_levels(configuration,heads,levels,controls)
  integer,intent(in)::configuration
  real(real64),intent(in)::heads(2)
  type(fmr_drainage_response_level_parameters_t),allocatable,intent(out)::levels(:)
  type(fmr_drainage_response_level_control_t),allocatable,intent(out)::controls(:)
  integer::n
  n=b13_level_count(configuration);allocate(levels(n),controls(n))
  levels(n)%variant=FMR_DRAIN_VARIANT_EMPIRICAL_INTERFLOW
  levels(n)%empirical%coefficient=.01_real64
  levels(n)%empirical%exponent=b13_exponent(configuration)
  levels(n)%linear%drainage_resistance=ieee_value(0._real64,ieee_quiet_nan)
  controls(n)%drain_head_supplied=.true.;controls(n)%drain_head=heads(2)
  if(n==2)then
   levels(1)%variant=FMR_DRAIN_VARIANT_LINEAR
   levels(1)%linear%drainage_resistance=200._real64
   levels(1)%empirical%coefficient=ieee_value(0._real64,ieee_quiet_nan)
   levels(1)%empirical%exponent=ieee_value(0._real64,ieee_quiet_nan)
   controls(1)%drain_head_supplied=.true.;controls(1)%drain_head=heads(1)
  end if
 end subroutine
end module
