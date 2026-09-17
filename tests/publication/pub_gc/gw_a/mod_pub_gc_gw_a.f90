module mod_pub_gc_gw_a
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_preparable_exchange_service_t, &
       GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  implicit none
  private

  real(real64), parameter :: DAY_TO_S = 86400.0_real64

  type, extends(groundwater_preparable_exchange_service_t), public :: pub_gc_gw_a_service_t
    private
    logical :: configured = .false.
    integer(int64) :: service_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: revision = 0_int64
    integer(int64) :: token_counter = 0_int64
    real(real64) :: accepted_head = 0.0_real64
    real(real64) :: accepted_time = 0.0_real64
    real(real64) :: area_m2 = 0.0_real64
    real(real64) :: specific_yield = 0.0_real64
    real(real64) :: reference_head_m = 0.0_real64
    real(real64) :: external_source_m_per_s = 0.0_real64

    logical :: checkpoint_active = .false.
    integer(int64) :: checkpoint_token = 0_int64
    integer(int64) :: checkpoint_revision = -1_int64
    real(real64) :: checkpoint_head = 0.0_real64
    real(real64) :: checkpoint_time = 0.0_real64
    real(real64) :: checkpoint_area_m2 = 0.0_real64
    real(real64) :: checkpoint_specific_yield = 0.0_real64
    real(real64) :: checkpoint_reference_head_m = 0.0_real64
    real(real64) :: checkpoint_external_source_m_per_s = 0.0_real64

    logical :: candidate_active = .false.
    integer(int64) :: candidate_token = 0_int64
    integer(int64) :: candidate_checkpoint_token = 0_int64
    real(real64) :: candidate_head = 0.0_real64
    real(real64) :: candidate_t1 = 0.0_real64
    real(real64) :: candidate_delta_volume_m3 = 0.0_real64
    real(real64) :: candidate_q_groundwater_m_per_s = 0.0_real64

    logical :: prepared_active = .false.
    integer(int64) :: prepared_token = 0_int64
    integer(int64) :: prepared_checkpoint_token = 0_int64
    real(real64) :: prepared_head = 0.0_real64
    real(real64) :: prepared_t1 = 0.0_real64
  contains
    procedure, public :: initialize => gw_a_initialize
    procedure, public :: accepted_head_m => gw_a_accepted_head_m
    procedure, public :: accepted_time_day => gw_a_accepted_time_day
    procedure, public :: current_revision => gw_a_current_revision
    procedure, public :: is_configured => gw_a_is_configured
    procedure, public :: last_candidate_volume_change_m3 => gw_a_last_candidate_volume_change_m3
    procedure, public :: storage_volume_m3 => gw_a_storage_volume_m3

    procedure :: capture_backend => gw_a_capture
    procedure :: trial_backend => gw_a_trial
    procedure :: commit_backend => gw_a_commit
    procedure :: discard_backend => gw_a_discard
    procedure :: prepare_backend => gw_a_prepare
    procedure :: commit_prepared_backend => gw_a_commit_prepared
    procedure :: abort_prepared_backend => gw_a_abort_prepared
  end type pub_gc_gw_a_service_t

contains

  subroutine gw_a_initialize(self, service_id, lineage_id, initial_head_m, initial_time_day, area_m2, specific_yield, &
       reference_head_m, external_source_m_per_s, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: service_id, lineage_id
    real(real64), intent(in) :: initial_head_m, initial_time_day, area_m2, specific_yield
    real(real64), intent(in) :: reference_head_m, external_source_m_per_s
    integer, intent(out) :: status

    status = GW_EXCHANGE_BACKEND_REJECTED
    if (.not. self%restart_quiescent()) return

    self%configured = .false.
    call clear_checkpoint(self)
    call clear_candidate(self)
    call clear_prepared(self)

    if (service_id <= 0_int64 .or. lineage_id <= 0_int64) return
    if (.not. ieee_is_finite(initial_head_m)) return
    if (.not. ieee_is_finite(initial_time_day)) return
    if (.not. ieee_is_finite(area_m2) .or. area_m2 <= 0.0_real64) return
    if (.not. ieee_is_finite(specific_yield) .or. specific_yield <= 0.0_real64 .or. specific_yield > 1.0_real64) return
    if (.not. ieee_is_finite(reference_head_m)) return
    if (.not. ieee_is_finite(external_source_m_per_s)) return

    self%service_id_value = service_id
    self%lineage_id_value = lineage_id
    self%revision = 0_int64
    self%accepted_head = initial_head_m
    self%accepted_time = initial_time_day
    self%area_m2 = area_m2
    self%specific_yield = specific_yield
    self%reference_head_m = reference_head_m
    self%external_source_m_per_s = external_source_m_per_s
    self%configured = .true.
    status = GW_EXCHANGE_OK
  end subroutine gw_a_initialize

  real(real64) function gw_a_accepted_head_m(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%accepted_head
  end function gw_a_accepted_head_m

  real(real64) function gw_a_accepted_time_day(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%accepted_time
  end function gw_a_accepted_time_day

  integer(int64) function gw_a_current_revision(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%revision
  end function gw_a_current_revision

  logical function gw_a_is_configured(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%configured
  end function gw_a_is_configured

  real(real64) function gw_a_last_candidate_volume_change_m3(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%candidate_delta_volume_m3
  end function gw_a_last_candidate_volume_change_m3

  real(real64) function gw_a_storage_volume_m3(self) result(value)
    class(pub_gc_gw_a_service_t), intent(in) :: self
    value = self%specific_yield * self%area_m2 * (self%accepted_head - self%reference_head_m)
  end function gw_a_storage_volume_m3

  subroutine gw_a_capture(self, service_id, lineage_id, origin_revision, origin_time, token, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(out) :: service_id, lineage_id, origin_revision, token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status
    logical :: issued

    service_id = 0_int64
    lineage_id = 0_int64
    origin_revision = -1_int64
    origin_time = 0.0_real64
    token = 0_int64
    status = GW_EXCHANGE_BACKEND_REJECTED

    if (.not. self%configured) return
    if (self%prepared_active) return
    if (.not. ieee_is_finite(self%accepted_head) .or. .not. ieee_is_finite(self%accepted_time)) return

    call issue_token(self, token, issued)
    if (.not. issued) return

    self%checkpoint_active = .true.
    self%checkpoint_token = token
    self%checkpoint_revision = self%revision
    self%checkpoint_head = self%accepted_head
    self%checkpoint_time = self%accepted_time
    self%checkpoint_area_m2 = self%area_m2
    self%checkpoint_specific_yield = self%specific_yield
    self%checkpoint_reference_head_m = self%reference_head_m
    self%checkpoint_external_source_m_per_s = self%external_source_m_per_s
    call clear_candidate(self)

    service_id = self%service_id_value
    lineage_id = self%lineage_id_value
    origin_revision = self%revision
    origin_time = self%accepted_time
    status = GW_EXCHANGE_OK
  end subroutine gw_a_capture

  subroutine gw_a_trial(self, checkpoint_token, window, q_groundwater_m_per_s, candidate_token, h_groundwater_m, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: q_groundwater_m_per_s
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: h_groundwater_m
    integer, intent(out) :: status
    real(real64) :: dt_s, delta_volume_m3, capacitance_m3_per_m
    logical :: issued

    candidate_token = 0_int64
    h_groundwater_m = 0.0_real64
    status = GW_EXCHANGE_BACKEND_REJECTED

    if (.not. self%configured .or. .not. self%checkpoint_active) return
    if (self%prepared_active .or. self%candidate_active) return
    if (checkpoint_token /= self%checkpoint_token) return
    if (self%revision /= self%checkpoint_revision) return
    if (.not. window%valid()) return
    if (transfer(window%t0, 0_int64) /= transfer(self%checkpoint_time, 0_int64)) return
    if (.not. ieee_is_finite(q_groundwater_m_per_s)) return

    dt_s = (window%t1 - window%t0) * DAY_TO_S
    if (.not. ieee_is_finite(dt_s) .or. dt_s <= 0.0_real64) return
    capacitance_m3_per_m = self%checkpoint_specific_yield * self%checkpoint_area_m2
    if (.not. ieee_is_finite(capacitance_m3_per_m) .or. capacitance_m3_per_m <= 0.0_real64) return

    delta_volume_m3 = self%checkpoint_area_m2 * &
         (self%checkpoint_external_source_m_per_s - q_groundwater_m_per_s) * dt_s
    if (.not. ieee_is_finite(delta_volume_m3)) return

    h_groundwater_m = self%checkpoint_head + delta_volume_m3 / capacitance_m3_per_m
    if (.not. ieee_is_finite(h_groundwater_m)) then
      h_groundwater_m = 0.0_real64
      return
    end if

    call issue_token(self, candidate_token, issued)
    if (.not. issued) then
      candidate_token = 0_int64
      h_groundwater_m = 0.0_real64
      return
    end if

    self%candidate_active = .true.
    self%candidate_token = candidate_token
    self%candidate_checkpoint_token = checkpoint_token
    self%candidate_head = h_groundwater_m
    self%candidate_t1 = window%t1
    self%candidate_delta_volume_m3 = delta_volume_m3
    self%candidate_q_groundwater_m_per_s = q_groundwater_m_per_s
    status = GW_EXCHANGE_OK
  end subroutine gw_a_trial

  subroutine gw_a_commit(self, checkpoint_token, candidate_token, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer, intent(out) :: status

    status = GW_EXCHANGE_BACKEND_REJECTED
    if (.not. self%configured) return
    if (.not. self%checkpoint_active .or. .not. self%candidate_active) return
    if (self%prepared_active) return
    if (checkpoint_token /= self%checkpoint_token) return
    if (candidate_token /= self%candidate_token) return
    if (self%candidate_checkpoint_token /= checkpoint_token) return
    if (self%revision /= self%checkpoint_revision) return
    if (self%revision >= huge(0_int64)) return

    self%accepted_head = self%candidate_head
    self%accepted_time = self%candidate_t1
    self%revision = self%revision + 1_int64
    call clear_candidate(self)
    call clear_checkpoint(self)
    status = GW_EXCHANGE_OK
  end subroutine gw_a_commit

  subroutine gw_a_discard(self, candidate_token, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: candidate_token
    integer, intent(out) :: status

    status = GW_EXCHANGE_BACKEND_REJECTED
    if (.not. self%candidate_active) return
    if (candidate_token /= self%candidate_token) return
    call clear_candidate(self)
    status = GW_EXCHANGE_OK
  end subroutine gw_a_discard

  subroutine gw_a_prepare(self, checkpoint_token, candidate_token, prepare_token, status)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status
    logical :: issued

    prepare_token = 0_int64
    status = GW_EXCHANGE_BACKEND_REJECTED
    if (.not. self%configured) return
    if (.not. self%checkpoint_active .or. .not. self%candidate_active) return
    if (self%prepared_active) return
    if (checkpoint_token /= self%checkpoint_token) return
    if (candidate_token /= self%candidate_token) return
    if (self%candidate_checkpoint_token /= checkpoint_token) return
    if (self%revision /= self%checkpoint_revision) return

    call issue_token(self, prepare_token, issued)
    if (.not. issued) then
      prepare_token = 0_int64
      return
    end if

    self%prepared_active = .true.
    self%prepared_token = prepare_token
    self%prepared_checkpoint_token = checkpoint_token
    self%prepared_head = self%candidate_head
    self%prepared_t1 = self%candidate_t1
    call clear_candidate(self)
    status = GW_EXCHANGE_OK
  end subroutine gw_a_prepare

  subroutine gw_a_commit_prepared(self, prepare_token)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%configured) error stop 'PUB-GC GW-A commit on unconfigured service'
    if (.not. self%prepared_active .or. .not. self%checkpoint_active) &
         error stop 'PUB-GC GW-A invalid prepared publication state'
    if (prepare_token /= self%prepared_token) error stop 'PUB-GC GW-A prepared token mismatch'
    if (self%prepared_checkpoint_token /= self%checkpoint_token) &
         error stop 'PUB-GC GW-A prepared checkpoint mismatch'
    if (self%revision /= self%checkpoint_revision) error stop 'PUB-GC GW-A stale prepared origin'
    if (self%revision >= huge(0_int64)) error stop 'PUB-GC GW-A revision exhausted'

    self%accepted_head = self%prepared_head
    self%accepted_time = self%prepared_t1
    self%revision = self%revision + 1_int64
    call clear_prepared(self)
    call clear_checkpoint(self)
  end subroutine gw_a_commit_prepared

  subroutine gw_a_abort_prepared(self, prepare_token)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(in) :: prepare_token

    if (.not. self%prepared_active) error stop 'PUB-GC GW-A abort without prepared candidate'
    if (prepare_token /= self%prepared_token) error stop 'PUB-GC GW-A abort token mismatch'
    call clear_prepared(self)
  end subroutine gw_a_abort_prepared

  subroutine issue_token(self, token, issued)
    class(pub_gc_gw_a_service_t), intent(inout) :: self
    integer(int64), intent(out) :: token
    logical, intent(out) :: issued

    token = 0_int64
    issued = .false.
    if (self%token_counter >= huge(0_int64)) return
    self%token_counter = self%token_counter + 1_int64
    token = self%token_counter
    issued = token > 0_int64
  end subroutine issue_token

  subroutine clear_checkpoint(self)
    class(pub_gc_gw_a_service_t), intent(inout) :: self

    self%checkpoint_active = .false.
    self%checkpoint_token = 0_int64
    self%checkpoint_revision = -1_int64
    self%checkpoint_head = 0.0_real64
    self%checkpoint_time = 0.0_real64
    self%checkpoint_area_m2 = 0.0_real64
    self%checkpoint_specific_yield = 0.0_real64
    self%checkpoint_reference_head_m = 0.0_real64
    self%checkpoint_external_source_m_per_s = 0.0_real64
  end subroutine clear_checkpoint

  subroutine clear_candidate(self)
    class(pub_gc_gw_a_service_t), intent(inout) :: self

    self%candidate_active = .false.
    self%candidate_token = 0_int64
    self%candidate_checkpoint_token = 0_int64
    self%candidate_head = 0.0_real64
    self%candidate_t1 = 0.0_real64
    self%candidate_delta_volume_m3 = 0.0_real64
    self%candidate_q_groundwater_m_per_s = 0.0_real64
  end subroutine clear_candidate

  subroutine clear_prepared(self)
    class(pub_gc_gw_a_service_t), intent(inout) :: self

    self%prepared_active = .false.
    self%prepared_token = 0_int64
    self%prepared_checkpoint_token = 0_int64
    self%prepared_head = 0.0_real64
    self%prepared_t1 = 0.0_real64
  end subroutine clear_prepared

end module mod_pub_gc_gw_a
