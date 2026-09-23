module mod_fmr_hupsel_management_transaction
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_parameters_t, &
       tcs1_dcs2_sprinkling_state_t, tcs1_dcs2_sprinkling_request_t, tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t, evaluate_tcs1_dcs2_sprinkling_interval, &
       TCS1_DCS2_OK, TCS1_DCS2_SPLIT_REQUIRED
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t, rutter_interval_result_t, &
       rutter_diagnostics_t, evaluate_rutter_interval, RUTTER_OK
  implicit none
  private

  integer, parameter, public :: FMR_RM_OK = 0
  integer, parameter, public :: FMR_RM_INVALID_STATE = 1
  integer, parameter, public :: FMR_RM_INVALID_PARAMETERS = 2
  integer, parameter, public :: FMR_RM_INVALID_FORCING = 3
  integer, parameter, public :: FMR_RM_INVALID_POLICY = 4
  integer, parameter, public :: FMR_RM_INTERVAL_MISMATCH = 5
  integer, parameter, public :: FMR_RM_IRRIGATION_DECISION_FAILED = 6
  integer, parameter, public :: FMR_RM_PARTIAL_SUPPLY_NOT_ADMITTED = 7
  integer, parameter, public :: FMR_RM_ACTIVE_EVENT_ORIGIN_NOT_ADMITTED = 8
  integer, parameter, public :: FMR_RM_RUTTER_FAILED = 9
  integer, parameter, public :: FMR_RM_INVALID_TRANSACTION_STATE = 10

  type, public :: fmr_hupsel_management_persistence_t
    logical :: valid = .false.
    type(tcs1_dcs2_sprinkling_state_t) :: irrigation
    type(rutter_state_t) :: rutter
  contains
    procedure, public :: ready => fmr_hupsel_management_persistence_ready
  end type fmr_hupsel_management_persistence_t

  type, extends(transaction_state_t), public :: fmr_hupsel_management_state_t
    private
    logical :: initialized = .false.
    type(tcs1_dcs2_sprinkling_state_t) :: irrigation
    type(rutter_state_t) :: rutter
  contains
    procedure :: clone => fmr_hupsel_management_clone
    procedure, public :: ready => fmr_hupsel_management_state_ready
    procedure, public :: snapshot => fmr_hupsel_management_snapshot
  end type fmr_hupsel_management_state_t

  type, extends(kernel_parameters_t), public :: fmr_hupsel_management_parameters_t
    private
    logical :: initialized = .false.
    type(tcs1_dcs2_sprinkling_parameters_t) :: irrigation
  contains
    procedure, public :: ready => fmr_hupsel_management_parameters_ready
  end type fmr_hupsel_management_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_hupsel_management_forcing_t
    private
    logical :: initialized = .false.
    type(tcs1_dcs2_sprinkling_request_t) :: irrigation_request
    type(rutter_interval_input_t) :: rutter_template
    integer(int64) :: crop_origin_revision = -1_int64
    real(real64) :: allocated_depth_cm = 0.0_real64
    real(real64) :: supplied_depth_cm = 0.0_real64
  contains
    procedure, public :: ready => fmr_hupsel_management_forcing_ready
  end type fmr_hupsel_management_forcing_t

  type, public :: fmr_hupsel_management_observation_t
    logical :: decision_evaluated = .false.
    logical :: irrigation_requested = .false.
    real(real64) :: requested_depth_cm = 0.0_real64
    real(real64) :: allocated_depth_cm = 0.0_real64
    real(real64) :: supplied_depth_cm = 0.0_real64
    real(real64) :: allocation_shortage_cm = 0.0_real64
    real(real64) :: realization_shortage_cm = 0.0_real64
    real(real64) :: gross_surface_rate_cm_per_day = 0.0_real64
    real(real64) :: net_surface_irrigation_amount_cm = 0.0_real64
    integer(int64) :: crop_origin_revision = -1_int64
  end type fmr_hupsel_management_observation_t

  type, extends(kernel_model_t), public :: fmr_hupsel_management_model_t
    private
    type(tcs1_dcs2_sprinkling_parameters_t) :: irrigation_parameters
    logical :: parameters_ready = .false.
    type(fmr_hupsel_management_forcing_t) :: forcing
    logical :: interval_ready = .false.
    integer :: last_status = FMR_RM_OK
    type(fmr_hupsel_management_observation_t) :: last_observation
  contains
    procedure :: configure_parameters => fmr_hupsel_management_configure_parameters
    procedure :: execution_admitted => fmr_hupsel_management_execution_admitted
    procedure :: prepare_interval => fmr_hupsel_management_prepare_interval
    procedure :: advance => fmr_hupsel_management_advance
    procedure :: storage => fmr_hupsel_management_storage
    procedure :: temporal_error => fmr_hupsel_management_temporal_error
    procedure :: storage_accounting_status => fmr_hupsel_management_storage_accounting_status
    procedure, public :: last_status_code => fmr_hupsel_management_last_status_code
    procedure, public :: observation => fmr_hupsel_management_observation
  end type fmr_hupsel_management_model_t

  public :: initialize_fmr_hupsel_management_state
  public :: construct_fmr_hupsel_management_parameters
  public :: prepare_fmr_hupsel_management_forcing
  public :: export_fmr_hupsel_management_persistence
  public :: reconstruct_fmr_hupsel_management_from_persistence

contains

  pure logical function valid_irrigation_state(state) result(ok)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: state
    ok = state%dayfix >= 0
    if (.not. ok) return
    if (state%active_event) then
      ok = ieee_is_finite(state%active_event_start) .and. ieee_is_finite(state%active_event_end) .and. &
           state%active_event_end > state%active_event_start
    else
      ok = abs(state%active_event_start) <= epsilon(1.0_real64) .and. &
           abs(state%active_event_end) <= epsilon(1.0_real64)
    end if
  end function valid_irrigation_state

  pure logical function valid_rutter_state(state) result(ok)
    type(rutter_state_t), intent(in) :: state
    ok = ieee_is_finite(state%canopy_storage_cm) .and. state%canopy_storage_cm >= 0.0_real64
  end function valid_rutter_state

  logical function fmr_hupsel_management_persistence_ready(self) result(ready)
    class(fmr_hupsel_management_persistence_t), intent(in) :: self
    ready = self%valid .and. valid_irrigation_state(self%irrigation) .and. valid_rutter_state(self%rutter)
  end function fmr_hupsel_management_persistence_ready

  subroutine initialize_fmr_hupsel_management_state(irrigation, rutter, state, status)
    type(tcs1_dcs2_sprinkling_state_t), intent(in) :: irrigation
    type(rutter_state_t), intent(in) :: rutter
    type(fmr_hupsel_management_state_t), intent(out) :: state
    integer, intent(out) :: status

    state = fmr_hupsel_management_state_t()
    status = FMR_RM_INVALID_STATE
    if (.not. valid_irrigation_state(irrigation) .or. .not. valid_rutter_state(rutter)) return
    state%irrigation = irrigation
    state%rutter = rutter
    state%initialized = .true.
    status = FMR_RM_OK
  end subroutine initialize_fmr_hupsel_management_state

  subroutine construct_fmr_hupsel_management_parameters(irrigation, parameters, status)
    type(tcs1_dcs2_sprinkling_parameters_t), intent(in) :: irrigation
    type(fmr_hupsel_management_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    type(tcs1_dcs2_sprinkling_state_t) :: seed, candidate
    type(tcs1_dcs2_sprinkling_request_t) :: request
    type(tcs1_dcs2_sprinkling_result_t) :: result
    type(tcs1_dcs2_sprinkling_diagnostics_t) :: diagnostics

    parameters = fmr_hupsel_management_parameters_t()
    status = FMR_RM_INVALID_PARAMETERS

    ! Reuse the admitted process validator without adding a second scientific
    ! validation implementation. A deliberately gated request forces parameter
    ! validation while leaving the seed immutable.
    seed = tcs1_dcs2_sprinkling_state_t()
    request = tcs1_dcs2_sprinkling_request_t()
    request%t0 = 0.0_real64
    request%t1 = 1.0_real64
    request%dvs = 0.0_real64
    request%selection_opportunity = .true.
    request%irrigation_enabled = .true.
    request%schedule_enabled = .true.
    request%crop_emerged = .true.
    request%irrigation_window_open = .true.
    call evaluate_tcs1_dcs2_sprinkling_interval(irrigation, seed, request, candidate, result, diagnostics)
    if (diagnostics%status /= TCS1_DCS2_OK .and. diagnostics%status /= TCS1_DCS2_SPLIT_REQUIRED) return

    parameters%irrigation = irrigation
    parameters%initialized = .true.
    status = FMR_RM_OK
  end subroutine construct_fmr_hupsel_management_parameters

  subroutine prepare_fmr_hupsel_management_forcing(request, rutter_template, crop_origin_revision, &
       allocated_depth_cm, supplied_depth_cm, forcing, status)
    type(tcs1_dcs2_sprinkling_request_t), intent(in) :: request
    type(rutter_interval_input_t), intent(in) :: rutter_template
    integer(int64), intent(in) :: crop_origin_revision
    real(real64), intent(in) :: allocated_depth_cm, supplied_depth_cm
    type(fmr_hupsel_management_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status

    forcing = fmr_hupsel_management_forcing_t()
    status = FMR_RM_INVALID_FORCING
    if (crop_origin_revision < 0_int64) return
    if (.not. ieee_is_finite(request%t0) .or. .not. ieee_is_finite(request%t1) .or. request%t1 <= request%t0) return
    if (.not. ieee_is_finite(allocated_depth_cm) .or. .not. ieee_is_finite(supplied_depth_cm)) return
    if (allocated_depth_cm < 0.0_real64 .or. supplied_depth_cm < 0.0_real64) return
    if (supplied_depth_cm > allocated_depth_cm + quantity_tolerance(allocated_depth_cm, supplied_depth_cm)) return
    if (.not. ieee_is_finite(rutter_template%gross_rain_cm_per_day)) return
    if (.not. ieee_is_finite(rutter_template%vegetation_cover_fraction)) return
    if (.not. ieee_is_finite(rutter_template%canopy_storage_capacity_cm)) return
    if (.not. ieee_is_finite(rutter_template%interception_evaporation_capacity_cm_per_day)) return
    if (.not. ieee_is_finite(rutter_template%potential_transpiration_dry_cm_per_day)) return
    if (.not. ieee_is_finite(rutter_template%potential_transpiration_wet_cm_per_day)) return

    forcing%irrigation_request = request
    forcing%rutter_template = rutter_template
    forcing%crop_origin_revision = crop_origin_revision
    forcing%allocated_depth_cm = allocated_depth_cm
    forcing%supplied_depth_cm = supplied_depth_cm
    forcing%initialized = .true.
    status = FMR_RM_OK
  end subroutine prepare_fmr_hupsel_management_forcing

  subroutine export_fmr_hupsel_management_persistence(state, view, exported, status)
    type(fmr_hupsel_management_state_t), intent(in) :: state
    type(fmr_hupsel_management_persistence_t), intent(out) :: view
    logical, intent(out) :: exported
    integer, intent(out) :: status

    view = fmr_hupsel_management_persistence_t()
    exported = .false.
    status = FMR_RM_INVALID_STATE
    if (.not. state%ready()) return
    view%irrigation = state%irrigation
    view%rutter = state%rutter
    view%valid = .true.
    if (.not. view%ready()) return
    exported = .true.
    status = FMR_RM_OK
  end subroutine export_fmr_hupsel_management_persistence

  subroutine reconstruct_fmr_hupsel_management_from_persistence(view, state, reconstructed, status)
    type(fmr_hupsel_management_persistence_t), intent(in) :: view
    type(fmr_hupsel_management_state_t), intent(out) :: state
    logical, intent(out) :: reconstructed
    integer, intent(out) :: status

    state = fmr_hupsel_management_state_t()
    reconstructed = .false.
    status = FMR_RM_INVALID_STATE
    if (.not. view%ready()) return
    call initialize_fmr_hupsel_management_state(view%irrigation, view%rutter, state, status)
    reconstructed = status == FMR_RM_OK
  end subroutine reconstruct_fmr_hupsel_management_from_persistence

  subroutine fmr_hupsel_management_clone(self, copy)
    class(fmr_hupsel_management_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fmr_hupsel_management_state_t :: copy)
    select type (typed => copy)
    type is (fmr_hupsel_management_state_t)
      typed%initialized = self%initialized
      typed%irrigation = self%irrigation
      typed%rutter = self%rutter
    class default
      error stop 'RM05 management clone allocation failure'
    end select
  end subroutine fmr_hupsel_management_clone

  logical function fmr_hupsel_management_state_ready(self) result(ready)
    class(fmr_hupsel_management_state_t), intent(in) :: self
    ready = self%initialized .and. valid_irrigation_state(self%irrigation) .and. valid_rutter_state(self%rutter)
  end function fmr_hupsel_management_state_ready

  subroutine fmr_hupsel_management_snapshot(self, irrigation, rutter, available)
    class(fmr_hupsel_management_state_t), intent(in) :: self
    type(tcs1_dcs2_sprinkling_state_t), intent(out) :: irrigation
    type(rutter_state_t), intent(out) :: rutter
    logical, intent(out) :: available

    irrigation = tcs1_dcs2_sprinkling_state_t()
    rutter = rutter_state_t()
    available = self%ready()
    if (.not. available) return
    irrigation = self%irrigation
    rutter = self%rutter
  end subroutine fmr_hupsel_management_snapshot

  logical function fmr_hupsel_management_parameters_ready(self) result(ready)
    class(fmr_hupsel_management_parameters_t), intent(in) :: self
    ready = self%initialized
  end function fmr_hupsel_management_parameters_ready

  logical function fmr_hupsel_management_forcing_ready(self) result(ready)
    class(fmr_hupsel_management_forcing_t), intent(in) :: self
    ready = self%initialized .and. self%crop_origin_revision >= 0_int64 .and. &
         ieee_is_finite(self%allocated_depth_cm) .and. ieee_is_finite(self%supplied_depth_cm) .and. &
         self%allocated_depth_cm >= 0.0_real64 .and. self%supplied_depth_cm >= 0.0_real64 .and. &
         self%supplied_depth_cm <= self%allocated_depth_cm + &
           quantity_tolerance(self%allocated_depth_cm, self%supplied_depth_cm)
  end function fmr_hupsel_management_forcing_ready

  subroutine fmr_hupsel_management_configure_parameters(self, parameters)
    class(fmr_hupsel_management_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    self%parameters_ready = .false.
    self%last_status = FMR_RM_INVALID_PARAMETERS
    select type (typed => parameters)
    type is (fmr_hupsel_management_parameters_t)
      if (.not. typed%ready()) return
      self%irrigation_parameters = typed%irrigation
      self%parameters_ready = .true.
      self%last_status = FMR_RM_OK
    class default
      return
    end select
  end subroutine fmr_hupsel_management_configure_parameters

  logical function fmr_hupsel_management_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    admitted = .false.
    if (.not. same_type_as(self, self)) return
    if (numerical_config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (numerical_config%transaction%max_retries /= 0) return
    if (numerical_config%max_committed_substeps /= 1) return
    select type (typed => parameters)
    type is (fmr_hupsel_management_parameters_t)
      admitted = typed%ready()
    class default
      admitted = .false.
    end select
  end function fmr_hupsel_management_execution_admitted

  subroutine fmr_hupsel_management_prepare_interval(self, forcing, interval, config)
    class(fmr_hupsel_management_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%interval_ready = .false.
    self%forcing = fmr_hupsel_management_forcing_t()
    self%last_observation = fmr_hupsel_management_observation_t()
    self%last_status = FMR_RM_INVALID_FORCING
    if (config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE .or. &
        config%transaction%max_retries /= 0 .or. config%max_committed_substeps /= 1) then
      self%last_status = FMR_RM_INVALID_POLICY
      return
    end if
    select type (typed => forcing)
    type is (fmr_hupsel_management_forcing_t)
      if (.not. typed%ready()) return
      if (.not. same_time(typed%irrigation_request%t0, interval%t0) .or. &
          .not. same_time(typed%irrigation_request%t1, interval%t1)) then
        self%last_status = FMR_RM_INTERVAL_MISMATCH
        return
      end if
      self%forcing = typed
      self%interval_ready = .true.
      self%last_status = FMR_RM_OK
    class default
      return
    end select
  end subroutine fmr_hupsel_management_prepare_interval

  subroutine fmr_hupsel_management_advance(self, state, t0, t1, outcome)
    class(fmr_hupsel_management_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(tcs1_dcs2_sprinkling_request_t) :: request
    type(tcs1_dcs2_sprinkling_state_t) :: irrigation_candidate
    type(tcs1_dcs2_sprinkling_result_t) :: irrigation_result
    type(tcs1_dcs2_sprinkling_diagnostics_t) :: irrigation_diagnostics
    type(rutter_interval_input_t) :: rutter_input
    type(rutter_interval_result_t) :: rutter_result
    type(rutter_diagnostics_t) :: rutter_diagnostics
    real(real64) :: requested_depth, event_end, tol

    outcome = trial_outcome_t()
    self%last_observation = fmr_hupsel_management_observation_t()
    self%last_status = FMR_RM_INVALID_TRANSACTION_STATE
    if (.not. self%parameters_ready .or. .not. self%interval_ready) return
    if (.not. same_time(self%forcing%irrigation_request%t0, t0) .or. &
        .not. same_time(self%forcing%irrigation_request%t1, t1)) then
      self%last_status = FMR_RM_INTERVAL_MISMATCH
      return
    end if

    select type (typed => state)
    type is (fmr_hupsel_management_state_t)
      if (.not. typed%ready()) return
      if (typed%irrigation%active_event) then
        self%last_status = FMR_RM_ACTIVE_EVENT_ORIGIN_NOT_ADMITTED
        return
      end if

      request = self%forcing%irrigation_request
      call evaluate_tcs1_dcs2_sprinkling_interval(self%irrigation_parameters, typed%irrigation, request, &
           irrigation_candidate, irrigation_result, irrigation_diagnostics)

      if (irrigation_diagnostics%status == TCS1_DCS2_SPLIT_REQUIRED) then
        event_end = irrigation_diagnostics%split_time
        request%t1 = event_end
        call evaluate_tcs1_dcs2_sprinkling_interval(self%irrigation_parameters, typed%irrigation, request, &
             irrigation_candidate, irrigation_result, irrigation_diagnostics)
      end if
      if (irrigation_diagnostics%status /= TCS1_DCS2_OK) then
        self%last_status = FMR_RM_IRRIGATION_DECISION_FAILED
        return
      end if

      requested_depth = 0.0_real64
      if (irrigation_result%event_started) requested_depth = irrigation_result%event_depth_cm
      self%last_observation%decision_evaluated = .true.
      self%last_observation%irrigation_requested = requested_depth > 0.0_real64
      self%last_observation%requested_depth_cm = requested_depth
      self%last_observation%allocated_depth_cm = self%forcing%allocated_depth_cm
      self%last_observation%supplied_depth_cm = self%forcing%supplied_depth_cm
      self%last_observation%allocation_shortage_cm = max(0.0_real64, requested_depth-self%forcing%allocated_depth_cm)
      self%last_observation%realization_shortage_cm = &
           max(0.0_real64, self%forcing%allocated_depth_cm-self%forcing%supplied_depth_cm)
      self%last_observation%crop_origin_revision = self%forcing%crop_origin_revision

      tol = quantity_tolerance(requested_depth, self%forcing%allocated_depth_cm)
      if (requested_depth <= tol) then
        if (self%forcing%allocated_depth_cm > tol .or. self%forcing%supplied_depth_cm > tol) then
          self%last_status = FMR_RM_INVALID_FORCING
          return
        end if
        typed%irrigation = irrigation_candidate
        self%last_status = FMR_RM_OK
      else
        ! RM05 intentionally admits only exact full realization. This prevents
        ! a new partial-irrigation/dayfix policy from being invented implicitly.
        if (abs(self%forcing%allocated_depth_cm-requested_depth) > tol .or. &
            abs(self%forcing%supplied_depth_cm-requested_depth) > tol) then
          self%last_status = FMR_RM_PARTIAL_SUPPLY_NOT_ADMITTED
          return
        end if
        if (.not. irrigation_result%applied .or. irrigation_result%event_duration_day <= 0.0_real64) then
          self%last_status = FMR_RM_IRRIGATION_DECISION_FAILED
          return
        end if

        rutter_input = self%forcing%rutter_template
        rutter_input%surface_irrigation_cm_per_day = irrigation_result%gross_surface_rate_cm_per_day
        rutter_input%surface_irrigation_is_intercepted = .true.
        rutter_input%interval_days = irrigation_result%event_duration_day
        call evaluate_rutter_interval(typed%rutter, rutter_input, rutter_result, rutter_diagnostics)
        if (rutter_diagnostics%status /= RUTTER_OK .or. .not. rutter_diagnostics%result_produced) then
          self%last_status = FMR_RM_RUTTER_FAILED
          return
        end if

        typed%irrigation = irrigation_candidate
        typed%rutter = rutter_result%candidate_state
        self%last_observation%gross_surface_rate_cm_per_day = irrigation_result%gross_surface_rate_cm_per_day
        self%last_observation%net_surface_irrigation_amount_cm = &
             rutter_result%net_surface_irrigation_cm_per_day * irrigation_result%event_duration_day
        self%last_status = FMR_RM_OK
      end if

      outcome%solver_ok = .true.
      ! This owner carries process continuation only. Water mass remains owned
      ! by the outer SWAP/Ribasim physical transfer ledger and SWAP hydrology.
      outcome%mass_in = 0.0_real64
      outcome%mass_out = 0.0_real64
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = 0.0_real64
    class default
      self%last_status = FMR_RM_INVALID_TRANSACTION_STATE
      return
    end select
  end subroutine fmr_hupsel_management_advance

  real(real64) function fmr_hupsel_management_storage(self, state) result(value)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(state, state)) value = 0.0_real64
  end function fmr_hupsel_management_storage

  real(real64) function fmr_hupsel_management_temporal_error(self, full_state, half_state) result(value)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, half_state)) value = huge(0.0_real64)
  end function fmr_hupsel_management_temporal_error

  subroutine fmr_hupsel_management_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. same_type_as(self, self)) return
    select type (typed => state)
    type is (fmr_hupsel_management_state_t)
      complete = typed%ready()
      if (complete) missing_mask = TX_MASS_MISSING_NONE
    class default
      complete = .false.
    end select
  end subroutine fmr_hupsel_management_storage_accounting_status

  integer function fmr_hupsel_management_last_status_code(self) result(status)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    status = self%last_status
  end function fmr_hupsel_management_last_status_code

  subroutine fmr_hupsel_management_observation(self, observation)
    class(fmr_hupsel_management_model_t), intent(in) :: self
    type(fmr_hupsel_management_observation_t), intent(out) :: observation
    observation = self%last_observation
  end subroutine fmr_hupsel_management_observation

  pure real(real64) function quantity_tolerance(a, b) result(tol)
    real(real64), intent(in) :: a, b
    tol = 128.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(a), abs(b))
  end function quantity_tolerance

  pure logical function same_time(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = abs(a-b) <= 128.0_real64 * epsilon(1.0_real64) * max(1.0_real64, abs(a), abs(b))
  end function same_time

end module mod_fmr_hupsel_management_transaction
