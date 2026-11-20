program test_fgc49d_oxygen_context_parity
   use iso_fortran_env, only : int64, real64
   use mod_oxygen_scalar_bracket, only : oxygen_bisect_monotone, oxygen_bisect_context, &
      OXYGEN_BRACKET_OK, OXYGEN_NO_STRESS, OXYGEN_FULL_STRESS, OXYGEN_INVALID_BRACKET
   implicit none

   type :: trace_t
      real(real64) :: intercept
      integer :: calls = 0
      integer(int64) :: samples(101) = 0_int64
   end type trace_t

   type(trace_t) :: incumbent, candidate
   real(real64) :: old_x, new_x
   integer :: old_status, new_status, old_iterations, new_iterations

   call compare(2.0_real64, 1.0_real64, 100, OXYGEN_NO_STRESS, 1)
   call compare(-1.0_real64, 1.0_real64, 100, OXYGEN_FULL_STRESS, 2)
   call compare(0.37_real64, 1.0_real64, 100, OXYGEN_BRACKET_OK, 30)
   call compare(0.37_real64, 1.0_real64, 1, OXYGEN_BRACKET_OK, 3)
   call compare(0.37_real64, -1.0_real64, 100, OXYGEN_INVALID_BRACKET, 0)

   print '(a)', 'FGC49D_PRIVATE_OXYGEN_BRACKET_TRACE_IDENTITY=PASS'

contains

   subroutine compare(intercept, xmax, maxiter, expected_status, min_calls)
      real(real64), intent(in) :: intercept, xmax
      integer, intent(in) :: maxiter, expected_status, min_calls

      incumbent = trace_t(intercept)
      candidate = trace_t(intercept)
      call oxygen_bisect_monotone(old_residual, xmax, old_x, old_status, old_iterations, 1.0e-8_real64, maxiter)
      call oxygen_bisect_context(new_residual, candidate, xmax, new_x, new_status, new_iterations, &
         1.0e-8_real64, maxiter)
      if (old_status /= expected_status .or. new_status /= old_status) error stop 'bracket status'
      if (new_iterations /= old_iterations) error stop 'bracket iterations'
      if (transfer(new_x, 0_int64) /= transfer(old_x, 0_int64)) error stop 'bracket result'
      if (incumbent%calls < min_calls .or. candidate%calls /= incumbent%calls) error stop 'callback count'
      if (any(candidate%samples /= incumbent%samples)) error stop 'callback order or value'
   end subroutine compare

   function old_residual(x) result(f)
      real(real64), intent(in) :: x
      real(real64) :: f
      f = record(incumbent, x)
   end function old_residual

   function new_residual(x, context) result(f)
      real(real64), intent(in) :: x
      class(*), intent(inout) :: context
      real(real64) :: f
      select type(context)
      type is (trace_t)
         f = record(context, x)
      class default
         error stop 'wrong callback context'
      end select
   end function new_residual

   function record(trace, x) result(f)
      type(trace_t), intent(inout) :: trace
      real(real64), intent(in) :: x
      real(real64) :: f
      trace%calls = trace%calls + 1
      trace%samples(trace%calls) = transfer(x, 0_int64)
      f = trace%intercept - x
   end function record

end program test_fgc49d_oxygen_context_parity
