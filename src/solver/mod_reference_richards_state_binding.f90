module mod_reference_richards_state_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_solve_request_t
  implicit none
  private

  type, public :: reference_richards_state_binding_t
     integer :: active_nodes = 0
     real(real64), allocatable :: h(:)
     real(real64), allocatable :: theta(:)
     real(real64), allocatable :: hm1(:)
     real(real64), allocatable :: thetm1(:)
     real(real64), allocatable :: k(:)
     real(real64), allocatable :: kmean(:)
     real(real64), allocatable :: dimoca(:)
     real(real64) :: pond = 0.0_real64
     real(real64) :: pondm1 = 0.0_real64
     real(real64) :: gwl = 0.0_real64
     real(real64) :: gwlm1 = 0.0_real64
     real(real64) :: gwlinp = 0.0_real64
     real(real64) :: dtold = 0.0_real64
     real(real64) :: qtop = 0.0_real64
     real(real64) :: qbot = 0.0_real64
     real(real64) :: hbot = 0.0_real64
     real(real64) :: q0 = 0.0_real64
     real(real64) :: hsurf = 0.0_real64
     real(real64) :: runots = 0.0_real64
     integer, allocatable :: itnumb(:,:)
     integer :: numbit = 0
     logical :: fllowgwl = .false.
     logical :: fldecdt = .false.
     logical :: flrunoff = .false.
     logical :: ftoph = .false.
  end type reference_richards_state_binding_t

  public :: initialize_reference_state_binding
  public :: validate_reference_state_binding

contains

  subroutine ensure_shape(state, n)
    type(reference_richards_state_binding_t), intent(inout) :: state
    integer, intent(in) :: n

    if (n <= 0) error stop 'reference state binding: active_nodes must be positive'
    if (allocated(state%h)) then
       if (size(state%h) == n .and. allocated(state%theta) .and. allocated(state%hm1) .and. &
           allocated(state%thetm1) .and. allocated(state%k) .and. allocated(state%kmean) .and. &
           allocated(state%dimoca) .and. allocated(state%itnumb)) then
          if (size(state%theta) == n .and. size(state%hm1) == n .and. size(state%thetm1) == n .and. &
              size(state%k) == n .and. size(state%kmean) == n+1 .and. size(state%dimoca) == n .and. &
              size(state%itnumb,1) == 100 .and. size(state%itnumb,2) == 2) return
       end if
       if (allocated(state%h)) deallocate(state%h)
       if (allocated(state%theta)) deallocate(state%theta)
       if (allocated(state%hm1)) deallocate(state%hm1)
       if (allocated(state%thetm1)) deallocate(state%thetm1)
       if (allocated(state%k)) deallocate(state%k)
       if (allocated(state%kmean)) deallocate(state%kmean)
       if (allocated(state%dimoca)) deallocate(state%dimoca)
       if (allocated(state%itnumb)) deallocate(state%itnumb)
    end if
    allocate(state%h(n), state%theta(n), state%hm1(n), state%thetm1(n))
    allocate(state%k(n), state%kmean(n+1), state%dimoca(n))
    allocate(state%itnumb(100,2))
  end subroutine ensure_shape

  subroutine initialize_reference_state_binding(state, request)
    type(reference_richards_state_binding_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(in) :: request
    integer :: n

    if (.not. associated(request%parameters)) error stop 'reference state binding: missing parameters'
    n = request%parameters%active_nodes
    if (request%base_state%active_nodes /= n) error stop 'reference state binding: state shape mismatch'
    if (.not. allocated(request%base_state%pressure_head) .or. &
        .not. allocated(request%base_state%water_content)) then
       error stop 'reference state binding: incomplete base state'
    end if
    if (size(request%base_state%pressure_head) /= n .or. &
        size(request%base_state%water_content) /= n) then
       error stop 'reference state binding: base arrays have wrong shape'
    end if

    call ensure_shape(state, n)
    state%active_nodes = n
    state%h = request%base_state%pressure_head
    state%theta = request%base_state%water_content
    state%hm1 = request%base_state%pressure_head
    state%thetm1 = request%base_state%water_content
    state%pond = request%base_state%ponding_depth
    state%pondm1 = request%base_state%ponding_depth
    state%gwl = request%base_state%groundwater_level
    state%gwlm1 = request%base_state%groundwater_level
    state%gwlinp = request%boundary%bottom_head
    state%hbot = request%boundary%bottom_head
    state%dtold = request%step_duration
    state%qtop = request%boundary%top_flux
    state%qbot = request%boundary%bottom_flux
    state%k = 0.0_real64
    state%kmean = 0.0_real64
    state%dimoca = 0.0_real64
    state%itnumb = 0
    state%numbit = 0
    state%fllowgwl = .false.
    state%fldecdt = .false.
    state%q0 = 0.0_real64
    state%hsurf = request%boundary%top_head
    state%runots = 0.0_real64
    state%flrunoff = .false.
    state%ftoph = .false.
  end subroutine initialize_reference_state_binding

  subroutine validate_reference_state_binding(state, ok)
    type(reference_richards_state_binding_t), intent(in) :: state
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = state%active_nodes
    if (n <= 0) return
    if (.not. allocated(state%h) .or. .not. allocated(state%theta) .or. &
        .not. allocated(state%hm1) .or. .not. allocated(state%thetm1)) return
    if (.not. allocated(state%k) .or. .not. allocated(state%kmean) .or. &
        .not. allocated(state%dimoca) .or. .not. allocated(state%itnumb)) return
    if (size(state%h) /= n .or. size(state%theta) /= n .or. size(state%hm1) /= n .or. &
        size(state%thetm1) /= n .or. size(state%k) /= n .or. size(state%kmean) /= n+1 .or. &
        size(state%dimoca) /= n) return
    if (size(state%itnumb,1) /= 100 .or. size(state%itnumb,2) /= 2) return
    ok = .true.
  end subroutine validate_reference_state_binding

end module mod_reference_richards_state_binding
