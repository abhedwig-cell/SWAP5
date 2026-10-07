module mod_soil_n_reaction_transfer
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_is_finite
 use mod_soil_n_pool_state, only: soil_n_transfer_t
 implicit none
 private
 integer,parameter,public::SOIL_N_REACTION_OK=0,SOIL_N_REACTION_INVALID=1
 public::build_nitrification_transfer,build_denitrification_transfer
contains
 subroutine build_nitrification_transfer(nitrified,transfer,status)
  real(real64),intent(in)::nitrified(:)
  type(soil_n_transfer_t),intent(out)::transfer
  integer,intent(out)::status
  integer::n
  transfer=soil_n_transfer_t();status=SOIL_N_REACTION_INVALID
  n=size(nitrified);if(n<1)return
  if(.not.all(ieee_is_finite(nitrified)).or.any(nitrified<0d0))return
  allocate(transfer%ammonium_delta(n),transfer%nitrate_delta(n), &
           transfer%organic_fast_delta(n),transfer%organic_slow_delta(n))
  transfer%ammonium_delta=-nitrified
  transfer%nitrate_delta=nitrified
  transfer%organic_fast_delta=0d0;transfer%organic_slow_delta=0d0
  status=SOIL_N_REACTION_OK
 end subroutine
 subroutine build_denitrification_transfer(denitrified,transfer,status)
  real(real64),intent(in)::denitrified(:)
  type(soil_n_transfer_t),intent(out)::transfer
  integer,intent(out)::status
  integer::n
  transfer=soil_n_transfer_t();status=SOIL_N_REACTION_INVALID
  n=size(denitrified);if(n<1)return
  if(.not.all(ieee_is_finite(denitrified)).or.any(denitrified<0d0))return
  allocate(transfer%ammonium_delta(n),transfer%nitrate_delta(n), &
           transfer%organic_fast_delta(n),transfer%organic_slow_delta(n))
  transfer%ammonium_delta=0d0
  transfer%nitrate_delta=-denitrified
  transfer%organic_fast_delta=0d0;transfer%organic_slow_delta=0d0
  transfer%external_output=sum(denitrified)
  status=SOIL_N_REACTION_OK
 end subroutine
end module
