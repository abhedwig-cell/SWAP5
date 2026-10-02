module mod_bartholomeus_waterfilm
   use iso_fortran_env, only : real64
   implicit none
   private
   public :: BartholomeusWaterfilmMvgInput
   public :: bartholomeus_waterfilm_mvg_integrand
   public :: bartholomeus_waterfilm_from_length_density

   real(real64), parameter :: PI = 3.14159265358979323846_real64

   type :: BartholomeusWaterfilmMvgInput
      real(real64) :: capac_term
      real(real64) :: n_minus_1
      real(real64) :: m_plus_1
      real(real64) :: alpha_per_pa
      real(real64) :: gen_n
      real(real64) :: surface_tension_water
   end type BartholomeusWaterfilmMvgInput

contains

   pure function bartholomeus_waterfilm_mvg_integrand(x,p) result(v)
      real(real64), intent(in) :: x
      type(BartholomeusWaterfilmMvgInput), intent(in) :: p
      real(real64) :: v, ax, axn

      ax = p%alpha_per_pa*x
      axn = ax**p%gen_n
      v = p%capac_term*ax**p%n_minus_1*(1.0_real64+axn)**(-p%m_plus_1) / &
          (4.0_real64*PI*p%surface_tension_water**2/x**2)
   end function

   pure function bartholomeus_waterfilm_from_length_density(length_density,matric_potential_pa, &
                                                             surface_tension_water) result(thickness)
      real(real64), intent(in) :: length_density,matric_potential_pa,surface_tension_water
      real(real64) :: thickness

      if (matric_potential_pa > 1.0e7_real64) then
         thickness = 1.0e-8_real64
      else if (length_density <= 0.0_real64 .or. matric_potential_pa <= 0.0_real64) then
         thickness = huge(1.0_real64)
      else
         thickness = 2.0_real64*(sqrt(1.0_real64/(PI*length_density)) - &
                                  2.0_real64*surface_tension_water/matric_potential_pa)
      end if
   end function

end module mod_bartholomeus_waterfilm
