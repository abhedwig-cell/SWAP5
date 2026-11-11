program test_oxygen_scalar_bracket
   use iso_fortran_env, only : int64, real64
   use mod_oxygen_scalar_bracket
   implicit none
   type :: ResidualState
      real(real64) :: root
      real(real64) :: first, second
      integer :: calls
   end type ResidualState

   real(real64) :: x, original
   integer :: status, n, original_iterations
   type(ResidualState) :: left, right

   call oxygen_bisect_monotone(no_stress, 1.0_real64, x, status, n)
   if (status /= OXYGEN_NO_STRESS .or. abs(x-1.0_real64) > epsilon(1.0_real64) .or. n /= 0) error stop 1

   call oxygen_bisect_monotone(full_stress, 1.0_real64, x, status, n)
   if (status /= OXYGEN_FULL_STRESS .or. abs(x) > epsilon(1.0_real64) .or. n /= 0) error stop 2

   call oxygen_bisect_monotone(interior, 1.0_real64, x, status, n)
   if (status /= OXYGEN_BRACKET_OK) error stop 3
   if (abs(x-0.37_real64) > 2.0e-12_real64) error stop 4

   original = x
   original_iterations = n
   left = ResidualState(0.37_real64, 0.0_real64, 0.0_real64, 0)
   right = ResidualState(0.62_real64, 0.0_real64, 0.0_real64, 0)
   call oxygen_bisect_monotone(xmax=1.0_real64, x=x, status=status, iterations=n, &
                                state=left, state_residual=stateful)
   if (status /= OXYGEN_BRACKET_OK .or. n /= original_iterations) error stop 5
   if (transfer(x,0_int64) /= transfer(original,0_int64)) error stop 6
   if (left%calls /= n+2 .or. left%first < 1.0_real64 .or. abs(left%second) > tiny(x)) error stop 7

   call oxygen_bisect_monotone(xmax=1.0_real64, x=x, status=status, iterations=n, &
                                state=right, state_residual=stateful)
   if (status /= OXYGEN_BRACKET_OK .or. abs(x-right%root) > 2.0e-12_real64) error stop 8
   if (right%calls /= n+2 .or. left%calls /= original_iterations+2) error stop 9

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
   function stateful(v, state) result(f)
      real(real64), intent(in) :: v
      class(*), intent(inout) :: state
      real(real64) :: f
      select type (state)
      type is (ResidualState)
         state%calls = state%calls+1
         if (state%calls == 1) state%first = v
         if (state%calls == 2) state%second = v
         f = state%root-v
      class default
         error stop 10
      end select
   end function stateful
end program test_oxygen_scalar_bracket
