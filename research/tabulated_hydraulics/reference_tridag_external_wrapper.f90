subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_reference_linear_solver, only: reference_tridag
  implicit none
  integer, intent(in) :: n
  real(real64), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(real64), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  real(real64), allocatable :: a(:), b(:), c(:), r(:), u(:), gamma(:)

  if (n <= 0) error stop 'TAB-HYD real tridag wrapper requires n > 0'
  allocate(a(n), b(n), c(n), r(n), u(n), gamma(n))
  a = lower(1:n)
  b = main(1:n)
  c = upper(1:n)
  r = rhs(1:n)
  gamma = 0.0_real64
  call reference_tridag(n, a, b, c, r, u, gamma, ierror)
  solution(1:n) = u
end subroutine tridag
