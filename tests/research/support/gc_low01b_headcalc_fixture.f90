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
  real(8), parameter :: z(numnod) = [-25.0d0, -75.0d0, -150.0d0, -250.0d0]
  real(8), parameter :: dz(numnod) = [50.0d0, 50.0d0, 100.0d0, 100.0d0]
  real(8), parameter :: disnod(numnod+1) = [25.0d0, 50.0d0, 75.0d0, 100.0d0, 50.0d0]
end module MOD_grid

module variables
  use MOD_grid, only: numnod
  implicit none
  logical :: fldaystart = .false.
  integer :: swbotb = 7
  real(8) :: runon = 0.0d0, epd = 0.0d0, reva = 0.0d0, pondm1 = 0.0d0
  real(8) :: dt = 1.0d0, runots = 0.0d0, t1900 = 1000.0d0
  real(8) :: thetm1(numnod) = 0.40d0, qrot(numnod) = 0.0d0
  integer :: swkimpl = 0, swkmean = 1
  real(8) :: hplate = 0.0d0
  integer :: swbotb3impl = 0, swbotb3resvert = 0
  real(8) :: deepgw = -1000.0d0, rimlay = 1.0d0
  integer :: sw4 = 0
  real(8) :: qbotab(2*4) = 0.0d0
  logical :: fldtmin = .false.
  integer :: maxit = 20, maxbacktr = 8
  real(8) :: critdevh2cp = 1.0d-12, critdevh1cp = 1.0d-12, critdevponddt = 1.0d-12
  real(8) :: dtmin = 1.0d-8
  integer :: nodgwl = numnod
  real(8) :: gwlm1 = -200.0d0, hm1(numnod) = 0.0d0
  real(8) :: CritDevBalCp = 1.0d-12, CritDevBalTot = 1.0d-12
  real(8) :: h(numnod) = 0.0d0, theta(numnod) = 0.40d0
  real(8) :: kmean(numnod+1) = 1.0d0, gwlinp = -200.0d0, pond = 0.0d0
  real(8) :: dtold = 1.0d0, qtop = 0.0d0, qbot = 0.0d0, hbot = 0.0d0
  integer :: itnumb(100,2) = 0
  logical :: fllowgwl = .false.
  real(8) :: k(numnod) = 1.0d0, dimoca(numnod) = 0.0d0
  integer :: numbit = 0
  logical :: fldecdt = .false.
  real(8) :: gwl = -200.0d0
end module variables

module MOD_MvG
  implicit none
contains
  pure real(8) function theta_sat(node)
    integer, intent(in) :: node
    theta_sat = 0.40d0 + 0.005d0*real(node-1,8)
  end function theta_sat

  real(8) function watcon(node, head)
    integer, intent(in) :: node
    real(8), intent(in) :: head
    if (head > huge(head)) error stop 'invalid watcon head'
    watcon = theta_sat(node)
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
    if (node < 1) error stop 'invalid cofgen node'
    select case(mode)
    case(2)
      cofgen = theta_sat(node)
    case(3)
      cofgen = 1.0d0
    case default
      cofgen = theta_sat(node)
    end select
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
    qtop = 0.0d0
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
  text = 'low01b-time'
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
  error stop 'unexpected swap_error in LOW01-B fixture'
end subroutine swap_error

module mod_gc_low01b_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       top_boundary_provider_t, soil_water_boundary_conditions_t
  use MOD_MvG, only: theta_sat
  implicit none
  type, extends(constitutive_hydraulics_provider_t) :: low01b_constitutive_t
  contains
    procedure :: evaluate => low01b_constitutive_evaluate
  end type
  type, extends(source_sink_provider_t) :: low01b_source_sink_t
  contains
    procedure :: evaluate => low01b_source_sink_evaluate
  end type
  type, extends(top_boundary_provider_t) :: low01b_top_t
  contains
    procedure :: evaluate => low01b_top_evaluate
  end type
contains
  subroutine low01b_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(low01b_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i
    if (.not.same_type_as(self,self)) error stop 'invalid provider self'
    do i=1,size(pressure_head)
      water_content(i)=theta_sat(i)
    end do
    conductivity=1.0_real64
    capacity=0.0_real64
    dconductivity_dhead=0.0_real64
  end subroutine
  subroutine low01b_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(low01b_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (.not.same_type_as(self,self) .or. size(pressure_head)/=size(water_content)) error stop 'invalid source provider'
    source=0.0_real64
    sink=0.0_real64
  end subroutine
  subroutine low01b_top_evaluate(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(low01b_top_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (.not.same_type_as(self,self) .or. pressure_head_top > huge(pressure_head_top) .or. &
        water_content_top < -huge(water_content_top)) error stop 'invalid top provider'
    actual_top_flux=requested%top_flux
    surface_head=requested%top_head
    runoff_flux=0.0_real64
  end subroutine
end module mod_gc_low01b_providers
