program test_fsi19_reference_linear_solver
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_reference_linear_solver, only: reference_tridag, reference_band_solve
  implicit none

  call test_tridag_success(1)
  call test_tridag_success(2)
  call test_tridag_success(4)
  call test_tridag_success(7)
  call test_tridag_first_pivot_failure()
  call test_tridag_internal_pivot_failure()
  call test_band_case(2, .false.)
  call test_band_case(4, .false.)
  call test_band_case(4, .true.)
  call test_band_case(5, .true.)

  print '(A)', 'FSI19_DIRECT_REFERENCE_LINEAR_SOLVER_ORACLE PASS'

contains

  subroutine test_tridag_success(n)
    integer, intent(in) :: n
    real(real64) :: a(n), b(n), c(n), r(n), candidate(n), oracle(n), gamma(n)
    integer :: i, ierr_candidate, ierr_oracle

    a = 0.0_real64
    b = 0.0_real64
    c = 0.0_real64
    r = 0.0_real64
    candidate = -999.0_real64
    oracle = -999.0_real64
    gamma = -777.0_real64
    do i = 1, n
      b(i) = 4.0_real64 + 0.125_real64 * real(i, real64)
      r(i) = 0.25_real64 * real(i*i + 1, real64)
      if (i > 1) a(i) = -0.5_real64 - 0.015625_real64 * real(i, real64)
      if (i < n) c(i) = -0.25_real64 + 0.0078125_real64 * real(i, real64)
    end do

    call legacy_tridag_oracle(n, a, b, c, r, oracle, ierr_oracle)
    call reference_tridag(n, a, b, c, r, candidate, gamma, ierr_candidate)
    if (ierr_candidate /= ierr_oracle .or. ierr_candidate /= 0) error stop 'F-SI19 TRIDAG success ierror mismatch'
    if (.not. bitwise_equal(candidate, oracle)) error stop 'F-SI19 TRIDAG success output mismatch'
    write(*,'(A,I0,A)') 'FSI19_TRIDAG_SUCCESS_N', n, '=PASS_BITWISE'
  end subroutine test_tridag_success

  subroutine test_tridag_first_pivot_failure()
    integer, parameter :: n = 3
    real(real64) :: a(n), b(n), c(n), r(n), candidate(n), oracle(n), gamma(n)
    integer :: ierr_candidate, ierr_oracle

    a = [0.0_real64, -1.0_real64, -1.0_real64]
    b = [0.0_real64, 4.0_real64, 4.0_real64]
    c = [-1.0_real64, -1.0_real64, 0.0_real64]
    r = [1.0_real64, 2.0_real64, 3.0_real64]
    candidate = -999.0_real64
    oracle = -999.0_real64
    gamma = -777.0_real64

    call legacy_tridag_oracle(n, a, b, c, r, oracle, ierr_oracle)
    call reference_tridag(n, a, b, c, r, candidate, gamma, ierr_candidate)
    if (ierr_oracle /= 1000 .or. ierr_candidate /= ierr_oracle) error stop 'F-SI19 TRIDAG first pivot failure mismatch'
    print '(A)', 'FSI19_TRIDAG_IERROR_1000=PASS'
  end subroutine test_tridag_first_pivot_failure

  subroutine test_tridag_internal_pivot_failure()
    integer, parameter :: n = 3
    real(real64) :: a(n), b(n), c(n), r(n), candidate(n), oracle(n), gamma(n)
    integer :: ierr_candidate, ierr_oracle

    a = [0.0_real64, 1.0_real64, 0.0_real64]
    b = [1.0_real64, 1.0_real64, 3.0_real64]
    c = [1.0_real64, 0.0_real64, 0.0_real64]
    r = [1.0_real64, 2.0_real64, 3.0_real64]
    candidate = -999.0_real64
    oracle = -999.0_real64
    gamma = -777.0_real64

    call legacy_tridag_oracle(n, a, b, c, r, oracle, ierr_oracle)
    call reference_tridag(n, a, b, c, r, candidate, gamma, ierr_candidate)
    if (ierr_oracle /= 1002 .or. ierr_candidate /= ierr_oracle) error stop 'F-SI19 TRIDAG internal pivot failure mismatch'
    print '(A)', 'FSI19_TRIDAG_IERROR_1002=PASS'
  end subroutine test_tridag_internal_pivot_failure

  subroutine test_band_case(n, force_pivot)
    integer, intent(in) :: n
    logical, intent(in) :: force_pivot
    integer, parameter :: np = 9
    real(real64) :: compact(n,3), compact0(n,3), aux(n,1), rhs(n), rhs0(n)
    real(real64) :: padded(np,3), padded_aux(np,1), oracle_rhs(n), d
    integer :: pivots(n), oracle_pivots(n), i

    compact = 0.0_real64
    do i = 1, n
      compact(i,1) = merge(0.0_real64, -0.75_real64, i == 1)
      compact(i,2) = 4.0_real64 + 0.125_real64 * real(i, real64)
      compact(i,3) = merge(0.0_real64, -0.5_real64, i == n)
    end do
    if (force_pivot .and. n >= 2) then
      compact(1,2) = 0.25_real64
      compact(2,1) = 2.0_real64
    end if
    compact0 = compact
    do i = 1, n
      rhs(i) = 0.5_real64 * real(i*i + 2, real64)
    end do
    rhs0 = rhs
    aux = 0.0_real64
    pivots = 0

    padded = -333.0_real64
    padded_aux = -444.0_real64
    padded(1:n,1:3) = compact0
    padded_aux(1:n,1) = 0.0_real64
    oracle_rhs = rhs0
    call legacy_bandec_oracle(padded, n, 1, 1, np, 3, padded_aux, 1, oracle_pivots, d)
    call legacy_banbks_oracle(padded, n, 1, 1, np, 3, padded_aux, 1, oracle_pivots, oracle_rhs)

    call reference_band_solve(compact, aux, pivots, rhs)
    if (.not. bitwise_equal(rhs, oracle_rhs)) error stop 'F-SI19 band solution mismatch'
    if (.not. bitwise_equal(reshape(compact,[3*n]), reshape(padded(1:n,1:3),[3*n]))) &
      error stop 'F-SI19 band factor matrix mismatch'
    if (.not. bitwise_equal(aux(:,1), padded_aux(1:n,1))) error stop 'F-SI19 band aux mismatch'
    if (any(pivots /= oracle_pivots)) error stop 'F-SI19 band pivot mismatch'
    write(*,'(A,I0,A,L1,A)') 'FSI19_BAND_N', n, '_FORCE_PIVOT_', force_pivot, '=PASS_BITWISE_PADDED_ORACLE'
  end subroutine test_band_case

  logical function bitwise_equal(x, y)
    real(real64), intent(in) :: x(:), y(:)
    integer(int64), allocatable :: ix(:), iy(:)
    if (size(x) /= size(y)) then
      bitwise_equal = .false.
      return
    end if
    ix = transfer(x, 0_int64, size(x))
    iy = transfer(y, 0_int64, size(y))
    bitwise_equal = all(ix == iy)
  end function bitwise_equal

  subroutine legacy_tridag_oracle(n, a, b, c, r, u, ierror)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(n), b(n), c(n), r(n)
    integer, intent(out) :: ierror
    real(real64), intent(out) :: u(n)
    real(real64), parameter :: small = 0.3e-37_real64
    real(real64) :: gam(n), bet
    integer :: i

    ierror = 0
    if (abs(b(1)) < small) then
      ierror = 1000
      return
    end if
    bet = b(1)
    u(1) = r(1) / bet
    do i = 2, n
      gam(i) = c(i-1) / bet
      bet = b(i) - a(i) * gam(i)
      if (abs(bet) < small) then
        ierror = 1000 + i
        return
      end if
      u(i) = (r(i) - a(i) * u(i-1)) / bet
    end do
    do i = n-1, 1, -1
      u(i) = u(i) - gam(i+1) * u(i+1)
    end do
  end subroutine legacy_tridag_oracle

  subroutine legacy_bandec_oracle(a,n,m1,m2,np,mp,al,mpl,indx,d)
    integer, intent(in) :: n, m1, m2, np, mp, mpl
    integer, intent(out) :: indx(n)
    real(real64), intent(inout) :: a(np,mp), al(np,mpl)
    real(real64), intent(out) :: d
    real(real64), parameter :: tiny = 1.0e-20_real64
    integer :: i,j,k,l,mm
    real(real64) :: dum

    mm=m1+m2+1
    if (mm > mp .or. m1 > mpl .or. n > np) error stop 'legacy bandec oracle bad args'
    l=m1
    do i=1,m1
      do j=m1+2-i,mm
        a(i,j-l)=a(i,j)
      end do
      l=l-1
      do j=mm-l,mm
        a(i,j)=0.0_real64
      end do
    end do
    d=1.0_real64
    l=m1
    do k=1,n
      dum=a(k,1)
      i=k
      if (l < n) l=l+1
      do j=k+1,l
        if (abs(a(j,1)) > abs(dum)) then
          dum=a(j,1)
          i=j
        end if
      end do
      indx(k)=i
      if (abs(dum) < 1.0e-20_real64) a(k,1)=tiny
      if (i /= k) then
        d=-d
        do j=1,mm
          dum=a(k,j)
          a(k,j)=a(i,j)
          a(i,j)=dum
        end do
      end if
      do i=k+1,l
        dum=a(i,1)/a(k,1)
        al(k,i-k)=dum
        do j=2,mm
          a(i,j-1)=a(i,j)-dum*a(k,j)
        end do
        a(i,mm)=0.0_real64
      end do
    end do
  end subroutine legacy_bandec_oracle

  subroutine legacy_banbks_oracle(a,n,m1,m2,np,mp,al,mpl,indx,b)
    integer, intent(in) :: n, np, mp, mpl, indx(n), m1, m2
    real(real64), intent(in) :: a(np,mp), al(np,mpl)
    real(real64), intent(inout) :: b(n)
    integer :: i,k,l,mm
    real(real64) :: dum

    mm=m1+m2+1
    if (mm > mp .or. m1 > mpl .or. n > np) error stop 'legacy banbks oracle bad args'
    l=m1
    do k=1,n
      i=indx(k)
      if (i /= k) then
        dum=b(k)
        b(k)=b(i)
        b(i)=dum
      end if
      if (l < n) l=l+1
      do i=k+1,l
        b(i)=b(i)-al(k,i-k)*b(k)
      end do
    end do
    l=1
    do i=n,1,-1
      dum=b(i)
      do k=2,l
        dum=dum-a(i,k)*b(k+i-1)
      end do
      b(i)=dum/a(i,1)
      if (l < mm) l=l+1
    end do
  end subroutine legacy_banbks_oracle

end program test_fsi19_reference_linear_solver
