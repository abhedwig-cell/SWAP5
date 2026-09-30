module mod_macropore_continuation_state
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  type, public :: macropore_continuation_state_t
    integer :: num_domains = 0
    integer :: num_nodes = 0
    integer, allocatable :: icp_bottom_domain(:)
    real(real64), allocatable :: sorptivity(:,:)
    real(real64), allocatable :: theta_sorption_ref(:,:)
    real(real64), allocatable :: absorption_time(:,:)
    real(real64), allocatable :: volume_domain_cp(:,:)
    real(real64), allocatable :: water_domain_cp(:,:)
    real(real64), allocatable :: dynamic_volume_cp(:)
  contains
    procedure, public :: initialize => macropore_state_initialize
    procedure, public :: clear => macropore_state_clear
    procedure, public :: ready => macropore_state_ready
    procedure, public :: same_values => macropore_state_same_values
    procedure, public :: payload_bytes => macropore_state_payload_bytes
  end type macropore_continuation_state_t

  public :: copy_macropore_continuation_state

contains

  subroutine macropore_state_initialize(self, num_domains, num_nodes, ok)
    class(macropore_continuation_state_t), intent(inout) :: self
    integer, intent(in) :: num_domains, num_nodes
    logical, intent(out) :: ok

    ok = .false.
    call self%clear()
    if (num_domains <= 0 .or. num_nodes <= 0) return

    allocate(self%icp_bottom_domain(num_domains))
    allocate(self%sorptivity(num_domains,num_nodes))
    allocate(self%theta_sorption_ref(num_domains,num_nodes))
    allocate(self%absorption_time(num_domains,num_nodes))
    allocate(self%volume_domain_cp(num_domains,num_nodes))
    allocate(self%water_domain_cp(num_domains,num_nodes))
    allocate(self%dynamic_volume_cp(num_nodes))

    self%num_domains = num_domains
    self%num_nodes = num_nodes
    self%icp_bottom_domain = 0
    self%sorptivity = 0.0_real64
    self%theta_sorption_ref = 0.0_real64
    self%absorption_time = 0.0_real64
    self%volume_domain_cp = 0.0_real64
    self%water_domain_cp = 0.0_real64
    self%dynamic_volume_cp = 0.0_real64
    ok = .true.
  end subroutine macropore_state_initialize

  subroutine macropore_state_clear(self)
    class(macropore_continuation_state_t), intent(inout) :: self
    if (allocated(self%icp_bottom_domain)) deallocate(self%icp_bottom_domain)
    if (allocated(self%sorptivity)) deallocate(self%sorptivity)
    if (allocated(self%theta_sorption_ref)) deallocate(self%theta_sorption_ref)
    if (allocated(self%absorption_time)) deallocate(self%absorption_time)
    if (allocated(self%volume_domain_cp)) deallocate(self%volume_domain_cp)
    if (allocated(self%water_domain_cp)) deallocate(self%water_domain_cp)
    if (allocated(self%dynamic_volume_cp)) deallocate(self%dynamic_volume_cp)
    self%num_domains = 0
    self%num_nodes = 0
  end subroutine macropore_state_clear

  pure logical function macropore_state_ready(self) result(ready)
    class(macropore_continuation_state_t), intent(in) :: self

    ready = self%num_domains > 0 .and. self%num_nodes > 0
    if (.not. ready) return
    ready = allocated(self%icp_bottom_domain) .and. allocated(self%sorptivity) .and. &
         allocated(self%theta_sorption_ref) .and. allocated(self%absorption_time) .and. &
         allocated(self%volume_domain_cp) .and. allocated(self%water_domain_cp) .and. &
         allocated(self%dynamic_volume_cp)
    if (.not. ready) return
    ready = size(self%icp_bottom_domain) == self%num_domains .and. &
         all(shape(self%sorptivity) == [self%num_domains,self%num_nodes]) .and. &
         all(shape(self%theta_sorption_ref) == [self%num_domains,self%num_nodes]) .and. &
         all(shape(self%absorption_time) == [self%num_domains,self%num_nodes]) .and. &
         all(shape(self%volume_domain_cp) == [self%num_domains,self%num_nodes]) .and. &
         all(shape(self%water_domain_cp) == [self%num_domains,self%num_nodes]) .and. &
         size(self%dynamic_volume_cp) == self%num_nodes
  end function macropore_state_ready

  logical function macropore_state_same_values(self, other) result(same)
    class(macropore_continuation_state_t), intent(in) :: self
    type(macropore_continuation_state_t), intent(in) :: other

    same = self%ready() .and. other%ready()
    if (.not. same) return
    same = self%num_domains == other%num_domains .and. self%num_nodes == other%num_nodes
    if (.not. same) return
    same = all(self%icp_bottom_domain == other%icp_bottom_domain) .and. &
         all(self%sorptivity == other%sorptivity) .and. &
         all(self%theta_sorption_ref == other%theta_sorption_ref) .and. &
         all(self%absorption_time == other%absorption_time) .and. &
         all(self%volume_domain_cp == other%volume_domain_cp) .and. &
         all(self%water_domain_cp == other%water_domain_cp) .and. &
         all(self%dynamic_volume_cp == other%dynamic_volume_cp)
  end function macropore_state_same_values

  integer(int64) function macropore_state_payload_bytes(self) result(bytes)
    class(macropore_continuation_state_t), intent(in) :: self
    bytes = 0_int64
    if (allocated(self%icp_bottom_domain)) bytes = bytes + &
         int(storage_size(0)/8,int64)*size(self%icp_bottom_domain,kind=int64)
    if (allocated(self%sorptivity)) bytes = bytes + 8_int64*size(self%sorptivity,kind=int64)
    if (allocated(self%theta_sorption_ref)) bytes = bytes + 8_int64*size(self%theta_sorption_ref,kind=int64)
    if (allocated(self%absorption_time)) bytes = bytes + 8_int64*size(self%absorption_time,kind=int64)
    if (allocated(self%volume_domain_cp)) bytes = bytes + 8_int64*size(self%volume_domain_cp,kind=int64)
    if (allocated(self%water_domain_cp)) bytes = bytes + 8_int64*size(self%water_domain_cp,kind=int64)
    if (allocated(self%dynamic_volume_cp)) bytes = bytes + 8_int64*size(self%dynamic_volume_cp,kind=int64)
  end function macropore_state_payload_bytes

  subroutine copy_macropore_continuation_state(source, target, ok)
    type(macropore_continuation_state_t), intent(in) :: source
    type(macropore_continuation_state_t), intent(inout) :: target
    logical, intent(out) :: ok

    ok = .false.
    call target%clear()
    if (.not. source%ready()) return
    target = source
    ok = target%ready()
  end subroutine copy_macropore_continuation_state

end module mod_macropore_continuation_state
