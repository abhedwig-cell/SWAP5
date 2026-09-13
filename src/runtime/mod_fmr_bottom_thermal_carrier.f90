module mod_fmr_bottom_thermal_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FMR_BOTTOM_THERMAL_DONOR_NONE = 0
  integer, parameter, public :: FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP = 1
  integer, parameter, public :: FMR_BOTTOM_THERMAL_DONOR_EXTERNAL = 2

  type, public :: fmr_bottom_thermal_sample_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: bottom_outward_exchange_native = 0.0_real64
    integer :: donor_class = FMR_BOTTOM_THERMAL_DONOR_NONE
    logical :: donor_thermal_complete = .false.
    real(real64) :: local_start_temperature_c = 0.0_real64
    real(real64) :: local_end_temperature_c = 0.0_real64
  end type fmr_bottom_thermal_sample_t

  type, public :: fmr_bottom_thermal_candidate_t
    private
    logical :: initialized = .false.
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    type(fmr_bottom_thermal_sample_t), allocatable :: samples(:)
  contains
    procedure, public :: ready => candidate_ready
    procedure, public :: sample_count => candidate_sample_count
    procedure, public :: sample_at => candidate_sample_at
    procedure, public :: thermal_complete => candidate_thermal_complete
    procedure, public :: interval => candidate_interval
  end type fmr_bottom_thermal_candidate_t

  type, public :: fmr_bottom_thermal_carrier_t
    private
    logical :: initialized = .false.
    integer :: capacity = 0
    integer :: count = 0
    type(fmr_bottom_thermal_sample_t), allocatable :: samples(:)
  contains
    procedure, public :: initialize => carrier_initialize
    procedure, public :: clear => carrier_clear
    procedure, public :: append_local => carrier_append_local
    procedure, public :: append_external_incomplete => carrier_append_external_incomplete
    procedure, public :: append_zero => carrier_append_zero
    procedure, public :: sample_count => carrier_sample_count
    procedure, public :: copy_to => carrier_copy_to
    procedure, public :: restore_from => carrier_restore_from
    procedure, public :: materialize_candidate => carrier_materialize_candidate
  end type fmr_bottom_thermal_carrier_t

contains

  subroutine carrier_initialize(self, max_samples, ok)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    integer, intent(in) :: max_samples
    logical, intent(out) :: ok

    call self%clear()
    ok = .false.
    if (max_samples <= 0) return
    allocate(self%samples(max_samples))
    self%capacity = max_samples
    self%count = 0
    self%initialized = .true.
    ok = .true.
  end subroutine carrier_initialize

  subroutine carrier_clear(self)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    if (allocated(self%samples)) deallocate(self%samples)
    self%initialized = .false.
    self%capacity = 0
    self%count = 0
  end subroutine carrier_clear

  subroutine carrier_append_local(self, t0, t1, outward_exchange, start_temperature_c, end_temperature_c, ok)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, outward_exchange, start_temperature_c, end_temperature_c
    logical, intent(out) :: ok
    type(fmr_bottom_thermal_sample_t) :: sample

    ok = .false.
    if (outward_exchange <= 0.0_real64) return
    if (.not. ieee_is_finite(start_temperature_c) .or. .not. ieee_is_finite(end_temperature_c)) return
    sample%t0 = t0
    sample%t1 = t1
    sample%bottom_outward_exchange_native = outward_exchange
    sample%donor_class = FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP
    sample%donor_thermal_complete = .true.
    sample%local_start_temperature_c = start_temperature_c
    sample%local_end_temperature_c = end_temperature_c
    call append_sample(self, sample, ok)
  end subroutine carrier_append_local

  subroutine carrier_append_external_incomplete(self, t0, t1, outward_exchange, ok)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, outward_exchange
    logical, intent(out) :: ok
    type(fmr_bottom_thermal_sample_t) :: sample

    ok = .false.
    if (outward_exchange >= 0.0_real64) return
    sample%t0 = t0
    sample%t1 = t1
    sample%bottom_outward_exchange_native = outward_exchange
    sample%donor_class = FMR_BOTTOM_THERMAL_DONOR_EXTERNAL
    sample%donor_thermal_complete = .false.
    call append_sample(self, sample, ok)
  end subroutine carrier_append_external_incomplete

  subroutine carrier_append_zero(self, t0, t1, ok)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1
    logical, intent(out) :: ok
    type(fmr_bottom_thermal_sample_t) :: sample

    sample%t0 = t0
    sample%t1 = t1
    sample%bottom_outward_exchange_native = 0.0_real64
    sample%donor_class = FMR_BOTTOM_THERMAL_DONOR_NONE
    sample%donor_thermal_complete = .true.
    call append_sample(self, sample, ok)
  end subroutine carrier_append_zero

  subroutine append_sample(self, sample, ok)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    type(fmr_bottom_thermal_sample_t), intent(in) :: sample
    logical, intent(out) :: ok

    ok = .false.
    if (.not. self%initialized .or. .not. allocated(self%samples)) return
    if (self%count < 0 .or. self%count >= self%capacity) return
    if (.not. sample_is_valid(sample)) return
    self%count = self%count + 1
    self%samples(self%count) = sample
    ok = .true.
  end subroutine append_sample

  integer function carrier_sample_count(self) result(n)
    class(fmr_bottom_thermal_carrier_t), intent(in) :: self
    n = 0
    if (self%initialized) n = self%count
  end function carrier_sample_count

  subroutine carrier_copy_to(self, target)
    class(fmr_bottom_thermal_carrier_t), intent(in) :: self
    type(fmr_bottom_thermal_carrier_t), intent(out) :: target

    call target%clear()
    if (.not. self%initialized) return
    if (.not. allocated(self%samples) .or. self%capacity <= 0 .or. self%count < 0 .or. self%count > self%capacity) return
    allocate(target%samples(self%capacity))
    target%samples = self%samples
    target%capacity = self%capacity
    target%count = self%count
    target%initialized = .true.
  end subroutine carrier_copy_to

  subroutine carrier_restore_from(self, source)
    class(fmr_bottom_thermal_carrier_t), intent(inout) :: self
    type(fmr_bottom_thermal_carrier_t), intent(in) :: source
    call source%copy_to(self)
  end subroutine carrier_restore_from

  subroutine carrier_materialize_candidate(self, requested_t0, requested_t1, candidate, ok)
    class(fmr_bottom_thermal_carrier_t), intent(in) :: self
    real(real64), intent(in) :: requested_t0, requested_t1
    type(fmr_bottom_thermal_candidate_t), intent(out) :: candidate
    logical, intent(out) :: ok
    integer :: i

    candidate = fmr_bottom_thermal_candidate_t()
    ok = .false.
    if (.not. self%initialized .or. self%count <= 0 .or. .not. allocated(self%samples)) return
    if (.not. ieee_is_finite(requested_t0) .or. .not. ieee_is_finite(requested_t1) .or. requested_t1 <= requested_t0) return
    if (.not. same_time(self%samples(1)%t0, requested_t0)) return
    if (.not. same_time(self%samples(self%count)%t1, requested_t1)) return
    do i = 1, self%count
      if (.not. sample_is_valid(self%samples(i))) return
      if (i > 1) then
        if (.not. same_time(self%samples(i-1)%t1, self%samples(i)%t0)) return
      end if
    end do
    allocate(candidate%samples(self%count))
    candidate%samples = self%samples(1:self%count)
    candidate%t0_value = requested_t0
    candidate%t1_value = requested_t1
    candidate%initialized = .true.
    ok = .true.
  end subroutine carrier_materialize_candidate

  logical function candidate_ready(self) result(ready)
    class(fmr_bottom_thermal_candidate_t), intent(in) :: self
    integer :: i

    ready = self%initialized .and. allocated(self%samples) .and. size(self%samples) > 0 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value
    if (.not. ready) return
    if (.not. same_time(self%samples(1)%t0, self%t0_value)) then
      ready = .false.
      return
    end if
    if (.not. same_time(self%samples(size(self%samples))%t1, self%t1_value)) then
      ready = .false.
      return
    end if
    do i = 1, size(self%samples)
      if (.not. sample_is_valid(self%samples(i))) then
        ready = .false.
        return
      end if
      if (i > 1) then
        if (.not. same_time(self%samples(i-1)%t1, self%samples(i)%t0)) then
          ready = .false.
          return
        end if
      end if
    end do
  end function candidate_ready

  integer function candidate_sample_count(self) result(n)
    class(fmr_bottom_thermal_candidate_t), intent(in) :: self
    n = 0
    if (self%ready()) n = size(self%samples)
  end function candidate_sample_count

  subroutine candidate_sample_at(self, index, sample, available)
    class(fmr_bottom_thermal_candidate_t), intent(in) :: self
    integer, intent(in) :: index
    type(fmr_bottom_thermal_sample_t), intent(out) :: sample
    logical, intent(out) :: available

    sample = fmr_bottom_thermal_sample_t()
    available = self%ready()
    if (.not. available) return
    available = index >= 1 .and. index <= size(self%samples)
    if (.not. available) return
    sample = self%samples(index)
  end subroutine candidate_sample_at

  logical function candidate_thermal_complete(self) result(complete)
    class(fmr_bottom_thermal_candidate_t), intent(in) :: self
    integer :: i

    complete = self%ready()
    if (.not. complete) return
    do i = 1, size(self%samples)
      if (.not. self%samples(i)%donor_thermal_complete) then
        complete = .false.
        return
      end if
    end do
  end function candidate_thermal_complete

  subroutine candidate_interval(self, t0, t1, available)
    class(fmr_bottom_thermal_candidate_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine candidate_interval

  logical function sample_is_valid(sample) result(valid)
    type(fmr_bottom_thermal_sample_t), intent(in) :: sample

    valid = ieee_is_finite(sample%t0) .and. ieee_is_finite(sample%t1) .and. sample%t1 > sample%t0 .and. &
         ieee_is_finite(sample%bottom_outward_exchange_native)
    if (.not. valid) return
    select case (sample%donor_class)
    case (FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP)
      valid = sample%bottom_outward_exchange_native > 0.0_real64 .and. sample%donor_thermal_complete .and. &
           ieee_is_finite(sample%local_start_temperature_c) .and. ieee_is_finite(sample%local_end_temperature_c)
    case (FMR_BOTTOM_THERMAL_DONOR_EXTERNAL)
      valid = sample%bottom_outward_exchange_native < 0.0_real64 .and. .not. sample%donor_thermal_complete
    case (FMR_BOTTOM_THERMAL_DONOR_NONE)
      valid = .not. (sample%bottom_outward_exchange_native > 0.0_real64) .and. &
           .not. (sample%bottom_outward_exchange_native < 0.0_real64) .and. sample%donor_thermal_complete
    case default
      valid = .false.
    end select
  end function sample_is_valid

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

end module mod_fmr_bottom_thermal_carrier
