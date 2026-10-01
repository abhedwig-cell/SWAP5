module mod_oxygen_macro_zero_depth
   use iso_fortran_env, only : real64
   implicit none
   private

   integer, parameter, public :: OXYGEN_MACRO_ROOT_OK = 0
   integer, parameter, public :: OXYGEN_MACRO_NO_FINITE_ROOT = 1
   integer, parameter, public :: OXYGEN_MACRO_INVALID = 2

   public :: oxygen_macro_zero_residual
   public :: oxygen_macro_zero_depth

contains

   pure function oxygen_macro_zero_residual(l, ctop, microbial_scale, root_scale, &
                                             microbial_shape, root_shape) result(f)
      real(real64), intent(in) :: l, ctop
      real(real64), intent(in) :: microbial_scale, root_scale
      real(real64), intent(in) :: microbial_shape, root_shape
      real(real64) :: f

      f = ctop &
          - microbial_scale * (1.0_real64 - (l/microbial_shape)*exp(-l/microbial_shape) &
                               - exp(-l/microbial_shape)) &
          - root_scale * (1.0_real64 - (l/root_shape)*exp(-l/root_shape) &
                          - exp(-l/root_shape))
   end function oxygen_macro_zero_residual

   subroutine oxygen_macro_zero_depth(ctop, microbial_scale, root_scale, microbial_shape, root_shape, &
                                      lroot, status, iterations, xtol, maxiter)
      real(real64), intent(in) :: ctop, microbial_scale, root_scale
      real(real64), intent(in) :: microbial_shape, root_shape
      real(real64), intent(out) :: lroot
      integer, intent(out) :: status
      integer, intent(out), optional :: iterations
      real(real64), intent(in), optional :: xtol
      integer, intent(in), optional :: maxiter

      real(real64) :: lo, hi, mid, fhi, fmid, tol, asymptote
      integer :: i, nmax

      if (ctop < 0.0_real64 .or. microbial_scale < 0.0_real64 .or. root_scale < 0.0_real64 .or. &
          microbial_shape <= 0.0_real64 .or. root_shape <= 0.0_real64) then
         lroot = 0.0_real64
         status = OXYGEN_MACRO_INVALID
         if (present(iterations)) iterations = 0
         return
      end if

      asymptote = ctop - microbial_scale - root_scale
      if (asymptote >= 0.0_real64) then
         lroot = huge(1.0_real64)
         status = OXYGEN_MACRO_NO_FINITE_ROOT
         if (present(iterations)) iterations = 0
         return
      end if

      tol = 1.0e-12_real64
      if (present(xtol)) tol = max(0.0_real64, xtol)
      nmax = 200
      if (present(maxiter)) nmax = max(1, maxiter)

      lo = 0.0_real64
      hi = max(microbial_shape, root_shape)

      do i = 1, nmax
         fhi = oxygen_macro_zero_residual(hi, ctop, microbial_scale, root_scale, microbial_shape, root_shape)
         if (fhi <= 0.0_real64) exit
         hi = 2.0_real64*hi
      end do
      if (fhi > 0.0_real64) then
         lroot = hi
         status = OXYGEN_MACRO_INVALID
         if (present(iterations)) iterations = nmax
         return
      end if

      do i = 1, nmax
         mid = 0.5_real64*(lo+hi)
         fmid = oxygen_macro_zero_residual(mid, ctop, microbial_scale, root_scale, microbial_shape, root_shape)
         if (abs(hi-lo) <= tol*max(1.0_real64,abs(mid)) .or. fmid == 0.0_real64) then
            lroot = mid
            status = OXYGEN_MACRO_ROOT_OK
            if (present(iterations)) iterations = i
            return
         end if
         if (fmid > 0.0_real64) then
            lo = mid
         else
            hi = mid
            fhi = fmid
         end if
      end do

      lroot = 0.5_real64*(lo+hi)
      status = OXYGEN_MACRO_ROOT_OK
      if (present(iterations)) iterations = nmax
   end subroutine oxygen_macro_zero_depth

end module mod_oxygen_macro_zero_depth
