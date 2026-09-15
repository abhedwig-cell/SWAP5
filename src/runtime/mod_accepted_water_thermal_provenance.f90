module mod_accepted_water_thermal_provenance
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_kernel_transactions, only: kernel_candidate_state_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  implicit none
  private

  integer, parameter, public :: AWT_PROV_OK = 0
  integer, parameter, public :: AWT_PROV_INVALID_WATER = 1
  integer, parameter, public :: AWT_PROV_INVALID_THERMAL = 2
  integer, parameter, public :: AWT_PROV_LINEAGE_MISMATCH = 3
  integer, parameter, public :: AWT_PROV_REVISION_MISMATCH = 4
  integer, parameter, public :: AWT_PROV_INTERVAL_MISMATCH = 5
  integer, parameter, public :: AWT_PROV_INVALID_BINDING = 6
  integer, parameter, public :: AWT_PROV_RECEIPT_NOT_ACCEPTED = 7
  integer, parameter, public :: AWT_PROV_RECEIPT_MISMATCH = 8

  type, public :: water_transfer_trial_provenance_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => water_provenance_ready
    procedure, public :: current_lineage_id => water_provenance_lineage
    procedure, public :: origin_revision => water_provenance_revision
    procedure, public :: origin_interval => water_provenance_interval
  end type water_transfer_trial_provenance_t

  type, public :: thermal_field_trial_provenance_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => thermal_provenance_ready
    procedure, public :: current_lineage_id => thermal_provenance_lineage
    procedure, public :: origin_revision => thermal_provenance_revision
    procedure, public :: origin_interval => thermal_provenance_interval
  end type thermal_field_trial_provenance_t

  type, public :: water_thermal_trial_binding_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => trial_binding_ready
    procedure, public :: current_lineage_id => trial_binding_lineage
    procedure, public :: origin_revision => trial_binding_revision
    procedure, public :: origin_interval => trial_binding_interval
  end type water_thermal_trial_binding_t

  type, public :: accepted_water_thermal_provenance_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
  contains
    procedure, public :: ready => accepted_provenance_ready
    procedure, public :: current_lineage_id => accepted_provenance_lineage
    procedure, public :: origin_revision => accepted_provenance_origin_revision
    procedure, public :: committed_revision => accepted_provenance_committed_revision
    procedure, public :: origin_interval => accepted_provenance_interval
  end type accepted_water_thermal_provenance_t

  public :: capture_water_transfer_trial_provenance
  public :: capture_thermal_field_trial_provenance
  public :: bind_water_thermal_trial_provenance
  public :: authorize_accepted_water_thermal_provenance

contains

  subroutine capture_water_transfer_trial_provenance(candidate, provenance, status)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(water_transfer_trial_provenance_t), intent(out) :: provenance
    integer, intent(out) :: status
    real(real64) :: t0, t1
    logical :: available

    provenance = water_transfer_trial_provenance_t()
    status = AWT_PROV_INVALID_WATER
    if (.not. candidate%ready()) return
    call candidate%origin_interval(t0, t1, available)
    if (.not. available) return
    if (.not. valid_interval(t0, t1)) return
    if (candidate%current_lineage_id() <= 0_int64 .or. candidate%origin_revision() < 0_int64) return

    provenance%lineage_id = candidate%current_lineage_id()
    provenance%origin_revision_value = candidate%origin_revision()
    provenance%t0_value = t0
    provenance%t1_value = t1
    provenance%initialized = .true.
    status = AWT_PROV_OK
  end subroutine capture_water_transfer_trial_provenance

  subroutine capture_thermal_field_trial_provenance(candidate, provenance, status)
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(thermal_field_trial_provenance_t), intent(out) :: provenance
    integer, intent(out) :: status
    real(real64) :: t0, t1
    logical :: available

    provenance = thermal_field_trial_provenance_t()
    status = AWT_PROV_INVALID_THERMAL
    if (.not. candidate%ready()) return
    call candidate%origin_interval(t0, t1, available)
    if (.not. available) return
    if (.not. valid_interval(t0, t1)) return
    if (candidate%current_lineage_id() <= 0_int64 .or. candidate%origin_revision() < 0_int64) return

    provenance%lineage_id = candidate%current_lineage_id()
    provenance%origin_revision_value = candidate%origin_revision()
    provenance%t0_value = t0
    provenance%t1_value = t1
    provenance%initialized = .true.
    status = AWT_PROV_OK
  end subroutine capture_thermal_field_trial_provenance

  subroutine bind_water_thermal_trial_provenance(water, thermal, binding, status)
    type(water_transfer_trial_provenance_t), intent(in) :: water
    type(thermal_field_trial_provenance_t), intent(in) :: thermal
    type(water_thermal_trial_binding_t), intent(out) :: binding
    integer, intent(out) :: status

    binding = water_thermal_trial_binding_t()
    status = AWT_PROV_INVALID_WATER
    if (.not. water%ready()) return
    status = AWT_PROV_INVALID_THERMAL
    if (.not. thermal%ready()) return
    status = AWT_PROV_LINEAGE_MISMATCH
    if (water%lineage_id /= thermal%lineage_id) return
    status = AWT_PROV_REVISION_MISMATCH
    if (water%origin_revision_value /= thermal%origin_revision_value) return
    status = AWT_PROV_INTERVAL_MISMATCH
    if (.not. same_transaction_time(water%t0_value, thermal%t0_value)) return
    if (.not. same_transaction_time(water%t1_value, thermal%t1_value)) return

    binding%lineage_id = water%lineage_id
    binding%origin_revision_value = water%origin_revision_value
    binding%t0_value = water%t0_value
    binding%t1_value = water%t1_value
    binding%initialized = .true.
    status = AWT_PROV_OK
  end subroutine bind_water_thermal_trial_provenance

  subroutine authorize_accepted_water_thermal_provenance(binding, receipt, accepted, status)
    type(water_thermal_trial_binding_t), intent(in) :: binding
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    type(accepted_water_thermal_provenance_t), intent(out) :: accepted
    integer, intent(out) :: status
    real(real64) :: t0, t1
    logical :: interval_available

    accepted = accepted_water_thermal_provenance_t()
    status = AWT_PROV_INVALID_BINDING
    if (.not. binding%ready()) return
    status = AWT_PROV_RECEIPT_NOT_ACCEPTED
    if (.not. receipt%ready()) return

    status = AWT_PROV_RECEIPT_MISMATCH
    if (receipt%current_lineage_id() /= binding%lineage_id) return
    if (receipt%origin_revision() /= binding%origin_revision_value) return
    call receipt%origin_interval(t0, t1, interval_available)
    if (.not. interval_available) return
    if (.not. same_transaction_time(t0, binding%t0_value)) return
    if (.not. same_transaction_time(t1, binding%t1_value)) return
    if (receipt%committed_revision() /= binding%origin_revision_value + 1_int64) return

    accepted%lineage_id = binding%lineage_id
    accepted%origin_revision_value = binding%origin_revision_value
    accepted%committed_revision_value = receipt%committed_revision()
    accepted%t0_value = binding%t0_value
    accepted%t1_value = binding%t1_value
    accepted%initialized = .true.
    status = AWT_PROV_OK
  end subroutine authorize_accepted_water_thermal_provenance

  pure logical function valid_interval(t0, t1) result(valid)
    real(real64), intent(in) :: t0, t1
    valid = ieee_is_finite(t0) .and. ieee_is_finite(t1) .and. t1 > t0
  end function valid_interval

  pure logical function same_transaction_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_transaction_time

  pure logical function water_provenance_ready(self) result(ready)
    class(water_transfer_trial_provenance_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         valid_interval(self%t0_value, self%t1_value)
  end function water_provenance_ready

  pure integer(int64) function water_provenance_lineage(self) result(value)
    class(water_transfer_trial_provenance_t), intent(in) :: self
    value = self%lineage_id
  end function water_provenance_lineage

  pure integer(int64) function water_provenance_revision(self) result(value)
    class(water_transfer_trial_provenance_t), intent(in) :: self
    value = self%origin_revision_value
  end function water_provenance_revision

  subroutine water_provenance_interval(self, t0, t1, available)
    class(water_transfer_trial_provenance_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    call expose_interval(self%ready(), self%t0_value, self%t1_value, t0, t1, available)
  end subroutine water_provenance_interval

  pure logical function thermal_provenance_ready(self) result(ready)
    class(thermal_field_trial_provenance_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         valid_interval(self%t0_value, self%t1_value)
  end function thermal_provenance_ready

  pure integer(int64) function thermal_provenance_lineage(self) result(value)
    class(thermal_field_trial_provenance_t), intent(in) :: self
    value = self%lineage_id
  end function thermal_provenance_lineage

  pure integer(int64) function thermal_provenance_revision(self) result(value)
    class(thermal_field_trial_provenance_t), intent(in) :: self
    value = self%origin_revision_value
  end function thermal_provenance_revision

  subroutine thermal_provenance_interval(self, t0, t1, available)
    class(thermal_field_trial_provenance_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    call expose_interval(self%ready(), self%t0_value, self%t1_value, t0, t1, available)
  end subroutine thermal_provenance_interval

  pure logical function trial_binding_ready(self) result(ready)
    class(water_thermal_trial_binding_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         valid_interval(self%t0_value, self%t1_value)
  end function trial_binding_ready

  pure integer(int64) function trial_binding_lineage(self) result(value)
    class(water_thermal_trial_binding_t), intent(in) :: self
    value = self%lineage_id
  end function trial_binding_lineage

  pure integer(int64) function trial_binding_revision(self) result(value)
    class(water_thermal_trial_binding_t), intent(in) :: self
    value = self%origin_revision_value
  end function trial_binding_revision

  subroutine trial_binding_interval(self, t0, t1, available)
    class(water_thermal_trial_binding_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    call expose_interval(self%ready(), self%t0_value, self%t1_value, t0, t1, available)
  end subroutine trial_binding_interval

  pure logical function accepted_provenance_ready(self) result(ready)
    class(accepted_water_thermal_provenance_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         valid_interval(self%t0_value, self%t1_value)
  end function accepted_provenance_ready

  pure integer(int64) function accepted_provenance_lineage(self) result(value)
    class(accepted_water_thermal_provenance_t), intent(in) :: self
    value = self%lineage_id
  end function accepted_provenance_lineage

  pure integer(int64) function accepted_provenance_origin_revision(self) result(value)
    class(accepted_water_thermal_provenance_t), intent(in) :: self
    value = self%origin_revision_value
  end function accepted_provenance_origin_revision

  pure integer(int64) function accepted_provenance_committed_revision(self) result(value)
    class(accepted_water_thermal_provenance_t), intent(in) :: self
    value = self%committed_revision_value
  end function accepted_provenance_committed_revision

  subroutine accepted_provenance_interval(self, t0, t1, available)
    class(accepted_water_thermal_provenance_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    call expose_interval(self%ready(), self%t0_value, self%t1_value, t0, t1, available)
  end subroutine accepted_provenance_interval

  subroutine expose_interval(valid, source_t0, source_t1, t0, t1, available)
    logical, intent(in) :: valid
    real(real64), intent(in) :: source_t0, source_t1
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = valid
    if (available) then
      t0 = source_t0
      t1 = source_t1
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine expose_interval

end module mod_accepted_water_thermal_provenance
