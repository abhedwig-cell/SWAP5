module mod_soil_n_reaction_transfer
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_pool_state,only:soil_n_transfer_t
 implicit none
 private
 integer,parameter,public::SOIL_N_REACTION_OK=0,SOIL_N_REACTION_INVALID=1
 public::build_nitrification_transfer,build_denitrification_transfer
contains
 subroutine base_transfer(nf,t)
  integer,intent(in)::nf;type(soil_n_transfer_t),intent(out)::t
  t=soil_n_transfer_t();allocate(t%fom_delta_kg_m3(nf));t%fom_delta_kg_m3=0d0
 end subroutine
 subroutine build_nitrification_transfer(nf,nitrified_n_kg_m2,transfer,status)
  integer,intent(in)::nf;real(real64),intent(in)::nitrified_n_kg_m2
  type(soil_n_transfer_t),intent(out)::transfer;integer,intent(out)::status
  call base_transfer(nf,transfer);status=SOIL_N_REACTION_INVALID
  if(nf<1.or..not.ieee_is_finite(nitrified_n_kg_m2).or.nitrified_n_kg_m2<0d0)return
  transfer%ammonium_n_delta_kg_m2=-nitrified_n_kg_m2
  transfer%nitrate_n_delta_kg_m2=nitrified_n_kg_m2
  status=SOIL_N_REACTION_OK
 end subroutine
 subroutine build_denitrification_transfer(nf,denitrified_n_kg_m2,transfer,status)
  integer,intent(in)::nf;real(real64),intent(in)::denitrified_n_kg_m2
  type(soil_n_transfer_t),intent(out)::transfer;integer,intent(out)::status
  call base_transfer(nf,transfer);status=SOIL_N_REACTION_INVALID
  if(nf<1.or..not.ieee_is_finite(denitrified_n_kg_m2).or.denitrified_n_kg_m2<0d0)return
  transfer%nitrate_n_delta_kg_m2=-denitrified_n_kg_m2
  transfer%external_n_output_kg_m2=denitrified_n_kg_m2
  status=SOIL_N_REACTION_OK
 end subroutine
end module
