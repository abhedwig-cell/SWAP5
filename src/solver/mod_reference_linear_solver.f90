module mod_reference_linear_solver
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  private

  public :: reference_tridag
  public :: reference_tridag_backsolve
  public :: reference_band_solve

contains

  subroutine reference_tridag(n, a, b, c, r, u, gamma, ierror, beta_factor)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:), b(:), c(:), r(:)
    real(real64), intent(out) :: u(:)
    real(real64), intent(inout) :: gamma(:)
    integer, intent(out) :: ierror
    real(real64), intent(out), optional :: beta_factor(:)

    real(real64), parameter :: small = 0.3e-37_real64
    integer :: i
    real(real64) :: bet
    logical :: capture_in_gamma

    call require_vector_sizes(n, a, b, c, r, u, gamma)
    capture_in_gamma = size(gamma) >= 2*n
    if (capture_in_gamma) gamma(n+1:2*n) = 0.0_real64
    if (present(beta_factor)) then
       if (size(beta_factor) < n) error stop 'reference_tridag: beta factor shape mismatch'
       beta_factor(1:n) = 0.0_real64
    end if

    ierror = 0

    if (abs(b(1)) < small) then
       ierror = 1000
       return
    else
       bet = b(1)
       if (capture_in_gamma) gamma(n+1) = bet
       if (present(beta_factor)) beta_factor(1) = bet
       u(1) = r(1) / bet
       do i = 2, n
          gamma(i) = c(i-1) / bet
          bet = b(i) - a(i) * gamma(i)
          if (abs(bet) < small) then
             ierror = 1000 + i
             return
          end if
          if (capture_in_gamma) gamma(n+i) = bet
          if (present(beta_factor)) beta_factor(i) = bet
          u(i) = (r(i) - a(i) * u(i-1)) / bet
       end do

       do i = n-1, 1, -1
          u(i) = u(i) - gamma(i+1) * u(i+1)
       end do
    end if
  end subroutine reference_tridag

  subroutine reference_tridag_backsolve(n, a, r, gamma, beta_factor, u, ierror)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:), r(:), gamma(:), beta_factor(:)
    real(real64), intent(out) :: u(:)
    integer, intent(out) :: ierror

    real(real64), parameter :: small = 0.3e-37_real64
    integer :: i

    if (n <= 0) error stop 'reference_tridag_backsolve requires n > 0'
    if (size(a) < n .or. size(r) < n .or. size(gamma) < n .or. size(beta_factor) < n .or. size(u) < n) &
         error stop 'reference_tridag_backsolve: vector shape mismatch'

    ierror = 0
    if (abs(beta_factor(1)) < small) then
       ierror = 1000
       return
    end if

    u(1) = r(1) / beta_factor(1)
    do i = 2, n
       if (abs(beta_factor(i)) < small) then
          ierror = 1000 + i
          return
       end if
       u(i) = (r(i) - a(i) * u(i-1)) / beta_factor(i)
    end do

    do i = n-1, 1, -1
       u(i) = u(i) - gamma(i+1) * u(i+1)
    end do
  end subroutine reference_tridag_backsolve

  subroutine reference_band_solve(a, al, indx, b)
    real(real64), intent(inout) :: a(:,:)
    real(real64), intent(inout) :: al(:,:)
    integer, intent(out) :: indx(:)
    real(real64), intent(inout) :: b(:)

    integer :: n
    real(real64) :: d

    n = size(b)
    if (n <= 0) error stop 'reference_band_solve requires n > 0'
    if (size(a,1) < n .or. size(a,2) < 3) error stop 'reference_band_solve: invalid matrix shape'
    if (size(al,1) < n .or. size(al,2) < 1) error stop 'reference_band_solve: invalid aux shape'
    if (size(indx) < n) error stop 'reference_band_solve: invalid pivot shape'

    call reference_bandec(a, n, 1, 1, al, indx, d)
    call reference_banbks(a, n, 1, 1, al, indx, b)
  end subroutine reference_band_solve

  subroutine reference_bandec(a, n, m1, m2, al, indx, d)
    real(real64), intent(inout) :: a(:,:), al(:,:)
    integer, intent(in) :: n, m1, m2
    integer, intent(out) :: indx(:)
    real(real64), intent(out) :: d

    real(real64), parameter :: tiny = 1.0e-20_real64
    integer :: i, j, k, l, mm
    real(real64) :: dum

    mm = m1 + m2 + 1
    if (mm > size(a,2) .or. m1 > size(al,2) .or. n > size(a,1) .or. n > size(al,1) .or. n > size(indx)) &
         error stop 'reference_bandec: bad args'

    l = m1
    do i = 1, m1
       do j = m1 + 2 - i, mm
          a(i,j-l) = a(i,j)
       end do
       l = l - 1
       do j = mm - l, mm
          a(i,j) = 0.0_real64
       end do
    end do

    d = 1.0_real64
    l = m1
    do k = 1, n
       dum = a(k,1)
       i = k
       if (l < n) l = l + 1
       do j = k + 1, l
          if (abs(a(j,1)) > abs(dum)) then
             dum = a(j,1)
             i = j
          end if
       end do
       indx(k) = i
       if (abs(dum) < 1.0e-20_real64) a(k,1) = tiny

       if (i /= k) then
          d = -d
          do j = 1, mm
             dum = a(k,j)
             a(k,j) = a(i,j)
             a(i,j) = dum
          end do
       end if
       do i = k + 1, l
          dum = a(i,1) / a(k,1)
          al(k,i-k) = dum
          do j = 2, mm
             a(i,j-1) = a(i,j) - dum * a(k,j)
          end do
          a(i,mm) = 0.0_real64
       end do
    end do
  end subroutine reference_bandec

  subroutine reference_banbks(a, n, m1, m2, al, indx, b)
    real(real64), intent(in) :: a(:,:), al(:,:)
    integer, intent(in) :: n, m1, m2, indx(:)
    real(real64), intent(inout) :: b(:)

    integer :: i, k, l, mm
    real(real64) :: dum

    mm = m1 + m2 + 1
    if (mm > size(a,2) .or. m1 > size(al,2) .or. n > size(a,1) .or. n > size(al,1) .or. &
        n > size(indx) .or. n > size(b)) error stop 'reference_banbks: bad args'

    l = m1
    do k = 1, n
       i = indx(k)
       if (i /= k) then
          dum = b(k)
          b(k) = b(i)
          b(i) = dum
       end if
       if (l < n) l = l + 1
       do i = k + 1, l
          b(i) = b(i) - al(k,i-k) * b(k)
       end do
    end do

    l = 1
    do i = n, 1, -1
       dum = b(i)
       do k = 2, l
          dum = dum - a(i,k) * b(k+i-1)
       end do
       b(i) = dum / a(i,1)
       if (l < mm) l = l + 1
    end do
  end subroutine reference_banbks

  subroutine require_vector_sizes(n, a, b, c, r, u, gamma)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:), b(:), c(:), r(:)
    real(real64), intent(in) :: u(:), gamma(:)

    if (n <= 0) error stop 'reference_tridag requires n > 0'
    if (size(a) < n .or. size(b) < n .or. size(c) < n .or. size(r) < n .or. size(u) < n .or. size(gamma) < n) &
         error stop 'reference_tridag: vector shape mismatch'
  end subroutine require_vector_sizes

end module mod_reference_linear_solver
