module mod_bartholomeus_microbial
   use iso_fortran_env, only : real64
   implicit none
   private
   public :: bartholomeus_microbial_respiration

contains
   pure function bartholomeus_microbial_respiration(soil_temp_k,percent_org_mat,soil_density, &
                                                     percent_sand,matric_potential_pa, &
                                                     specific_resp_humus,q10_microbial) result(r)
      real(real64), intent(in) :: soil_temp_k,percent_org_mat,soil_density,percent_sand
      real(real64), intent(in) :: matric_potential_pa,specific_resp_humus,q10_microbial
      real(real64) :: r
      real(real64) :: fmoist, carbon, psat
      real(real64), parameter :: h1=25000.0_real64, h2=762500.0_real64, h3=1500000.0_real64

      carbon = 0.48_real64*(0.01_real64*percent_org_mat)*soil_density
      psat = (10.0_real64**(-0.0131_real64*percent_sand+1.88_real64))*100.0_real64

      if (matric_potential_pa < psat) then
         fmoist = 0.5_real64
      else if (matric_potential_pa < h1) then
         fmoist = 1.0_real64 - 0.5_real64*((log10(h1)-log10(matric_potential_pa))/ &
                                           (log10(h1)-log10(psat)))
      else if (matric_potential_pa <= h2) then
         fmoist = 1.0_real64
      else if (matric_potential_pa <= h3) then
         fmoist = 1.0_real64-(log10(matric_potential_pa)-log10(h2))/(log10(h3)-log10(h2))
      else
         fmoist = 0.0_real64
      end if

      r = specific_resp_humus*carbon*(q10_microbial**(0.1_real64*(soil_temp_k-298.0_real64)))*fmoist
   end function
end module mod_bartholomeus_microbial
