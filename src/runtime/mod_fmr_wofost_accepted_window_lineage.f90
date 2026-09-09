module mod_fmr_wofost_accepted_window_lineage
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_checkpoint_t, kernel_committed_state_t
  use mod_wofost_one_day_structural_evolution, only: wofost_accepted_window_aggregates_t
  implicit none
  private

  integer, parameter, public :: FMR_WOFOST_LINEAGE_OK = 0
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT = 1
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_COMMITTED = 2
  integer, parameter, public :: FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN = 3
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_TRIAL = 4
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_WINDOW = 5
  integer, parameter, public :: FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE = 6
  integer, parameter, public :: FMR_WOFOST_LINEAGE_NONCONTIGUOUS = 7
  integer, parameter, public :: FMR_WOFOST_LINEAGE_CERTIFICATE_MISMATCH = 8
  integer, parameter, public :: FMR_WOFOST_LINEAGE_WINDOW_INCOMPLETE = 9
  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED = 10
  integer, parameter, public :: FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH = 11

  type, public :: fmr_wofost_accepted_interval_certificate_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    integer(int64) :: committed_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
  contains
    procedure, public :: ready => certificate_ready
  end type fmr_wofost_accepted_interval_certificate_t

  type, public :: fmr_wofost_trial_contribution_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: next_t = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
  contains
    procedure, public :: ready => trial_ready
    procedure, public :: complete => trial_complete
  end type fmr_wofost_trial_contribution_t

  type, public :: fmr_wofost_accepted_window_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: start_revision = -1_int64
    integer(int64) :: next_revision = -1_int64
    integer :: accepted_intervals = 0
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: covered_t = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
    logical :: event_delivered = .false.
  contains
    procedure, public :: ready => accepted_window_ready
    procedure, public :: complete => accepted_window_complete
    procedure, public :: event_due => accepted_window_event_due
    procedure, public :: delivery_committed => accepted_window_delivery_committed
    procedure, public :: interval_count => accepted_window_interval_count
  end type fmr_wofost_accepted_window_t

  type, public :: fmr_wofost_crop_event_token_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: final_revision = -1_int64
    real(real64) :: t0 = 0.0_real64
    real(real64) :: t1 = 0.0_real64
    real(real64) :: actual_root_uptake_integral = 0.0_real64
    real(real64) :: potential_transpiration_integral = 0.0_real64
  contains
    procedure, public :: ready => crop_event_token_ready
  end type fmr_wofost_crop_event_token_t

  public :: certify_fkt_accepted_interval
  public :: begin_wofost_trial_contribution
  public :: accumulate_wofost_trial_process_rate
  public :: discard_wofost_trial_contribution
  public :: open_wofost_accepted_window
  public :: admit_wofost_accepted_trial
  public :: prepare_wofost_crop_event_delivery
  public :: commit_wofost_crop_event_delivery

contains

  subroutine certify_fkt_accepted_interval(checkpoint, committed_after, certificate, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_committed_state_t), intent(in) :: committed_after
    type(fmr_wofost_accepted_interval_certificate_t), intent(out) :: certificate
    integer, intent(out) :: status
    integer(int64) :: origin_revision, committed_revision, lineage_id
    real(real64) :: t0, t1
    logical :: t0_available, t1_available

    certificate = fmr_wofost_accepted_interval_certificate_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready() .or. .not. checkpoint%time_is_bound()) return

    status = FMR_WOFOST_LINEAGE_INVALID_COMMITTED
    if (.not. committed_after%ready() .or. .not. committed_after%time_is_bound()) return

    lineage_id = checkpoint%current_lineage_id()
    if (lineage_id <= 0_int64 .or. committed_after%current_lineage_id() /= lineage_id) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    origin_revision = checkpoint%origin_revision()
    committed_revision = committed_after%current_revision()
    if (origin_revision < 0_int64 .or. origin_revision >= huge(origin_revision)) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (committed_revision /= origin_revision + 1_int64) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    call checkpoint%current_time(t0, t0_available)
    call committed_after%current_time(t1, t1_available)
    if (.not. t0_available .or. .not. t1_available) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) then
      status = FMR_WOFOST_LINEAGE_COMMIT_NOT_PROVEN
      return
    end if

    certificate%lineage_id = lineage_id
    certificate%origin_revision = origin_revision
    certificate%committed_revision = committed_revision
    certificate%t0 = t0
    certificate%t1 = t1
    certificate%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine certify_fkt_accepted_interval

  subroutine begin_wofost_trial_contribution(checkpoint, trial_t1, trial, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: trial_t1
    type(fmr_wofost_trial_contribution_t), intent(out) :: trial
    integer, intent(out) :: status
    real(real64) :: trial_t0
    logical :: time_available

    trial = fmr_wofost_trial_contribution_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready() .or. .not. checkpoint%time_is_bound()) return

    call checkpoint%current_time(trial_t0, time_available)
    if (.not. time_available) return
    if (.not. ieee_is_finite(trial_t0) .or. .not. ieee_is_finite(trial_t1) .or. trial_t1 <= trial_t0) then
      status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
      return
    end if

    trial%lineage_id = checkpoint%current_lineage_id()
    trial%origin_revision = checkpoint%origin_revision()
    if (trial%lineage_id <= 0_int64 .or. trial%origin_revision < 0_int64) then
      status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
      trial = fmr_wofost_trial_contribution_t()
      return
    end if
    trial%t0 = trial_t0
    trial%t1 = trial_t1
    trial%next_t = trial_t0
    trial%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine begin_wofost_trial_contribution

  subroutine accumulate_wofost_trial_process_rate(trial, sub_t0, sub_t1, &
       actual_root_uptake_rate, potential_transpiration_rate, status)
    type(fmr_wofost_trial_contribution_t), intent(inout) :: trial
    real(real64), intent(in) :: sub_t0, sub_t1
    real(real64), intent(in) :: actual_root_uptake_rate, potential_transpiration_rate
    integer, intent(out) :: status
    real(real64) :: dt, actual_add, potential_add, actual_new, potential_new

    status = FMR_WOFOST_LINEAGE_INVALID_TRIAL
    if (.not. trial%ready() .or. trial%complete()) return
    if (.not. ieee_is_finite(sub_t0) .or. .not. ieee_is_finite(sub_t1) .or. sub_t1 <= sub_t0) return
    if (.not. same_time(sub_t0, trial%next_t)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (sub_t1 > trial%t1 .and. .not. same_time(sub_t1, trial%t1)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (.not. valid_nonnegative(actual_root_uptake_rate) .or. &
        .not. valid_nonnegative(potential_transpiration_rate)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    dt = sub_t1 - sub_t0
    actual_add = actual_root_uptake_rate * dt
    potential_add = potential_transpiration_rate * dt
    actual_new = trial%actual_root_uptake_integral + actual_add
    potential_new = trial%potential_transpiration_integral + potential_add
    if (.not. ieee_is_finite(actual_add) .or. .not. ieee_is_finite(potential_add) .or. &
        .not. ieee_is_finite(actual_new) .or. .not. ieee_is_finite(potential_new)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    trial%actual_root_uptake_integral = actual_new
    trial%potential_transpiration_integral = potential_new
    trial%next_t = sub_t1
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine accumulate_wofost_trial_process_rate

  subroutine discard_wofost_trial_contribution(trial)
    type(fmr_wofost_trial_contribution_t), intent(inout) :: trial
    trial = fmr_wofost_trial_contribution_t()
  end subroutine discard_wofost_trial_contribution

  subroutine open_wofost_accepted_window(checkpoint, window_t1, window, status)
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    real(real64), intent(in) :: window_t1
    type(fmr_wofost_accepted_window_t), intent(out) :: window
    integer, intent(out) :: status
    real(real64) :: window_t0
    logical :: time_available

    window = fmr_wofost_accepted_window_t()
    status = FMR_WOFOST_LINEAGE_INVALID_CHECKPOINT
    if (.not. checkpoint%ready() .or. .not. checkpoint%time_is_bound()) return
    call checkpoint%current_time(window_t0, time_available)
    if (.not. time_available) return

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. ieee_is_finite(window_t0) .or. .not. ieee_is_finite(window_t1) .or. window_t1 <= window_t0) return
    window%lineage_id = checkpoint%current_lineage_id()
    window%start_revision = checkpoint%origin_revision()
    if (window%lineage_id <= 0_int64 .or. window%start_revision < 0_int64) then
      window = fmr_wofost_accepted_window_t()
      return
    end if
    window%next_revision = window%start_revision
    window%t0 = window_t0
    window%t1 = window_t1
    window%covered_t = window_t0
    window%initialized = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine open_wofost_accepted_window

  subroutine admit_wofost_accepted_trial(window, certificate, trial, status)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(fmr_wofost_accepted_interval_certificate_t), intent(in) :: certificate
    type(fmr_wofost_trial_contribution_t), intent(in) :: trial
    integer, intent(out) :: status
    real(real64) :: actual_new, potential_new

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready() .or. window%event_delivered) return
    status = FMR_WOFOST_LINEAGE_CERTIFICATE_MISMATCH
    if (.not. certificate%ready() .or. .not. trial%ready() .or. .not. trial%complete()) return
    if (certificate%lineage_id /= window%lineage_id .or. trial%lineage_id /= window%lineage_id) return
    if (certificate%origin_revision /= window%next_revision .or. &
        trial%origin_revision /= window%next_revision) return
    if (certificate%committed_revision /= certificate%origin_revision + 1_int64) return
    if (.not. same_time(certificate%t0, trial%t0) .or. .not. same_time(certificate%t1, trial%t1)) return
    if (.not. same_time(certificate%t0, window%covered_t)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if
    if (certificate%t1 > window%t1 .and. .not. same_time(certificate%t1, window%t1)) then
      status = FMR_WOFOST_LINEAGE_NONCONTIGUOUS
      return
    end if

    actual_new = window%actual_root_uptake_integral + trial%actual_root_uptake_integral
    potential_new = window%potential_transpiration_integral + trial%potential_transpiration_integral
    if (.not. ieee_is_finite(actual_new) .or. .not. ieee_is_finite(potential_new)) then
      status = FMR_WOFOST_LINEAGE_INVALID_PROCESS_RATE
      return
    end if

    window%actual_root_uptake_integral = actual_new
    window%potential_transpiration_integral = potential_new
    window%covered_t = certificate%t1
    window%next_revision = certificate%committed_revision
    window%accepted_intervals = window%accepted_intervals + 1
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine admit_wofost_accepted_trial

  subroutine prepare_wofost_crop_event_delivery(window, aggregates, token, available, status)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_accepted_window_aggregates_t), intent(out) :: aggregates
    type(fmr_wofost_crop_event_token_t), intent(out) :: token
    logical, intent(out) :: available
    integer, intent(out) :: status

    aggregates = wofost_accepted_window_aggregates_t()
    token = fmr_wofost_crop_event_token_t()
    available = .false.
    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready()) return
    if (window%event_delivered) then
      status = FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED
      return
    end if
    if (.not. window%complete()) then
      status = FMR_WOFOST_LINEAGE_WINDOW_INCOMPLETE
      return
    end if

    aggregates%actual_root_uptake = window%actual_root_uptake_integral
    aggregates%potential_transpiration = window%potential_transpiration_integral
    token%lineage_id = window%lineage_id
    token%final_revision = window%next_revision
    token%t0 = window%t0
    token%t1 = window%t1
    token%actual_root_uptake_integral = window%actual_root_uptake_integral
    token%potential_transpiration_integral = window%potential_transpiration_integral
    token%initialized = .true.
    available = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine prepare_wofost_crop_event_delivery

  subroutine commit_wofost_crop_event_delivery(window, token, status)
    type(fmr_wofost_accepted_window_t), intent(inout) :: window
    type(fmr_wofost_crop_event_token_t), intent(in) :: token
    integer, intent(out) :: status

    status = FMR_WOFOST_LINEAGE_INVALID_WINDOW
    if (.not. window%ready() .or. .not. window%complete()) return
    if (window%event_delivered) then
      status = FMR_WOFOST_LINEAGE_EVENT_ALREADY_DELIVERED
      return
    end if
    status = FMR_WOFOST_LINEAGE_EVENT_TOKEN_MISMATCH
    if (.not. token%ready()) return
    if (token%lineage_id /= window%lineage_id .or. token%final_revision /= window%next_revision) return
    if (.not. same_time(token%t0, window%t0) .or. .not. same_time(token%t1, window%t1)) return
    if (.not. same_real_bits(token%actual_root_uptake_integral, window%actual_root_uptake_integral)) return
    if (.not. same_real_bits(token%potential_transpiration_integral, &
         window%potential_transpiration_integral)) return

    window%event_delivered = .true.
    status = FMR_WOFOST_LINEAGE_OK
  end subroutine commit_wofost_crop_event_delivery

  logical function certificate_ready(self) result(ready)
    class(fmr_wofost_accepted_interval_certificate_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision >= 0_int64 .and. self%committed_revision == self%origin_revision + 1_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0
  end function certificate_ready

  logical function trial_ready(self) result(ready)
    class(fmr_wofost_trial_contribution_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%origin_revision >= 0_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. ieee_is_finite(self%next_t) .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. self%t1 > self%t0 .and. &
         self%next_t >= self%t0 .and. self%next_t <= self%t1
  end function trial_ready

  logical function trial_complete(self) result(complete)
    class(fmr_wofost_trial_contribution_t), intent(in) :: self
    complete = self%ready() .and. same_time(self%next_t, self%t1)
  end function trial_complete

  logical function accepted_window_ready(self) result(ready)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%start_revision >= 0_int64 .and. &
         self%next_revision >= self%start_revision .and. self%accepted_intervals >= 0 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. ieee_is_finite(self%covered_t) .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral) .and. self%t1 > self%t0 .and. &
         self%covered_t >= self%t0 .and. self%covered_t <= self%t1
  end function accepted_window_ready

  logical function accepted_window_complete(self) result(complete)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    complete = self%ready() .and. same_time(self%covered_t, self%t1)
  end function accepted_window_complete

  logical function accepted_window_event_due(self) result(due)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    due = self%complete() .and. .not. self%event_delivered
  end function accepted_window_event_due

  logical function accepted_window_delivery_committed(self) result(committed)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    committed = self%ready() .and. self%event_delivered
  end function accepted_window_delivery_committed

  integer function accepted_window_interval_count(self) result(count)
    class(fmr_wofost_accepted_window_t), intent(in) :: self
    if (self%ready()) then
      count = self%accepted_intervals
    else
      count = 0
    end if
  end function accepted_window_interval_count

  logical function crop_event_token_ready(self) result(ready)
    class(fmr_wofost_crop_event_token_t), intent(in) :: self
    ready = self%initialized .and. self%lineage_id > 0_int64 .and. self%final_revision >= 0_int64 .and. &
         ieee_is_finite(self%t0) .and. ieee_is_finite(self%t1) .and. self%t1 > self%t0 .and. &
         ieee_is_finite(self%actual_root_uptake_integral) .and. &
         ieee_is_finite(self%potential_transpiration_integral)
  end function crop_event_token_ready

  pure logical function valid_nonnegative(value) result(valid)
    real(real64), intent(in) :: value
    valid = .false.
    if (.not. ieee_is_finite(value)) return
    valid = value >= 0.0_real64
  end function valid_nonnegative

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    matches = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

  pure logical function same_real_bits(a, b) result(matches)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    matches = ia == ib
  end function same_real_bits

end module mod_fmr_wofost_accepted_window_lineage
