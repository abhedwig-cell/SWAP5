module mod_fmr_groundwater_swap_tangent_observation_service
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t, groundwater_head_datum_t
  use mod_groundwater_swap_forcing_adapter, only: groundwater_swap_forcing_materializer_t
  use mod_groundwater_swap_transaction_participant, only: groundwater_swap_trial_t, &
       GW_SWAP_PARTICIPANT_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_serialized_reference_backend_t
  use mod_fmr_groundwater_swap_participant, only: fmr_groundwater_swap_participant_t, &
       fmr_groundwater_swap_trial_observation_t
  implicit none
  private

  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_OK = 0
  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_INVALID_SESSION = 1
  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_ORIGIN_DRIFT = 2
  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_TRIAL_UNAVAILABLE = 3
  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_CLEANUP_FAILED = 4
  integer, parameter, public :: FMR_GW_TANGENT_OBSERVATION_CACHE_FAILED = 5

  type :: fmr_tangent_observation_cache_entry_t
    integer(int64) :: head_key = 0_int64
    type(fmr_groundwater_swap_trial_observation_t) :: observation
  end type fmr_tangent_observation_cache_entry_t

  type, public :: fmr_groundwater_swap_tangent_observation_service_t
    private
    type(fmr_tangent_observation_cache_entry_t), allocatable :: cache(:)
    integer(int64) :: session_lineage_id = 0_int64
    integer(int64) :: session_revision = -1_int64
    integer :: logical_requests = 0
    integer :: participant_trials = 0
    integer :: cache_hits = 0
    logical :: active = .false.
  contains
    procedure, public :: begin_session => fmr_tangent_begin_session
    procedure, public :: observe_head => fmr_tangent_observe_head
    procedure, public :: end_session => fmr_tangent_end_session
    procedure, public :: request_count => fmr_tangent_request_count
    procedure, public :: trial_count => fmr_tangent_trial_count
    procedure, public :: hit_count => fmr_tangent_hit_count
    procedure, public :: cached_head_count => fmr_tangent_cached_head_count
    procedure, public :: session_active => fmr_tangent_session_active
  end type fmr_groundwater_swap_tangent_observation_service_t

contains

  subroutine fmr_tangent_begin_session(self, participant, status)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(inout) :: self
    type(fmr_groundwater_swap_participant_t), intent(in) :: participant
    integer, intent(out) :: status

    call clear_session(self)
    status = FMR_GW_TANGENT_OBSERVATION_INVALID_SESSION
    if (.not. participant%has_origin()) return
    if (participant%has_live_candidate()) return

    self%session_lineage_id = participant%captured_lineage_id()
    self%session_revision = participant%captured_revision()
    if (self%session_lineage_id <= 0_int64 .or. self%session_revision < 0_int64) return

    self%active = .true.
    status = FMR_GW_TANGENT_OBSERVATION_OK
  end subroutine fmr_tangent_begin_session

  subroutine fmr_tangent_observe_head(self, participant, backend, column, template, parameters, committed, &
       materializer, numerical, datum, window, prescribed_head_m, observation, status)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(inout) :: self
    type(fmr_groundwater_swap_participant_t), intent(inout) :: participant
    type(fmr_serialized_reference_backend_t), intent(inout) :: backend
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    class(groundwater_swap_forcing_materializer_t), intent(in) :: materializer
    type(canonical_numerical_config_t), intent(in) :: numerical
    type(groundwater_head_datum_t), intent(in) :: datum
    type(groundwater_coupling_window_t), intent(in) :: window
    real(real64), intent(in) :: prescribed_head_m
    type(fmr_groundwater_swap_trial_observation_t), intent(out) :: observation
    integer, intent(out) :: status

    type(groundwater_swap_trial_t) :: trial
    integer(int64) :: key
    integer :: i, participant_status
    logical :: stored

    observation = fmr_groundwater_swap_trial_observation_t()
    status = FMR_GW_TANGENT_OBSERVATION_INVALID_SESSION
    if (.not. self%active) return
    if (.not. ieee_is_finite(prescribed_head_m)) return
    if (.not. participant_origin_matches(self, participant)) then
      status = FMR_GW_TANGENT_OBSERVATION_ORIGIN_DRIFT
      return
    end if
    if (participant%has_live_candidate()) return

    self%logical_requests = self%logical_requests + 1
    key = transfer(prescribed_head_m, key)

    do i = 1, cache_size(self)
      if (self%cache(i)%head_key == key) then
        observation = self%cache(i)%observation
        self%cache_hits = self%cache_hits + 1
        status = FMR_GW_TANGENT_OBSERVATION_OK
        return
      end if
    end do

    call participant%trial_from_origin(backend, column, template, parameters, committed, materializer, &
         numerical, datum, window, prescribed_head_m, trial, participant_status)
    self%participant_trials = self%participant_trials + 1
    call participant%observe_last_trial(observation)

    if (.not. observation%available) then
      if (participant%has_live_candidate()) call participant%discard_candidate(backend)
      status = FMR_GW_TANGENT_OBSERVATION_TRIAL_UNAVAILABLE
      return
    end if
    if (observation%participant_status /= participant_status) then
      if (participant%has_live_candidate()) call participant%discard_candidate(backend)
      status = FMR_GW_TANGENT_OBSERVATION_TRIAL_UNAVAILABLE
      return
    end if

    if (participant_status == GW_SWAP_PARTICIPANT_OK) then
      if (.not. trial%valid .or. .not. observation%q_available) then
        if (participant%has_live_candidate()) call participant%discard_candidate(backend)
        status = FMR_GW_TANGENT_OBSERVATION_TRIAL_UNAVAILABLE
        return
      end if
      if (.not. participant%has_live_candidate()) then
        status = FMR_GW_TANGENT_OBSERVATION_TRIAL_UNAVAILABLE
        return
      end if
      call participant%discard_candidate(backend)
    end if

    if (participant%has_live_candidate()) then
      status = FMR_GW_TANGENT_OBSERVATION_CLEANUP_FAILED
      return
    end if
    if (.not. participant_origin_matches(self, participant)) then
      status = FMR_GW_TANGENT_OBSERVATION_ORIGIN_DRIFT
      return
    end if

    call store_observation(self, key, observation, stored)
    if (.not. stored) then
      status = FMR_GW_TANGENT_OBSERVATION_CACHE_FAILED
      return
    end if

    status = FMR_GW_TANGENT_OBSERVATION_OK
  end subroutine fmr_tangent_observe_head

  subroutine fmr_tangent_end_session(self)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(inout) :: self
    call clear_session(self)
  end subroutine fmr_tangent_end_session

  integer function fmr_tangent_request_count(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = self%logical_requests
  end function fmr_tangent_request_count

  integer function fmr_tangent_trial_count(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = self%participant_trials
  end function fmr_tangent_trial_count

  integer function fmr_tangent_hit_count(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = self%cache_hits
  end function fmr_tangent_hit_count

  integer function fmr_tangent_cached_head_count(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = cache_size(self)
  end function fmr_tangent_cached_head_count

  logical function fmr_tangent_session_active(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = self%active
  end function fmr_tangent_session_active

  logical function participant_origin_matches(self, participant) result(matches)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    type(fmr_groundwater_swap_participant_t), intent(in) :: participant
    matches = .false.
    if (.not. participant%has_origin()) return
    if (participant%captured_lineage_id() /= self%session_lineage_id) return
    if (participant%captured_revision() /= self%session_revision) return
    matches = .true.
  end function participant_origin_matches

  integer function cache_size(self) result(value)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(in) :: self
    value = 0
    if (allocated(self%cache)) value = size(self%cache)
  end function cache_size

  subroutine store_observation(self, key, observation, stored)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(inout) :: self
    integer(int64), intent(in) :: key
    type(fmr_groundwater_swap_trial_observation_t), intent(in) :: observation
    logical, intent(out) :: stored
    type(fmr_tangent_observation_cache_entry_t), allocatable :: grown(:)
    integer :: n, stat

    stored = .false.
    n = cache_size(self)
    allocate(grown(n+1), stat=stat)
    if (stat /= 0) return
    if (n > 0) grown(1:n) = self%cache
    grown(n+1)%head_key = key
    grown(n+1)%observation = observation
    call move_alloc(grown, self%cache)
    stored = .true.
  end subroutine store_observation

  subroutine clear_session(self)
    class(fmr_groundwater_swap_tangent_observation_service_t), intent(inout) :: self
    if (allocated(self%cache)) deallocate(self%cache)
    self%session_lineage_id = 0_int64
    self%session_revision = -1_int64
    self%logical_requests = 0
    self%participant_trials = 0
    self%cache_hits = 0
    self%active = .false.
  end subroutine clear_session

end module mod_fmr_groundwater_swap_tangent_observation_service
