! F-SI16 independent exact-B1.10 oracle fixture support.
! The qualified oracle compiles canonical HeadCalc, watstor and fluxes plus the
! SWAP-008/B1.5 tridag verbatim. Only unrelated external modules are replaced
! by deterministic fixture doubles matching the common F-SI16 request.
module MOD_swap_base
  implicit none
  integer :: swmacro = 0
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
  ! F-SI16 explicit geometry uses request node_distance for soil faces and
  ! derives the lower boundary face as exactly 0.5*dz(NN).
  real(8), parameter :: disnod(numnod+1) = [1.0d0, 1.0d0, 1.0d0, 1.0d0, 0.5d0]
end module MOD_grid

module variables
  use MOD_grid, only: numnod
  implicit none
  logical :: fldaystart = .false.
  integer :: swbotb = 5
  real(8) :: runon = 0d0, epd = 0d0, reva = 0d0, pondm1 = 0d0
  real(8) :: dt = 0.25d0, runots = 0d0, t1900 = 1000d0
  real(8) :: thetm1(numnod) = 0.30d0, qrot(numnod) = 0d0
  integer :: swkimpl = 0, swkmean = 1
  real(8) :: hplate = 0d0
  integer :: swbotb3impl = 0, swbotb3resvert = 0
  real(8) :: deepgw = -100d0, rimlay = 1d0
  integer :: sw4 = 0
  real(8) :: qbotab(8) = 0d0
  logical :: fldtmin = .false.
  integer :: maxit = 16, maxbacktr = 8
  real(8) :: critdevh2cp = 1d-12, critdevh1cp = 1d-12, critdevponddt = 1d-12
  real(8) :: dtmin = 1d-6
  integer :: nodgwl = numnod
  real(8) :: gwlm1 = -2d0, hm1(numnod) = -75d0
  real(8) :: CritDevBalCp = 1d-12, CritDevBalTot = 1d-12
  real(8) :: h(numnod) = -75d0, theta(numnod) = 0.30d0
  real(8) :: kmean(numnod+1) = 1d0, gwlinp = -2d0, pond = 0d0
  real(8) :: dtold = 0.25d0, qtop = -1d0, qbot = 123d0, hbot = -74d0
  integer :: itnumb(100,2) = 0
  logical :: fllowgwl = .false.
  real(8) :: k(numnod) = 1d0, dimoca(numnod) = 0d0
  integer :: numbit = 0
  logical :: fldecdt = .false.
  real(8) :: gwl = -2d0
  real(8) :: q(numnod+1) = 0d0, qimmob(numnod) = 0d0
  real(8) :: volact = 0d0, volm1 = 0d0
end module variables

module MOD_MvG
  implicit none
contains
  real(8) function watcon(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1) error stop 'F-SI16 exact oracle watcon node'
    watcon = 0.30d0 + 0.001d0*(head + 75.0d0)
  end function watcon

  real(8) function hconduc(node, head, water_content, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, frost_factor
    if (node < 1 .or. frost_factor < 0d0 .or. head > huge(head) .or. &
        water_content > huge(water_content)) error stop 'F-SI16 exact oracle hconduc arguments'
    hconduc = 1.0d0
  end function hconduc

  real(8) function moiscap(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (node < 1 .or. head > huge(head)) error stop 'F-SI16 exact oracle moiscap arguments'
    moiscap = 0.001d0
  end function moiscap

  real(8) function dhconduc(node, head, water_content, capacity, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, capacity, frost_factor
    if (node < 1 .or. frost_factor < 0d0 .or. head > huge(head) .or. &
        water_content > huge(water_content) .or. capacity > huge(capacity)) &
      error stop 'F-SI16 exact oracle dhconduc arguments'
    dhconduc = 0.0d0
  end function dhconduc

  real(8) function cofgen(mode, node)
    integer, intent(in) :: mode, node
    if (mode < 0 .or. node < 1) error stop 'F-SI16 exact oracle cofgen arguments'
    cofgen = 0.30d0
  end function cofgen
end module MOD_MvG

module MOD_top
  implicit none
  real(8) :: q0 = 0d0
  logical :: flrunoff = .false., ftoph = .false.
  real(8) :: hsurf = 0d0
contains
  subroutine boundtop(task)
    use variables, only: qtop
    integer, intent(in) :: task
    if (task < 0) error stop 'F-SI16 exact oracle boundtop task'
    ftoph = .false.
    qtop = -1.0d0
  end subroutine boundtop

  subroutine pondrunoff()
  end subroutine pondrunoff
end module MOD_top

module MOD_meteo
  implicit none
  real(8) :: nraidt = 0d0
end module MOD_meteo

module MOD_macropore
  implicit none
contains
  subroutine macropore(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'F-SI16 exact oracle macropore task'
  end subroutine macropore
end module MOD_macropore

module MOD_rootextraction
  implicit none
contains
  subroutine RootExtraction(task)
    integer, intent(in) :: task
    if (task < 0) error stop 'F-SI16 exact oracle root task'
  end subroutine RootExtraction
end module MOD_rootextraction

module MOD_snow
  implicit none
  real(8) :: melt = 0d0
end module MOD_snow

module MOD_frost
  use MOD_grid, only: numnod
  implicit none
  real(8) :: rfcp(numnod) = 1d0
end module MOD_frost

module MOD_drain
  use MOD_grid, only: numnod
  implicit none
  integer, parameter :: nrlevs = 1
  real(8) :: qdra(nrlevs,numnod) = 0d0
  real(8) :: qdrtot = 0d0
end module MOD_drain

module MOD_irrigation
  use MOD_grid, only: numnod
  implicit none
  real(8) :: qssdi(numnod) = 0d0
  real(8) :: nird = 0d0
  real(8) :: qssdisum = 0d0
end module MOD_irrigation

module MOD_swap_mp
  use MOD_grid, only: numnod
  implicit none
  real(8) :: armpss = 0d0, frarmtrx(numnod) = 1d0
  real(8) :: qexcmpmtx(numnod) = 0d0, dfdhmp(numnod) = 0d0
  integer :: ictopmp = 2
  real(8) :: qmplatss = 0d0, QMaPo = 0d0
  integer :: idecmprat = 0
  logical :: fldecmprat = .false., fldecMPmbf = .false.
end module MOD_swap_mp

module MOD_integral
  use MOD_grid, only: numnod
  implicit none
  real(8) :: inq(numnod+1) = 0d0
end module MOD_integral

module MOD_re_global
  implicit none
  real(8) :: qrosum = 0d0
end module MOD_re_global

real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  if (method < 0 .or. node < 1 .or. dzup <= 0d0 .or. dzlow <= 0d0) &
    error stop 'F-SI16 exact oracle hcomean arguments'
  if (hup > huge(hup) .or. hlow > huge(hlow)) error stop 'F-SI16 exact oracle hcomean heads'
  hcomean = 0.5d0*(kup + klow)
end function hcomean

real(8) function afgen(table, n, x)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: table(*), x
  if (n <= 0 .or. x > huge(x) .or. table(1) > huge(table(1))) error stop 'F-SI16 exact oracle afgen'
  afgen = 0d0
end function afgen

subroutine dtdpst(mode, time, text)
  implicit none
  character(len=*), intent(in) :: mode
  real(8), intent(in) :: time
  character(len=*), intent(out) :: text
  if (len_trim(mode) == 0 .or. time > huge(time)) error stop 'F-SI16 exact oracle dtdpst'
  text = 'fixture-time'
end subroutine dtdpst

subroutine swap_warning(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  if (len(origin) < 0 .or. len(message) < 0) error stop 'unreachable'
end subroutine swap_warning

subroutine swap_error(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  write(*,*) trim(origin), trim(message)
  error stop 'F-SI16 exact oracle swap_error'
end subroutine swap_error
