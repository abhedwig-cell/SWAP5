module mod_b110_generated_mvg_provider_owner
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t
  use mod_b110_generated_mvg_table_state, only: b110_generated_mvg_table_state_t, &
       initialize_b110_generated_mvg_table_state, F_TAB02_STATE_OK
  use mod_b110_generated_mvg_provider, only: b110_generated_mvg_provider_t, &
       bind_b110_generated_mvg_provider, F_TAB02_PROVIDER_OK
  implicit none
  private

  integer, parameter, public :: F_TAB02_OWNER_OK = 0
  integer, parameter, public :: F_TAB02_OWNER_INACTIVE = 1
  integer, parameter, public :: F_TAB02_OWNER_STATE_FAILED = 2
  integer, parameter, public :: F_TAB02_OWNER_BIND_FAILED = 3

  type, public :: b110_generated_mvg_provider_owner_t
    private
    logical :: selected = .false.
    integer(int64) :: parameter_set_id = 0_int64
    integer :: generation_counter = 0
    type(b110_generated_mvg_table_state_t), pointer :: table_state => null()
    type(b110_generated_mvg_provider_t), pointer :: provider => null()
  contains
    procedure :: configure => generated_owner_configure
    procedure :: bind_step => generated_owner_bind_step
    procedure :: provider_pointer => generated_owner_provider_pointer
    procedure :: active => generated_owner_active
    procedure :: bound_parameter_set_id => generated_owner_parameter_set_id
    procedure :: generation_count => generated_owner_generation_count
    procedure :: close => generated_owner_close
  end type b110_generated_mvg_provider_owner_t

contains

  subroutine generated_owner_configure(self, select_generated, parameter_set_id, parameters, status)
    class(b110_generated_mvg_provider_owner_t), intent(inout) :: self
    logical, intent(in) :: select_generated
    integer(int64), intent(in) :: parameter_set_id
    type(b110_default_mvg_parameters_t), intent(in) :: parameters
    integer, intent(out) :: status
    integer :: state_status

    status = F_TAB02_OWNER_INACTIVE

    if (.not. select_generated) then
      call discard_generated_state(self)
      return
    end if

    if (parameter_set_id <= 0_int64) then
      call discard_generated_state(self)
      status = F_TAB02_OWNER_STATE_FAILED
      return
    end if

    ! Immutable state is reused when the typed parameter authority identity is
    ! unchanged. Trial/retry reconfiguration must not rebuild the table.
    if (self%selected .and. self%parameter_set_id == parameter_set_id .and. &
        associated(self%table_state)) then
      if (self%table_state%ready()) then
        status = F_TAB02_OWNER_OK
        return
      end if
    end if

    call discard_generated_state(self)

    allocate(self%table_state)
    call initialize_b110_generated_mvg_table_state(self%table_state, parameters, state_status)
    if (state_status /= F_TAB02_STATE_OK .or. .not. self%table_state%ready()) then
      if (associated(self%table_state)) deallocate(self%table_state)
      nullify(self%table_state)
      status = F_TAB02_OWNER_STATE_FAILED
      return
    end if

    self%selected = .true.
    self%parameter_set_id = parameter_set_id
    self%generation_counter = self%generation_counter + 1
    status = F_TAB02_OWNER_OK
  end subroutine generated_owner_configure

  subroutine generated_owner_bind_step(self, step_duration, status)
    class(b110_generated_mvg_provider_owner_t), intent(inout) :: self
    real(real64), intent(in) :: step_duration
    integer, intent(out) :: status
    integer :: provider_status

    status = F_TAB02_OWNER_INACTIVE
    if (.not. self%selected .or. .not. associated(self%table_state)) return
    if (.not. self%table_state%ready()) then
      status = F_TAB02_OWNER_STATE_FAILED
      return
    end if

    if (.not. associated(self%provider)) allocate(self%provider)
    call bind_b110_generated_mvg_provider(self%provider, self%table_state, step_duration, provider_status)
    if (provider_status /= F_TAB02_PROVIDER_OK .or. .not. self%provider%ready()) then
      if (associated(self%provider)) deallocate(self%provider)
      nullify(self%provider)
      status = F_TAB02_OWNER_BIND_FAILED
      return
    end if
    status = F_TAB02_OWNER_OK
  end subroutine generated_owner_bind_step

  subroutine generated_owner_provider_pointer(self, provider, status)
    class(b110_generated_mvg_provider_owner_t), intent(in), target :: self
    class(constitutive_hydraulics_provider_t), pointer, intent(out) :: provider
    integer, intent(out) :: status

    nullify(provider)
    status = F_TAB02_OWNER_INACTIVE
    if (.not. self%selected .or. .not. associated(self%provider)) return
    if (.not. self%provider%ready()) then
      status = F_TAB02_OWNER_BIND_FAILED
      return
    end if
    provider => self%provider
    status = F_TAB02_OWNER_OK
  end subroutine generated_owner_provider_pointer

  logical function generated_owner_active(self) result(active)
    class(b110_generated_mvg_provider_owner_t), intent(in) :: self
    active = self%selected .and. associated(self%table_state)
    if (active) active = self%table_state%ready()
  end function generated_owner_active

  integer(int64) function generated_owner_parameter_set_id(self) result(value)
    class(b110_generated_mvg_provider_owner_t), intent(in) :: self
    value = 0_int64
    if (self%active()) value = self%parameter_set_id
  end function generated_owner_parameter_set_id

  integer function generated_owner_generation_count(self) result(value)
    class(b110_generated_mvg_provider_owner_t), intent(in) :: self
    value = self%generation_counter
  end function generated_owner_generation_count

  subroutine generated_owner_close(self)
    class(b110_generated_mvg_provider_owner_t), intent(inout) :: self
    call discard_generated_state(self)
    self%generation_counter = 0
  end subroutine generated_owner_close

  subroutine discard_generated_state(self)
    class(b110_generated_mvg_provider_owner_t), intent(inout) :: self
    ! The provider contains a pointer into table_state, so retire it first.
    if (associated(self%provider)) deallocate(self%provider)
    nullify(self%provider)
    if (associated(self%table_state)) deallocate(self%table_state)
    nullify(self%table_state)
    self%selected = .false.
    self%parameter_set_id = 0_int64
  end subroutine discard_generated_state

end module mod_b110_generated_mvg_provider_owner
