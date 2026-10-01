program test_oxygen_scalar_bracket
   use iso_fortran_env, only : real64
   use mod_oxygen_scalar_bracket
   implicit none
   real(real64) :: x
   integer :: status, n

   call oxygen_bisect_monotone(no_stress, 1.0_real64, x, status, n)
   if (status /= OXYGEN_NO_STRESS .or. x /= 1.0_real64 .or. n /= 0) error stop 1

   call oxygen_bisect_monotone(full_stress, 1.0_real64, x, status, n)
   if (status /= OXYGEN_FULL_STRESS .or. x /= 0.0_real64 .or. n /= 0) error stop 2

   call oxygen_bisect_monotone(interior, 1.0_real64, x, status, n)
   if (status /= OXYGEN_BRACKET_OK) error stop 3
   if (abs(x-0.37_real64) > 2.0e-12_real64) error stop 4

   print '(a)', 'PPA_WU05C3R_SCALAR_BRACKET=PASS'

contains
   pure function no_stress(v) result(f)
      real(real64), intent(in) :: v
      real(real64) :: f
      f = 2.0_real64-v
   end function
   pure function full_stress(v) result(f)
      real(real64), intent(in) :: v
      real(real64) :: f
      f = -1.0_real64-v
   end function
   pure function interior(v) result(f)
      real(real64), intent(in) :: v
      real(real64) :: f
      f = 0.37_real64-v
   end function
end program test_oxygen_scalar_bracket
