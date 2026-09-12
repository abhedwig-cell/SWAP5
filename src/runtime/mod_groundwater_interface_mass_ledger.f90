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

  type, public :: groundwater_interface_mass_snapshot_t
    logical :: available = .false.
    integer :: committed_exchange_count = 0
    integer :: discarded_trial_count = 0
    logical :: trial_active = .false.
    real(real64) :: committed_swap_outward_exchange_m = 0.0_real64
    real(real64) :: committed_groundwater_outward_exchange_m = 0.0_real64
    real(real64) :: conservation_residual_m = 0.0_real64
  end type groundwater_interface_mass_snapshot_t

  type, public :: groundwater_interface_mass_ledger_t
    private
    real(real64) :: committed_swap_outward_exchange_m = 0.0_real64
    integer :: committed_exchange_count = 0
    integer :: discarded_trial_count = 0
    logical :: trial_active = .false.
    real(real64) :: trial_exchange_m = 0.0_real64
    real(real64) :: trial_t0 = 0.0_real64
    real(real64) :: trial_t1 = 0.0_real64
    integer(int64) :: trial_coupling_id = 0_int64
    integer(int64) :: trial_candidate_revision = -1_int64
  contains
    procedure, public :: stage_exchange => groundwater_mass_stage_exchange
    procedure, public :: discard_trial => groundwater_mass_discard_trial
    procedure, public :: commit_trial => groundwater_mass_commit_trial
    procedure, public :: snapshot => groundwater_mass_snapshot
    procedure, public :: has_active_trial => groundwater_mass_has_active_trial
  end type groundwater_interface_mass_ledger_t

contains

  subroutine groundwater_mass_stage_exchange(self, window, lineage, swap_outward_exchange_m, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    type(groundwater_coupling_window_t), intent(in) :: window
    type(groundwater_interface_lineage_t), intent(in) :: lineage
    real(real64), intent(in) :: swap_outward_exchange_m
    integer, intent(out) :: status

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

    status = GW_MASS_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return
    call clear_trial(self)
    self%discarded_trial_count = self%discarded_trial_count + 1
    status = GW_MASS_LEDGER_OK
  end subroutine groundwater_mass_discard_trial

  subroutine groundwater_mass_commit_trial(self, status)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    integer, intent(out) :: status
    real(real64) :: candidate_total

    status = GW_MASS_LEDGER_NO_ACTIVE_TRIAL
    if (.not. self%trial_active) return

    candidate_total = self%committed_swap_outward_exchange_m + self%trial_exchange_m
    status = GW_MASS_LEDGER_ACCUMULATION_FAILED
    if (.not. ieee_is_finite(candidate_total)) return

    ! Store one canonical signed amount only. The groundwater-side amount is
    ! always derived as its exact arithmetic negative, so accepted accounting
    ! cannot develop two independently accumulated mass histories.
    self%committed_swap_outward_exchange_m = candidate_total
    self%committed_exchange_count = self%committed_exchange_count + 1
    call clear_trial(self)
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
    snapshot%trial_active = self%trial_active
    snapshot%committed_swap_outward_exchange_m = self%committed_swap_outward_exchange_m
    snapshot%committed_groundwater_outward_exchange_m = -self%committed_swap_outward_exchange_m
    snapshot%conservation_residual_m = snapshot%committed_swap_outward_exchange_m + &
         snapshot%committed_groundwater_outward_exchange_m
  end subroutine groundwater_mass_snapshot

  pure logical function groundwater_mass_has_active_trial(self) result(active)
    class(groundwater_interface_mass_ledger_t), intent(in) :: self
    active = self%trial_active
  end function groundwater_mass_has_active_trial

  subroutine clear_trial(self)
    class(groundwater_interface_mass_ledger_t), intent(inout) :: self
    self%trial_active = .false.
    self%trial_exchange_m = 0.0_real64
    self%trial_t0 = 0.0_real64
    self%trial_t1 = 0.0_real64
    self%trial_coupling_id = 0_int64
    self%trial_candidate_revision = -1_int64
  end subroutine clear_trial

end module mod_groundwater_interface_mass_ledger
