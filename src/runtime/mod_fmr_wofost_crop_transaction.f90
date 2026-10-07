module mod_fmr_wofost_crop_transaction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_forcing_t, canonical_interval_t, canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_forcing_t, &
       wofost_accepted_window_aggregates_t, wofost_one_day_update_parameters_t, wofost_one_day_rate_packet_t
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t, wofost_rate_scalar_parameters_t, WOFOST_RATE_PARAMETER_OK
  use mod_wofost_phenology_rate_contract, only: wofost_phenology_rate_t
  use mod_wofost_phenology_dispatch, only: wofost_phenology_request_t, wofost_phenology_dispatch_result_t, &
       resolve_wofost_phenology, WOFOST_PHENOLOGY_CLASSIC, WOFOST_PHENOLOGY_SOYBEAN, &
       WOFOST_PHENOLOGY_VERNALISATION, WOFOST_PHENOLOGY_DISPATCH_OK
  use mod_wofost_soybean_phenology_factors, only: soybean_phenology_parameters_t
  use mod_wofost_vernalisation_phenology, only: wofost_vernalisation_parameters_t
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, &
       initialize_wofost_potential_shadow_from_actual, WOFOST_POTENTIAL_SHADOW_OK
  use mod_wofost_potential_shadow_daily, only: wofost_potential_daily_result_t, &
       evaluate_wofost_potential_shadow_day, WOFOST_POTENTIAL_DAILY_OK
  use mod_wofost_two_phase_crop_window, only: wofost_two_phase_crop_window_t, &
       wofost_crop_window_begin_diagnostics_t, wofost_crop_window_complete_diagnostics_t, &
       begin_wofost_one_day_crop_window, complete_wofost_one_day_crop_window, WOFOST_CROP_WINDOW_OK
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, &
       prepare_wofost_crop_event_delivery, identify_wofost_crop_event, &
       same_wofost_crop_event_identity, crop_event_identity_matches_interval, FMR_WOFOST_LINEAGE_OK, &
       export_wofost_crop_event_identity_persistence, &
       reconstruct_wofost_crop_event_identity_from_persistence
  implicit none
  private

  integer, parameter, public :: FMR_WOF38_OK = 0
  integer, parameter, public :: FMR_WOF38_INVALID_OWNER = 1
  integer, parameter, public :: FMR_WOF38_INVALID_PARAMETERS = 2
  integer, parameter, public :: FMR_WOF38_INVALID_EVENT = 3
  integer, parameter, public :: FMR_WOF38_INVALID_POLICY = 4
  integer, parameter, public :: FMR_WOF38_EVENT_INTERVAL_MISMATCH = 5
  integer, parameter, public :: FMR_WOF38_EVENT_ALREADY_CONSUMED = 6
  integer, parameter, public :: FMR_WOF38_CROP_BEGIN_ERROR = 7
  integer, parameter, public :: FMR_WOF38_CROP_COMPLETE_ERROR = 8
  integer, parameter, public :: FMR_WOF38_INVALID_TRANSACTION_STATE = 9
  integer, parameter, public :: FMR_WOF38_POTENTIAL_ERROR = 10
  integer, parameter, public :: FMR_WOF38_PHENOLOGY_ERROR = 11

  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_OK = 0
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE = 1
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW = 2
  integer, parameter, public :: FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT = 3

  type, public :: fmr_wofost_root_growth_carrier_t
    real(real64) :: actual_gross_root_growth = 0.0_real64
    real(real64) :: potential_gross_root_growth = 0.0_real64
    logical :: valid = .false.
  contains
    procedure, public :: ready => fmr_wofost_root_growth_carrier_ready
  end type fmr_wofost_root_growth_carrier_t

  type, extends(transaction_state_t), public :: fmr_wofost_crop_transaction_state_t
    private
    logical :: initialized = .false.
    type(wofost_crop_owner_state_t) :: owner
    type(wofost_potential_shadow_state_t), allocatable :: potential_shadow
    type(fmr_wofost_root_growth_carrier_t), allocatable :: root_growth_carrier
    type(fmr_wofost_crop_event_identity_t) :: last_consumed_event
  contains
    procedure :: clone => fmr_wofost_crop_transaction_clone
    procedure, public :: ready => fmr_wofost_crop_transaction_state_ready
    procedure, public :: snapshot_owner => fmr_wofost_crop_transaction_snapshot_owner
    procedure, public :: potential_shadow_enabled => fmr_wofost_crop_transaction_potential_shadow_enabled
    procedure, public :: snapshot_potential_shadow => fmr_wofost_crop_transaction_snapshot_potential_shadow
    procedure, public :: snapshot_root_growth => fmr_wofost_crop_transaction_snapshot_root_growth
    procedure, public :: receipt_ready => fmr_wofost_crop_transaction_receipt_ready
    procedure, public :: consumed_event => fmr_wofost_crop_transaction_consumed_event
  end type fmr_wofost_crop_transaction_state_t

  ! Compact physical continuation view. Parameters, forcing and retired
  ! accepted-window cache are deliberately absent.
  type, public :: fmr_wofost_crop_transaction_persistence_t
    logical :: valid = .false.
    type(wofost_crop_owner_state_t) :: owner
    logical :: potential_shadow_present = .false.
    type(wofost_potential_shadow_state_t) :: potential_shadow
    logical :: root_growth_carrier_present = .false.
    type(fmr_wofost_root_growth_carrier_t) :: root_growth_carrier
    logical :: receipt_present = .false.
    type(fmr_wofost_crop_event_identity_persistence_t) :: receipt
  contains
    procedure, public :: ready => fmr_wofost_crop_transaction_persistence_ready
  end type fmr_wofost_crop_transaction_persistence_t

  type, extends(kernel_parameters_t), public :: fmr_wofost_crop_transaction_parameters_t
    private
    logical :: initialized = .false.
    type(wofost_rate_parameter_bundle_t) :: rate_parameters
    type(wofost_one_day_update_parameters_t) :: update_parameters
    real(real64) :: stem_area_coefficient = 0.0_real64
    real(real64) :: storage_area_coefficient = 0.0_real64
    logical :: potential_shadow_enabled = .false.
    real(real64) :: potential_attainable_multiplier = 1.0_real64
    integer :: phenology_mode = WOFOST_PHENOLOGY_CLASSIC
    type(soybean_phenology_parameters_t), allocatable :: soybean_phenology
    type(wofost_vernalisation_parameters_t), allocatable :: vernalisation_phenology
  contains
    procedure, public :: ready => fmr_wofost_crop_transaction_parameters_ready
  end type fmr_wofost_crop_transaction_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_wofost_crop_event_forcing_t
    private
    logical :: initialized = .false.
    type(wofost_one_day_forcing_t) :: crop_forcing
    type(wofost_accepted_window_aggregates_t) :: accepted_aggregates
    type(fmr_wofost_crop_event_identity_t) :: event_identity
    real(real64) :: soybean_latitude_degrees = 0.0_real64
    integer :: soybean_day_of_year = 1
  contains
    procedure, public :: ready => fmr_wofost_crop_event_forcing_ready
  end type fmr_wofost_crop_event_forcing_t

  type, extends(kernel_model_t), public :: fmr_wofost_crop_transaction_model_t
    private
    type(wofost_rate_parameter_bundle_t) :: rate_parameters
    type(wofost_one_day_update_parameters_t) :: update_parameters
    real(real64) :: stem_area_coefficient = 0.0_real64
    real(real64) :: storage_area_coefficient = 0.0_real64
    logical :: potential_shadow_enabled = .false.
    real(real64) :: potential_attainable_multiplier = 1.0_real64
    integer :: phenology_mode = WOFOST_PHENOLOGY_CLASSIC
    type(soybean_phenology_parameters_t), allocatable :: soybean_phenology
    type(wofost_vernalisation_parameters_t), allocatable :: vernalisation_phenology
    logical :: parameters_ready = .false.
    type(fmr_wofost_crop_event_forcing_t) :: event_forcing
    logical :: interval_ready = .false.
    integer :: last_status = FMR_WOF38_OK
  contains
    procedure :: configure_parameters => fmr_wofost_crop_configure_parameters
    procedure :: execution_admitted => fmr_wofost_crop_execution_admitted
    procedure :: prepare_interval => fmr_wofost_crop_prepare_interval
    procedure :: advance => fmr_wofost_crop_advance
    procedure :: storage => fmr_wofost_crop_storage
    procedure :: temporal_error => fmr_wofost_crop_temporal_error
    procedure :: storage_accounting_status => fmr_wofost_crop_storage_accounting_status
    procedure, public :: last_status_code => fmr_wofost_crop_last_status_code
  end type fmr_wofost_crop_transaction_model_t

  public :: initialize_fmr_wofost_crop_transaction_state
  public :: construct_fmr_wofost_crop_transaction_parameters
  public :: prepare_fmr_wofost_crop_event_forcing
  public :: export_fmr_wofost_crop_transaction_persistence
  public :: reconstruct_fmr_wofost_crop_transaction_from_persistence

contains

  logical function fmr_wofost_root_growth_carrier_ready(self) result(ready)
    class(fmr_wofost_root_growth_carrier_t), intent(in) :: self
    ready = self%valid .and. ieee_is_finite(self%actual_gross_root_growth) .and. &
         ieee_is_finite(self%potential_gross_root_growth) .and. &
         self%actual_gross_root_growth >= 0.0_real64 .and. self%potential_gross_root_growth >= 0.0_real64
  end function fmr_wofost_root_growth_carrier_ready

  logical function fmr_wofost_crop_transaction_persistence_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_persistence_t), intent(in) :: self
    ready = .false.
    if (.not. self%valid) return
    if (self%owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (self%potential_shadow_present) then
      if (self%potential_shadow%validate() /= WOFOST_POTENTIAL_SHADOW_OK) return
      if (.not. self%root_growth_carrier_present) return
    else
      if (self%root_growth_carrier_present) return
    end if
    if (self%root_growth_carrier_present) then
      if (self%root_growth_carrier%valid) then
        if (.not. self%root_growth_carrier%ready()) return
      else
        ! Before the first accepted crop event the optional shadow already
        ! exists but no accepted GRRT/GRRTPOT observation exists yet.
        ! A receipt proves an event was consumed and therefore requires a
        ! ready root-growth carrier.
        if (self%receipt_present) return
      end if
    end if
    if (self%receipt_present) then
      if (.not. self%receipt%ready()) return
    else
      if (self%receipt%valid) return
    end if
    ready = .true.
  end function fmr_wofost_crop_transaction_persistence_ready

  subroutine export_fmr_wofost_crop_transaction_persistence(state, view, exported, status)
    type(fmr_wofost_crop_transaction_state_t), intent(in) :: state
    type(fmr_wofost_crop_transaction_persistence_t), intent(out) :: view
    logical, intent(out) :: exported
    integer, intent(out) :: status
    logical :: receipt_exported

    view = fmr_wofost_crop_transaction_persistence_t()
    exported = .false.
    status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE
    if (.not. state%ready()) return
    view%owner = state%owner
    if (allocated(state%potential_shadow)) then
      view%potential_shadow = state%potential_shadow
      view%potential_shadow_present = .true.
      if (allocated(state%root_growth_carrier)) then
        view%root_growth_carrier = state%root_growth_carrier
        view%root_growth_carrier_present = .true.
      end if
    end if
    if (state%last_consumed_event%ready()) then
      call export_wofost_crop_event_identity_persistence(state%last_consumed_event, view%receipt, receipt_exported)
      if (.not. receipt_exported) then
        status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT
        return
      end if
      view%receipt_present = .true.
    end if
    view%valid = .true.
    if (.not. view%ready()) then
      view = fmr_wofost_crop_transaction_persistence_t()
      status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW
      return
    end if
    exported = .true.
    status = FMR_WOFOST_CROP_PERSISTENCE_OK
  end subroutine export_fmr_wofost_crop_transaction_persistence

  subroutine reconstruct_fmr_wofost_crop_transaction_from_persistence(view, state, reconstructed, status)
    type(fmr_wofost_crop_transaction_persistence_t), intent(in) :: view
    type(fmr_wofost_crop_transaction_state_t), intent(out) :: state
    logical, intent(out) :: reconstructed
    integer, intent(out) :: status
    integer :: receipt_status

    state = fmr_wofost_crop_transaction_state_t()
    reconstructed = .false.
    status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_VIEW
    if (.not. view%ready()) return
    state%owner = view%owner
    if (view%potential_shadow_present) then
      allocate(state%potential_shadow)
      state%potential_shadow = view%potential_shadow
      allocate(state%root_growth_carrier)
      state%root_growth_carrier = view%root_growth_carrier
    end if
    if (view%receipt_present) then
      call reconstruct_wofost_crop_event_identity_from_persistence(view%receipt, state%last_consumed_event, receipt_status)
      if (receipt_status /= FMR_WOFOST_LINEAGE_OK) then
        state = fmr_wofost_crop_transaction_state_t()
        status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_RECEIPT
        return
      end if
    end if
    state%initialized = .true.
    if (.not. state%ready()) then
      state = fmr_wofost_crop_transaction_state_t()
      status = FMR_WOFOST_CROP_PERSISTENCE_INVALID_STATE
      return
    end if
    reconstructed = .true.
    status = FMR_WOFOST_CROP_PERSISTENCE_OK
  end subroutine reconstruct_fmr_wofost_crop_transaction_from_persistence

  subroutine initialize_fmr_wofost_crop_transaction_state(owner, state, status, enable_potential_shadow)
    type(wofost_crop_owner_state_t), intent(in) :: owner
    type(fmr_wofost_crop_transaction_state_t), intent(out) :: state
    integer, intent(out) :: status
    logical, intent(in), optional :: enable_potential_shadow
    logical :: enable_shadow
    integer :: shadow_status

    state = fmr_wofost_crop_transaction_state_t()
    enable_shadow = .false.
    if (present(enable_potential_shadow)) enable_shadow = enable_potential_shadow
    status = FMR_WOF38_INVALID_OWNER
    if (owner%validate() /= WOFOST_CROP_OWNER_OK) return
    state%owner = owner
    if (enable_shadow) then
      allocate(state%potential_shadow, state%root_growth_carrier)
      call initialize_wofost_potential_shadow_from_actual(owner, state%potential_shadow, shadow_status)
      if (shadow_status /= WOFOST_POTENTIAL_SHADOW_OK) then
        state = fmr_wofost_crop_transaction_state_t()
        return
      end if
      state%root_growth_carrier = fmr_wofost_root_growth_carrier_t()
    end if
    state%initialized = .true.
    status = FMR_WOF38_OK
  end subroutine initialize_fmr_wofost_crop_transaction_state

  subroutine construct_fmr_wofost_crop_transaction_parameters(rate_parameters, update_parameters, &
       stem_area_coefficient, storage_area_coefficient, parameters, status, enable_potential_shadow, &
       potential_attainable_multiplier, phenology_mode, soybean_phenology, vernalisation_phenology)
    type(wofost_rate_parameter_bundle_t), intent(in) :: rate_parameters
    type(wofost_one_day_update_parameters_t), intent(in) :: update_parameters
    real(real64), intent(in) :: stem_area_coefficient, storage_area_coefficient
    type(fmr_wofost_crop_transaction_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    logical, intent(in), optional :: enable_potential_shadow
    real(real64), intent(in), optional :: potential_attainable_multiplier
    integer, intent(in), optional :: phenology_mode
    type(soybean_phenology_parameters_t), intent(in), optional :: soybean_phenology
    type(wofost_vernalisation_parameters_t), intent(in), optional :: vernalisation_phenology
    logical :: enable_shadow
    integer :: resolved_phenology_mode
    real(real64) :: potential_multiplier
    type(wofost_rate_scalar_parameters_t) :: rate_scalars

    parameters = fmr_wofost_crop_transaction_parameters_t()
    enable_shadow = .false.
    if (present(enable_potential_shadow)) enable_shadow = enable_potential_shadow
    potential_multiplier = 1.0_real64
    if (present(potential_attainable_multiplier)) potential_multiplier = potential_attainable_multiplier
    resolved_phenology_mode = WOFOST_PHENOLOGY_CLASSIC
    if (present(phenology_mode)) resolved_phenology_mode = phenology_mode
    status = FMR_WOF38_INVALID_PARAMETERS
    if (.not. rate_parameters%ready()) return
    if (.not. ieee_is_finite(stem_area_coefficient) .or. stem_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(storage_area_coefficient) .or. storage_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(update_parameters%development_stage_end) .or. &
        update_parameters%development_stage_end <= 0.0_real64) return
    if (.not. ieee_is_finite(update_parameters%leaf_lifespan) .or. update_parameters%leaf_lifespan < 0.0_real64) return
    if (.not. ieee_is_finite(potential_multiplier) .or. potential_multiplier < 0.0_real64 .or. &
        potential_multiplier > 1.0_real64) return
    rate_scalars = rate_parameters%scalar_view()
    select case(resolved_phenology_mode)
    case(WOFOST_PHENOLOGY_CLASSIC)
      if (present(soybean_phenology) .or. present(vernalisation_phenology)) return
    case(WOFOST_PHENOLOGY_SOYBEAN)
      if (.not. present(soybean_phenology) .or. present(vernalisation_phenology)) return
      if (.not. soybean_phenology%ready()) return
      if (rate_scalars%development_daylength_mode /= 0) return
    case(WOFOST_PHENOLOGY_VERNALISATION)
      if (.not. present(vernalisation_phenology) .or. present(soybean_phenology)) return
      if (.not. vernalisation_phenology%ready()) return
      if (rate_scalars%development_daylength_mode /= 1) return
    case default
      return
    end select

    parameters%rate_parameters = rate_parameters
    parameters%update_parameters = update_parameters
    parameters%stem_area_coefficient = stem_area_coefficient
    parameters%storage_area_coefficient = storage_area_coefficient
    parameters%potential_shadow_enabled = enable_shadow
    parameters%potential_attainable_multiplier = potential_multiplier
    parameters%phenology_mode = resolved_phenology_mode
    if (present(soybean_phenology)) then
      allocate(parameters%soybean_phenology)
      parameters%soybean_phenology = soybean_phenology
    end if
    if (present(vernalisation_phenology)) then
      allocate(parameters%vernalisation_phenology)
      parameters%vernalisation_phenology = vernalisation_phenology
    end if
    parameters%initialized = .true.
    status = FMR_WOF38_OK
  end subroutine construct_fmr_wofost_crop_transaction_parameters

  subroutine prepare_fmr_wofost_crop_event_forcing(window, crop_forcing, forcing, status, &
       soybean_latitude_degrees, soybean_day_of_year)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_one_day_forcing_t), intent(in) :: crop_forcing
    type(fmr_wofost_crop_event_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status
    real(real64), intent(in), optional :: soybean_latitude_degrees
    integer, intent(in), optional :: soybean_day_of_year
    type(fmr_wofost_crop_event_token_t) :: token
    type(wofost_accepted_window_aggregates_t) :: aggregates
    logical :: available
    integer :: lineage_status

    forcing = fmr_wofost_crop_event_forcing_t()
    status = FMR_WOF38_INVALID_EVENT
    call prepare_wofost_crop_event_delivery(window, aggregates, token, available, lineage_status)
    if (lineage_status /= FMR_WOFOST_LINEAGE_OK .or. .not. available .or. .not. token%ready()) return
    call identify_wofost_crop_event(token, forcing%event_identity, lineage_status)
    if (lineage_status /= FMR_WOFOST_LINEAGE_OK .or. .not. forcing%event_identity%ready()) return

    forcing%crop_forcing = crop_forcing
    forcing%accepted_aggregates = aggregates
    if (present(soybean_latitude_degrees)) forcing%soybean_latitude_degrees = soybean_latitude_degrees
    if (present(soybean_day_of_year)) forcing%soybean_day_of_year = soybean_day_of_year
    if (.not. ieee_is_finite(forcing%soybean_latitude_degrees) .or. &
        abs(forcing%soybean_latitude_degrees) > 90.0_real64) return
    if (forcing%soybean_day_of_year < 1 .or. forcing%soybean_day_of_year > 366) return
    forcing%initialized = .true.
    status = FMR_WOF38_OK
  end subroutine prepare_fmr_wofost_crop_event_forcing

  subroutine fmr_wofost_crop_transaction_clone(self, copy)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(fmr_wofost_crop_transaction_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_wofost_crop_transaction_state_t)
      typed_copy%initialized = self%initialized
      typed_copy%owner = self%owner
      if (allocated(self%potential_shadow)) then
        allocate(typed_copy%potential_shadow)
        typed_copy%potential_shadow = self%potential_shadow
      end if
      if (allocated(self%root_growth_carrier)) then
        allocate(typed_copy%root_growth_carrier)
        typed_copy%root_growth_carrier = self%root_growth_carrier
      end if
      typed_copy%last_consumed_event = self%last_consumed_event
    class default
      error stop 'F-WOF38 crop transaction clone allocation failure'
    end select
  end subroutine fmr_wofost_crop_transaction_clone

  logical function fmr_wofost_crop_transaction_state_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (self%owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (allocated(self%potential_shadow)) then
      if (self%potential_shadow%validate() /= WOFOST_POTENTIAL_SHADOW_OK) return
      if (.not. allocated(self%root_growth_carrier)) return
      if (self%root_growth_carrier%valid) then
        if (.not. self%root_growth_carrier%ready()) return
      else
        if (self%last_consumed_event%ready()) return
      end if
    else
      if (allocated(self%root_growth_carrier)) return
    end if
    ready = .true.
  end function fmr_wofost_crop_transaction_state_ready

  subroutine fmr_wofost_crop_transaction_snapshot_owner(self, owner, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(wofost_crop_owner_state_t), intent(out) :: owner
    logical, intent(out) :: available

    owner = wofost_crop_owner_state_t()
    available = self%ready()
    if (available) owner = self%owner
  end subroutine fmr_wofost_crop_transaction_snapshot_owner

  logical function fmr_wofost_crop_transaction_potential_shadow_enabled(self) result(enabled)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    enabled = allocated(self%potential_shadow)
  end function fmr_wofost_crop_transaction_potential_shadow_enabled

  subroutine fmr_wofost_crop_transaction_snapshot_potential_shadow(self, shadow, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(wofost_potential_shadow_state_t), intent(out) :: shadow
    logical, intent(out) :: available
    shadow = wofost_potential_shadow_state_t()
    available = self%ready() .and. allocated(self%potential_shadow)
    if (available) shadow = self%potential_shadow
  end subroutine fmr_wofost_crop_transaction_snapshot_potential_shadow

  subroutine fmr_wofost_crop_transaction_snapshot_root_growth(self, carrier, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(fmr_wofost_root_growth_carrier_t), intent(out) :: carrier
    logical, intent(out) :: available
    carrier = fmr_wofost_root_growth_carrier_t()
    available = self%ready() .and. allocated(self%root_growth_carrier)
    if (available) then
      available = self%root_growth_carrier%ready() .and. self%last_consumed_event%ready()
      if (available) carrier = self%root_growth_carrier
    end if
  end subroutine fmr_wofost_crop_transaction_snapshot_root_growth

  logical function fmr_wofost_crop_transaction_receipt_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self

    ready = .false.
    if (.not. self%ready()) return
    ready = self%last_consumed_event%ready()
  end function fmr_wofost_crop_transaction_receipt_ready

  logical function fmr_wofost_crop_transaction_consumed_event(self, identity) result(consumed)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(fmr_wofost_crop_event_identity_t), intent(in) :: identity

    consumed = .false.
    if (.not. self%receipt_ready()) return
    if (.not. identity%ready()) return
    consumed = same_wofost_crop_event_identity(self%last_consumed_event, identity)
  end function fmr_wofost_crop_transaction_consumed_event

  logical function fmr_wofost_crop_transaction_parameters_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_parameters_t), intent(in) :: self
    type(wofost_rate_scalar_parameters_t) :: rate_scalars

    ready = .false.
    if (.not. self%initialized) return
    if (.not. self%rate_parameters%ready()) return
    rate_scalars = self%rate_parameters%scalar_view()
    if (.not. ieee_is_finite(self%stem_area_coefficient)) return
    if (self%stem_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(self%storage_area_coefficient)) return
    if (self%storage_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(self%update_parameters%development_stage_end)) return
    if (self%update_parameters%development_stage_end <= 0.0_real64) return
    if (.not. ieee_is_finite(self%update_parameters%leaf_lifespan)) return
    if (self%update_parameters%leaf_lifespan < 0.0_real64) return
    if (.not. ieee_is_finite(self%potential_attainable_multiplier)) return
    if (self%potential_attainable_multiplier < 0.0_real64 .or. self%potential_attainable_multiplier > 1.0_real64) return
    select case(self%phenology_mode)
    case(WOFOST_PHENOLOGY_CLASSIC)
      if (allocated(self%soybean_phenology) .or. allocated(self%vernalisation_phenology)) return
    case(WOFOST_PHENOLOGY_SOYBEAN)
      if (.not. allocated(self%soybean_phenology) .or. allocated(self%vernalisation_phenology)) return
      if (.not. self%soybean_phenology%ready()) return
      if (rate_scalars%development_daylength_mode /= 0) return
    case(WOFOST_PHENOLOGY_VERNALISATION)
      if (.not. allocated(self%vernalisation_phenology) .or. allocated(self%soybean_phenology)) return
      if (.not. self%vernalisation_phenology%ready()) return
      if (self%rate_parameters%scalar_view()%development_daylength_mode /= 1) return
    case default
      return
    end select
    ready = .true.
  end function fmr_wofost_crop_transaction_parameters_ready

  logical function fmr_wofost_crop_event_forcing_ready(self) result(ready)
    class(fmr_wofost_crop_event_forcing_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (.not. self%event_identity%ready()) return
    if (.not. ieee_is_finite(self%accepted_aggregates%actual_root_uptake)) return
    if (.not. ieee_is_finite(self%accepted_aggregates%potential_transpiration)) return
    if (self%accepted_aggregates%actual_root_uptake < 0.0_real64) return
    if (self%accepted_aggregates%potential_transpiration < 0.0_real64) return
    if (.not. ieee_is_finite(self%soybean_latitude_degrees) .or. abs(self%soybean_latitude_degrees) > 90.0_real64) return
    if (self%soybean_day_of_year < 1 .or. self%soybean_day_of_year > 366) return
    ready = .true.
  end function fmr_wofost_crop_event_forcing_ready

  subroutine fmr_wofost_crop_configure_parameters(self, parameters)
    class(fmr_wofost_crop_transaction_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    self%parameters_ready = .false.
    self%last_status = FMR_WOF38_INVALID_PARAMETERS
    select type (typed_parameters => parameters)
    type is (fmr_wofost_crop_transaction_parameters_t)
      if (.not. typed_parameters%ready()) return
      self%rate_parameters = typed_parameters%rate_parameters
      self%update_parameters = typed_parameters%update_parameters
      self%stem_area_coefficient = typed_parameters%stem_area_coefficient
      self%storage_area_coefficient = typed_parameters%storage_area_coefficient
      self%potential_shadow_enabled = typed_parameters%potential_shadow_enabled
      self%potential_attainable_multiplier = typed_parameters%potential_attainable_multiplier
      self%parameters_ready = .true.
      self%last_status = FMR_WOF38_OK
    class default
      return
    end select
  end subroutine fmr_wofost_crop_configure_parameters

  logical function fmr_wofost_crop_execution_admitted(self, parameters, numerical_config) result(admitted)
    class(fmr_wofost_crop_transaction_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config

    admitted = .false.
    if (.not. same_type_as(self, self)) return
    if (numerical_config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (numerical_config%transaction%max_retries /= 0) return
    if (numerical_config%max_committed_substeps /= 1) return
    select type (typed_parameters => parameters)
    type is (fmr_wofost_crop_transaction_parameters_t)
      admitted = typed_parameters%ready()
    class default
      admitted = .false.
    end select
  end function fmr_wofost_crop_execution_admitted

  subroutine fmr_wofost_crop_prepare_interval(self, forcing, interval, config)
    class(fmr_wofost_crop_transaction_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%interval_ready = .false.
    self%event_forcing = fmr_wofost_crop_event_forcing_t()
    self%last_status = FMR_WOF38_INVALID_EVENT
    if (config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE .or. &
        config%transaction%max_retries /= 0 .or. config%max_committed_substeps /= 1) then
      self%last_status = FMR_WOF38_INVALID_POLICY
      return
    end if
    select type (typed_forcing => forcing)
    type is (fmr_wofost_crop_event_forcing_t)
      if (.not. typed_forcing%ready()) return
      if (.not. crop_event_identity_matches_interval(typed_forcing%event_identity, interval%t0, interval%t1)) then
        self%last_status = FMR_WOF38_EVENT_INTERVAL_MISMATCH
        return
      end if
      self%event_forcing = typed_forcing
      self%interval_ready = .true.
      self%last_status = FMR_WOF38_OK
    class default
      return
    end select
  end subroutine fmr_wofost_crop_prepare_interval

  subroutine fmr_wofost_crop_advance(self, state, t0, t1, outcome)
    class(fmr_wofost_crop_transaction_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(wofost_two_phase_crop_window_t) :: crop_window
    type(wofost_crop_window_begin_diagnostics_t) :: begin_diagnostics
    type(wofost_crop_window_complete_diagnostics_t) :: complete_diagnostics
    type(wofost_crop_owner_state_t) :: candidate_owner
    type(wofost_one_day_rate_packet_t) :: rates
    type(wofost_potential_daily_result_t) :: potential_result
    type(fmr_wofost_root_growth_carrier_t) :: candidate_growth_carrier
    integer :: crop_status

    outcome = trial_outcome_t()
    self%last_status = FMR_WOF38_INVALID_TRANSACTION_STATE
    if (.not. self%parameters_ready .or. .not. self%interval_ready) then
      if (.not. self%parameters_ready) self%last_status = FMR_WOF38_INVALID_PARAMETERS
      if (.not. self%interval_ready) self%last_status = FMR_WOF38_INVALID_EVENT
      return
    end if
    if (.not. crop_event_identity_matches_interval(self%event_forcing%event_identity, t0, t1)) then
      self%last_status = FMR_WOF38_EVENT_INTERVAL_MISMATCH
      return
    end if

    select type (typed_state => state)
    type is (fmr_wofost_crop_transaction_state_t)
      if (.not. typed_state%ready()) return
      if (typed_state%consumed_event(self%event_forcing%event_identity)) then
        self%last_status = FMR_WOF38_EVENT_ALREADY_CONSUMED
        return
      end if
      if (self%potential_shadow_enabled .neqv. allocated(typed_state%potential_shadow)) then
        self%last_status = FMR_WOF38_INVALID_TRANSACTION_STATE
        return
      end if

      candidate_growth_carrier = fmr_wofost_root_growth_carrier_t()
      if (self%potential_shadow_enabled) then
        call evaluate_wofost_potential_shadow_day(typed_state%owner, typed_state%potential_shadow, &
             self%event_forcing%crop_forcing, t0, t1, self%stem_area_coefficient, &
             self%storage_area_coefficient, self%rate_parameters, self%update_parameters, &
             self%potential_attainable_multiplier, potential_result, crop_status)
        if (crop_status /= WOFOST_POTENTIAL_DAILY_OK) then
          self%last_status = FMR_WOF38_POTENTIAL_ERROR
          return
        end if
      end if

      call begin_wofost_one_day_crop_window(typed_state%owner, self%event_forcing%crop_forcing, t0, t1, &
           self%stem_area_coefficient, self%storage_area_coefficient, self%rate_parameters, &
           crop_window, begin_diagnostics, crop_status)
      if (crop_status /= WOFOST_CROP_WINDOW_OK) then
        self%last_status = FMR_WOF38_CROP_BEGIN_ERROR
        return
      end if

      call complete_wofost_one_day_crop_window(crop_window, self%rate_parameters, self%update_parameters, &
           self%event_forcing%accepted_aggregates, candidate_owner, rates, complete_diagnostics, crop_status)
      if (crop_status /= WOFOST_CROP_WINDOW_OK .or. .not. complete_diagnostics%candidate_built) then
        self%last_status = FMR_WOF38_CROP_COMPLETE_ERROR
        return
      end if
      if (candidate_owner%validate() /= WOFOST_CROP_OWNER_OK) then
        self%last_status = FMR_WOF38_CROP_COMPLETE_ERROR
        return
      end if

      if (self%potential_shadow_enabled) then
        candidate_growth_carrier%actual_gross_root_growth = rates%gross_root_growth_rate
        candidate_growth_carrier%potential_gross_root_growth = potential_result%gross_root_growth_rate
        candidate_growth_carrier%valid = .true.
        if (.not. candidate_growth_carrier%ready()) then
          self%last_status = FMR_WOF38_POTENTIAL_ERROR
          return
        end if
      end if

      typed_state%owner = candidate_owner
      if (self%potential_shadow_enabled) then
        typed_state%potential_shadow = potential_result%candidate_shadow
        typed_state%root_growth_carrier = candidate_growth_carrier
      end if
      typed_state%last_consumed_event = self%event_forcing%event_identity
      typed_state%initialized = .true.
      outcome%solver_ok = .true.
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%mass_in = 0.0_real64
      outcome%mass_out = 0.0_real64
      outcome%temporal_certificate_available = .true.
      outcome%temporal_indicator = 0.0_real64
      self%last_status = FMR_WOF38_OK
    class default
      self%last_status = FMR_WOF38_INVALID_TRANSACTION_STATE
      return
    end select
  end subroutine fmr_wofost_crop_advance

  real(real64) function fmr_wofost_crop_storage(self, state) result(value)
    class(fmr_wofost_crop_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state

    value = 0.0_real64
    if (.not. same_type_as(self, self)) return
    select type (typed_state => state)
    type is (fmr_wofost_crop_transaction_state_t)
      if (.not. typed_state%ready()) value = 0.0_real64
    class default
      value = 0.0_real64
    end select
  end function fmr_wofost_crop_storage

  real(real64) function fmr_wofost_crop_temporal_error(self, full_state, half_state) result(value)
    class(fmr_wofost_crop_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state

    value = 0.0_real64
    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, half_state)) value = huge(0.0_real64)
  end function fmr_wofost_crop_temporal_error

  subroutine fmr_wofost_crop_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr_wofost_crop_transaction_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(kind=8), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. same_type_as(self, self)) return
    select type (typed_state => state)
    type is (fmr_wofost_crop_transaction_state_t)
      complete = typed_state%ready()
      if (complete) missing_mask = TX_MASS_MISSING_NONE
    class default
      complete = .false.
    end select
  end subroutine fmr_wofost_crop_storage_accounting_status

  integer function fmr_wofost_crop_last_status_code(self) result(status)
    class(fmr_wofost_crop_transaction_model_t), intent(in) :: self
    status = self%last_status
  end function fmr_wofost_crop_last_status_code

end module mod_fmr_wofost_crop_transaction
