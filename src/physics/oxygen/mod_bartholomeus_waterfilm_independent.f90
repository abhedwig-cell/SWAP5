module mod_bartholomeus_waterfilm_independent
   use iso_fortran_env, only : real64
   use ieee_arithmetic,only:ieee_is_finite
   use mod_bartholomeus_waterfilm, only : BartholomeusWaterfilmMvgInput, &
                                           bartholomeus_waterfilm_mvg_integrand, &
                                           bartholomeus_waterfilm_from_length_density
   implicit none
   private
   public :: bartholomeus_waterfilm_mvg_independent

contains

   function bartholomeus_waterfilm_mvg_independent(matric_potential_pa,p,ok,require_two_refinements) result(thickness)
      real(real64), intent(in) :: matric_potential_pa
      type(BartholomeusWaterfilmMvgInput), intent(in) :: p
      logical, intent(out) :: ok
      logical,optional,intent(in)::require_two_refinements
      real(real64) :: thickness
      real(real64) :: integral, previous
      integer :: level,stable_levels
      logical::refined,converged

      ok = .false.
      refined=.false.;converged=.false.;stable_levels=0
      if(present(require_two_refinements))refined=require_two_refinements
      if(refined)then
         if(.not.all(ieee_is_finite([matric_potential_pa,p%capac_term,p%n_minus_1,p%m_plus_1, &
                     p%alpha_per_pa,p%gen_n,p%surface_tension_water])))then
            thickness=huge(1.0_real64)
            return
         end if
      end if
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
         integral = trapezoid_refine(1.0e-10_real64,matric_potential_pa,p,level,previous)
         if(refined)then
            if(abs(integral-previous)<=1.0e-5_real64*max(abs(integral),tiny(1.0_real64)))then
               stable_levels=stable_levels+1
            else
               stable_levels=0
            end if
            if(stable_levels>=2)then
               converged=.true.
               exit
            end if
         else
         if (abs(integral-previous) <= 1.0e-5_real64*max(abs(integral),tiny(1.0_real64))) exit
         end if
      end do

      if(refined.and..not.converged)then
         thickness=huge(1.0_real64)
         return
      end if
      if (integral <= 0.0_real64) then
         thickness = huge(1.0_real64)
         return
      end if
      thickness = bartholomeus_waterfilm_from_length_density(integral,matric_potential_pa, &
                                                              p%surface_tension_water)
      ok = .true.
   end function

   pure function trapezoid_refine(a,b,p,level,previous) result(s)
      real(real64), intent(in) :: a,b,previous
      type(BartholomeusWaterfilmMvgInput), intent(in) :: p
      integer, intent(in) :: level
      real(real64) :: s,h,x,sum_new
      integer :: n_new,k

      n_new = 2**(level-2)
      h = (b-a)/real(2*n_new,real64)
      sum_new = 0.0_real64
      do k=1,n_new
         x = a+h*real(2*k-1,real64)
         sum_new = sum_new+bartholomeus_waterfilm_mvg_integrand(x,p)
      end do
      s = 0.5_real64*previous+h*sum_new
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
