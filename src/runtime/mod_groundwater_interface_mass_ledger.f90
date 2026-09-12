module mod_groundwater_interface_mass_ledger
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_interface_lineage_t
  implicit none
  private

  integer, parameter, public :: GW_MASS_LEDGER_OK = 0
  integer, parameter, public :: GW_MASS_LEDGER_INVALID_WINDOW = 1
  integer, parameter, public :: GW_MASS_LEDGER_INVALID_LINEAGE = 2
  integer, parameter, public :: GW_MASS_LEDGER_INVALID_EXCHANGE = 3
  integer, parameter, public :: GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE = 4
  integer, parameter, public :: GW_MASS_LEDGER_NO_ACTIVE_TRIAL = 5
  integer, parameter, public :: GW_MASS_LEDGER_ACCUMULATION_FAILED = 6
  integer, parameter, public :: GW_MASS_LEDGER_ALREADY_PREPARED = 7
  integer, parameter, public :: GW_MASS_LEDGER_COUNTER_EXHAUSTED = 8
  integer, parameter, public :: GW_MASS_LEDGER_GENERATION_EXHAUSTED = 9

  type, public :: groundwater_interface_mass_snapshot_t
    logical :: available = .false.
    integer :: committed_exchange_count = 0
    integer :: discarded_trial_count = 0
    logical :: discarded_trial_count_saturated = .false.
    logical :: trial_active = .false.
    logical :: prepared_active = .false.
    real(real64) :: committed_swap_outward_exchange_m = 0.0_real64
    real(real64) :: committed_groundwater_outward_exchange_m = 0.0_real64
    real(real64) :: conservation_residual_m = 0.0_real64
  end type groundwater_interface_mass_snapshot_t

  type, public :: groundwater_interface_mass_prepared_t
    private
    logical :: initialized = .false.
    integer(int64) :: generation = 0_int64
  contains
    procedure, public :: ready => groundwater_mass_prepared_ready
  end type groundwater_interface_mass_prepared_t

  type, public :: groundwater_interface_mass_ledger_t
    private
    real(real64) :: committed_swap_outward_exchange_m = 0.0_real64
    integer :: committed_exchange_count = 0
    integer :: discarded_trial_count = 0
    logical :: discarded_trial_count_saturated = .false.
    logical :: trial_active = .false.
    real(real64) :: trial_exchange_m = 0.0_real64
    real(real64) :: trial_t0 = 0.0_real64
    real(real64) :: trial_t1 = 0.0_real64
    integer(int64) :: trial_coupling_id = 0_int64
    integer(int64) :: trial_candidate_revision = -1_int64
    logical :: prepared_active = .false.
    integer(int64) :: preparation_generation = 0_int64
    integer(int64) :: prepared_generation = 0_int64
    real(real64) :: prepared_total_swap_m = 0.0_real64
    integer :: prepared_committed_exchange_count = 0
  contains
    procedure, public :: stage_exchange => groundwater_mass_stage_exchange
    procedure, public :: discard_trial => groundwater_mass_discard_trial
    procedure, public :: prepare_trial => groundwater_mass_prepare_trial
    procedure, public :: prepared_ready_for_commit => groundwater_mass_prepared_ready_for_commit
    procedure, public :: commit_prepared => groundwater_mass_commit_prepared
    procedure, public :: abort_prepared => groundwater_mass_abort_prepared
    procedure, public :: commit_trial => groundwater_mass_commit_trial
    procedure, public :: snapshot => groundwater_mass_snapshot
    procedure, public :: has_active_trial => groundwater_mass_has_active_trial
    procedure, public :: has_prepared_trial => groundwater_mass_has_prepared_trial
  end type groundwater_interface_mass_ledger_t

contains

  subroutine groundwater_mass_stage_exchange(self, window, lineage, swap_outward_exchange_m, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_interface_lineage_t), intent(in) :: lineage
    real(real64), intent(in) :: swap_outward_exchange_m
    integer, intent(out) :: status

    status = GW_MASS_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return

    status = GW_MASS_LEDGER_TRIAL_ALREADY_ACTIVE
    if (self%trial_active) return

    status = GW_MASS_LEDGER_INVALID_WINDOW
    if (.not. window%valid()) return

    status = GW_MASS_LEDGER_INVALID_LINEAGE
    if (.not. lineage%valid()) return

    status = GW_MASS_LEDGER_INVALID_EXCHANGE
    if (.not. ieee_is_finite(swap_outward_exchange_m)) return

    self%trial_exchange_m = swap_outward_exchange_m
    self%trial_t0 = window%t0
    self%trial_t1 = window%t1
    self%trial_coupling_id = lineage%coupling_id
    self%trial_candidate_revision = lineage%candidate_revision
    self%trial_active = .true.
    status = GW_MASS_LEDGER_OK
  end subroutine groundwater_mass_stage_exchange

  subroutine groundwater_mass_discard_trial(self, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    integer, intent(out) :: status

    status = GW_MASS_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return

    status = GW_MASS_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return

    call clear_trial(self)
    call increment_discard_counter(self)
    status = GW_MASS_LEDGER_OK
  end subroutine groundwater_mass_discard_trial

  subroutine groundwater_mass_prepare_trial(self, prepared, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    type(groundwater_interface_mass_prepared_t), intent(out) :: prepared
    integer, intent(out) :: status

    real(real64) :: candidate_total
    logical :: sum_ok

    prepared = groundwater_interface_mass_prepared_t()

    status = GW_MASS_LEDGER_ALREADY_PREPARED
    if (self%prepared_active) return

    status = GW_MASS_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return

    status = GW_MASS_LEDGER_ACCUMULATION_FAILED
    call safe_real_sum(self%committed_swap_outward_exchange_m, self%trial_exchange_m, &
         candidate_total, sum_ok)
    if (.not. sum_ok) return

    status = GW_MASS_LEDGER_COUNTER_EXHAUSTED
    if (self%committed_exchange_count >= huge(self%committed_exchange_count)) return

    status = GW_MASS_LEDGER_GENERATION_EXHAUSTED
    if (self%preparation_generation >= huge(self%preparation_generation)) return

    ! All recoverable arithmetic/counter failures have occurred before a
    ! reservation is published. The final prepared commit performs assignments
    ! of these precomputed values only.
    self%prepared_total_swap_m = candidate_total
    self%prepared_committed_exchange_count = self%committed_exchange_count + 1
    self%prepared_generation = self%preparation_generation + 1_int64
    self%preparation_generation = self%prepared_generation
    self%prepared_active = .true.

    prepared%generation = self%prepared_generation
    prepared%initialized = .true.
    call clear_trial(self)
    status = GW_MASS_LEDGER_OK
  end subroutine groundwater_mass_prepare_trial

  pure logical function groundwater_mass_prepared_ready_for_commit(self, prepared) result(ready)
    class(groundwater_interface_mass_ledger_t), intent(in) :: self
    type(groundwater_interface_mass_prepared_t), intent(in) :: prepared

    ready = .false.
    if (.not. self%prepared_active) return
    if (.not. prepared%ready()) return
    if (prepared%generation /= self%prepared_generation) return
    if (.not. ieee_is_finite(self%prepared_total_swap_m)) return
    if (self%committed_exchange_count >= huge(self%committed_exchange_count)) return
    if (self%prepared_committed_exchange_count /= self%committed_exchange_count + 1) return
    ready = .true.
  end function groundwater_mass_prepared_ready_for_commit

  subroutine groundwater_mass_commit_prepared(self, prepared)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    type(groundwater_interface_mass_prepared_t), intent(inout) :: prepared

    if (.not. self%prepared_ready_for_commit(prepared)) then
      error stop 'groundwater mass ledger prepared commit invariant violation'
    end if

    self%committed_swap_outward_exchange_m = self%prepared_total_swap_m
    self%committed_exchange_count = self%prepared_committed_exchange_count
    call clear_prepared(self)
    prepared%initialized = .false.
    prepared%generation = 0_int64
  end subroutine groundwater_mass_commit_prepared

  subroutine groundwater_mass_abort_prepared(self, prepared)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    type(groundwater_interface_mass_prepared_t), intent(inout) :: prepared

    if (.not. self%prepared_ready_for_commit(prepared)) then
      error stop 'groundwater mass ledger prepared abort invariant violation'
    end if

    ! Aborting a prepared ledger publication changes no committed exchange.
    ! Count it diagnostically as a discarded trial. This counter saturates
    ! explicitly instead of risking integer overflow in a rollback path.
    call increment_discard_counter(self)
    call clear_prepared(self)
    prepared%initialized = .false.
    prepared%generation = 0_int64
  end subroutine groundwater_mass_abort_prepared

  subroutine groundwater_mass_commit_trial(self, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    integer, intent(out) :: status
    type(groundwater_interface_mass_prepared_t) :: prepared

    ! Backward-compatible F-GC19 entry point. All recoverable rejection now
    ! happens in prepare_trial, before the deterministic assignment-only commit.
    call self%prepare_trial(prepared, status)
    if (status /= GW_MASS_LEDGER_OK) return
    call self%commit_prepared(prepared)
    status = GW_MASS_LEDGER_OK
  end subroutine groundwater_mass_commit_trial

  subroutine groundwater_mass_snapshot(self, snapshot)
    class(groundwater_interface_mass_ledger_t), intent(in) :: self
    type(groundwater_interface_mass_snapshot_t), intent(out) :: snapshot

    snapshot = groundwater_interface_mass_snapshot_t()
    if (.not. ieee_is_finite(self%committed_swap_outward_exchange_m)) return
    snapshot%available = .true.
    snapshot%committed_exchange_count = self%committed_exchange_count
    snapshot%discarded_trial_count = self%discarded_trial_count
    snapshot%discarded_trial_count_saturated = self%discarded_trial_count_saturated
    snapshot%trial_active = self%trial_active
    snapshot%prepared_active = self%prepared_active
    snapshot%committed_swap_outward_exchange_m = self%committed_swap_outward_exchange_m
    snapshot%committed_groundwater_outward_exchange_m = -self%committed_swap_outward_exchange_m
    snapshot%conservation_residual_m = snapshot%committed_swap_outward_exchange_m + &
         snapshot%committed_groundwater_outward_exchange_m
  end subroutine groundwater_mass_snapshot

  pure logical function groundwater_mass_has_active_trial(self) result(active)
    class(groundwater_interface_mass_ledger_t), intent(in) :: self
    active = self%trial_active
  end function groundwater_mass_has_active_trial

  pure logical function groundwater_mass_has_prepared_trial(self) result(active)
    class(groundwater_interface_mass_ledger_t), intent(in) :: self
    active = self%prepared_active
  end function groundwater_mass_has_prepared_trial

  pure logical function groundwater_mass_prepared_ready(self) result(ready)
    class(groundwater_interface_mass_prepared_t), intent(in) :: self
    ready = self%initialized .and. self%generation > 0_int64
  end function groundwater_mass_prepared_ready

  subroutine increment_discard_counter(self)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self

    if (self%discarded_trial_count < huge(self%discarded_trial_count)) then
      self%discarded_trial_count = self%discarded_trial_count + 1
    else
      self%discarded_trial_count_saturated = .true.
    end if
  end subroutine increment_discard_counter

  subroutine clear_trial(self)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    self%trial_active = .false.
    self%trial_exchange_m = 0.0_real64
    self%trial_t0 = 0.0_real64
    self%trial_t1 = 0.0_real64
    self%trial_coupling_id = 0_int64
    self%trial_candidate_revision = -1_int64
  end subroutine clear_trial

  subroutine clear_prepared(self)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    self%prepared_active = .false.
    self%prepared_generation = 0_int64
    self%prepared_total_swap_m = 0.0_real64
    self%prepared_committed_exchange_count = 0
  end subroutine clear_prepared

  pure subroutine safe_real_sum(a, b, value, ok)
    real(real64), intent(in) :: a, b
    real(real64), intent(out) :: value
    logical, intent(out) :: ok
    real(real64) :: limit

    value = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) return

    limit = huge(0.0_real64)
    if (b > 0.0_real64) then
      if (a > limit - b) return
    else if (b < 0.0_real64) then
      if (a < -limit - b) return
    end if

    value = a + b
    if (.not. ieee_is_finite(value)) return
    ok = .true.
  end subroutine safe_real_sum

end module mod_groundwater_interface_mass_ledger
