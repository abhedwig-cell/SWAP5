module MOD_swap_base
  implicit none
  integer :: swmacro = 0
  integer :: swdra = 0
  integer :: swpondmx = 0
  integer :: swfrost = 0
  integer :: swrunon = 0
  integer :: swinco = 3
  integer :: swhyst = 0
  integer :: swsolve = 1
  integer :: i_instance = 1
end module MOD_swap_base

module MOD_arrays
  implicit none
  integer, parameter :: macp = 4
  integer, parameter :: mabbc = 4
end module MOD_arrays

module MOD_params
  implicit none
  real(8), parameter :: nihil = 1.0d-12
end module MOD_params

module MOD_grid
  implicit none
  integer, parameter :: numnod = 4
  real(8), parameter :: z(numnod) = [-0.25d0, -0.75d0, -1.50d0, -2.50d0]
  real(8), parameter :: dz(numnod) = [0.50d0, 0.50d0, 1.00d0, 1.00d0]
  real(8), parameter :: disnod(numnod+1) = 1.0d0
end module MOD_grid

module variables
  use MOD_grid, only: numnod
  implicit none
  logical :: fldaystart = .false.
  integer :: swbotb = 2
  real(8) :: runon = 0.0d0, epd = 0.0d0, reva = 0.0d0, pondm1 = 0.0d0
  real(8) :: dt = 0.125d0, runots = 0.0d0, t1900 = 1000.0d0
  real(8), target :: thetm1(numnod) = 0.30d0, qrot(numnod) = 0.0d0
  integer :: swkimpl = 0, swkmean = 1
  real(8) :: hplate = 0.0d0
  integer :: swbotb3impl = 0, swbotb3resvert = 0
  real(8) :: deepgw = -100.0d0, rimlay = 1.0d0
  integer :: sw4 = 0
  real(8) :: qbotab(2*4) = 0.0d0
  logical :: fldtmin = .false.
  integer :: maxit = 12, maxbacktr = 6
  real(8) :: critdevh2cp = 1.0d-12, critdevh1cp = 1.0d-12, critdevponddt = 1.0d-12
  real(8) :: dtmin = 1.0d-6
  integer :: nodgwl = numnod
  real(8) :: gwlm1 = -2.0d0, hm1(numnod) = -75.0d0
  real(8) :: CritDevBalCp = 1.0d-12, CritDevBalTot = 1.0d-12

  real(8) :: h(numnod) = -75.0d0, theta(numnod) = 0.30d0
  real(8) :: kmean(numnod+1) = 1.0d0, gwlinp = -5.0d0, pond = 0.0d0
  real(8) :: dtold = 0.125d0, qtop = 0.0d0, qbot = 0.0d0, hbot = -100.0d0
  integer :: itnumb(100,2) = 0

  logical :: fllowgwl = .false.
  real(8) :: k(numnod) = 1.0d0, dimoca(numnod) = 0.0d0
  integer :: numbit = 0
  logical :: fldecdt = .false.
  real(8) :: gwl = -2.0d0

  real(8) :: pondmx = 10.0d0, rsro = 0.5d0, rsroexp = 1.0d0
  integer :: swredu = 0

  real(8), allocatable :: htb(:)
  integer :: nhead = 0
  real(8) :: gwli = -2.0d0
  real(8) :: gwltab(8) = 0.0d0
  real(8) :: volact = 0.0d0
  real(8) :: ithetabeg(numnod) = 0.0d0
  real(8) :: volini = 0.0d0, pondini = 0.0d0, ivolbeg = 0.0d0, ipondbeg = 0.0d0
end module variables

module MOD_MvG
  use MOD_grid, only: numnod
  implicit none
  real(8), target :: cofgen(42,numnod+1) = 0.0d0
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

module MOD_gwl
  implicit none
contains
  subroutine calcgwl()
    use variables, only: gwl
    gwl = gwl
  end subroutine calcgwl
end module MOD_gwl

module MOD_sss
  implicit none
contains
  subroutine sss_solver()
  end subroutine sss_solver
  real(8) function sss_solver_gwl()
    sss_solver_gwl = -2.0d0
  end function sss_solver_gwl
end module MOD_sss

module MOD_meteo
  implicit none
  real(8) :: nraidt = 0.0d0
  real(8) :: epond = 0.0d0
  real(8) :: peva = 0.0d0
  real(8) :: empreva = 0.0d0
end module MOD_meteo

module MOD_macropore
  implicit none
contains
  subroutine macropore(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid macropore task'
  end subroutine macropore
  subroutine macrostatevar(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'invalid macrostatevar task'
  end subroutine macrostatevar
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
  real(8), target :: qdra(nrlevs,numnod) = 0.0d0
end module MOD_drain

module MOD_irrigation
  use MOD_grid, only: numnod
  implicit none
  real(8), target :: qssdi(numnod) = 0.0d0
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

subroutine afgen_2(table, n, x, value, ipos)
  implicit none
  integer, intent(in) :: n
  integer, intent(inout) :: ipos
  real(8), intent(in) :: table(*), x
  real(8), intent(out) :: value
  if (n < 0 .or. x > huge(x)) error stop 'invalid afgen_2 arguments'
  if (n > 0 .and. table(1) > huge(table(1))) error stop 'invalid afgen_2 table'
  ipos = max(0,ipos)
  value = 0.0d0
end subroutine afgen_2

subroutine watstor()
  use variables, only: volact, theta
  use MOD_grid, only: dz
  volact = sum(theta*dz)
end subroutine watstor

subroutine fluxes()
end subroutine fluxes

subroutine hysteresis()
end subroutine hysteresis

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
  error stop 'unexpected swap_error in F-KT15 fixture'
end subroutine swap_error
