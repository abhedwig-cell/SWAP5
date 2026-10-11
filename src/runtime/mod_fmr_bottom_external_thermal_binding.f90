module mod_fmr_bottom_external_thermal_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_OK = 0
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_INVALID_BUNDLE = 1
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_LINEAGE_MISMATCH = 2
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_INVALID_ORDINAL = 3
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_UNAVAILABLE = 4
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_DUPLICATE = 5
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_NONFINITE = 6
  integer, parameter, public :: FMR_EXT_THERMAL_BINDING_CAPACITY_EXHAUSTED = 7

  type :: fmr_bottom_external_thermal_binding_record_t
    integer :: sample_ordinal = 0
    real(real64) :: donor_temperature_c = 0.0_real64
    integer(int64) :: provenance_token = 0_int64
  end type fmr_bottom_external_thermal_binding_record_t

  type, public :: fmr_bottom_external_thermal_binding_bundle_t
    private
    logical :: initialized = .false.
    integer(int64) :: candidate_lineage_id_value = 0_int64
    integer :: capacity = 0
    integer :: count = 0
    type(fmr_bottom_external_thermal_binding_record_t), allocatable :: bindings(:)
  contains
    procedure, public :: initialize => external_binding_bundle_initialize
    procedure, public :: clear => external_binding_bundle_clear
    procedure, public :: ready => external_binding_bundle_ready
    procedure, public :: candidate_lineage_id => external_binding_bundle_candidate_lineage_id
    procedure, public :: binding_count => external_binding_bundle_binding_count
    procedure, public :: append => external_binding_bundle_append
    procedure, public :: resolve => external_binding_bundle_resolve
  end type fmr_bottom_external_thermal_binding_bundle_t

contains

  subroutine external_binding_bundle_initialize(self, candidate_lineage_id, max_bindings, ok)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_lineage_id
    integer, intent(in) :: max_bindings
    logical, intent(out) :: ok

    call self%clear()
    ok = .false.
    if (candidate_lineage_id <= 0_int64) return
    if (max_bindings < 0) return

    if (max_bindings > 0) allocate(self%bindings(max_bindings))
    self%candidate_lineage_id_value = candidate_lineage_id
    self%capacity = max_bindings
    self%count = 0
    self%initialized = .true.
    ok = .true.
  end subroutine external_binding_bundle_initialize

  subroutine external_binding_bundle_clear(self)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(inout) :: self

    if (allocated(self%bindings)) deallocate(self%bindings)
    self%initialized = .false.
    self%candidate_lineage_id_value = 0_int64
    self%capacity = 0
    self%count = 0
  end subroutine external_binding_bundle_clear

  logical function external_binding_bundle_ready(self) result(ready)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (self%candidate_lineage_id_value <= 0_int64) return
    if (self%capacity < 0 .or. self%count < 0 .or. self%count > self%capacity) return
    if (self%capacity == 0) then
      if (allocated(self%bindings)) return
    else
      if (.not. allocated(self%bindings)) return
      if (size(self%bindings) /= self%capacity) return
    end if
    ready = .true.
  end function external_binding_bundle_ready

  integer(int64) function external_binding_bundle_candidate_lineage_id(self) result(lineage_id)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(in) :: self

    lineage_id = 0_int64
    if (self%ready()) lineage_id = self%candidate_lineage_id_value
  end function external_binding_bundle_candidate_lineage_id

  integer function external_binding_bundle_binding_count(self) result(n)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(in) :: self

    n = 0
    if (self%ready()) n = self%count
  end function external_binding_bundle_binding_count

  subroutine external_binding_bundle_append(self, sample_ordinal, donor_temperature_c, provenance_token, status)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(inout) :: self
    integer, intent(in) :: sample_ordinal
    real(real64), intent(in) :: donor_temperature_c
    integer(int64), intent(in), optional :: provenance_token
    integer, intent(out) :: status

    integer :: i
    integer(int64) :: token

    status = FMR_EXT_THERMAL_BINDING_INVALID_BUNDLE
    if (.not. self%ready()) return
    if (sample_ordinal <= 0) then
      status = FMR_EXT_THERMAL_BINDING_INVALID_ORDINAL
      return
    end if
    if (.not. ieee_is_finite(donor_temperature_c)) then
      status = FMR_EXT_THERMAL_BINDING_NONFINITE
      return
    end if

    token = 0_int64
    if (present(provenance_token)) token = provenance_token
    if (token < 0_int64) then
      status = FMR_EXT_THERMAL_BINDING_INVALID_BUNDLE
      return
    end if

    do i = 1, self%count
      if (self%bindings(i)%sample_ordinal == sample_ordinal) then
        status = FMR_EXT_THERMAL_BINDING_DUPLICATE
        return
      end if
    end do

    if (self%count >= self%capacity) then
      status = FMR_EXT_THERMAL_BINDING_CAPACITY_EXHAUSTED
      return
    end if

    self%count = self%count + 1
    self%bindings(self%count)%sample_ordinal = sample_ordinal
    self%bindings(self%count)%donor_temperature_c = donor_temperature_c
    self%bindings(self%count)%provenance_token = token
    status = FMR_EXT_THERMAL_BINDING_OK
  end subroutine external_binding_bundle_append

  subroutine external_binding_bundle_resolve(self, candidate_lineage_id, sample_ordinal, donor_temperature_c, &
                                             provenance_token, available, status)
    class(fmr_bottom_external_thermal_binding_bundle_t), intent(in) :: self
    integer(int64), intent(in) :: candidate_lineage_id
    integer, intent(in) :: sample_ordinal
    real(real64), intent(out) :: donor_temperature_c
    integer(int64), intent(out) :: provenance_token
    logical, intent(out) :: available
    integer, intent(out) :: status

    integer :: i

    donor_temperature_c = 0.0_real64
    provenance_token = 0_int64
    available = .false.
    status = FMR_EXT_THERMAL_BINDING_INVALID_BUNDLE
    if (.not. self%ready()) return
    if (candidate_lineage_id <= 0_int64 .or. candidate_lineage_id /= self%candidate_lineage_id_value) then
      status = FMR_EXT_THERMAL_BINDING_LINEAGE_MISMATCH
      return
    end if
    if (sample_ordinal <= 0) then
      status = FMR_EXT_THERMAL_BINDING_INVALID_ORDINAL
      return
    end if

    do i = 1, self%count
      if (self%bindings(i)%sample_ordinal == sample_ordinal) then
        if (.not. ieee_is_finite(self%bindings(i)%donor_temperature_c)) then
          status = FMR_EXT_THERMAL_BINDING_NONFINITE
          return
        end if
        donor_temperature_c = self%bindings(i)%donor_temperature_c
        provenance_token = self%bindings(i)%provenance_token
        available = .true.
        status = FMR_EXT_THERMAL_BINDING_OK
        return
      end if
    end do

    status = FMR_EXT_THERMAL_BINDING_UNAVAILABLE
  end subroutine external_binding_bundle_resolve

end module mod_fmr_bottom_external_thermal_binding
