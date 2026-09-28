module mod_fmr_vonhhbraden_source_window_progress
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  implicit none
  private

  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_OK = 0
  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_INVALID_SOURCE = 1
  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_INVALID_RECEIPT = 2
  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_INTERVAL_GAP = 3
  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_AGGREGATE_EXCEEDED = 4
  integer, parameter, public :: FMR_VONHHBRADEN_PROGRESS_INVALID_RESTART = 5

  type, public :: fmr_vonhhbraden_source_window_restart_t
    integer(int64) :: source_window_id = 0_int64
    real(real64) :: source_t0 = 0.0_real64
    real(real64) :: source_t1 = 0.0_real64
    real(real64) :: aggregate_aintc_cm = 0.0_real64
    real(real64) :: accepted_through_time = 0.0_real64
    real(real64) :: accepted_interception_cm = 0.0_real64
    integer(int64) :: receipt_lineage_id = 0_int64
    integer(int64) :: expected_origin_revision = -1_int64
    logical :: receipt_binding_ready = .false.
  end type fmr_vonhhbraden_source_window_restart_t

  type, public :: fmr_vonhhbraden_source_window_progress_t
    private
    integer(int64) :: source_window_id_value = 0_int64
    real(real64) :: source_t0_value = 0.0_real64
    real(real64) :: source_t1_value = 0.0_real64
    real(real64) :: aggregate_aintc_value = 0.0_real64
    real(real64) :: accepted_through_value = 0.0_real64
    real(real64) :: accepted_interception_value = 0.0_real64
    integer(int64) :: receipt_lineage_id_value = 0_int64
    integer(int64) :: expected_origin_revision_value = -1_int64
    logical :: receipt_binding_ready_value = .false.
    logical :: initialized = .false.
  contains
    procedure, public :: ready => progress_ready
    procedure, public :: remaining_interception => progress_remaining_interception
    procedure, public :: export_restart => progress_export_restart
  end type fmr_vonhhbraden_source_window_progress_t

  public :: fmr_initialize_vonhhbraden_source_window_progress
  public :: fmr_apply_vonhhbraden_accepted_receipt
  public :: fmr_restore_vonhhbraden_source_window_progress

contains

  subroutine fmr_initialize_vonhhbraden_source_window_progress(source_window_id, source_t0, source_t1, &
       aggregate_aintc_cm, progress, status, expected_lineage_id, expected_origin_revision)
    integer(int64), intent(in) :: source_window_id
    real(real64), intent(in) :: source_t0, source_t1, aggregate_aintc_cm
    type(fmr_vonhhbraden_source_window_progress_t), intent(out) :: progress
    integer, intent(out) :: status
    integer(int64), intent(in), optional :: expected_lineage_id, expected_origin_revision

    progress = fmr_vonhhbraden_source_window_progress_t()
    status = FMR_VONHHBRADEN_PROGRESS_INVALID_SOURCE
    if (.not. source_is_valid(source_window_id, source_t0, source_t1, aggregate_aintc_cm)) return
    progress%source_window_id_value = source_window_id
    progress%source_t0_value = source_t0
    progress%source_t1_value = source_t1
    progress%aggregate_aintc_value = aggregate_aintc_cm
    progress%accepted_through_value = source_t0
    if (present(expected_lineage_id) .neqv. present(expected_origin_revision)) return
    if (present(expected_lineage_id)) then
      if (expected_lineage_id <= 0_int64 .or. expected_origin_revision < 0_int64) then
        progress = fmr_vonhhbraden_source_window_progress_t()
        status = FMR_VONHHBRADEN_PROGRESS_INVALID_SOURCE
        return
      end if
      progress%receipt_lineage_id_value = expected_lineage_id
      progress%expected_origin_revision_value = expected_origin_revision
      progress%receipt_binding_ready_value = .true.
    end if
    progress%initialized = .true.
    status = FMR_VONHHBRADEN_PROGRESS_OK
  end subroutine fmr_initialize_vonhhbraden_source_window_progress

  subroutine fmr_apply_vonhhbraden_accepted_receipt(progress, receipt, accepted_interception_cm, status)
    type(fmr_vonhhbraden_source_window_progress_t), intent(inout) :: progress
    type(fmr_accepted_commit_receipt_t), intent(in) :: receipt
    real(real64), intent(in) :: accepted_interception_cm
    integer, intent(out) :: status
    real(real64) :: t0, t1, candidate_total
    integer(int64) :: receipt_lineage, receipt_origin_revision, receipt_committed_revision
    logical :: available

    status = FMR_VONHHBRADEN_PROGRESS_INVALID_RECEIPT
    if (.not. progress%ready() .or. .not. receipt%ready()) return
    if (.not. ieee_is_finite(accepted_interception_cm) .or. accepted_interception_cm < 0.0_real64) return
    call receipt%origin_interval(t0, t1, available)
    if (.not. available .or. .not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    receipt_lineage = receipt%current_lineage_id()
    receipt_origin_revision = receipt%origin_revision()
    receipt_committed_revision = receipt%committed_revision()
    if (receipt_lineage <= 0_int64 .or. receipt_origin_revision < 0_int64 .or. &
        receipt_committed_revision /= receipt_origin_revision + 1_int64) return
    if (progress%receipt_binding_ready_value) then
      if (receipt_lineage /= progress%receipt_lineage_id_value .or. &
          receipt_origin_revision /= progress%expected_origin_revision_value) return
    end if
    if (.not. same_time(t0, progress%accepted_through_value) .or. t1 > progress%source_t1_value) then
      status = FMR_VONHHBRADEN_PROGRESS_INTERVAL_GAP
      return
    end if
    candidate_total = progress%accepted_interception_value + accepted_interception_cm
    if (candidate_total > progress%aggregate_aintc_value + aggregate_tolerance(progress%aggregate_aintc_value)) then
      status = FMR_VONHHBRADEN_PROGRESS_AGGREGATE_EXCEEDED
      return
    end if
    progress%accepted_through_value = t1
    progress%accepted_interception_value = min(candidate_total, progress%aggregate_aintc_value)
    if (.not. progress%receipt_binding_ready_value) then
      progress%receipt_lineage_id_value = receipt_lineage
      progress%receipt_binding_ready_value = .true.
    end if
    progress%expected_origin_revision_value = receipt_committed_revision
    status = FMR_VONHHBRADEN_PROGRESS_OK
  end subroutine fmr_apply_vonhhbraden_accepted_receipt

  subroutine fmr_restore_vonhhbraden_source_window_progress(record, progress, restored, status)
    type(fmr_vonhhbraden_source_window_restart_t), intent(in) :: record
    type(fmr_vonhhbraden_source_window_progress_t), intent(out) :: progress
    logical, intent(out) :: restored
    integer, intent(out) :: status

    progress = fmr_vonhhbraden_source_window_progress_t()
    restored = .false.
    status = FMR_VONHHBRADEN_PROGRESS_INVALID_RESTART
    if (.not. source_is_valid(record%source_window_id, record%source_t0, record%source_t1, &
         record%aggregate_aintc_cm)) return
    if (.not. ieee_is_finite(record%accepted_through_time) .or. &
         .not. ieee_is_finite(record%accepted_interception_cm)) return
    if (record%receipt_binding_ready) then
      if (record%receipt_lineage_id <= 0_int64 .or. record%expected_origin_revision < 0_int64) return
    else
      if (record%receipt_lineage_id /= 0_int64 .or. record%expected_origin_revision /= -1_int64) return
      if (.not. same_time(record%accepted_through_time, record%source_t0) .or. &
          abs(record%accepted_interception_cm) > aggregate_tolerance(0.0_real64)) return
    end if
    if (record%accepted_through_time < record%source_t0 .or. record%accepted_through_time > record%source_t1) return
    if (record%accepted_interception_cm < 0.0_real64 .or. record%accepted_interception_cm > &
         record%aggregate_aintc_cm + aggregate_tolerance(record%aggregate_aintc_cm)) return
    progress%source_window_id_value = record%source_window_id
    progress%source_t0_value = record%source_t0
    progress%source_t1_value = record%source_t1
    progress%aggregate_aintc_value = record%aggregate_aintc_cm
    progress%accepted_through_value = record%accepted_through_time
    progress%accepted_interception_value = min(record%accepted_interception_cm, record%aggregate_aintc_cm)
    progress%receipt_lineage_id_value = record%receipt_lineage_id
    progress%expected_origin_revision_value = record%expected_origin_revision
    progress%receipt_binding_ready_value = record%receipt_binding_ready
    progress%initialized = .true.
    restored = .true.
    status = FMR_VONHHBRADEN_PROGRESS_OK
  end subroutine fmr_restore_vonhhbraden_source_window_progress

  pure logical function progress_ready(self) result(ready)
    class(fmr_vonhhbraden_source_window_progress_t), intent(in) :: self
    ready = self%initialized .and. source_is_valid(self%source_window_id_value, self%source_t0_value, &
         self%source_t1_value, self%aggregate_aintc_value) .and. &
         self%accepted_through_value >= self%source_t0_value .and. self%accepted_through_value <= self%source_t1_value .and. &
         self%accepted_interception_value >= 0.0_real64 .and. &
         self%accepted_interception_value <= self%aggregate_aintc_value + aggregate_tolerance(self%aggregate_aintc_value) .and. &
         ((self%receipt_binding_ready_value .and. self%receipt_lineage_id_value > 0_int64 .and. &
           self%expected_origin_revision_value >= 0_int64) .or. &
          (.not. self%receipt_binding_ready_value .and. self%receipt_lineage_id_value == 0_int64 .and. &
           self%expected_origin_revision_value == -1_int64 .and. &
           same_time(self%accepted_through_value, self%source_t0_value) .and. &
           abs(self%accepted_interception_value) <= aggregate_tolerance(0.0_real64)))
  end function progress_ready

  pure real(real64) function progress_remaining_interception(self) result(value)
    class(fmr_vonhhbraden_source_window_progress_t), intent(in) :: self
    value = 0.0_real64
    if (self%ready()) value = max(self%aggregate_aintc_value - self%accepted_interception_value, 0.0_real64)
  end function progress_remaining_interception

  subroutine progress_export_restart(self, record, exported)
    class(fmr_vonhhbraden_source_window_progress_t), intent(in) :: self
    type(fmr_vonhhbraden_source_window_restart_t), intent(out) :: record
    logical, intent(out) :: exported
    record = fmr_vonhhbraden_source_window_restart_t()
    exported = self%ready()
    if (.not. exported) return
    record%source_window_id = self%source_window_id_value
    record%source_t0 = self%source_t0_value
    record%source_t1 = self%source_t1_value
    record%aggregate_aintc_cm = self%aggregate_aintc_value
    record%accepted_through_time = self%accepted_through_value
    record%accepted_interception_cm = self%accepted_interception_value
    record%receipt_lineage_id = self%receipt_lineage_id_value
    record%expected_origin_revision = self%expected_origin_revision_value
    record%receipt_binding_ready = self%receipt_binding_ready_value
  end subroutine progress_export_restart

  pure logical function source_is_valid(source_window_id, source_t0, source_t1, aggregate_aintc_cm) result(valid)
    integer(int64), intent(in) :: source_window_id
    real(real64), intent(in) :: source_t0, source_t1, aggregate_aintc_cm
    valid = source_window_id > 0_int64 .and. ieee_is_finite(source_t0) .and. ieee_is_finite(source_t1) .and. &
         ieee_is_finite(aggregate_aintc_cm) .and. source_t1 > source_t0 .and. aggregate_aintc_cm >= 0.0_real64
  end function source_is_valid

  pure logical function same_time(left, right) result(matches)
    real(real64), intent(in) :: left, right
    matches = abs(left - right) <= 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(left), abs(right))
  end function same_time

  pure real(real64) function aggregate_tolerance(value) result(tolerance)
    real(real64), intent(in) :: value
    tolerance = 64.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(value))
  end function aggregate_tolerance
end module mod_fmr_vonhhbraden_source_window_progress
