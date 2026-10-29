module mod_reference_linear_solver
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  public :: reference_tridag
  public :: reference_tridag_backsolve
  public :: reference_band_solve
  public :: reference_tridag_low_rank

contains

  subroutine reference_tridag_low_rank(n,a,b,c,r,left,right,solution,gamma,ierror,additional_solves)
    integer,intent(in)::n
    real(real64),intent(in)::a(:),b(:),c(:),r(:),left(:,:),right(:,:)
    real(real64),intent(out)::solution(:)
    real(real64),intent(inout)::gamma(:)
    integer,intent(out)::ierror
    integer,intent(out),optional::additional_solves
    real(real64),allocatable::beta(:),z(:,:),small_matrix(:,:),rhs(:),row(:)
    real(real64)::pivot_value,multiplier,swap_value
    integer::rank,j,k,pivot
    if(present(additional_solves))additional_solves=0
    ierror=2000;rank=size(left,2)
    if(n<=0.or.size(a)<n.or.size(b)<n.or.size(c)<n.or.size(r)<n.or.size(solution)<n.or.size(gamma)<n)return
    if(size(left,1)/=n.or.size(right,1)/=n.or.size(right,2)/=rank)return
    if(any(.not.ieee_is_finite(left)).or.any(.not.ieee_is_finite(right)))return
    allocate(beta(n),z(n,rank),small_matrix(rank,rank),rhs(rank),row(rank))
    call reference_tridag(n,a,b,c,r,solution,gamma,ierror,beta_factor=beta,capture_in_gamma_requested=.false.)
    if(ierror/=0)return
    if(rank==0)return
    do j=1,rank
      call reference_tridag_backsolve(n,a,left(:,j),gamma,beta,z(:,j),ierror)
      if(present(additional_solves))additional_solves=additional_solves+1
      if(ierror/=0)return
    end do
    small_matrix=matmul(transpose(right),z)
    do j=1,rank
      small_matrix(j,j)=small_matrix(j,j)+1d0
    end do
    rhs=matmul(transpose(right),solution(:n))
    if(any(.not.ieee_is_finite(small_matrix)).or.any(.not.ieee_is_finite(rhs)))then
      ierror=2001;return
    end if
    ! Pivot only the small Woodbury system. The soil matrix remains tridiagonal.
    do k=1,rank
      pivot=k-1+maxloc(abs(small_matrix(k:rank,k)),dim=1)
      if(abs(small_matrix(pivot,k))<0.3e-37_real64)then
        ierror=2000+k;return
      end if
      if(pivot/=k)then
        row=small_matrix(k,:);small_matrix(k,:)=small_matrix(pivot,:);small_matrix(pivot,:)=row
        swap_value=rhs(k);rhs(k)=rhs(pivot);rhs(pivot)=swap_value
      end if
      pivot_value=small_matrix(k,k)
      do j=k+1,rank
        multiplier=small_matrix(j,k)/pivot_value
        small_matrix(j,k:rank)=small_matrix(j,k:rank)-multiplier*small_matrix(k,k:rank)
        rhs(j)=rhs(j)-multiplier*rhs(k)
      end do
    end do
    do k=rank,1,-1
      rhs(k)=(rhs(k)-sum(small_matrix(k,k+1:rank)*rhs(k+1:rank)))/small_matrix(k,k)
    end do
    solution(:n)=solution(:n)-matmul(z,rhs)
    if(any(.not.ieee_is_finite(solution(:n))))ierror=2100
  end subroutine reference_tridag_low_rank

  subroutine reference_tridag(n, a, b, c, r, u, gamma, ierror, beta_factor, capture_in_gamma_requested)
    integer, intent(in) :: n
    real(real64), intent(in) :: a(:), b(:), c(:), r(:)
    real(real64), intent(out) :: u(:)
    real(real64), intent(inout) :: gamma(:)
    integer, intent(out) :: ierror
    real(real64), intent(out), optional :: beta_factor(:)
    logical, intent(in), optional :: capture_in_gamma_requested

    real(real64), parameter :: small = 0.3e-37_real64
    integer :: i
    real(real64) :: bet
    logical :: capture_in_gamma

    call require_vector_sizes(n, a, b, c, r, u, gamma)
    capture_in_gamma = size(gamma) >= 2*n
    if (present(capture_in_gamma_requested)) capture_in_gamma = capture_in_gamma_requested
    if (capture_in_gamma .and. size(gamma) < 2*n) error stop 'reference_tridag: capture requires gamma capacity >= 2*n'
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
