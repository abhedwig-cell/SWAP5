module mod_fmr_root_uptake_attribution_receipt
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_candidate_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  implicit none
  private

  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_OK = 0
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_INVALID_CANDIDATE = 1
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_INVALID_FORCING = 2
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT = 3
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH = 4
  integer, parameter, public :: FMR_ROOT_ATTRIBUTION_TIME_MISMATCH = 5

  ! Worker/job-local preparation only. This object is deliberately not column
  ! state and never authorizes publication. It captures the exact qrot forcing
  ! paired with the candidate before the candidate is physically committed.
  type, public :: fmr_prepared_root_uptake_attribution_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: actual_transpiration_amount_value = 0.0_real64
  contains
    procedure, public :: ready => prepared_ready
  end type fmr_prepared_root_uptake_attribution_t

  ! Postcommit publication object. The amount is reconciliation metadata: it is
  ! a named subset of water already booked through qrot in transaction mass_out
  ! and must never be added to the mass ledger a second time.
  type, public :: fmr_root_uptake_attribution_receipt_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: actual_transpiration_amount_value = 0.0_real64
  contains
    procedure, public :: ready => attribution_ready
    procedure, public :: current_lineage_id => attribution_lineage_id
    procedure, public :: origin_revision => attribution_origin_revision
    procedure, public :: committed_revision => attribution_committed_revision
    procedure, public :: origin_interval => attribution_origin_interval
    procedure, public :: actual_transpiration_amount => attribution_actual_transpiration_amount
  end type fmr_root_uptake_attribution_receipt_t

  public :: fmr_prepare_root_uptake_attribution
  public :: fmr_finalize_root_uptake_attribution

contains

  subroutine fmr_prepare_root_uptake_attribution(forcing, candidate, prepared, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(fmr_prepared_root_uptake_attribution_t), intent(out) :: prepared
    integer, intent(out) :: status

    real(real64) :: t0, t1, amount
    logical :: interval_available
    integer(int64) :: lineage_id, origin_revision

    prepared = fmr_prepared_root_uptake_attribution_t()
    status = FMR_ROOT_ATTRIBUTION_INVALID_CANDIDATE
    if (.not. candidate%ready()) return

    lineage_id = candidate%current_lineage_id()
    origin_revision = candidate%origin_revision()
    call candidate%origin_interval(t0, t1, interval_available)
    if (.not. interval_available .or. lineage_id <= 0_int64 .or. origin_revision < 0_int64) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return

    status = FMR_ROOT_ATTRIBUTION_INVALID_FORCING
    if (.not. allocated(forcing%root_extraction_sink)) return
    if (size(forcing%root_extraction_sink) <= 0) return
    if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
    if (any(forcing%root_extraction_sink < 0.0_real64)) return

    amount = sum(forcing%root_extraction_sink) * (t1 - t0)
    if (.not. ieee_is_finite(amount) .or. amount < 0.0_real64) return

    prepared%lineage_id = lineage_id
    prepared%origin_revision_value = origin_revision
    prepared%t0_value = t0
    prepared%t1_value = t1
    prepared%actual_transpiration_amount_value = amount
    prepared%initialized = .true.
    status = FMR_ROOT_ATTRIBUTION_OK
  end subroutine fmr_prepare_root_uptake_attribution

  subroutine fmr_finalize_root_uptake_attribution(prepared, commit_receipt, attribution, status)
    type(fmr_prepared_root_uptake_attribution_t), intent(in) :: prepared
    type(fmr_accepted_commit_receipt_t), intent(in) :: commit_receipt
    type(fmr_root_uptake_attribution_receipt_t), intent(out) :: attribution
    integer, intent(out) :: status

    real(real64) :: t0, t1
    logical :: interval_available

    attribution = fmr_root_uptake_attribution_receipt_t()
    status = FMR_ROOT_ATTRIBUTION_INVALID_CANDIDATE
    if (.not. prepared%ready()) return

    status = FMR_ROOT_ATTRIBUTION_INVALID_COMMIT_RECEIPT
    if (.not. commit_receipt%ready()) return
    call commit_receipt%origin_interval(t0, t1, interval_available)
    if (.not. interval_available) return

    status = FMR_ROOT_ATTRIBUTION_PROVENANCE_MISMATCH
    if (commit_receipt%current_lineage_id() /= prepared%lineage_id) return
    if (commit_receipt%origin_revision() /= prepared%origin_revision_value) return
    if (commit_receipt%committed_revision() /= prepared%origin_revision_value + 1_int64) return

    status = FMR_ROOT_ATTRIBUTION_TIME_MISMATCH
    if (.not. same_time_value(t0, prepared%t0_value)) return
    if (.not. same_time_value(t1, prepared%t1_value)) return

    attribution%lineage_id = prepared%lineage_id
    attribution%origin_revision_value = prepared%origin_revision_value
    attribution%committed_revision_value = commit_receipt%committed_revision()
    attribution%t0_value = prepared%t0_value
    attribution%t1_value = prepared%t1_value
    attribution%actual_transpiration_amount_value = prepared%actual_transpiration_amount_value
    attribution%initialized = .true.
    status = FMR_ROOT_ATTRIBUTION_OK
  end subroutine fmr_finalize_root_uptake_attribution

  pure logical function prepared_ready(self) result(ready)
    class(fmr_prepared_root_uptake_attribution_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%actual_transpiration_amount_value) .and. self%actual_transpiration_amount_value >= 0.0_real64
  end function prepared_ready

  pure logical function attribution_ready(self) result(ready)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%actual_transpiration_amount_value) .and. self%actual_transpiration_amount_value >= 0.0_real64
  end function attribution_ready

  pure integer(int64) function attribution_lineage_id(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%lineage_id
  end function attribution_lineage_id

  pure integer(int64) function attribution_origin_revision(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%origin_revision_value
  end function attribution_origin_revision

  pure integer(int64) function attribution_committed_revision(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    value = self%committed_revision_value
  end function attribution_committed_revision

  subroutine attribution_origin_interval(self, t0, t1, available)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
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
  end subroutine attribution_origin_interval

  pure real(real64) function attribution_actual_transpiration_amount(self) result(value)
    class(fmr_root_uptake_attribution_receipt_t), intent(in) :: self
    if (self%ready()) then
      value = self%actual_transpiration_amount_value
    else
      value = 0.0_real64
    end if
  end function attribution_actual_transpiration_amount

  pure logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time_value

end module mod_fmr_root_uptake_attribution_receipt
