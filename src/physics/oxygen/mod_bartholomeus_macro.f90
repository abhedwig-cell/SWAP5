module mod_bartholomeus_macro
   use iso_fortran_env, only : real64
   use mod_oxygen_macro_zero_depth, only : oxygen_macro_zero_depth, OXYGEN_MACRO_ROOT_OK, OXYGEN_MACRO_NO_FINITE_ROOT
   implicit none
   private

   public :: BartholomeusMacroInput
   public :: bartholomeus_macro_concentration

   type :: BartholomeusMacroInput
      real(real64) :: depth_m
      real(real64) :: c_mroot
      real(real64) :: w_root_z0
      real(real64) :: f_senes
      real(real64) :: q10_root
      real(real64) :: soil_temp_k
      real(real64) :: ctop
      real(real64) :: microbial_shape_m
      real(real64) :: root_shape_m
      real(real64) :: r_microbial_z0
      real(real64) :: d_soil
   end type BartholomeusMacroInput

contains

   pure function bartholomeus_macro_concentration(p, resp_factor, ok) result(c_macro)
      type(BartholomeusMacroInput), intent(in) :: p
      real(real64), intent(in) :: resp_factor
      logical, intent(out) :: ok
      real(real64) :: c_macro
      real(real64) :: r_mroot_z0, a, b, dum, lroot
      integer :: status

      ok = .false.
      c_macro = 0.0_real64
      if (p%d_soil <= 0.0_real64 .or. p%microbial_shape_m <= 0.0_real64 .or. p%root_shape_m <= 0.0_real64) return

      r_mroot_z0 = p%f_senes*(p%c_mroot*p%w_root_z0*resp_factor) * &
                   (p%q10_root**(0.1_real64*(p%soil_temp_k-298.0_real64)))
      a = p%microbial_shape_m**2*p%r_microbial_z0/p%d_soil
      b = p%root_shape_m**2*r_mroot_z0/p%d_soil
      dum = a+b

      if (dum < p%ctop) then
         c_macro = p%ctop - a*(1.0_real64-exp(-p%depth_m/p%microbial_shape_m)) - &
                              b*(1.0_real64-exp(-p%depth_m/p%root_shape_m))
         ok = .true.
         return
      end if

      call oxygen_macro_zero_depth(p%ctop,a,b,p%microbial_shape_m,p%root_shape_m,lroot,status)
      if (status == OXYGEN_MACRO_NO_FINITE_ROOT) then
         ! Boundary dum == ctop: l -> infinity. Use the analytical limit.
         c_macro = p%ctop - a*(1.0_real64-exp(-p%depth_m/p%microbial_shape_m)) - &
                              b*(1.0_real64-exp(-p%depth_m/p%root_shape_m))
         ok = .true.
         return
      end if
      if (status /= OXYGEN_MACRO_ROOT_OK) return

      if (p%depth_m < lroot) then
         c_macro = p%ctop - a*(1.0_real64-(p%depth_m/p%microbial_shape_m)*exp(-lroot/p%microbial_shape_m) - &
                               exp(-p%depth_m/p%microbial_shape_m)) - &
                              b*(1.0_real64-(p%depth_m/p%root_shape_m)*exp(-lroot/p%root_shape_m) - &
                               exp(-p%depth_m/p%root_shape_m))
      else
         c_macro = 0.0_real64
      end if
      ok = .true.
   end function bartholomeus_macro_concentration

end module mod_bartholomeus_macro
