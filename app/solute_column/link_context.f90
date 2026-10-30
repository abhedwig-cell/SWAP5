! Link-only legacy context for the opt-in serialized Reference application.
! Only the source arithmetic face mean executes here; other entries abort.
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
  integer :: numnod = 0
  real(8), allocatable :: z(:), dz(:), disnod(:)
end module MOD_grid

module variables
  use MOD_grid, only: numnod
  implicit none
  logical :: fldaystart = .false.
  integer :: swbotb = 7
  real(8) :: runon = 0.0d0, epd = 0.0d0, reva = 0.0d0, pondm1 = 0.0d0
  real(8) :: dt = 0.25d0, runots = 0.0d0, t1900 = 1000.0d0
  real(8), allocatable :: thetm1(:), qrot(:)
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
  integer :: nodgwl = 0
  real(8) :: gwlm1 = -2.0d0
  real(8), allocatable :: hm1(:)
  real(8) :: CritDevBalCp = 1.0d-12, CritDevBalTot = 1.0d-12

  real(8), allocatable :: h(:), theta(:), kmean(:)
  real(8) :: gwlinp = -5.0d0, pond = 0.0d0
  real(8) :: dtold = 0.25d0, qtop = -1.0d0, qbot = -1.0d0, hbot = -100.0d0
  integer :: itnumb(100,2) = 0

  logical :: fllowgwl = .false.
  real(8), allocatable :: k(:), dimoca(:)
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
    error stop 'standalone: disabled legacy entry watcon'
  end function watcon

  real(8) function hconduc(node, head, water_content, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, frost_factor
    error stop 'standalone: disabled legacy entry hconduc'
  end function hconduc

  real(8) function moiscap(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    error stop 'standalone: disabled legacy entry moiscap'
  end function moiscap

  real(8) function dhconduc(node, head, water_content, capacity, frost_factor)
    integer, intent(in) :: node
    real(8), intent(in) :: head, water_content, capacity, frost_factor
    error stop 'standalone: disabled legacy entry dhconduc'
  end function dhconduc

  real(8) function cofgen(mode, node)
    integer, intent(in) :: mode, node
    error stop 'standalone: disabled legacy entry cofgen'
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
    error stop 'standalone: disabled legacy entry boundtop'
  end subroutine boundtop
  subroutine pondrunoff()

    error stop 'standalone: disabled legacy entry pondrunoff'
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
    error stop 'standalone: disabled legacy entry macropore'
  end subroutine macropore
end module MOD_macropore

module MOD_rootextraction
  implicit none
contains
  subroutine RootExtraction(task)
    integer, intent(in) :: task
    error stop 'standalone: disabled legacy entry RootExtraction'
  end subroutine RootExtraction
end module MOD_rootextraction

module MOD_snow
  implicit none
  real(8) :: melt = 0.0d0
end module MOD_snow

module MOD_frost
  use MOD_grid, only: numnod
  implicit none
  real(8), allocatable :: rfcp(:)
end module MOD_frost

module MOD_drain
  use MOD_grid, only: numnod
  implicit none
  integer, parameter :: nrlevs = 1
  real(8), allocatable :: qdra(:,:)
end module MOD_drain

module MOD_irrigation
  use MOD_grid, only: numnod
  implicit none
  real(8), allocatable :: qssdi(:)
  real(8) :: nird = 0.0d0
end module MOD_irrigation

module MOD_swap_mp
  use MOD_grid, only: numnod
  implicit none
  real(8) :: armpss = 0.0d0
  real(8), allocatable :: frarmtrx(:), qexcmpmtx(:), dfdhmp(:)
  integer :: ictopmp = 2
  real(8) :: qmplatss = 0.0d0
  integer :: idecmprat = 0
  logical :: fldecmprat = .false., fldecMPmbf = .false.
end module MOD_swap_mp

module solute_column_context
  implicit none
contains
  subroutine initialize_column_context(thickness)
    use MOD_grid
    use variables, only: thetm1,qrot,nodgwl,hm1,h,theta,kmean,k,dimoca
    use MOD_frost, only: rfcp
    use MOD_drain, only: qdra,nrlevs
    use MOD_irrigation, only: qssdi
    use MOD_swap_mp, only: frarmtrx,qexcmpmtx,dfdhmp
    real(8), intent(in) :: thickness(:)
    integer :: j
    if(numnod/=0)error stop 'standalone: immutable grid already initialized'
    numnod=size(thickness)
    dz=thickness
    allocate(z(numnod),disnod(numnod+1))
    z(1)=-0.5d0*dz(1)
    do j=2,numnod
      z(j)=z(j-1)-0.5d0*(dz(j-1)+dz(j))
    end do
    disnod(1)=0.5d0*dz(1)
    disnod(2:numnod)=0.5d0*(dz(1:numnod-1)+dz(2:numnod))
    disnod(numnod+1)=0.5d0*dz(numnod)
    allocate(thetm1(numnod),qrot(numnod),hm1(numnod),h(numnod),theta(numnod), &
      kmean(numnod+1),k(numnod),dimoca(numnod),rfcp(numnod),qdra(nrlevs,numnod), &
      qssdi(numnod),frarmtrx(numnod),qexcmpmtx(numnod),dfdhmp(numnod))
    thetm1=0.30d0;qrot=0d0;nodgwl=numnod;hm1=-100d0;h=-100d0;theta=0.30d0
    kmean=1d0;k=1d0;dimoca=0d0;rfcp=1d0;qdra=0d0;qssdi=0d0
    frarmtrx=1d0;qexcmpmtx=0d0;dfdhmp=0d0
  end subroutine
end module solute_column_context

real(8) function hcomean(method, kup, klow, dzup, dzlow, node, hup, hlow)
  implicit none
  integer, intent(in) :: method, node
  real(8), intent(in) :: kup, klow, dzup, dzlow, hup, hlow
  ! SWAP/functions.f90 SHA256 b32dee127747e619cb92965d0473173ec7fd93c56128a0dbd5ebf5942c300527.
  ! Source SWKMEAN2 is required by original Hupsel. The unweighted path
  ! retains its literal predecessor arithmetic.
  select case(method)
  case(1)
    hcomean=0.5d0*(kup+klow)
  case(2)
    if(dzup+dzlow<=0d0)error stop 'invalid weighted conductivity geometry'
    hcomean=(dzup*kup+dzlow*klow)/(dzup+dzlow)
  case default
    error stop 'standalone: conductivity mean not implemented'
  end select
end function hcomean

subroutine tridag(n, upper, main, lower, rhs, solution, ierror)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: upper(*), main(*), lower(*), rhs(*)
  real(8), intent(out) :: solution(*)
  integer, intent(out) :: ierror
  integer :: i
  error stop 'standalone: disabled legacy entry tridag'
end subroutine tridag

subroutine bandec(a, n, m1, m2, np, mp, al, mpl, indx, d)
  implicit none
  integer, intent(in) :: n, m1, m2, np, mp, mpl
  real(8), intent(inout) :: a(*), al(*)
  integer, intent(out) :: indx(*)
  real(8), intent(out) :: d
  integer :: i
  error stop 'standalone: disabled legacy entry bandec'
end subroutine bandec

subroutine banbks(a, n, m1, m2, np, mp, al, mpl, indx, b)
  implicit none
  integer, intent(in) :: n, m1, m2, np, mp, mpl, indx(*)
  real(8), intent(in) :: a(*), al(*)
  real(8), intent(inout) :: b(*)
  error stop 'standalone: disabled legacy entry banbks'
end subroutine banbks

real(8) function afgen(table, n, x)
  implicit none
  integer, intent(in) :: n
  real(8), intent(in) :: table(*), x
  error stop 'standalone: disabled legacy entry afgen'
end function afgen

subroutine dtdpst(mode, time, text)
  implicit none
  character(len=*), intent(in) :: mode
  real(8), intent(in) :: time
  character(len=*), intent(out) :: text
  error stop 'standalone: disabled legacy entry dtdpst'
end subroutine dtdpst

subroutine swap_warning(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  write(*,'(A)') 'SWAP_WARNING: '//trim(origin)//': '//trim(message)
end subroutine swap_warning

subroutine swap_error(origin, message)
  implicit none
  character(len=*), intent(in) :: origin, message
  error stop 'standalone: disabled legacy entry swap_error'
end subroutine swap_error

