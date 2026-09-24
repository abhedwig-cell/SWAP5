program ahl05_split_runtime_screen
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none

  integer, parameter :: NHEAD = 4096
  integer, parameter :: NREP = 3
  integer, parameter :: NCYCLE = 512
  real(real64), parameter :: HCRIT = -1.0e-2_real64
  real(real64), parameter :: DT = 1.0_real64 / 24.0_real64

  character(len=512) :: direct_path, logit_path, material_id
  real(real64), allocatable :: xd(:), yd1(:), yd2(:), yd3(:)
  real(real64), allocatable :: xl(:), yl1(:), yl2(:), yl3(:)
  real(real64) :: p(6), p2(6), heads(NHEAD)
  real(real64) :: t_analytic(NREP), t_direct(NREP), t_logit(NREP), t_split(NREP)
  real(real64) :: checksum_a, checksum_d, checksum_l, checksum_s
  integer :: i, rep

  call get_command_argument(1, direct_path)
  call get_command_argument(2, logit_path)
  call get_command_argument(3, material_id)
  if (len_trim(direct_path) == 0 .or. len_trim(logit_path) == 0 .or. len_trim(material_id) == 0) then
    error stop 'usage: ahl03_runtime_screen DIRECT LOGIT MATERIAL'
  end if

  call read_table(trim(direct_path), p, xd, yd1, yd2, yd3)
  call read_table(trim(logit_path), p2, xl, yl1, yl2, yl3)
  if (any(p /= p2)) error stop 'parameter mismatch between tables'

  do i = 1, NHEAD
    ! Deterministic log-spaced pressure heads over exactly the tabulated core.
    heads(i) = -10.0_real64 ** (-2.0_real64 + 8.0_real64 * real(i-1,real64) / real(NHEAD-1,real64))
  end do

  checksum_a = 0.0_real64
  checksum_d = 0.0_real64
  checksum_l = 0.0_real64
  checksum_s = 0.0_real64
  do rep = 1, NREP
    call time_analytic(heads, p, t_analytic(rep), checksum_a)
    call time_direct(heads, xd, yd1, yd2, yd3, t_direct(rep), checksum_d)
    call time_logit(heads, p, xl, yl1, yl2, yl3, t_logit(rep), checksum_l)
    call time_split(heads, p, xl, yl2, yl3, t_split(rep), checksum_s)
  end do

  call sort3(t_analytic)
  call sort3(t_direct)
  call sort3(t_logit)
  call sort3(t_split)

  if (.not. ieee_is_finite(checksum_a + checksum_d + checksum_l + checksum_s)) error stop 'non-finite benchmark checksum'

  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT', trim(material_id), 'analytical', &
       t_analytic(2) / real(NHEAD*NCYCLE,real64), checksum_a
  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT', trim(material_id), 'direct', &
       t_direct(2) / real(NHEAD*NCYCLE,real64), checksum_d
  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT', trim(material_id), 'logit', &
       t_logit(2) / real(NHEAD*NCYCLE,real64), checksum_l
  write(*,'(A,1X,A,1X,A,1X,ES18.10,1X,ES24.16)') 'RESULT', trim(material_id), 'split', &
       t_split(2) / real(NHEAD*NCYCLE,real64), checksum_s

contains

  subroutine read_table(path, params, x, y1, y2, y3)
    character(len=*), intent(in) :: path
    real(real64), intent(out) :: params(6)
    real(real64), allocatable, intent(out) :: x(:), y1(:), y2(:), y3(:)
    integer :: u, ios, n, j
    open(newunit=u, file=path, status='old', action='read', iostat=ios)
    if (ios /= 0) error stop 'cannot open table'
    read(u,*,iostat=ios) params
    if (ios /= 0) error stop 'cannot read parameters'
    read(u,*,iostat=ios) n
    if (ios /= 0 .or. n < 2) error stop 'invalid table size'
    allocate(x(n), y1(n), y2(n), y3(n))
    do j = 1, n
      read(u,*,iostat=ios) x(j), y1(j), y2(j), y3(j)
      if (ios /= 0) error stop 'cannot read table row'
    end do
    close(u)
    if (any(x(2:) <= x(:n-1))) error stop 'table coordinate not strictly increasing'
  end subroutine read_table

  subroutine time_analytic(h, params, elapsed, checksum)
    real(real64), intent(in) :: h(:), params(6)
    real(real64), intent(out) :: elapsed
    real(real64), intent(inout) :: checksum
    real(real64) :: t0, t1, theta, cap, cond
    integer :: c, j
    call cpu_time(t0)
    do c = 1, NCYCLE
      do j = 1, size(h)
        call analytical_core(h(j), params, theta, cap, cond)
        checksum = checksum + theta + 1.0e-6_real64*cap + 1.0e-9_real64*cond
      end do
    end do
    call cpu_time(t1)
    elapsed = t1 - t0
  end subroutine time_analytic

  subroutine time_direct(h, x, ytheta, ylogc, ylogk, elapsed, checksum)
    real(real64), intent(in) :: h(:), x(:), ytheta(:), ylogc(:), ylogk(:)
    real(real64), intent(out) :: elapsed
    real(real64), intent(inout) :: checksum
    real(real64) :: t0, t1, xv, f, theta, cap, cond
    integer :: c, j, idx
    call cpu_time(t0)
    do c = 1, NCYCLE
      do j = 1, size(h)
        xv = log10(-h(j))
        call locate_interval(x, xv, idx, f)
        theta = ytheta(idx) + f*(ytheta(idx+1)-ytheta(idx))
        cap = exp(ylogc(idx) + f*(ylogc(idx+1)-ylogc(idx)))
        cond = exp(ylogk(idx) + f*(ylogk(idx+1)-ylogk(idx)))
        checksum = checksum + theta + 1.0e-6_real64*cap + 1.0e-9_real64*cond
      end do
    end do
    call cpu_time(t1)
    elapsed = t1 - t0
  end subroutine time_direct

  subroutine time_logit(h, params, x, yz, ylogc, ylogk, elapsed, checksum)
    real(real64), intent(in) :: h(:), params(6), x(:), yz(:), ylogc(:), ylogk(:)
    real(real64), intent(out) :: elapsed
    real(real64), intent(inout) :: checksum
    real(real64) :: t0, t1, xv, f, z, se, theta, cap, cond, span
    integer :: c, j, idx
    span = params(2) - params(1)
    call cpu_time(t0)
    do c = 1, NCYCLE
      do j = 1, size(h)
        xv = log10(-h(j))
        call locate_interval(x, xv, idx, f)
        z = yz(idx) + f*(yz(idx+1)-yz(idx))
        if (z >= 0.0_real64) then
          se = 1.0_real64 / (1.0_real64 + exp(-z))
        else
          se = exp(z) / (1.0_real64 + exp(z))
        end if
        theta = params(1) + span*se
        cap = exp(ylogc(idx) + f*(ylogc(idx+1)-ylogc(idx)))
        cond = exp(ylogk(idx) + f*(ylogk(idx+1)-ylogk(idx)))
        checksum = checksum + theta + 1.0e-6_real64*cap + 1.0e-9_real64*cond
      end do
    end do
    call cpu_time(t1)
    elapsed = t1 - t0
  end subroutine time_logit

  subroutine time_split(h, params, x, ylogc, ylogk, elapsed, checksum)
    real(real64), intent(in) :: h(:), params(6), x(:), ylogc(:), ylogk(:)
    real(real64), intent(out) :: elapsed
    real(real64), intent(inout) :: checksum
    real(real64) :: t0, t1, xv, f, theta, cap, cond, tr, ts, alpha, n, m, span, ah
    integer :: c, j, idx
    tr=params(1); ts=params(2); alpha=params(3); n=params(4)
    m=1.0_real64-1.0_real64/n; span=ts-tr
    call cpu_time(t0)
    do c=1,NCYCLE
      do j=1,size(h)
        ! Exact retention only.
        ah=abs(alpha*h(j))
        theta=tr+span/(1.0_real64+ah**n)**m
        ! C and K remain in the frozen adaptive lookup.
        xv=log10(-h(j))
        call locate_interval(x,xv,idx,f)
        cap=exp(ylogc(idx)+f*(ylogc(idx+1)-ylogc(idx)))
        cond=exp(ylogk(idx)+f*(ylogk(idx+1)-ylogk(idx)))
        checksum=checksum+theta+1.0e-6_real64*cap+1.0e-9_real64*cond
      end do
    end do
    call cpu_time(t1)
    elapsed=t1-t0
  end subroutine time_split

  subroutine locate_interval(x, value, idx, fraction)
    real(real64), intent(in) :: x(:), value
    integer, intent(out) :: idx
    real(real64), intent(out) :: fraction
    integer :: lo, hi, mid, n
    n = size(x)
    if (value <= x(1)) then
      idx = 1
      fraction = 0.0_real64
      return
    else if (value >= x(n)) then
      idx = n-1
      fraction = 1.0_real64
      return
    end if
    lo = 1
    hi = n
    do while (hi-lo > 1)
      mid = (lo+hi)/2
      if (x(mid) <= value) then
        lo = mid
      else
        hi = mid
      end if
    end do
    idx = lo
    fraction = (value-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate_interval

  subroutine analytical_core(head, params, theta, capacity, conductivity)
    real(real64), intent(in) :: head, params(6)
    real(real64), intent(out) :: theta, capacity, conductivity
    real(real64) :: tr, ts, alpha, n, ksat, lambda, m, span
    real(real64) :: ah, term1, relsat, term
    tr = params(1)
    ts = params(2)
    alpha = params(3)
    n = params(4)
    ksat = params(5)
    lambda = params(6)
    m = 1.0_real64 - 1.0_real64/n
    span = ts-tr
    ah = abs(alpha*head)
    theta = tr + span/(1.0_real64 + ah**n)**m
    term1 = ah**(n-1.0_real64)
    capacity = n*m*alpha*(span/(1.0_real64 + term1*ah)**(m+1.0_real64))*term1
    if (head > -1.0_real64 .and. capacity < DT*1.0e-7_real64) capacity = DT*1.0e-7_real64
    relsat = (theta-tr)/span
    if (relsat > 1.0_real64-1.0e-6_real64) then
      conductivity = ksat
    else
      term = (1.0_real64-relsat**(1.0_real64/m))**m
      conductivity = ksat*relsat**lambda*(1.0_real64-term)**2
      conductivity = min(conductivity,ksat)
    end if
  end subroutine analytical_core

  subroutine sort3(v)
    real(real64), intent(inout) :: v(3)
    real(real64) :: tmp
    if (v(1) > v(2)) then; tmp=v(1); v(1)=v(2); v(2)=tmp; end if
    if (v(2) > v(3)) then; tmp=v(2); v(2)=v(3); v(3)=tmp; end if
    if (v(1) > v(2)) then; tmp=v(1); v(1)=v(2); v(2)=tmp; end if
  end subroutine sort3

end program ahl05_split_runtime_screen
