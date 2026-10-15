module mod_soil_n_profile_temperature
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::N_PROFILE_OK=0,N_PROFILE_INVALID=1,N_PROFILE_EMPTY=2
 public::soil_n_profile_temperature
contains
 ! Literal ordered strict-depth selection from B111 management_soil, 361–374.
 ! A rejected layer does not end the loop. This is not a partial-layer average.
 pure subroutine soil_n_profile_temperature(dz_cm,temperature_c,depth_m,temperature,selected_depth,status)
  real(real64),intent(in)::dz_cm(:),temperature_c(:),depth_m
  real(real64),intent(out)::temperature,selected_depth
  integer,intent(out)::status
  real(real64)::weighted
  integer::i
  temperature=0d0;selected_depth=0d0;weighted=0d0;status=N_PROFILE_INVALID
  if(size(dz_cm)<1.or.size(dz_cm)>100000.or.size(dz_cm)/=size(temperature_c))return
  if(.not.ieee_is_finite(depth_m))return
  if(depth_m<=0d0.or.depth_m>1d4)return
  if(.not.all(ieee_is_finite(dz_cm)).or..not.all(ieee_is_finite(temperature_c)))return
  if(any(dz_cm<=0d0).or.any(dz_cm>1d6).or.any(abs(temperature_c)>1d3))return
  do i=1,size(dz_cm)
   if(selected_depth+1d-2*dz_cm(i)<depth_m)then
    selected_depth=selected_depth+1d-2*dz_cm(i)
    weighted=weighted+temperature_c(i)*1d-2*dz_cm(i)
   end if
  end do
  status=N_PROFILE_EMPTY;if(selected_depth==0d0)return
  temperature=weighted/selected_depth;status=N_PROFILE_OK
 end subroutine
end module
