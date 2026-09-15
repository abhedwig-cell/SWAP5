module mod_fmr_top_sensible_boundary_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: fmr_top_sensible_boundary_sample_t
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    ! Canonical top-water sign: positive leaves soil, negative enters soil.
    real(real64) :: top_exchange_native = 0.0_real64
    logical :: thermal_accounting_complete = .false.
    real(real64) :: boundary_energy_into_soil_j_cm2 = 0.0_real64
    real(real64) :: storage_change_j_cm2 = 0.0_real64
    real(real64) :: energy_residual_j_cm2 = 0.0_real64
  end type fmr_top_sensible_boundary_sample_t

  type, public :: fmr_top_sensible_boundary_candidate_t
    private
    logical :: initialized = .false.
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    type(fmr_top_sensible_boundary_sample_t), allocatable :: samples(:)
  contains
    procedure, public :: clear => candidate_clear
    procedure, public :: copy_to => candidate_copy_to
    procedure, public :: ready => candidate_ready
    procedure, public :: sample_count => candidate_sample_count
    procedure, public :: sample_at => candidate_sample_at
    procedure, public :: interval => candidate_interval
    procedure, public :: total_boundary_energy => candidate_total_boundary_energy
    procedure, public :: total_top_exchange => candidate_total_top_exchange
  end type fmr_top_sensible_boundary_candidate_t

  type, public :: fmr_top_sensible_boundary_carrier_t
    private
    logical :: initialized = .false.
    integer :: capacity = 0
    integer :: count = 0
    type(fmr_top_sensible_boundary_sample_t), allocatable :: samples(:)
  contains
    procedure, public :: initialize => carrier_initialize
    procedure, public :: clear => carrier_clear
    procedure, public :: append => carrier_append
    procedure, public :: sample_count => carrier_sample_count
    procedure, public :: copy_to => carrier_copy_to
    procedure, public :: restore_from => carrier_restore_from
    procedure, public :: materialize_candidate => carrier_materialize_candidate
  end type fmr_top_sensible_boundary_carrier_t

contains

  subroutine carrier_initialize(self, max_samples, ok)
    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self
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
    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self
    if (allocated(self%samples)) deallocate(self%samples)
    self%initialized = .false.
    self%capacity = 0
    self%count = 0
  end subroutine carrier_clear

  subroutine carrier_append(self, t0, t1, top_exchange_native, thermal_accounting_complete, &
       boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2, ok)
    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1, top_exchange_native
    logical, intent(in) :: thermal_accounting_complete
    real(real64), intent(in) :: boundary_energy_into_soil_j_cm2, storage_change_j_cm2, energy_residual_j_cm2
    logical, intent(out) :: ok
    type(fmr_top_sensible_boundary_sample_t) :: sample

    sample%t0 = t0
    sample%t1 = t1
    sample%top_exchange_native = top_exchange_native
    sample%thermal_accounting_complete = thermal_accounting_complete
    sample%boundary_energy_into_soil_j_cm2 = boundary_energy_into_soil_j_cm2
    sample%storage_change_j_cm2 = storage_change_j_cm2
    sample%energy_residual_j_cm2 = energy_residual_j_cm2

    ok = .false.
    if (.not. self%initialized .or. .not. allocated(self%samples)) return
    if (self%count < 0 .or. self%count >= self%capacity) return
    if (.not. sample_is_valid(sample)) return
    self%count = self%count + 1
    self%samples(self%count) = sample
    ok = .true.
  end subroutine carrier_append

  integer function carrier_sample_count(self) result(n)
    class(fmr_top_sensible_boundary_carrier_t), intent(in) :: self
    n = 0
    if (self%initialized) n = self%count
  end function carrier_sample_count

  subroutine carrier_copy_to(self, target)
    class(fmr_top_sensible_boundary_carrier_t), intent(in) :: self
    type(fmr_top_sensible_boundary_carrier_t), intent(out) :: target

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
    class(fmr_top_sensible_boundary_carrier_t), intent(inout) :: self
    type(fmr_top_sensible_boundary_carrier_t), intent(in) :: source
    call source%copy_to(self)
  end subroutine carrier_restore_from

  subroutine carrier_materialize_candidate(self, requested_t0, requested_t1, candidate, ok)
    class(fmr_top_sensible_boundary_carrier_t), intent(in) :: self
    real(real64), intent(in) :: requested_t0, requested_t1
    type(fmr_top_sensible_boundary_candidate_t), intent(out) :: candidate
    logical, intent(out) :: ok
    integer :: i

    call candidate%clear()
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

  subroutine candidate_clear(self)
    class(fmr_top_sensible_boundary_candidate_t), intent(inout) :: self
    if (allocated(self%samples)) deallocate(self%samples)
    self%initialized = .false.
    self%t0_value = 0.0_real64
    self%t1_value = 0.0_real64
  end subroutine candidate_clear

  subroutine candidate_copy_to(self, target)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    type(fmr_top_sensible_boundary_candidate_t), intent(out) :: target

    call target%clear()
    if (.not. self%ready()) return
    allocate(target%samples(size(self%samples)))
    target%samples = self%samples
    target%t0_value = self%t0_value
    target%t1_value = self%t1_value
    target%initialized = .true.
  end subroutine candidate_copy_to

  logical function candidate_ready(self) result(ready)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    integer :: i

    ready = .false.
    if (.not. self%initialized .or. .not. allocated(self%samples)) return
    if (size(self%samples) <= 0) return
    if (.not. ieee_is_finite(self%t0_value) .or. .not. ieee_is_finite(self%t1_value) .or. &
        self%t1_value <= self%t0_value) return
    if (.not. same_time(self%samples(1)%t0, self%t0_value)) return
    if (.not. same_time(self%samples(size(self%samples))%t1, self%t1_value)) return
    do i = 1, size(self%samples)
      if (.not. sample_is_valid(self%samples(i))) return
      if (i > 1) then
        if (.not. same_time(self%samples(i-1)%t1, self%samples(i)%t0)) return
      end if
    end do
    ready = .true.
  end function candidate_ready

  integer function candidate_sample_count(self) result(n)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    n = 0
    if (self%ready()) n = size(self%samples)
  end function candidate_sample_count

  subroutine candidate_sample_at(self, index, sample, available)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    integer, intent(in) :: index
    type(fmr_top_sensible_boundary_sample_t), intent(out) :: sample
    logical, intent(out) :: available

    sample = fmr_top_sensible_boundary_sample_t()
    available = self%ready()
    if (.not. available) return
    available = index >= 1 .and. index <= size(self%samples)
    if (available) sample = self%samples(index)
  end subroutine candidate_sample_at

  subroutine candidate_interval(self, t0, t1, available)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
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

  subroutine candidate_total_boundary_energy(self, total_j_cm2, available)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    real(real64), intent(out) :: total_j_cm2
    logical, intent(out) :: available
    integer :: i

    total_j_cm2 = 0.0_real64
    available = self%ready()
    if (.not. available) return
    do i = 1, size(self%samples)
      total_j_cm2 = total_j_cm2 + self%samples(i)%boundary_energy_into_soil_j_cm2
    end do
    available = ieee_is_finite(total_j_cm2)
    if (.not. available) total_j_cm2 = 0.0_real64
  end subroutine candidate_total_boundary_energy

  subroutine candidate_total_top_exchange(self, total_native, available)
    class(fmr_top_sensible_boundary_candidate_t), intent(in) :: self
    real(real64), intent(out) :: total_native
    logical, intent(out) :: available
    integer :: i

    total_native = 0.0_real64
    available = self%ready()
    if (.not. available) return
    do i = 1, size(self%samples)
      total_native = total_native + self%samples(i)%top_exchange_native
    end do
    available = ieee_is_finite(total_native)
    if (.not. available) total_native = 0.0_real64
  end subroutine candidate_total_top_exchange

  logical function sample_is_valid(sample) result(valid)
    type(fmr_top_sensible_boundary_sample_t), intent(in) :: sample
    real(real64) :: identity, scale

    valid = ieee_is_finite(sample%t0) .and. ieee_is_finite(sample%t1) .and. sample%t1 > sample%t0 .and. &
         ieee_is_finite(sample%top_exchange_native) .and. sample%thermal_accounting_complete .and. &
         ieee_is_finite(sample%boundary_energy_into_soil_j_cm2) .and. &
         ieee_is_finite(sample%storage_change_j_cm2) .and. ieee_is_finite(sample%energy_residual_j_cm2)
    if (.not. valid) return

    ! Qualified F-PM07B/FMR39 identity:
    ! residual = sensible_storage_change - boundary_energy_into_soil.
    identity = sample%storage_change_j_cm2 - sample%boundary_energy_into_soil_j_cm2 - sample%energy_residual_j_cm2
    scale = max(1.0_real64, abs(sample%storage_change_j_cm2), abs(sample%boundary_energy_into_soil_j_cm2), &
         abs(sample%energy_residual_j_cm2))
    valid = ieee_is_finite(identity) .and. abs(identity) <= 256.0_real64 * epsilon(1.0_real64) * scale
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

end module mod_fmr_top_sensible_boundary_carrier
