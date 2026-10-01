module MOD_swap_base
  implicit none
  integer :: swmacro = 0
  integer :: i_instance = 1
end module MOD_swap_base

module MOD_arrays
  implicit none
  integer, parameter :: macp = 112
  integer, parameter :: mabbc = 4
end module MOD_arrays

module MOD_params
  implicit none
  real(8), parameter :: nihil = 1.0d-12
end module MOD_params

module MOD_grid
  implicit none
  integer, parameter :: numnod = 112
  real(8), parameter :: z(112) = [ &
    -0.50000000d0, -1.50000000d0, -2.50000000d0, -3.50000000d0, -4.50000000d0, -5.50000000d0, -6.50000000d0, -7.50000000d0, &
    -8.50000000d0, -9.50000000d0, -10.50000000d0, -11.50000000d0, -12.50000000d0, -13.50000000d0, -14.50000000d0, -15.50000000d0, &
    -16.50000000d0, -17.50000000d0, -18.50000000d0, -19.50000000d0, -20.50000000d0, -21.50000000d0, -22.50000000d0, -23.50000000d0, &
    -24.50000000d0, -25.50000000d0, -26.50000000d0, -27.50000000d0, -28.50000000d0, -29.50000000d0, -30.50000000d0, -31.50000000d0, &
    -32.50000000d0, -33.50000000d0, -35.00000000d0, -37.00000000d0, -39.00000000d0, -41.00000000d0, -43.00000000d0, -45.00000000d0, &
    -47.00000000d0, -49.00000000d0, -51.00000000d0, -53.00000000d0, -55.00000000d0, -57.00000000d0, -59.00000000d0, -61.00000000d0, &
    -63.00000000d0, -65.00000000d0, -67.00000000d0, -69.00000000d0, -71.25000000d0, -73.75000000d0, -76.25000000d0, -78.75000000d0, &
    -81.25000000d0, -83.75000000d0, -86.25000000d0, -88.75000000d0, -91.25000000d0, -93.75000000d0, -96.25000000d0, -98.75000000d0, &
    -101.25000000d0, -103.75000000d0, -106.25000000d0, -108.75000000d0, -111.25000000d0, -113.75000000d0, -116.25000000d0, -118.75000000d0, &
    -122.50000000d0, -127.50000000d0, -132.50000000d0, -137.50000000d0, -142.50000000d0, -147.50000000d0, -152.50000000d0, -157.50000000d0, &
    -162.50000000d0, -167.50000000d0, -172.50000000d0, -177.50000000d0, -182.50000000d0, -187.50000000d0, -192.50000000d0, -197.50000000d0, &
    -202.50000000d0, -207.50000000d0, -212.50000000d0, -217.50000000d0, -222.50000000d0, -227.50000000d0, -232.50000000d0, -237.50000000d0, &
    -242.50000000d0, -247.50000000d0, -252.50000000d0, -257.50000000d0, -262.50000000d0, -267.50000000d0, -272.50000000d0, -277.50000000d0, &
    -282.50000000d0, -287.50000000d0, -292.50000000d0, -297.50000000d0, -302.50000000d0, -307.50000000d0, -312.50000000d0, -317.50000000d0 ]
  real(8), parameter :: dz(112) = [ &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, &
    2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, &
    2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0 ]
  real(8), parameter :: disnod(113) = [ &
    0.50000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, 1.00000000d0, &
    1.00000000d0, 1.00000000d0, 1.50000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, &
    2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, &
    2.00000000d0, 2.00000000d0, 2.00000000d0, 2.00000000d0, 2.25000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, 2.50000000d0, &
    3.75000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, 5.00000000d0, &
    2.50000000d0 ]
end module MOD_grid

module variables
  use MOD_grid, only: numnod
  implicit none
  logical :: fldaystart = .false.
  integer :: swbotb = 7
  real(8) :: runon = 0.0d0, epd = 0.0d0, reva = 0.0d0, pondm1 = 0.0d0
  real(8) :: dt = 0.25d0, runots = 0.0d0, t1900 = 1000.0d0
  real(8) :: thetm1(numnod) = 0.30d0, qrot(numnod) = 0.0d0
  integer :: swkimpl = 0, swkmean = 1
  real(8) :: hplate = 0.0d0
  integer :: swbotb3impl = 0, swbotb3resvert = 0
  real(8) :: deepgw = -100.0d0, rimlay = 1.0d0
  integer :: sw4 = 0
  real(8) :: qbotab(2*4) = 0.0d0
  logical :: fldtmin = .false.
  integer :: maxit = 8, maxbacktr = 4
  real(8) :: critdevh2cp = 1.0d-12, critdevh1cp = 1.0d-12, critdevponddt = 1.0d-12
  real(8) :: dtmin = 1.0d-6
  integer :: nodgwl = numnod
  real(8) :: gwlm1 = -2.0d0, hm1(numnod) = -100.0d0
  real(8) :: CritDevBalCp = 1.0d-12, CritDevBalTot = 1.0d-12

  real(8) :: h(numnod) = -100.0d0, theta(numnod) = 0.30d0
  real(8) :: kmean(numnod+1) = 1.0d0, gwlinp = -5.0d0, pond = 0.0d0
  real(8) :: dtold = 0.25d0, qtop = -1.0d0, qbot = -1.0d0, hbot = -100.0d0
  integer :: itnumb(100,2) = 0

  logical :: fllowgwl = .false.
  real(8) :: k(numnod) = 1.0d0, dimoca(numnod) = 0.0d0
  integer :: numbit = 0
  logical :: fldecdt = .false.
  real(8) :: gwl = -2.0d0
end module variables

module MOD_MvG
  implicit none
contains
  real(8) function watcon(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1 .or. head > huge(head)) error stop 'invalid watcon arguments'
    watcon = 0.30d0
  end function watcon

  real(8) function hconduc(node, head, water_content, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, frost_factor
    if (node < 1 .or. head > huge(head) .or. water_content < -huge(water_content) .or. frost_factor < 0.0d0) &
      error stop 'invalid hconduc arguments'
    hconduc = 1.0d0
  end function hconduc

  real(8) function moiscap(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1 .or. head > huge(head)) error stop 'invalid moiscap arguments'
    moiscap = 0.0d0
  end function moiscap

  real(8) function dhconduc(node, head, water_content, capacity, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, capacity, frost_factor
    if (node < 1 .or. head > huge(head) .or. water_content < -huge(water_content) .or. &
        capacity < -huge(capacity) .or. frost_factor < 0.0d0) error stop 'invalid dhconduc arguments'
    dhconduc = 0.0d0
  end function dhconduc

  real(8) function cofgen(mode, node)
    integer, intent(in) :: mode, node
    if (mode < 0 .or. node < 1) error stop 'invalid cofgen arguments'
    cofgen = 0.30d0
  end function cofgen
end module MOD_MvG

module MOD_top
  implicit none
  real(8) :: q0 = 0.0d0
  logical :: flrunoff = .false., ftoph = .false.
  real(8) :: hsurf = 0.0d0
contains
  subroutine boundtop(task)
    use variables, only: qtop
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid boundtop task'
    ftoph = .false.
    qtop = -1.0d0
  end subroutine boundtop
  subroutine pondrunoff()
  end subroutine pondrunoff
end module MOD_top

module MOD_meteo
  implicit none
  real(8) :: nraidt = 0.0d0
end module MOD_meteo

module MOD_macropore
  implicit none
contains
  subroutine macropore(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid macropore task'
  end subroutine macropore
end module MOD_macropore

module MOD_rootextraction
  implicit none
contains
  subroutine RootExtraction(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid root extraction task'
  end subroutine RootExtraction
end module MOD_rootextraction

module MOD_snow
  implicit none
  real(8) :: melt = 0.0d0
end module MOD_snow

module MOD_frost
  use MOD_grid, only: numnod
  implicit none
  real(8) :: rfcp(numnod) = 1.0d0
end module MOD_frost

module MOD_drain
  use MOD_grid, only: numnod
  implicit none
  integer, parameter :: nrlevs = 1
  real(8) :: qdra(nrlevs,numnod) = 0.0d0
end module MOD_drain

module MOD_irrigation
  use MOD_grid, only: numnod
  implicit none
  real(8) :: qssdi(numnod) = 0.0d0
  real(8) :: nird = 0.0d0
end module MOD_irrigation

module MOD_swap_mp
  use MOD_grid, only: numnod
  implicit none
  real(8) :: armpss = 0.0d0
  real(8) :: frarmtrx(numnod) = 1.0d0
  real(8) :: qexcmpmtx(numnod) = 0.0d0
  real(8) :: dfdhmp(numnod) = 0.0d0
  integer :: ictopmp = 2
  real(8) :: qmplatss = 0.0d0
  integer :: idecmprat = 0
  logical :: fldecmprat = .false., fldecMPmbf = .false.
end module MOD_swap_mp

real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  if (method < 0 .or. node < 1 .or. dzup <= 0.0d0 .or. dzlow <= 0.0d0 .or. &
      hup > huge(hup) .or. hlow > huge(hlow)) error stop 'invalid hcomean arguments'
  hcomean = 0.5d0*(kup+klow)
end function hcomean

subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i
  if (n <= 0 .or. upper(1) > huge(upper(1)) .or. main(1) > huge(main(1)) .or. &
      lower(1) > huge(lower(1)) .or. rhs(1) > huge(rhs(1))) error stop 'invalid tridag arguments'
  do i = 1, n
    solution(i) = 0.0d0
  end do
  ierror = 0
end subroutine tridag

subroutine bandec(a, n, m1, m2, np, mp, al, mpl, indx, d)
  implicit none
  integer, intent(in) :: n, m1, m2, np, mp, mpl
  real(8), intent(inout) :: a(*), al(*)
  integer, intent(out) :: indx(*)
  real(8), intent(out) :: d
  integer :: i
  if (m1 < 0 .or. m2 < 0 .or. np < n .or. mp < 1 .or. mpl < 1 .or. a(1) > huge(a(1)) .or. al(1) > huge(al(1))) &
    error stop 'invalid bandec arguments'
  do i = 1, n
    indx(i) = i
  end do
  d = 1.0d0
end subroutine bandec

subroutine banbks(a, n, m1, m2, np, mp, al, mpl, indx, b)
  implicit none
  integer, intent(in) :: n, m1, m2, np, mp, mpl, indx(*)
  real(8), intent(in) :: a(*), al(*)
  real(8), intent(inout) :: b(*)
  if (n <= 0 .or. m1 < 0 .or. m2 < 0 .or. np < n .or. mp < 1 .or. mpl < 1 .or. &
      indx(1) < 1 .or. a(1) > huge(a(1)) .or. al(1) > huge(al(1)) .or. b(1) > huge(b(1))) &
    error stop 'invalid banbks arguments'
end subroutine banbks

real(8) function afgen(table, n, x)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: table(*), x
  if (n <= 0 .or. table(1) > huge(table(1)) .or. x > huge(x)) error stop 'invalid afgen arguments'
  afgen = 0.0d0
end function afgen

subroutine dtdpst(mode, time, text)
  implicit none
  character(len=*), intent(in) :: mode
  real(8), intent(in) :: time
  character(len=*), intent(out) :: text
  if (len(mode) <= 0 .or. time > huge(time)) error stop 'invalid dtdpst arguments'
  text = 'fixture-time'
end subroutine dtdpst

subroutine swap_warning(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  if (len(origin) + len(message) < 0) error stop 'unreachable'
end subroutine swap_warning

subroutine swap_error(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  write(*,'(A,1X,A)') trim(origin), trim(message)
  error stop 'unexpected swap_error in F-SI04 fixture'
end subroutine swap_error
