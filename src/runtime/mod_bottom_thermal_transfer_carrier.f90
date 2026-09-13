module mod_bottom_thermal_transfer_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: BTT_DONOR_NONE = 0
  integer, parameter, public :: BTT_DONOR_LOCAL_SOIL = 1
  integer, parameter, public :: BTT_DONOR_EXTERNAL = 2

  integer, parameter, public :: BTT_OK = 0
  integer, parameter, public :: BTT_NOT_INITIALIZED = 1
  integer, parameter, public :: BTT_INVALID_INTERVAL = 2
  integer, parameter, public :: BTT_INVALID_TRANSFER = 3
  integer, parameter, public :: BTT_INVALID_TEMPERATURE = 4
  integer, parameter, public :: BTT_CAPACITY_EXHAUSTED = 5

  type, public :: bottom_thermal_transfer_sample_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: oriented_water_amount_cm = 0.0_real64
    integer :: donor_kind = BTT_DONOR_NONE
    logical :: donor_thermal_complete = .false.
    logical :: start_temperature_available = .false.
    logical :: end_temperature_available = .false.
    real(real64) :: donor_temperature_start_c = 0.0_real64
    real(real64) :: donor_temperature_end_c = 0.0_real64
  contains
    procedure, public :: ready => bottom_thermal_sample_ready
  end type bottom_thermal_transfer_sample_t

  type, public :: bottom_thermal_transfer_carrier_t
    private
    type(bottom_thermal_transfer_sample_t), allocatable :: samples(:)
    integer :: used = 0
  contains
    procedure, public :: initialize => bottom_thermal_carrier_initialize
    procedure, public :: reset => bottom_thermal_carrier_reset
    procedure, public :: ready => bottom_thermal_carrier_ready
    procedure, public :: sample_count => bottom_thermal_carrier_sample_count
    procedure, public :: capacity => bottom_thermal_carrier_capacity
    procedure, public :: append_local_outward => bottom_thermal_carrier_append_local_outward
    procedure, public :: append_external_inward_incomplete => bottom_thermal_carrier_append_external_inward_incomplete
    procedure, public :: snapshot => bottom_thermal_carrier_snapshot
    procedure, public :: copy_to => bottom_thermal_carrier_copy_to
    procedure, public :: restore_from => bottom_thermal_carrier_restore_from
  end type bottom_thermal_transfer_carrier_t

contains

  subroutine bottom_thermal_carrier_initialize(self, max_samples, status)
    class(bottom_thermal_transfer_carrier_t), intent(inout) :: self
    integer, intent(in) :: max_samples
    integer, intent(out) :: status

    if (allocated(self%samples)) deallocate(self%samples)
    self%used = 0
    status = BTT_NOT_INITIALIZED
    if (max_samples <= 0) return
    allocate(self%samples(max_samples))
    status = BTT_OK
  end subroutine bottom_thermal_carrier_initialize

  subroutine bottom_thermal_carrier_reset(self)
    class(bottom_thermal_transfer_carrier_t), intent(inout) :: self
    self%used = 0
  end subroutine bottom_thermal_carrier_reset

  logical function bottom_thermal_carrier_ready(self) result(is_ready)
    class(bottom_thermal_transfer_carrier_t), intent(in) :: self
    is_ready = allocated(self%samples) .and. size(self%samples) > 0 .and. &
         self%used >= 0 .and. self%used <= size(self%samples)
  end function bottom_thermal_carrier_ready

  integer function bottom_thermal_carrier_sample_count(self) result(count)
    class(bottom_thermal_transfer_carrier_t), intent(in) :: self
    count = self%used
  end function bottom_thermal_carrier_sample_count

  integer function bottom_thermal_carrier_capacity(self) result(value)
    class(bottom_thermal_transfer_carrier_t), intent(in) :: self
    value = 0
    if (allocated(self%samples)) value = size(self%samples)
  end function bottom_thermal_carrier_capacity

  subroutine bottom_thermal_carrier_append_local_outward(self, t0, t1, oriented_water_amount_cm, &
       donor_temperature_start_c, donor_temperature_end_c, status)
    class(bottom_thermal_transfer_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, oriented_water_amount_cm
    real(real64), intent(in) :: donor_temperature_start_c, donor_temperature_end_c
    integer, intent(out) :: status
    type(bottom_thermal_transfer_sample_t) :: sample

    status = BTT_NOT_INITIALIZED
    if (.not. self%ready()) return
    status = BTT_INVALID_INTERVAL
    if (.not. valid_interval(t0, t1)) return
    status = BTT_INVALID_TRANSFER
    if (.not. ieee_is_finite(oriented_water_amount_cm) .or. oriented_water_amount_cm < 0.0_real64) return
    if (oriented_water_amount_cm == 0.0_real64) then
      status = BTT_OK
      return
    end if
    status = BTT_INVALID_TEMPERATURE
    if (.not. ieee_is_finite(donor_temperature_start_c) .or. &
        .not. ieee_is_finite(donor_temperature_end_c)) return
    status = BTT_CAPACITY_EXHAUSTED
    if (self%used >= size(self%samples)) return

    sample%t0 = t0
    sample%t1 = t1
    sample%oriented_water_amount_cm = oriented_water_amount_cm
    sample%donor_kind = BTT_DONOR_LOCAL_SOIL
    sample%donor_thermal_complete = .true.
    sample%start_temperature_available = .true.
    sample%end_temperature_available = .true.
    sample%donor_temperature_start_c = donor_temperature_start_c
    sample%donor_temperature_end_c = donor_temperature_end_c
    self%used = self%used + 1
    self%samples(self%used) = sample
    status = BTT_OK
  end subroutine bottom_thermal_carrier_append_local_outward

  subroutine bottom_thermal_carrier_append_external_inward_incomplete(self, t0, t1, oriented_water_amount_cm, status)
    class(bottom_thermal_transfer_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, oriented_water_amount_cm
    integer, intent(out) :: status
    type(bottom_thermal_transfer_sample_t) :: sample

    status = BTT_NOT_INITIALIZED
    if (.not. self%ready()) return
    status = BTT_INVALID_INTERVAL
    if (.not. valid_interval(t0, t1)) return
    status = BTT_INVALID_TRANSFER
    if (.not. ieee_is_finite(oriented_water_amount_cm) .or. oriented_water_amount_cm > 0.0_real64) return
    if (oriented_water_amount_cm == 0.0_real64) then
      status = BTT_OK
      return
    end if
    status = BTT_CAPACITY_EXHAUSTED
    if (self%used >= size(self%samples)) return

    sample%t0 = t0
    sample%t1 = t1
    sample%oriented_water_amount_cm = oriented_water_amount_cm
    sample%donor_kind = BTT_DONOR_EXTERNAL
    sample%donor_thermal_complete = .false.
    sample%start_temperature_available = .false.
    sample%end_temperature_available = .false.
    self%used = self%used + 1
    self%samples(self%used) = sample
    status = BTT_OK
  end subroutine bottom_thermal_carrier_append_external_inward_incomplete

  subroutine bottom_thermal_carrier_snapshot(self, values, status)
    class(bottom_thermal_transfer_carrier_t), intent(in) :: self
    type(bottom_thermal_transfer_sample_t), allocatable, intent(out) :: values(:)
    integer, intent(out) :: status

    status = BTT_NOT_INITIALIZED
    allocate(values(0))
    if (.not. self%ready()) return
    deallocate(values)
    allocate(values(self%used))
    if (self%used > 0) values = self%samples(1:self%used)
    status = BTT_OK
  end subroutine bottom_thermal_carrier_snapshot

  subroutine bottom_thermal_carrier_copy_to(self, target, status)
    class(bottom_thermal_transfer_carrier_t), intent(in) :: self
    type(bottom_thermal_transfer_carrier_t), intent(out) :: target
    integer, intent(out) :: status

    status = BTT_NOT_INITIALIZED
    if (.not. self%ready()) return
    allocate(target%samples(size(self%samples)))
    target%samples = self%samples
    target%used = self%used
    status = BTT_OK
  end subroutine bottom_thermal_carrier_copy_to

  subroutine bottom_thermal_carrier_restore_from(self, source, status)
    class(bottom_thermal_transfer_carrier_t), intent(inout) :: self
    type(bottom_thermal_transfer_carrier_t), intent(in) :: source
    integer, intent(out) :: status

    status = BTT_NOT_INITIALIZED
    if (.not. source%ready()) return
    if (allocated(self%samples)) deallocate(self%samples)
    allocate(self%samples(size(source%samples)))
    self%samples = source%samples
    self%used = source%used
    status = BTT_OK
  end subroutine bottom_thermal_carrier_restore_from

  logical function bottom_thermal_sample_ready(self) result(is_ready)
    class(bottom_thermal_transfer_sample_t), intent(in) :: self

    is_ready = valid_interval(self%t0, self%t1) .and. ieee_is_finite(self%oriented_water_amount_cm)
    if (.not. is_ready) return
    select case (self%donor_kind)
    case (BTT_DONOR_LOCAL_SOIL)
      is_ready = self%oriented_water_amount_cm > 0.0_real64 .and. self%donor_thermal_complete .and. &
           self%start_temperature_available .and. self%end_temperature_available .and. &
           ieee_is_finite(self%donor_temperature_start_c) .and. ieee_is_finite(self%donor_temperature_end_c)
    case (BTT_DONOR_EXTERNAL)
      is_ready = self%oriented_water_amount_cm < 0.0_real64 .and. .not. self%donor_thermal_complete .and. &
           .not. self%start_temperature_available .and. .not. self%end_temperature_available
    case default
      is_ready = .false.
    end select
  end function bottom_thermal_sample_ready

  logical function valid_interval(t0, t1) result(valid)
    real(real64), intent(in) :: t0, t1
    valid = ieee_is_finite(t0) .and. ieee_is_finite(t1) .and. t1 > t0
  end function valid_interval

end module mod_bottom_thermal_transfer_carrier
