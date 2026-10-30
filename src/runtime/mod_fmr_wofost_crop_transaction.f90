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
  use mod_wofost_rate_parameters, only: wofost_rate_parameter_bundle_t,wofost_rate_scalar_parameters_t
  use mod_wofost_grass_development
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, &
       initialize_wofost_potential_shadow_from_actual, WOFOST_POTENTIAL_SHADOW_OK
  use mod_wofost_potential_shadow_daily, only: wofost_potential_daily_result_t, &
       evaluate_wofost_potential_shadow_day, WOFOST_POTENTIAL_DAILY_OK
  use mod_crop_root_anaerobic_extension_gate, only: root_extension_allowed_by_daily_oxygen, ROOT_ANOX_GATE_OK
  use mod_wofost_two_phase_crop_window, only: wofost_two_phase_crop_window_t, &
       wofost_crop_window_begin_diagnostics_t, wofost_crop_window_complete_diagnostics_t, &
       begin_wofost_one_day_crop_window, complete_wofost_one_day_crop_window, complete_wofost_grass_crop_window, WOFOST_CROP_WINDOW_OK,WOFOST_CROP_WINDOW_CONTEXT_NOT_READY
  use mod_fmr_wofost_accepted_window_lineage, only: fmr_wofost_accepted_window_t, &
       fmr_wofost_crop_event_token_t, fmr_wofost_crop_event_identity_t, &
       fmr_wofost_crop_event_identity_persistence_t, &
       prepare_wofost_crop_event_delivery, identify_wofost_crop_event, &
       same_wofost_crop_event_identity, crop_event_identity_matches_interval, FMR_WOFOST_LINEAGE_OK, &
       export_wofost_crop_event_identity_persistence, &
       reconstruct_wofost_crop_event_identity_from_persistence
  use mod_crop_lifecycle_continuation, only: crop_lifecycle_continuation_t, &
       propose_crop_lifecycle_continuation, propose_crop_active_continuation, CROP_CONT_OK, CROP_PROFILE_BOUNDED, CROP_PROFILE_B111_TASK2
  use mod_wofost_emergence_initialization, only: initialize_wofost_emergence_owner, WOFOST_EMERGENCE_INIT_OK
  use mod_crop_lifecycle_daily_composition, only: crop_daily_lifecycle_candidate_t
  use mod_crop_germination_preflight, only: crop_germination_candidate_t
  use mod_crop_root_depth_rate_owner, only: crop_root_depth_rate_parameters_t, crop_root_depth_rate_state_t, &
       crop_root_depth_rate_daily_forcing_t, crop_root_depth_rate_diagnostics_t, initialize_crop_root_depth_rate_state, &
       evaluate_crop_root_depth_rate_candidate, CROP_ROOT_RATE_OK
  use mod_crop_adaptive_root_profile_owner
  use mod_crop_root_depth_rate_owner, only: CROP_ROOT_RATE_DROUGHT_SUPPLY
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
  integer, parameter, public :: FMR_WOF38_MISSING_DAILY_OXYGEN = 11
  integer, parameter, public :: FMR_WOF38_INVALID_DAILY_OXYGEN = 12
  integer, parameter, public :: FMR_WOF38_LIFECYCLE_REJECTED = 13
  integer, parameter, public :: FMR_WOF38_ROOT_DEPTH_REJECTED = 14

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
    type(crop_lifecycle_continuation_t), allocatable :: lifecycle
    type(crop_root_depth_rate_state_t), allocatable :: root_depth
    type(adaptive_root_profile_state_t),allocatable :: root_profile
    type(grass_management_continuation_t),allocatable::grass_management
  contains
    procedure :: clone => fmr_wofost_crop_transaction_clone
    procedure, public :: ready => fmr_wofost_crop_transaction_state_ready
    procedure, public :: snapshot_owner => fmr_wofost_crop_transaction_snapshot_owner
    procedure, public :: potential_shadow_enabled => fmr_wofost_crop_transaction_potential_shadow_enabled
    procedure, public :: snapshot_potential_shadow => fmr_wofost_crop_transaction_snapshot_potential_shadow
    procedure, public :: snapshot_root_growth => fmr_wofost_crop_transaction_snapshot_root_growth
    procedure, public :: snapshot_root_depth => fmr_wofost_crop_transaction_snapshot_root_depth
    procedure, public :: snapshot_root_profile => fmr_wofost_snapshot_root_profile
    procedure, public :: snapshot_grass_management=>fmr_wofost_snapshot_grass_management
    procedure, public :: receipt_ready => fmr_wofost_crop_transaction_receipt_ready
    procedure, public :: snapshot_lifecycle => fmr_wofost_crop_transaction_snapshot_lifecycle
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
    logical :: root_depth_present = .false.
    type(crop_root_depth_rate_state_t) :: root_depth
    logical :: root_profile_present=.false.
    logical::grass_management_present=.false.
    type(grass_management_continuation_t)::grass_management
    type(adaptive_root_profile_state_t)::root_profile
    logical :: receipt_present = .false.
    logical :: lifecycle_present = .false.
    integer :: lifecycle_schema_version = 1
    type(crop_lifecycle_continuation_t) :: lifecycle
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
    logical :: anaerobic_root_growth_gate_enabled = .false.
    real(real64) :: aeration_critical_factor = 0.0001_real64
    type(crop_root_depth_rate_parameters_t), allocatable :: root_depth_parameters
    type(adaptive_root_profile_configuration_t),allocatable :: root_profile_configuration
    type(grass_management_parameters_t),allocatable::grass_parameters
  contains
    procedure, public :: ready => fmr_wofost_crop_transaction_parameters_ready
    procedure, public :: matches_canopy => fmr_wofost_parameters_matches_canopy
    procedure, public :: matches_root_depth => fmr_wofost_parameters_matches_root_depth
    procedure, public :: matches_root_profile => fmr_wofost_matches_root_profile
  end type fmr_wofost_crop_transaction_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_wofost_crop_event_forcing_t
    private
    logical :: initialized = .false.
    type(wofost_one_day_forcing_t) :: crop_forcing
    type(wofost_accepted_window_aggregates_t) :: accepted_aggregates
    type(fmr_wofost_crop_event_identity_t) :: event_identity
    logical :: lifecycle_requested = .false., active_lifecycle_requested = .false., emergence_requested = .false.
    real(real64) :: emergence_dry_weight = 0.0_real64
    integer(kind=8) :: lifecycle_expected_revision = -1_8
    type(crop_daily_lifecycle_candidate_t) :: lifecycle_plan
    type(crop_germination_candidate_t) :: lifecycle_germination
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
    logical :: anaerobic_root_growth_gate_enabled = .false.
    real(real64) :: aeration_critical_factor = 0.0001_real64
    type(crop_root_depth_rate_parameters_t), allocatable :: root_depth_parameters
    type(adaptive_root_profile_configuration_t),allocatable :: root_profile_configuration
    type(grass_management_parameters_t),allocatable::grass_parameters
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
  public :: prepare_fmr_wofost_morning_emergence

contains
  subroutine prepare_fmr_wofost_morning_emergence(base,parameters,time,initial_dry_weight,candidate,status)
    type(fmr_wofost_crop_transaction_state_t),intent(in)::base
    type(fmr_wofost_crop_transaction_parameters_t),intent(in)::parameters
    real(real64),intent(in)::time,initial_dry_weight
    type(fmr_wofost_crop_transaction_state_t),intent(out)::candidate
    integer,intent(out)::status
    type(fmr_wofost_crop_event_identity_persistence_t)::receipt
    type(crop_lifecycle_continuation_t)::lifecycle
    type(wofost_crop_owner_state_t)::owner
    logical::ok
    integer::code
    candidate=fmr_wofost_crop_transaction_state_t();status=FMR_WOF38_LIFECYCLE_REJECTED
    if(.not.base%ready().or..not.parameters%ready())return
    if(.not.ieee_is_finite(time).or..not.ieee_is_finite(initial_dry_weight))return
    if(time/=aint(time).or.initial_dry_weight<0.0_real64.or.initial_dry_weight>10000.0_real64)return
    if(.not.allocated(base%lifecycle).or.base%owner%crop_emerged)return
    lifecycle=base%lifecycle
    if(lifecycle%initialization_profile/=CROP_PROFILE_B111_TASK2)return
    if(lifecycle%emerged.or.lifecycle%harvested.or..not.lifecycle%germinated)return
    if(.not.lifecycle%prepared.or..not.lifecycle%sown)return
    if(lifecycle%revision==huge(lifecycle%revision))return
    call export_wofost_crop_event_identity_persistence(base%last_consumed_event,receipt,ok)
    if(.not.ok)return
    if(receipt%t1/=time.or.receipt%t0/=time-1.0_real64)return
    if(receipt%actual_root_uptake_integral/=0.0_real64)return
    if(receipt%potential_transpiration_integral/=0.0_real64)then
      ! The source microscopic/root-depth laws define Tp<NIHIL as inactive.
      ! Direct PM on the original bare canopy leaves a3.5e-24cm numerical
      ! demand. Do not reinterpret it as root extraction or alter its ledger.
      if(.not.allocated(parameters%root_depth_parameters))return
      if(receipt%potential_transpiration_integral>=parameters%root_depth_parameters%negligible_transpiration)return
    end if
    call initialize_wofost_emergence_owner(initial_dry_weight,parameters%rate_parameters,owner,code)
    if(code/=WOFOST_EMERGENCE_INIT_OK)return
    lifecycle%emerged=.true.;lifecycle%revision=lifecycle%revision+1_8
    if(allocated(parameters%root_profile_configuration))then
      call initialize_fmr_wofost_crop_transaction_state(owner,candidate,code,.true.,lifecycle, &
        parameters%root_depth_parameters,parameters%root_profile_configuration)
    else if(allocated(parameters%root_depth_parameters))then
      call initialize_fmr_wofost_crop_transaction_state(owner,candidate,code,.true.,lifecycle,parameters%root_depth_parameters)
    else
      call initialize_fmr_wofost_crop_transaction_state(owner,candidate,code,parameters%potential_shadow_enabled,lifecycle)
    end if
    if(code/=FMR_WOF38_OK)return
    candidate%last_consumed_event=base%last_consumed_event
    if(allocated(candidate%root_growth_carrier))candidate%root_growth_carrier%valid=.true.
    if(.not.candidate%ready())return
    status=FMR_WOF38_OK
  end subroutine prepare_fmr_wofost_morning_emergence


  logical function fmr_wofost_root_growth_carrier_ready(self) result(ready)
    class(fmr_wofost_root_growth_carrier_t), intent(in) :: self
    ready = self%valid .and. ieee_is_finite(self%actual_gross_root_growth) .and. &
         ieee_is_finite(self%potential_gross_root_growth) .and. &
         self%actual_gross_root_growth >= 0.0_real64 .and. self%potential_gross_root_growth >= 0.0_real64
  end function fmr_wofost_root_growth_carrier_ready

  logical function fmr_wofost_crop_transaction_persistence_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_persistence_t), intent(in) :: self
    type(fmr_wofost_crop_event_identity_t) :: lifecycle_receipt
    integer :: lifecycle_receipt_status
    ready = .false.
    if (.not. self%valid) return
    if (self%owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if(self%grass_management_present)then
      if(.not.self%owner%crop_emerged.or..not.self%potential_shadow_present)return
      if(.not.self%grass_management%ready())return
    end if
    if(self%root_profile_present)then
      if(.not.self%root_depth_present.or..not.self%owner%crop_emerged)return
      if(self%root_profile%validate()/=ADAPTIVE_ROOT_PROFILE_OK)return
      if(abs(sum(self%root_profile%root_biomass_by_node)-self%owner%biomass%root_biomass)> &
        1e-10_real64*max(1.0_real64,self%owner%biomass%root_biomass))return
    end if
    if (self%root_depth_present) then
      if (.not.self%potential_shadow_present) return
      if (self%root_depth%validate()/=CROP_ROOT_RATE_OK) return
      if (.not.self%owner%crop_emerged) then
        if (self%root_depth%actual_root_depth_cm/=0.0_real64.or.self%root_depth%potential_root_depth_cm/=0.0_real64) return
      end if
    end if
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
    if (self%lifecycle_present) then
      if (.not. self%lifecycle%ready()) return
      if(self%lifecycle%initialization_profile==CROP_PROFILE_B111_TASK2) then
        if(self%owner%crop_emerged.neqv.self%lifecycle%emerged) return
      end if
      if(self%lifecycle%initialization_profile==CROP_PROFILE_B111_TASK2) then
        if(self%lifecycle_schema_version/=2) return
      else
        if(self%lifecycle_schema_version/=1) return
      end if
      if (self%lifecycle%last_event_identity%ready()) then
        if (.not. self%receipt_present) return
        if (.not. self%receipt%ready()) return
        call reconstruct_wofost_crop_event_identity_from_persistence(self%receipt, lifecycle_receipt, &
             lifecycle_receipt_status)
        if (lifecycle_receipt_status /= FMR_WOFOST_LINEAGE_OK) return
        if (.not. same_wofost_crop_event_identity(self%lifecycle%last_event_identity,lifecycle_receipt)) return
      end if
    else
      if (self%lifecycle%valid) return
      if (self%lifecycle_schema_version/=1) return
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
    if(allocated(state%grass_management))then
      view%grass_management_present=.true.;view%grass_management=state%grass_management
    end if
    if(allocated(state%root_profile))then
      view%root_profile_present=.true.;view%root_profile=state%root_profile
    end if
    if (allocated(state%root_depth)) then
      view%root_depth_present=.true.
      view%root_depth=state%root_depth
    end if
    if (allocated(state%lifecycle)) then
      view%lifecycle = state%lifecycle
      view%lifecycle_present = .true.
      if(state%lifecycle%initialization_profile==CROP_PROFILE_B111_TASK2) view%lifecycle_schema_version=2
    end if
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
    if(view%grass_management_present)state%grass_management=view%grass_management
    if(view%root_profile_present)state%root_profile=view%root_profile
    if (view%root_depth_present) then
      allocate(state%root_depth)
      state%root_depth=view%root_depth
    end if
    if (view%lifecycle_present) then
      allocate(state%lifecycle)
      state%lifecycle = view%lifecycle
    end if
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

  subroutine initialize_fmr_wofost_crop_transaction_state(owner, state, status, enable_potential_shadow, lifecycle_initial, &
       root_depth_parameters,root_profile_configuration,grass_management)
    type(wofost_crop_owner_state_t), intent(in) :: owner
    type(fmr_wofost_crop_transaction_state_t), intent(out) :: state
    integer, intent(out) :: status
    logical, intent(in), optional :: enable_potential_shadow
    type(crop_lifecycle_continuation_t), intent(in), optional :: lifecycle_initial
    type(crop_root_depth_rate_parameters_t), intent(in), optional :: root_depth_parameters
    type(adaptive_root_profile_configuration_t),intent(in),optional::root_profile_configuration
    type(grass_management_continuation_t),intent(in),optional::grass_management
    logical :: enable_shadow
    integer :: shadow_status

    state = fmr_wofost_crop_transaction_state_t()
    enable_shadow = .false.
    if (present(enable_potential_shadow)) enable_shadow = enable_potential_shadow
    status = FMR_WOF38_INVALID_OWNER
    if (owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if (present(root_depth_parameters)) then
      status=FMR_WOF38_INVALID_PARAMETERS
      if (.not.root_depth_parameters%ready().or..not.enable_shadow) return
      if (root_depth_parameters%negligible_transpiration<=0.0_real64) return
      allocate(state%root_depth)
      call initialize_crop_root_depth_rate_state(root_depth_parameters,state%root_depth,shadow_status)
      if (shadow_status/=CROP_ROOT_RATE_OK) return
      if (.not.owner%crop_emerged) state%root_depth=crop_root_depth_rate_state_t()
    end if
    if(present(root_profile_configuration))then
      status=FMR_WOF38_INVALID_PARAMETERS
      if(.not.present(root_depth_parameters))return
      if(.not.root_profile_configuration%ready())return
      if(root_depth_parameters%initial_root_depth_cm<=0.0_real64)return
      if(root_profile_configuration%maximum_root_depth_cm/=root_depth_parameters%maximum_root_depth_cm)return
      if(owner%crop_emerged)then
        allocate(state%root_profile)
        call initialize_adaptive_root_profile_state(root_profile_configuration%initial_density, &
          root_profile_configuration%zbot_cm,root_profile_configuration%maximum_root_depth_cm, &
          state%root_depth%actual_root_depth_cm,owner%biomass%root_biomass,state%root_profile,shadow_status)
        if(shadow_status/=ADAPTIVE_ROOT_PROFILE_OK)return
      end if
    end if
    state%owner = owner
    if (present(lifecycle_initial)) then
      if (.not. lifecycle_initial%ready()) return
      allocate(state%lifecycle)
      state%lifecycle = lifecycle_initial
    end if
    if (enable_shadow) then
      allocate(state%potential_shadow, state%root_growth_carrier)
      call initialize_wofost_potential_shadow_from_actual(owner, state%potential_shadow, shadow_status)
      if (shadow_status /= WOFOST_POTENTIAL_SHADOW_OK) then
        state = fmr_wofost_crop_transaction_state_t()
        return
      end if
      state%root_growth_carrier = fmr_wofost_root_growth_carrier_t()
    end if
    if(present(grass_management))then
      status=FMR_WOF38_INVALID_PARAMETERS
      if(.not.owner%crop_emerged.or..not.enable_shadow.or..not.grass_management%ready())return
      state%grass_management=grass_management
    end if
    state%initialized = .true.
    status = FMR_WOF38_OK
  end subroutine initialize_fmr_wofost_crop_transaction_state

  subroutine construct_fmr_wofost_crop_transaction_parameters(rate_parameters, update_parameters, &
       stem_area_coefficient, storage_area_coefficient, parameters, status, enable_potential_shadow, &
       potential_attainable_multiplier, enable_anaerobic_root_growth_gate, aeration_critical_factor, root_depth_parameters, &
       root_profile_configuration,grass_management_parameters)
    type(wofost_rate_parameter_bundle_t), intent(in) :: rate_parameters
    type(wofost_one_day_update_parameters_t), intent(in) :: update_parameters
    real(real64), intent(in) :: stem_area_coefficient, storage_area_coefficient
    type(fmr_wofost_crop_transaction_parameters_t), intent(out) :: parameters
    integer, intent(out) :: status
    logical, intent(in), optional :: enable_potential_shadow
    real(real64), intent(in), optional :: potential_attainable_multiplier
    logical, intent(in), optional :: enable_anaerobic_root_growth_gate
    real(real64), intent(in), optional :: aeration_critical_factor
    type(crop_root_depth_rate_parameters_t), intent(in), optional :: root_depth_parameters
    type(adaptive_root_profile_configuration_t),intent(in),optional::root_profile_configuration
    type(grass_management_parameters_t),intent(in),optional::grass_management_parameters
    type(wofost_rate_scalar_parameters_t)::scalars
    logical :: enable_shadow, enable_anaerobic_gate
    real(real64) :: potential_multiplier, aeration_threshold

    parameters = fmr_wofost_crop_transaction_parameters_t()
    enable_shadow = .false.
    if (present(enable_potential_shadow)) enable_shadow = enable_potential_shadow
    potential_multiplier = 1.0_real64
    if (present(potential_attainable_multiplier)) potential_multiplier = potential_attainable_multiplier
    enable_anaerobic_gate = .false.
    if (present(enable_anaerobic_root_growth_gate)) enable_anaerobic_gate = enable_anaerobic_root_growth_gate
    aeration_threshold = 0.0001_real64
    if (present(aeration_critical_factor)) aeration_threshold = aeration_critical_factor
    status = FMR_WOF38_INVALID_PARAMETERS
    if (present(root_depth_parameters)) then
      if (.not.root_depth_parameters%ready().or..not.enable_shadow) return
      if (root_depth_parameters%negligible_transpiration<=0.0_real64) return
      parameters%root_depth_parameters=root_depth_parameters
    end if
    if (.not. rate_parameters%ready()) return
    if (.not. ieee_is_finite(stem_area_coefficient) .or. stem_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(storage_area_coefficient) .or. storage_area_coefficient < 0.0_real64) return
    if (.not. ieee_is_finite(update_parameters%development_stage_end) .or. &
        update_parameters%development_stage_end <= 0.0_real64) return
    if (.not. ieee_is_finite(update_parameters%leaf_lifespan) .or. update_parameters%leaf_lifespan < 0.0_real64) return
    if (.not. ieee_is_finite(potential_multiplier) .or. potential_multiplier < 0.0_real64 .or. &
        potential_multiplier > 1.0_real64) return
    if (.not. ieee_is_finite(aeration_threshold) .or. aeration_threshold < 0.0_real64 .or. &
        aeration_threshold > 1.0_real64) return

    if(present(root_profile_configuration))then
      if(.not.present(root_depth_parameters))return
      if(.not.root_profile_configuration%ready())return
      if(root_depth_parameters%initial_root_depth_cm<=0.0_real64)return
      if(root_profile_configuration%maximum_root_depth_cm/=root_depth_parameters%maximum_root_depth_cm)return
      parameters%root_profile_configuration=root_profile_configuration
    else if(allocated(parameters%root_depth_parameters))then
      if(parameters%root_depth_parameters%actual_extension_mode==CROP_ROOT_RATE_DROUGHT_SUPPLY)return
    end if
    if(present(grass_management_parameters))then
      if(.not.grass_management_parameters%ready().or..not.enable_shadow)return
      scalars=rate_parameters%scalar_view()
      if(.not.scalars%grass_development.or..not.update_parameters%grass_development)return
      parameters%grass_parameters=grass_management_parameters
    end if
    parameters%rate_parameters = rate_parameters
    parameters%update_parameters = update_parameters
    parameters%stem_area_coefficient = stem_area_coefficient
    parameters%storage_area_coefficient = storage_area_coefficient
    parameters%potential_shadow_enabled = enable_shadow
    parameters%potential_attainable_multiplier = potential_multiplier
    parameters%anaerobic_root_growth_gate_enabled = enable_anaerobic_gate
    parameters%aeration_critical_factor = aeration_threshold
    parameters%initialized = .true.
    status = FMR_WOF38_OK
  end subroutine construct_fmr_wofost_crop_transaction_parameters

  subroutine prepare_fmr_wofost_crop_event_forcing(window, crop_forcing, forcing, status, &
       lifecycle_plan, lifecycle_germination, lifecycle_expected_revision, active_expected_revision, emergence_dry_weight)
    type(fmr_wofost_accepted_window_t), intent(in) :: window
    type(wofost_one_day_forcing_t), intent(in) :: crop_forcing
    type(fmr_wofost_crop_event_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status
    type(crop_daily_lifecycle_candidate_t), intent(in), optional :: lifecycle_plan
    type(crop_germination_candidate_t), intent(in), optional :: lifecycle_germination
    integer(kind=8), intent(in), optional :: lifecycle_expected_revision
    integer(kind=8),intent(in),optional :: active_expected_revision
    real(real64),intent(in),optional :: emergence_dry_weight
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

    if (present(lifecycle_plan) .or. present(lifecycle_germination) .or. &
         present(lifecycle_expected_revision)) then
      status = FMR_WOF38_LIFECYCLE_REJECTED
      if (.not. present(lifecycle_plan) .or. .not. present(lifecycle_germination) .or. &
           .not. present(lifecycle_expected_revision)) return
      if (.not. lifecycle_plan%valid) return
      if (lifecycle_expected_revision < 0_8) return
      ! Validate crop-gating invariants before supplying the physical trial.
      ! The F-KT crop transaction remains the only acceptance authority.
      if (lifecycle_plan%preparation_delay < 0 .or. lifecycle_plan%sowing_delay < 0) return
      select case(lifecycle_plan%initialization_profile)
      case(CROP_PROFILE_BOUNDED)
        if (lifecycle_plan%sown .and. .not. lifecycle_plan%prepared) return
        if (lifecycle_plan%germinated .and. .not. lifecycle_plan%sown) return
        if (lifecycle_plan%emergence_eligible .neqv. lifecycle_plan%germinated) return
      case(CROP_PROFILE_B111_TASK2)
        if (lifecycle_plan%emergence_eligible .neqv. &
             (lifecycle_plan%prepared.and.lifecycle_plan%sown.and.lifecycle_plan%germinated)) return
      case default
        return
      end select
      if (lifecycle_plan%germination_evaluated) then
        if (.not. (lifecycle_plan%prepared .and. lifecycle_plan%sown)) return
        if (.not. lifecycle_germination%valid) return
        if (lifecycle_plan%germinated .neqv. lifecycle_germination%complete) return
        if (.not. ieee_is_finite(lifecycle_germination%next_temperature_sum)) return
        if (lifecycle_germination%next_temperature_sum < 0.0_real64) return
      else
        if (lifecycle_plan%prepared .and. lifecycle_plan%sown) return
        if (lifecycle_plan%emergence_eligible) return
        if (lifecycle_plan%initialization_profile==CROP_PROFILE_BOUNDED.and.lifecycle_plan%germinated) return
      end if
      forcing%lifecycle_plan = lifecycle_plan
      forcing%lifecycle_germination = lifecycle_germination
      forcing%lifecycle_expected_revision = lifecycle_expected_revision
      forcing%lifecycle_requested = .true.
    end if
    if(present(active_expected_revision)) then
      status=FMR_WOF38_LIFECYCLE_REJECTED
      if(forcing%lifecycle_requested.or.active_expected_revision<0_8) return
      forcing%active_lifecycle_requested=.true.
      forcing%lifecycle_expected_revision=active_expected_revision
      if(present(emergence_dry_weight)) then
        if(.not.ieee_is_finite(emergence_dry_weight)) return
        if(emergence_dry_weight<0.0_real64.or.emergence_dry_weight>10000.0_real64) return
        ! A previous root-free window cannot be reinterpreted as growth.
        if(aggregates%actual_root_uptake/=0.0_real64.or.aggregates%potential_transpiration/=0.0_real64) return
        forcing%emergence_requested=.true.;forcing%emergence_dry_weight=emergence_dry_weight
      end if
    else if(present(emergence_dry_weight)) then
      status=FMR_WOF38_LIFECYCLE_REJECTED;return
    end if
    forcing%crop_forcing = crop_forcing
    forcing%accepted_aggregates = aggregates
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
      if (allocated(self%root_depth)) typed_copy%root_depth=self%root_depth
      if(allocated(self%root_profile))typed_copy%root_profile=self%root_profile
      if(allocated(self%grass_management))typed_copy%grass_management=self%grass_management
      typed_copy%last_consumed_event = self%last_consumed_event
      if (allocated(self%lifecycle)) then
        allocate(typed_copy%lifecycle)
        typed_copy%lifecycle = self%lifecycle
      end if
    class default
      error stop 'F-WOF38 crop transaction clone allocation failure'
    end select
  end subroutine fmr_wofost_crop_transaction_clone

  logical function fmr_wofost_crop_transaction_state_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (self%owner%validate() /= WOFOST_CROP_OWNER_OK) return
    if(allocated(self%grass_management))then
      if(.not.self%owner%crop_emerged.or..not.allocated(self%potential_shadow))return
      if(.not.self%grass_management%ready())return
    end if
    if (allocated(self%lifecycle)) then
      if (.not. self%lifecycle%ready()) return
      if (self%lifecycle%last_event_identity%ready()) then
        if (.not. self%last_consumed_event%ready()) return
        if (.not. same_wofost_crop_event_identity(self%lifecycle%last_event_identity, &
             self%last_consumed_event)) return
      end if
    end if
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
    if(allocated(self%root_profile))then
      if(.not.allocated(self%root_depth).or..not.self%owner%crop_emerged)return
      if(self%root_profile%validate()/=ADAPTIVE_ROOT_PROFILE_OK)return
      if(abs(sum(self%root_profile%root_biomass_by_node)-self%owner%biomass%root_biomass)> &
        1e-10_real64*max(1.0_real64,self%owner%biomass%root_biomass))return
    end if
    if (allocated(self%root_depth)) then
      if (.not.allocated(self%potential_shadow)) return
      if (self%root_depth%validate()/=CROP_ROOT_RATE_OK) return
      if (.not.self%owner%crop_emerged) then
        if (self%root_depth%actual_root_depth_cm/=0.0_real64.or.self%root_depth%potential_root_depth_cm/=0.0_real64) return
      end if
    end if
    ready = .true.
  end function fmr_wofost_crop_transaction_state_ready

  subroutine fmr_wofost_snapshot_grass_management(self,management,available)
    class(fmr_wofost_crop_transaction_state_t),intent(in)::self
    type(grass_management_continuation_t),intent(out)::management
    logical,intent(out)::available
    management=grass_management_continuation_t();available=.false.
    if(.not.self%ready().or..not.allocated(self%grass_management))return
    management=self%grass_management;available=.true.
  end subroutine

  subroutine fmr_wofost_crop_transaction_snapshot_owner(self, owner, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(wofost_crop_owner_state_t), intent(out) :: owner
    logical, intent(out) :: available

    owner = wofost_crop_owner_state_t()
    available = self%ready()
    if (available) owner = self%owner
  end subroutine fmr_wofost_crop_transaction_snapshot_owner

  subroutine fmr_wofost_crop_transaction_snapshot_lifecycle(self, lifecycle, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(crop_lifecycle_continuation_t), intent(out) :: lifecycle
    logical, intent(out) :: available
    lifecycle = crop_lifecycle_continuation_t()
    available = self%ready() .and. allocated(self%lifecycle)
    if (available) lifecycle = self%lifecycle
  end subroutine fmr_wofost_crop_transaction_snapshot_lifecycle

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

  subroutine fmr_wofost_crop_transaction_snapshot_root_depth(self, depth, available)
    class(fmr_wofost_crop_transaction_state_t), intent(in) :: self
    type(crop_root_depth_rate_state_t), intent(out) :: depth
    logical, intent(out) :: available
    depth=crop_root_depth_rate_state_t()
    available=self%ready().and.allocated(self%root_depth)
    if(available) depth=self%root_depth
  end subroutine

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

  logical function fmr_wofost_parameters_matches_canopy(self,stem_area,storage_area) result(matches)
    class(fmr_wofost_crop_transaction_parameters_t),intent(in)::self
    real(real64),intent(in)::stem_area,storage_area
    matches=.false.
    if(.not.self%ready()) return
    if(.not.all(ieee_is_finite([stem_area,storage_area]))) return
    matches=self%stem_area_coefficient==stem_area.and.self%storage_area_coefficient==storage_area
  end function

  logical function fmr_wofost_parameters_matches_root_depth(self, mode, parameters) result(matches)
    class(fmr_wofost_crop_transaction_parameters_t), intent(in) :: self
    integer, intent(in) :: mode
    type(crop_root_depth_rate_parameters_t), intent(in) :: parameters
    type(crop_root_depth_rate_parameters_t) :: p
    matches=.false.
    if(.not.self%ready()) return
    if(mode/=2) then
      matches=.not.allocated(self%root_depth_parameters)
      return
    end if
    if(.not.allocated(self%root_depth_parameters)) return
    p=self%root_depth_parameters
    matches=all([p%initial_root_depth_cm,p%maximum_root_depth_cm,p%maximum_daily_extension_cm, &
      p%negligible_transpiration,p%negligible_root_growth,p%negligible_extension,p%aeration_critical_factor, &
      p%minimum_daily_extension_cm,p%extent_critical_fraction]== &
      [parameters%initial_root_depth_cm,parameters%maximum_root_depth_cm,parameters%maximum_daily_extension_cm, &
      parameters%negligible_transpiration,parameters%negligible_root_growth,parameters%negligible_extension, &
      parameters%aeration_critical_factor,parameters%minimum_daily_extension_cm, &
      parameters%extent_critical_fraction]).and.p%actual_extension_mode==parameters%actual_extension_mode
    matches=matches.and.(p%require_root_growth.eqv.parameters%require_root_growth).and. &
      (p%anaerobic_extension_gate_enabled.eqv.parameters%anaerobic_extension_gate_enabled)
  end function

  logical function fmr_wofost_crop_transaction_parameters_ready(self) result(ready)
    class(fmr_wofost_crop_transaction_parameters_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (.not. self%rate_parameters%ready()) return
    if(allocated(self%grass_parameters))then
      if(.not.self%grass_parameters%ready().or..not.self%potential_shadow_enabled)return
      if(.not.self%update_parameters%grass_development)return
    end if
    if (allocated(self%root_depth_parameters)) then
      if (.not.self%root_depth_parameters%ready().or..not.self%potential_shadow_enabled) return
      if (self%root_depth_parameters%negligible_transpiration<=0.0_real64) return
    end if
    if(allocated(self%root_profile_configuration))then
      if(.not.allocated(self%root_depth_parameters))return
      if(.not.self%root_profile_configuration%ready())return
    else if(allocated(self%root_depth_parameters))then
      if(self%root_depth_parameters%actual_extension_mode==CROP_ROOT_RATE_DROUGHT_SUPPLY)return
    end if
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
    if (.not. ieee_is_finite(self%aeration_critical_factor)) return
    if (self%aeration_critical_factor < 0.0_real64 .or. self%aeration_critical_factor > 1.0_real64) return
    ready = .true.
  end function fmr_wofost_crop_transaction_parameters_ready

  logical function fmr_wofost_crop_event_forcing_ready(self) result(ready)
    class(fmr_wofost_crop_event_forcing_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (.not. self%event_identity%ready()) return
    if (self%lifecycle_requested) then
      if (.not. self%lifecycle_plan%valid) return
      if (self%lifecycle_expected_revision < 0_8) return
    end if
    if(self%active_lifecycle_requested) then
      if(self%lifecycle_requested.or.self%lifecycle_expected_revision<0_8) return
    end if
    if(self%emergence_requested.and..not.self%active_lifecycle_requested) return
    if (.not. ieee_is_finite(self%accepted_aggregates%actual_root_uptake)) return
    if (.not. ieee_is_finite(self%accepted_aggregates%potential_transpiration)) return
    if (self%accepted_aggregates%actual_root_uptake < 0.0_real64) return
    if (self%accepted_aggregates%potential_transpiration < 0.0_real64) return
    if (self%accepted_aggregates%deepest_root_oxygen_factor_available) then
      if (.not. ieee_is_finite(self%accepted_aggregates%deepest_root_oxygen_factor_integral)) return
      if (self%accepted_aggregates%deepest_root_oxygen_factor_integral < 0.0_real64 .or. &
          self%accepted_aggregates%deepest_root_oxygen_factor_integral > 1.0_real64 + &
          64.0_real64*epsilon(1.0_real64)) return
    else
      if (abs(self%accepted_aggregates%deepest_root_oxygen_factor_integral) > tiny(1.0_real64)) return
    end if
    ready = .true.
  end function fmr_wofost_crop_event_forcing_ready

  subroutine fmr_wofost_crop_configure_parameters(self, parameters)
    class(fmr_wofost_crop_transaction_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters

    self%parameters_ready = .false.
    if(allocated(self%root_depth_parameters)) deallocate(self%root_depth_parameters)
    if(allocated(self%root_profile_configuration))deallocate(self%root_profile_configuration)
    if(allocated(self%grass_parameters))deallocate(self%grass_parameters)
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
      self%anaerobic_root_growth_gate_enabled = typed_parameters%anaerobic_root_growth_gate_enabled
      self%aeration_critical_factor = typed_parameters%aeration_critical_factor
      if(allocated(typed_parameters%root_depth_parameters)) self%root_depth_parameters=typed_parameters%root_depth_parameters
      if(allocated(typed_parameters%root_profile_configuration))self%root_profile_configuration=typed_parameters%root_profile_configuration
      if(allocated(typed_parameters%grass_parameters))self%grass_parameters=typed_parameters%grass_parameters
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
    type(crop_lifecycle_continuation_t) :: candidate_lifecycle
    type(grass_management_continuation_t)::candidate_management
    type(crop_root_depth_rate_state_t) :: candidate_depth
    type(crop_root_depth_rate_daily_forcing_t) :: depth_forcing
    type(crop_root_depth_rate_diagnostics_t) :: depth_diagnostics
    type(adaptive_root_profile_state_t)::candidate_profile,raw_profile
    type(adaptive_root_profile_daily_forcing_t)::profile_forcing
    type(fmr_wofost_crop_event_identity_persistence_t)::layer_receipt
    integer::old_nodes,new_nodes,n
    logical::layers_ok
    integer :: crop_status, oxygen_status, lifecycle_status
    logical :: actual_root_growth_allowed, suppress_actual_root_growth

    outcome = trial_outcome_t()
    old_nodes=0
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
      if (allocated(self%root_depth_parameters).neqv.allocated(typed_state%root_depth)) then
        self%last_status=FMR_WOF38_ROOT_DEPTH_REJECTED
        return
      end if

      if(allocated(typed_state%grass_management).neqv.allocated(self%grass_parameters))return
      if(allocated(typed_state%root_profile).and..not.allocated(self%root_profile_configuration))return
      if(allocated(self%root_profile_configuration).and.typed_state%owner%crop_emerged)then
        if(.not.allocated(typed_state%root_profile))return
        call export_wofost_crop_event_identity_persistence(self%event_forcing%event_identity,layer_receipt,layers_ok)
        if(.not.layers_ok)return
        if(.not.allocated(layer_receipt%potential_root_sink_integral))return
        n=size(self%root_profile_configuration%dz_cm)
        if(size(layer_receipt%potential_root_sink_integral)/=n)return
        if(size(typed_state%root_profile%root_biomass_by_node)/=n)return
        old_nodes=self%root_profile_configuration%rooted_nodes(typed_state%root_depth%actual_root_depth_cm)
        if(old_nodes<=0)return
        if(any(typed_state%root_profile%root_biomass_by_node(old_nodes+1:)/=0.0_real64))return
      end if
      if (self%event_forcing%lifecycle_requested) then
        self%last_status = FMR_WOF38_LIFECYCLE_REJECTED
        if (.not. allocated(typed_state%lifecycle)) return
        call propose_crop_lifecycle_continuation(typed_state%lifecycle, &
             self%event_forcing%lifecycle_plan, self%event_forcing%lifecycle_germination, &
             self%event_forcing%lifecycle_expected_revision, self%event_forcing%event_identity, &
             candidate_lifecycle, lifecycle_status)
        if (lifecycle_status /= CROP_CONT_OK) return
      end if
      if(self%event_forcing%active_lifecycle_requested) then
        self%last_status=FMR_WOF38_LIFECYCLE_REJECTED
        if(.not.allocated(typed_state%lifecycle)) return
        if(typed_state%owner%crop_emerged.neqv.typed_state%lifecycle%emerged) return
        call propose_crop_active_continuation(typed_state%lifecycle, &
             self%event_forcing%lifecycle_expected_revision,self%event_forcing%event_identity, &
             self%event_forcing%emergence_requested,candidate_lifecycle,lifecycle_status)
        if(lifecycle_status/=CROP_CONT_OK) return
      end if
      candidate_growth_carrier = fmr_wofost_root_growth_carrier_t()
      if(self%event_forcing%emergence_requested) then
        ! Existing initializer constructs only this F-KT trial clone. No
        ! previous-day growth is applied to newly emerged morning biomass.
        call initialize_wofost_emergence_owner(self%event_forcing%emergence_dry_weight, &
             self%rate_parameters,candidate_owner,crop_status)
        if(crop_status/=WOFOST_EMERGENCE_INIT_OK) return
        if(self%potential_shadow_enabled) then
          call initialize_wofost_potential_shadow_from_actual(candidate_owner,potential_result%candidate_shadow,crop_status)
          if(crop_status/=WOFOST_POTENTIAL_SHADOW_OK) return
          candidate_growth_carrier%valid=.true.
        end if
      else
      if(allocated(self%grass_parameters))then
        call evaluate_managed_grass_transaction(self,typed_state,t0,t1,candidate_owner,rates,potential_result, &
             candidate_growth_carrier,candidate_management,crop_status)
        self%last_status=crop_status
        if(crop_status/=FMR_WOF38_OK)return
      else
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

      suppress_actual_root_growth = .false.
      if (self%anaerobic_root_growth_gate_enabled) then
        if (.not. self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_available) then
          self%last_status = FMR_WOF38_MISSING_DAILY_OXYGEN
          return
        end if
        call root_extension_allowed_by_daily_oxygen(.true., &
             self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_integral, &
             self%aeration_critical_factor, actual_root_growth_allowed, oxygen_status)
        if (oxygen_status /= ROOT_ANOX_GATE_OK) then
          self%last_status = FMR_WOF38_INVALID_DAILY_OXYGEN
          return
        end if
        suppress_actual_root_growth = .not. actual_root_growth_allowed
      end if

      call complete_wofost_one_day_crop_window(crop_window, self%rate_parameters, self%update_parameters, &
           self%event_forcing%accepted_aggregates, candidate_owner, rates, complete_diagnostics, crop_status, &
           suppress_actual_root_growth=suppress_actual_root_growth)
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

      end if ! Ordinary annual or managed grass day.
      end if ! Emergence initialization or ordinary evolution.
      if (allocated(self%root_depth_parameters)) then
        self%last_status=FMR_WOF38_ROOT_DEPTH_REJECTED
        candidate_depth=typed_state%root_depth
        if (self%event_forcing%emergence_requested) then
          call initialize_crop_root_depth_rate_state(self%root_depth_parameters,candidate_depth,crop_status)
          if(crop_status/=CROP_ROOT_RATE_OK) return
        else if (typed_state%owner%crop_emerged) then
          depth_forcing%potential_transpiration=self%event_forcing%accepted_aggregates%potential_transpiration
          depth_forcing%actual_root_uptake=self%event_forcing%accepted_aggregates%actual_root_uptake
          depth_forcing%actual_root_growth=candidate_growth_carrier%actual_gross_root_growth
          depth_forcing%potential_root_growth=candidate_growth_carrier%potential_gross_root_growth
          depth_forcing%deepest_root_oxygen_factor_available= &
            self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_available
          depth_forcing%deepest_root_oxygen_factor_integral= &
            self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_integral
          if(allocated(self%root_profile_configuration))then
            depth_forcing%deepest_root_biomass_available=.true.
            depth_forcing%deepest_root_biomass=typed_state%root_profile%root_biomass_by_node(old_nodes)
            depth_forcing%deepest_node_top_cm=self%root_profile_configuration%ztop_cm(old_nodes)
            depth_forcing%rootzone_drought_uptake_factor_available= &
              self%event_forcing%accepted_aggregates%rootzone_drought_uptake_factor_available
            depth_forcing%rootzone_drought_uptake_factor_integral= &
              self%event_forcing%accepted_aggregates%rootzone_drought_uptake_factor_integral
          end if
          call evaluate_crop_root_depth_rate_candidate(self%root_depth_parameters,typed_state%root_depth, &
            depth_forcing,candidate_depth,depth_diagnostics,crop_status)
          if(crop_status/=CROP_ROOT_RATE_OK.or..not.depth_diagnostics%candidate_built) return
        end if
      end if
      if(allocated(self%root_profile_configuration).and.self%event_forcing%emergence_requested)then
        call initialize_adaptive_root_profile_state(self%root_profile_configuration%initial_density, &
          self%root_profile_configuration%zbot_cm,self%root_profile_configuration%maximum_root_depth_cm, &
          candidate_depth%actual_root_depth_cm,candidate_owner%biomass%root_biomass,candidate_profile,crop_status)
        if(crop_status/=ADAPTIVE_ROOT_PROFILE_OK)return
      else if(allocated(self%root_profile_configuration).and.typed_state%owner%crop_emerged)then
        new_nodes=self%root_profile_configuration%rooted_nodes(candidate_depth%actual_root_depth_cm)
        profile_forcing%old_rooted_nodes=old_nodes;profile_forcing%rooted_nodes=new_nodes
        profile_forcing%old_root_depth_cm=typed_state%root_depth%actual_root_depth_cm
        profile_forcing%root_depth_cm=candidate_depth%actual_root_depth_cm
        profile_forcing%root_depth_extension_cm=candidate_depth%actual_root_depth_cm-typed_state%root_depth%actual_root_depth_cm
        profile_forcing%root_biomass_end=candidate_owner%biomass%root_biomass
        profile_forcing%root_growth=rates%gross_root_growth_rate
        profile_forcing%root_death=rates%gross_root_growth_rate-rates%root_net_growth_rate
        if(allocated(self%grass_parameters))profile_forcing%root_death=rates%root_death_rate
        profile_forcing%potential_root_sink=layer_receipt%potential_root_sink_integral
        profile_forcing%root_sink_reduction=layer_receipt%root_sink_reduction_integral
        call evaluate_adaptive_root_profile_candidate(self%root_profile_configuration%adaptation, &
          typed_state%root_profile,profile_forcing,self%root_profile_configuration%ztop_cm, &
          self%root_profile_configuration%zbot_cm,self%root_profile_configuration%dz_cm,raw_profile,crop_status)
        if(crop_status/=ADAPTIVE_ROOT_PROFILE_OK)return
        call finalize_adaptive_root_profile_candidate(raw_profile,new_nodes,candidate_owner%biomass%root_biomass, &
          candidate_profile,crop_status)
        if(crop_status/=ADAPTIVE_ROOT_PROFILE_OK)return
      end if
      ! All optional depth work succeeded before publishing any crop field.
      typed_state%owner = candidate_owner
      if(allocated(self%grass_parameters))typed_state%grass_management=candidate_management
      if(allocated(self%root_profile_configuration))then
        if(candidate_owner%crop_emerged)typed_state%root_profile=candidate_profile
      end if
      if(allocated(self%root_depth_parameters)) typed_state%root_depth=candidate_depth
      if (self%potential_shadow_enabled) then
        typed_state%potential_shadow = potential_result%candidate_shadow
        typed_state%root_growth_carrier = candidate_growth_carrier
      end if
      typed_state%last_consumed_event = self%event_forcing%event_identity
      if (self%event_forcing%lifecycle_requested.or.self%event_forcing%active_lifecycle_requested) &
           typed_state%lifecycle = candidate_lifecycle
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

  subroutine evaluate_managed_grass_transaction(self,base,t0,t1,owner,rates,potential_result,growth,management,status)
    class(fmr_wofost_crop_transaction_model_t),intent(in)::self
    type(fmr_wofost_crop_transaction_state_t),intent(in)::base
    real(real64),intent(in)::t0,t1
    type(wofost_crop_owner_state_t),intent(out)::owner
    type(wofost_one_day_rate_packet_t),intent(out)::rates
    type(wofost_potential_daily_result_t),intent(out)::potential_result
    type(fmr_wofost_root_growth_carrier_t),intent(out)::growth
    type(grass_management_continuation_t),intent(out)::management
    integer,intent(out)::status
    type(grass_development_candidate_t)::actual_development,potential_development
    type(grass_management_continuation_t)::potential_management
    type(wofost_crop_owner_state_t)::potential_owner,potential_candidate
    type(wofost_one_day_rate_packet_t)::potential_rates
    type(wofost_accepted_window_aggregates_t)::potential_aggregates
    real(real64)::soil_temperature,removed,potential_removed
    logical::allowed,available,suppress
    integer::code
    owner=wofost_crop_owner_state_t();rates=wofost_one_day_rate_packet_t()
    potential_result=wofost_potential_daily_result_t();growth=fmr_wofost_root_growth_carrier_t()
    management=grass_management_continuation_t();status=FMR_WOF38_CROP_COMPLETE_ERROR
    if(.not.allocated(self%grass_parameters).or..not.allocated(base%grass_management))return
    if(.not.allocated(base%potential_shadow).or..not.base%owner%crop_emerged)return
    if(.not.allocated(base%owner%evolution_continuation))return
    if(t1-t0/=1.0_real64)return
    if(self%event_forcing%crop_forcing%calendar_day_of_year<1.or. &
       self%event_forcing%crop_forcing%calendar_day_of_year>366)return
    if(max(base%grass_management%cut_index,base%grass_management%potential_cut_index)> &
       self%grass_parameters%sequence_length+1)return
    soil_temperature=0.0_real64
    if(self%grass_parameters%development%temperature_start_mode==2)then
      if(.not.self%event_forcing%crop_forcing%grass_soil_temperature_available)return
      soil_temperature=self%event_forcing%crop_forcing%grass_soil_temperature_c
    end if
    call prepare_grass_development_candidate(self%grass_parameters%development,base%grass_management, &
         base%owner%evolution_continuation%temperature_sum,self%event_forcing%crop_forcing%average_temperature, &
         soil_temperature,actual_development,code)
    if(code/=GRASS_DEVELOPMENT_OK)return
    management=actual_development%management
    potential_management=base%grass_management
    potential_management%regrowth_delay_days=base%grass_management%potential_regrowth_delay_days
    call prepare_grass_development_candidate(self%grass_parameters%development,potential_management, &
         base%owner%evolution_continuation%temperature_sum,self%event_forcing%crop_forcing%average_temperature, &
         soil_temperature,potential_development,code)
    if(code/=GRASS_DEVELOPMENT_OK)return
    management%potential_regrowth_delay_days=potential_development%management%regrowth_delay_days
    suppress=.false.
    if(self%anaerobic_root_growth_gate_enabled)then
      if(.not.self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_available)return
      call root_extension_allowed_by_daily_oxygen(.true., &
           self%event_forcing%accepted_aggregates%deepest_root_oxygen_factor_integral,self%aeration_critical_factor, &
           allowed,code)
      if(code/=ROOT_ANOX_GATE_OK)return
      suppress=.not.allowed
    end if
    call complete_threshold_grass_day(self,base%owner,t0,t1,self%event_forcing%accepted_aggregates,actual_development, &
         management%actual_cut_age,management%cut_index,management%regrowth_delay_days,owner,rates,removed,code,suppress)
    if(code/=WOFOST_CROP_WINDOW_OK)return
    call base%potential_shadow%materialize_owner(base%owner,potential_owner,available,code)
    if(code/=WOFOST_POTENTIAL_SHADOW_OK.or..not.available)return
    potential_aggregates%actual_root_uptake=1.0_real64;potential_aggregates%potential_transpiration=1.0_real64
    call complete_threshold_grass_day(self,potential_owner,t0,t1,potential_aggregates,potential_development, &
         management%potential_cut_age,management%potential_cut_index,management%potential_regrowth_delay_days, &
         potential_candidate,potential_rates,potential_removed,code,.false.,self%potential_attainable_multiplier)
    if(code/=WOFOST_CROP_WINDOW_OK)return
    potential_result%candidate_shadow=base%potential_shadow
    call potential_result%candidate_shadow%absorb_owner(potential_candidate,code)
    if(code/=WOFOST_POTENTIAL_SHADOW_OK)return
    potential_result%gross_root_growth_rate=potential_rates%gross_root_growth_rate
    potential_result%potential_root_biomass=potential_result%candidate_shadow%root_biomass()
    growth%actual_gross_root_growth=rates%gross_root_growth_rate
    growth%potential_gross_root_growth=potential_rates%gross_root_growth_rate;growth%valid=.true.
    if(.not.growth%ready())return
    management%harvested_dry_matter=base%grass_management%harvested_dry_matter+removed
    management%potential_harvested_dry_matter=base%grass_management%potential_harvested_dry_matter+potential_removed
    if(.not.management%ready())return
    status=FMR_WOF38_OK
  end subroutine evaluate_managed_grass_transaction

  subroutine complete_threshold_grass_day(self,base,t0,t1,aggregates,development,cut_age,cut_index,delay, &
       candidate,rates,removed,status,suppress,attainable_multiplier)
    class(fmr_wofost_crop_transaction_model_t),intent(in)::self
    type(wofost_crop_owner_state_t),intent(in)::base
    real(real64),intent(in)::t0,t1
    type(wofost_accepted_window_aggregates_t),intent(in)::aggregates
    type(grass_development_candidate_t),intent(in)::development
    integer,intent(inout)::cut_age,cut_index,delay
    type(wofost_crop_owner_state_t),intent(out)::candidate
    type(wofost_one_day_rate_packet_t),intent(out)::rates
    real(real64),intent(out)::removed
    integer,intent(out)::status
    logical,intent(in)::suppress
    real(real64),intent(in),optional::attainable_multiplier
    type(wofost_two_phase_crop_window_t)::window
    type(wofost_crop_window_begin_diagnostics_t)::diagnostics
    real(real64)::aerial,threshold,delay_value
    logical::cut
    integer::code
    removed=0.0_real64;status=WOFOST_CROP_WINDOW_CONTEXT_NOT_READY
    if(.not.allocated(self%grass_parameters).or..not.allocated(base%biomass))return
    call begin_wofost_one_day_crop_window(base,self%event_forcing%crop_forcing,t0,t1, &
         self%stem_area_coefficient,self%storage_area_coefficient,self%rate_parameters,window,diagnostics,code, &
         attainable_multiplier_override=attainable_multiplier)
    if(code/=WOFOST_CROP_WINDOW_OK)return
    cut=.false.
    if(development%growth_enabled)then
      if(cut_age==huge(cut_age))return
      cut_age=cut_age+1
      if(cut_index<=self%grass_parameters%sequence_length)then
        call self%grass_parameters%mowing_threshold%evaluate( &
             real(self%event_forcing%crop_forcing%calendar_day_of_year,real64),threshold,code)
        if(code/=0)return
        aerial=sum(base%biomass%leaf_biomass)+base%biomass%stem_biomass+base%biomass%storage_biomass+ &
             base%biomass%cumulative_dead_leaf_biomass+base%biomass%cumulative_dead_stem_biomass
        cut=aerial>threshold.or.(cut_age>self%grass_parameters%max_growing_days.and.cut_index>1)
      end if
    end if
    if(cut)then
      call complete_wofost_grass_crop_window(window,self%rate_parameters,self%update_parameters,aggregates, &
           development,candidate,rates,status,self%grass_parameters%mowing_residual,removed,suppress)
      if(status/=WOFOST_CROP_WINDOW_OK)return
      call self%grass_parameters%regrowth_delay%evaluate(removed,delay_value,code)
      if(code/=0.or.delay_value<0.0_real64.or.delay_value>366.0_real64)return
      delay=int(delay_value);cut_index=cut_index+1;cut_age=0
    else
      call complete_wofost_grass_crop_window(window,self%rate_parameters,self%update_parameters,aggregates, &
           development,candidate,rates,status,suppress_actual_root_growth=suppress)
    end if
  end subroutine complete_threshold_grass_day

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

  subroutine fmr_wofost_snapshot_root_profile(self,profile,available)
    class(fmr_wofost_crop_transaction_state_t),intent(in)::self
    type(adaptive_root_profile_state_t),intent(out)::profile
    logical,intent(out)::available
    profile=adaptive_root_profile_state_t()
    available=self%ready().and.allocated(self%root_profile)
    if(available)profile=self%root_profile
  end subroutine

  logical function fmr_wofost_matches_root_profile(self,enabled,c)result(matches)
    class(fmr_wofost_crop_transaction_parameters_t),intent(in)::self
    logical,intent(in)::enabled
    type(adaptive_root_profile_configuration_t),intent(in)::c
    type(adaptive_root_profile_configuration_t)::p
    type(adaptive_root_profile_state_t)::a,b
    integer::status
    matches=.false.
    if(.not.self%ready())return
    if(.not.enabled)then
      matches=.not.allocated(self%root_profile_configuration);return
    end if
    if(.not.allocated(self%root_profile_configuration))return
    if(.not.c%ready())return
    p=self%root_profile_configuration
    if(size(p%dz_cm)/=size(c%dz_cm))return
    if(any(p%ztop_cm/=c%ztop_cm).or.any(p%zbot_cm/=c%zbot_cm).or.any(p%dz_cm/=c%dz_cm))return
    if(p%maximum_root_depth_cm/=c%maximum_root_depth_cm)return
    if(any([p%adaptation%growth_adaptation_fraction,p%adaptation%death_adaptation_fraction, &
      p%adaptation%minimum_root_biomass_per_cm,p%adaptation%specific_root_length_m_per_kg]/= &
      [c%adaptation%growth_adaptation_fraction,c%adaptation%death_adaptation_fraction, &
      c%adaptation%minimum_root_biomass_per_cm,c%adaptation%specific_root_length_m_per_kg]))return
    call initialize_adaptive_root_profile_state(p%initial_density,p%zbot_cm,p%maximum_root_depth_cm, &
      self%root_depth_parameters%initial_root_depth_cm,1.0_real64,a,status)
    if(status/=ADAPTIVE_ROOT_PROFILE_OK)return
    call initialize_adaptive_root_profile_state(c%initial_density,c%zbot_cm,c%maximum_root_depth_cm, &
      self%root_depth_parameters%initial_root_depth_cm,1.0_real64,b,status)
    if(status/=ADAPTIVE_ROOT_PROFILE_OK)return
    matches=all(a%root_biomass_by_node==b%root_biomass_by_node)
  end function

end module mod_fmr_wofost_crop_transaction
