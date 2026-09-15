module fgc26_direct_commit_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_external_gateway, only: external_groundwater_backend_t, GW_EXTERNAL_BACKEND_OK
  implicit none
  private

  type, extends(external_groundwater_backend_t), public :: direct_backend_t
    integer(int64) :: revision = 0_int64
    real(real64) :: origin_time = 0.0_real64
    integer(int64) :: candidate_token = 0_int64
    integer(int64) :: prepare_token = 0_int64
    real(real64) :: candidate_t1 = 0.0_real64
    logical :: fail_commit = .false.
  contains
    procedure :: capture => backend_capture
    procedure :: trial => backend_trial
    procedure :: commit_candidate => backend_commit_candidate
    procedure :: discard_candidate => backend_discard_candidate
    procedure :: prepare => backend_prepare
    procedure :: commit_prepared => backend_commit_prepared
    procedure :: abort_prepared => backend_abort_prepared
  end type direct_backend_t

contains

  integer(int64) function current_checkpoint_token(self) result(value)
    class(direct_backend_t), intent(in) :: self
    value = 9000_int64 + self%revision
  end function current_checkpoint_token

  subroutine backend_capture(self, cell_id, lineage_id, origin_revision, origin_time, checkpoint_token, status)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id
    integer(int64), intent(out) :: lineage_id, origin_revision, checkpoint_token
    real(real64), intent(out) :: origin_time
    integer, intent(out) :: status

    if (cell_id /= 7_int64) then
      lineage_id = 0_int64; origin_revision = -1_int64; origin_time = 0.0_real64; checkpoint_token = 0_int64
      status = 799
      return
    end if
    lineage_id = 7007_int64
    origin_revision = self%revision
    origin_time = self%origin_time
    checkpoint_token = current_checkpoint_token(self)
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_capture

  subroutine backend_trial(self, cell_id, checkpoint_token, t0, t1, flux_native, candidate_token, head_native, status)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token
    real(real64), intent(in) :: t0, t1, flux_native
    integer(int64), intent(out) :: candidate_token
    real(real64), intent(out) :: head_native
    integer, intent(out) :: status

    candidate_token = 0_int64
    head_native = 0.0_real64
    if (cell_id /= 7_int64 .or. checkpoint_token /= current_checkpoint_token(self) .or. &
        abs(t0-self%origin_time) > 1.0e-12_real64 .or. t1 <= t0) then
      status = 798
      return
    end if
    if (.not. (abs(flux_native) < huge(flux_native))) then
      status = 797
      return
    end if
    self%candidate_token = 9100_int64 + self%revision
    self%candidate_t1 = t1
    candidate_token = self%candidate_token
    head_native = 12.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_trial

  subroutine backend_commit_candidate(self, cell_id, checkpoint_token, candidate_token, status)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer, intent(out) :: status

    if (self%fail_commit) then
      status = 703
      return
    end if
    if (cell_id /= 7_int64 .or. checkpoint_token /= current_checkpoint_token(self) .or. &
        candidate_token /= self%candidate_token .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    self%revision = self%revision + 1_int64
    self%origin_time = self%candidate_t1
    self%candidate_token = 0_int64
    self%candidate_t1 = 0.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_commit_candidate

  subroutine backend_discard_candidate(self, cell_id, candidate_token, status)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, candidate_token
    integer, intent(out) :: status

    if (cell_id /= 7_int64 .or. candidate_token /= self%candidate_token .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    self%candidate_token = 0_int64
    self%candidate_t1 = 0.0_real64
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_discard_candidate

  subroutine backend_prepare(self, cell_id, checkpoint_token, candidate_token, prepare_token, status)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, checkpoint_token, candidate_token
    integer(int64), intent(out) :: prepare_token
    integer, intent(out) :: status

    prepare_token = 0_int64
    if (cell_id /= 7_int64 .or. checkpoint_token /= current_checkpoint_token(self) .or. &
        candidate_token /= self%candidate_token .or. candidate_token <= 0_int64) then
      status = 704
      return
    end if
    self%prepare_token = 9200_int64 + self%revision
    prepare_token = self%prepare_token
    status = GW_EXTERNAL_BACKEND_OK
  end subroutine backend_prepare

  subroutine backend_commit_prepared(self, cell_id, prepare_token)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    if (cell_id /= 7_int64 .or. prepare_token /= self%prepare_token) error stop 2631
    self%revision = self%revision + 1_int64
    self%origin_time = self%candidate_t1
    self%prepare_token = 0_int64
    self%candidate_token = 0_int64
    self%candidate_t1 = 0.0_real64
  end subroutine backend_commit_prepared

  subroutine backend_abort_prepared(self, cell_id, prepare_token)
    class(direct_backend_t), intent(inout) :: self
    integer(int64), intent(in) :: cell_id, prepare_token
    if (cell_id /= 7_int64 .or. prepare_token /= self%prepare_token) error stop 2632
    self%prepare_token = 0_int64
    self%candidate_token = 0_int64
    self%candidate_t1 = 0.0_real64
  end subroutine backend_abort_prepared

end module fgc26_direct_commit_backend

program test_fgc26_direct_commit_and_rebind
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_exchange_service_contract, only: groundwater_exchange_checkpoint_t, &
       groundwater_exchange_candidate_t, groundwater_exchange_prepared_t, groundwater_exchange_trial_result_t, &
       groundwater_capture_checkpoint, groundwater_trial_from_checkpoint, groundwater_commit_candidate, &
       groundwater_prepare_candidate, groundwater_abort_prepared, GW_EXCHANGE_OK, GW_EXCHANGE_BACKEND_REJECTED
  use mod_groundwater_external_gateway, only: groundwater_external_gateway_t, groundwater_external_gateway_config_t, &
       bind_groundwater_external_gateway_batch, GW_EXTERNAL_GATEWAY_OK, GW_EXTERNAL_GATEWAY_NOT_QUIESCENT
  use fgc26_direct_commit_backend, only: direct_backend_t
  implicit none

  type(direct_backend_t), target :: backend
  type(groundwater_external_gateway_t) :: gateway
  type(groundwater_external_gateway_t) :: batch(2)
  type(groundwater_external_gateway_config_t) :: config
  type(groundwater_external_gateway_config_t) :: batch_initial(2), batch_rebind(2)
  type(groundwater_exchange_checkpoint_t) :: checkpoint
  type(groundwater_exchange_candidate_t) :: candidate
  type(groundwater_exchange_prepared_t) :: prepared
  type(groundwater_exchange_trial_result_t) :: trial_result
  type(groundwater_coupling_window_t) :: window
  real(real64), parameter :: CM_DAY_TO_M_S = 0.01_real64 / 86400.0_real64
  integer :: status

  config = groundwater_external_gateway_config_t(service_id=707_int64, cell_id=7_int64, &
       head_native_to_m_scale=0.1_real64, head_native_zero_m=3.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=1)
  call gateway%bind(backend, config, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'bind')

  call groundwater_capture_checkpoint(gateway, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture direct candidate')
  window = groundwater_coupling_window_t(t0=0.0_real64, t1=0.25_real64)
  call groundwater_trial_from_checkpoint(gateway, checkpoint, window, CM_DAY_TO_M_S, candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial direct candidate')

  backend%fail_commit = .true.
  call groundwater_commit_candidate(gateway, checkpoint, candidate, status)
  call require(status == GW_EXCHANGE_BACKEND_REJECTED .and. gateway%last_backend_status() == 703, &
       'direct commit failure propagation')
  call require(candidate%ready() .and. checkpoint%ready() .and. backend%revision == 0_int64, &
       'failed direct commit mutated wrapper or committed state')

  backend%fail_commit = .false.
  call groundwater_commit_candidate(gateway, checkpoint, candidate, status)
  call require(status == GW_EXCHANGE_OK .and. backend%revision == 1_int64, 'direct commit retry')
  print '(A)', 'FGC26_DIRECT_CANDIDATE_COMMIT_AND_FAILURE=PASS'

  call groundwater_capture_checkpoint(gateway, checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'capture before prepared rebind')
  window = groundwater_coupling_window_t(t0=0.25_real64, t1=0.5_real64)
  call groundwater_trial_from_checkpoint(gateway, checkpoint, window, CM_DAY_TO_M_S, candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'trial before prepared rebind')
  call groundwater_prepare_candidate(gateway, checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. gateway%restart_quiescent(), 'prepare before rebind')

  call gateway%bind(backend, config, status)
  call require(status == GW_EXTERNAL_GATEWAY_NOT_QUIESCENT .and. .not. gateway%restart_quiescent(), &
       'active prepared rebind was not rejected')
  call groundwater_abort_prepared(gateway, checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. gateway%restart_quiescent(), 'abort after rebind rejection')
  call gateway%bind(backend, config, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK .and. gateway%ready(), 'quiescent rebind')
  print '(A)', 'FGC26_ACTIVE_PREPARED_REBIND_REJECTED=PASS'

  batch_initial(1) = groundwater_external_gateway_config_t(service_id=801_int64, cell_id=8_int64, &
       head_native_to_m_scale=0.1_real64, head_native_zero_m=3.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=1)
  batch_initial(2) = groundwater_external_gateway_config_t(service_id=807_int64, cell_id=7_int64, &
       head_native_to_m_scale=0.1_real64, head_native_zero_m=3.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=1)
  call bind_groundwater_external_gateway_batch(batch, backend, batch_initial, status)
  call require(status == GW_EXTERNAL_GATEWAY_OK, 'initial batch bind')

  call groundwater_capture_checkpoint(batch(2), checkpoint, status)
  call require(status == GW_EXCHANGE_OK, 'batch atomicity capture')
  window = groundwater_coupling_window_t(t0=0.25_real64, t1=0.5_real64)
  call groundwater_trial_from_checkpoint(batch(2), checkpoint, window, CM_DAY_TO_M_S, candidate, trial_result, status)
  call require(status == GW_EXCHANGE_OK, 'batch atomicity trial')
  call groundwater_prepare_candidate(batch(2), checkpoint, candidate, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. .not. batch(2)%restart_quiescent(), 'batch member prepare')

  batch_rebind(1) = groundwater_external_gateway_config_t(service_id=901_int64, cell_id=9_int64, &
       head_native_to_m_scale=0.1_real64, head_native_zero_m=3.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=1)
  batch_rebind(2) = groundwater_external_gateway_config_t(service_id=910_int64, cell_id=10_int64, &
       head_native_to_m_scale=0.1_real64, head_native_zero_m=3.0_real64, &
       flux_native_to_m_per_s_scale=CM_DAY_TO_M_S, native_flux_sign_relative_to_groundwater=1)
  call bind_groundwater_external_gateway_batch(batch, backend, batch_rebind, status)
  call require(status == GW_EXTERNAL_GATEWAY_NOT_QUIESCENT, 'batch rebind did not reject non-quiescent member')
  call require(batch(1)%configured_cell_id() == 8_int64, 'failed batch rebind mutated earlier member')
  call require(batch(2)%configured_cell_id() == 7_int64, 'failed batch rebind mutated rejecting member')
  call groundwater_abort_prepared(batch(2), checkpoint, prepared, status)
  call require(status == GW_EXCHANGE_OK .and. batch(2)%restart_quiescent(), 'batch atomicity cleanup')
  print '(A)', 'FGC26_BATCH_REBIND_PREFLIGHT_ATOMIC=PASS'
  print '(A)', 'F-GC26 DIRECT COMMIT AND REBIND GATE PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write (*,'(A,A)') 'ASSERTION FAILED: ', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fgc26_direct_commit_and_rebind
