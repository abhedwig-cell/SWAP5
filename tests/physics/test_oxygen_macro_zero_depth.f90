program test_oxygen_macro_zero_depth
   use iso_fortran_env, only : real64
   use mod_oxygen_macro_zero_depth
   implicit none

   integer :: i, j, status, n, checks
   real(real64) :: ctop, a, b, sm, sr, root, f, prev, x
   real(real64), parameter :: vals(5) = [1.0e-12_real64, 1.0e-6_real64, 1.0e-3_real64, 1.0_real64, 1.0e3_real64]

   checks = 0

   ! No finite root when the asymptote is non-negative.
   call oxygen_macro_zero_depth(1.0_real64, 0.4_real64, 0.6_real64, 0.9_real64, 0.9_real64, root, status, n)
   if (status /= OXYGEN_MACRO_NO_FINITE_ROOT) error stop 1
   checks = checks + 1

   ! Broad positive-domain sweep. A and B are the already-scaled source terms.
   do i = 1, size(vals)
      do j = 1, size(vals)
         sm = 0.05_real64 + 0.3_real64*i
         sr = 0.07_real64 + 0.2_real64*j
         a = vals(i)
         b = vals(j)
         ctop = 0.73_real64*(a+b)
         call oxygen_macro_zero_depth(ctop, a, b, sm, sr, root, status, n)
         if (status /= OXYGEN_MACRO_ROOT_OK) error stop 2
         f = oxygen_macro_zero_residual(root,ctop,a,b,sm,sr)
         if (abs(f) > 1.0e-9_real64*max(1.0_real64,ctop,a+b)) error stop 3
         if (root <= 0.0_real64) error stop 4

         ! Direct monotonicity check over [0, root*2].
         prev = oxygen_macro_zero_residual(0.0_real64,ctop,a,b,sm,sr)
         do n = 1, 100
            x = 2.0_real64*root*real(n,real64)/100.0_real64
            f = oxygen_macro_zero_residual(x,ctop,a,b,sm,sr)
            if (f > prev + 1.0e-13_real64*max(1.0_real64,abs(prev))) error stop 5
            prev = f
         end do
         checks = checks + 1
      end do
   end do

   ! Extreme scale separation: representative of the tiny-derivative class
   ! that made the legacy Newton quotient unsafe.
   call oxygen_macro_zero_depth(1.0e-12_real64, 1.0e-12_real64, 1.0e-6_real64, &
                                0.9_real64, 0.9_real64, root, status, n)
   if (status /= OXYGEN_MACRO_ROOT_OK) error stop 6
   if (.not.(root > 0.0_real64)) error stop 7
   checks = checks + 1

   write(*,'(a,i0)') 'PPA_WU05C3R_MACRO_ZERO_DEPTH_CHECKS=', checks
   write(*,'(a)') 'PPA_WU05C3R_MACRO_ZERO_DEPTH=PASS'
end program test_oxygen_macro_zero_depth
