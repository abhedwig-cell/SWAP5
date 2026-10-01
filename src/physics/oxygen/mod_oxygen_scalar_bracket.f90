module mod_oxygen_scalar_bracket
   use iso_fortran_env, only : real64
   implicit none
   private

   integer, parameter, public :: OXYGEN_BRACKET_OK = 0
   integer, parameter, public :: OXYGEN_NO_STRESS = 1
   integer, parameter, public :: OXYGEN_FULL_STRESS = 2
   integer, parameter, public :: OXYGEN_INVALID_BRACKET = 3

   public :: oxygen_bisect_monotone

   abstract interface
      pure function oxygen_residual(x) result(f)
         import real64
         real(real64), intent(in) :: x
         real(real64) :: f
      end function oxygen_residual
   end interface

contains

   subroutine oxygen_bisect_monotone(residual, xmax, x, status, iterations, xtol, maxiter)
      procedure(oxygen_residual) :: residual
      real(real64), intent(in) :: xmax
      real(real64), intent(out) :: x
      integer, intent(out) :: status
      integer, intent(out), optional :: iterations
      real(real64), intent(in), optional :: xtol
      integer, intent(in), optional :: maxiter

      real(real64) :: a, b, fa, fb, fm, mid, tol
      integer :: i, nmax

      tol = 1.0e-12_real64
      if (present(xtol)) tol = max(xtol, 0.0_real64)
      nmax = 100
      if (present(maxiter)) nmax = max(1, maxiter)

      if (xmax < 0.0_real64) then
         x = 0.0_real64
         status = OXYGEN_INVALID_BRACKET
         if (present(iterations)) iterations = 0
         return
      end if

      ! Exact-preserving fast path recovered from the 4.3.1 oxygen audit.
      b = xmax
      fb = residual(b)
      if (fb >= 0.0_real64) then
         x = b
         status = OXYGEN_NO_STRESS
         if (present(iterations)) iterations = 0
         return
      end if

      a = 0.0_real64
      fa = residual(a)
      if (fa <= 0.0_real64) then
         x = a
         status = OXYGEN_FULL_STRESS
         if (present(iterations)) iterations = 0
         return
      end if

      if (fa*fb >= 0.0_real64) then
         x = a
         status = OXYGEN_INVALID_BRACKET
         if (present(iterations)) iterations = 0
         return
      end if

      do i = 1, nmax
         mid = 0.5_real64*(a+b)
         fm = residual(mid)
         if (abs(b-a) <= tol*max(1.0_real64, abs(mid)) .or. fm == 0.0_real64) then
            x = mid
            status = OXYGEN_BRACKET_OK
            if (present(iterations)) iterations = i
            return
         end if
         if (fm > 0.0_real64) then
            a = mid
            fa = fm
         else
            b = mid
            fb = fm
         end if
      end do

      x = 0.5_real64*(a+b)
      status = OXYGEN_BRACKET_OK
      if (present(iterations)) iterations = nmax
   end subroutine oxygen_bisect_monotone

end module mod_oxygen_scalar_bracket
