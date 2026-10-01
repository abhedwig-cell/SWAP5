module mod_bartholomeus_waterfilm_independent
   use iso_fortran_env, only : real64
   use mod_bartholomeus_waterfilm, only : BartholomeusWaterfilmMvgInput, &
                                           bartholomeus_waterfilm_mvg_integrand, &
                                           bartholomeus_waterfilm_from_length_density
   implicit none
   private
   public :: bartholomeus_waterfilm_mvg_independent

contains

   pure function bartholomeus_waterfilm_mvg_independent(matric_potential_pa,p,ok) result(thickness)
      real(real64), intent(in) :: matric_potential_pa
      type(BartholomeusWaterfilmMvgInput), intent(in) :: p
      logical, intent(out) :: ok
      real(real64) :: thickness
      real(real64) :: integral, previous
      integer :: level

      ok = .false.
      if (matric_potential_pa <= 0.0_real64 .or. p%surface_tension_water <= 0.0_real64) then
         thickness = huge(1.0_real64)
         return
      end if
      if (matric_potential_pa > 1.0e7_real64) then
         thickness = 1.0e-8_real64
         ok = .true.
         return
      end if

      ! Source lower bound is retained. The old implementation could execute a
      ! second complete QROMBD call; this reference kernel intentionally does not.
      integral = trapezoid_level(1.0e-10_real64,matric_potential_pa,p,1)
      previous = 2.0_real64*integral
      do level = 2, 24
         previous = integral
         integral = trapezoid_level(1.0e-10_real64,matric_potential_pa,p,level)
         if (abs(integral-previous) <= 1.0e-5_real64*max(abs(integral),tiny(1.0_real64))) exit
      end do

      if (integral <= 0.0_real64) then
         thickness = huge(1.0_real64)
         return
      end if
      thickness = bartholomeus_waterfilm_from_length_density(integral,matric_potential_pa, &
                                                              p%surface_tension_water)
      ok = .true.
   end function

   pure function trapezoid_level(a,b,p,level) result(s)
      real(real64), intent(in) :: a,b
      type(BartholomeusWaterfilmMvgInput), intent(in) :: p
      integer, intent(in) :: level
      real(real64) :: s,h,x
      integer :: n,k

      n = 2**(level-1)
      h = (b-a)/real(n,real64)
      s = 0.5_real64*(bartholomeus_waterfilm_mvg_integrand(a,p)+ &
                      bartholomeus_waterfilm_mvg_integrand(b,p))
      do k=1,n-1
         x = a+h*real(k,real64)
         s = s+bartholomeus_waterfilm_mvg_integrand(x,p)
      end do
      s = h*s
   end function

end module mod_bartholomeus_waterfilm_independent
