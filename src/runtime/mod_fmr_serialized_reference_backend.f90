module mod_fmr_serialized_reference_backend
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, TX_MASS_MISSING_NONE, &
       TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fkt_temporal_indicator_history, only: fkt_temporal_indicator_history_t
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, canonical_interval_t, &
       canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_parameters_t, kernel_model_t, kernel_committed_state_t, &
       kernel_checkpoint_t, kernel_executor_t, kernel_result_t, kernel_candidate_state_t, kernel_diagnostics_t, &
       KERNEL_STATUS_NOT_ADMITTED
  use mod_fmr_checkpoint_orchestrator, only: fmr_trial_from_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_optional_state_layouts, only: FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, soil_water_solver_diagnostics_t, top_boundary_provider_t, SW_SOLVE_CONVERGED, &
       soil_water_temporal_indicator_request_t, soil_water_temporal_indicator_result_t, &
       SW_TEMPORAL_INDICATOR_NOT_RUN
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_snow_process, only: snow_parameters_t, snow_state_t, snow_forcing_t, snow_flux_result_t, &
       snow_mass_contribution_t, snow_diagnostics_t, evaluate_snow_reference_call, SNOW_OK
  use mod_restricted_fixed_weir_surface_water, only: fixed_weir_surface_water_parameters_t, &
       fixed_weir_surface_water_state_t, fixed_weir_surface_water_forcing_t, &
       fixed_weir_surface_water_numerical_config_t, fixed_weir_surface_water_result_t, &
       evaluate_restricted_fixed_weir_surface_water, validate_fixed_weir_surface_water_parameters, &
       FIXED_WEIR_AVAILABLE
  implicit none
  private

  type, public :: fmr_snow_runtime_state_t
    type(snow_state_t) :: process
    logical :: event_applied = .false.
    real(real64) :: event_t0 = 0.0_real64
  end type fmr_snow_runtime_state_t

  type, extends(canonical_state_t), public :: fmr_b110_physical_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
    real(real64) :: ponding_depth = 0.0_real64
    real(real64) :: groundwater_level = 0.0_real64
    type(fmr_snow_runtime_state_t), allocatable :: snow
  contains
    procedure :: clone => fmr_b110_state_clone
  end type fmr_b110_physical_state_t

  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_temporal_indicator_state_t
    private
    type(fkt_temporal_indicator_history_t) :: temporal_history
  contains
    procedure :: clone => fmr_b110_temporal_indicator_state_clone
    procedure, public :: temporal_history_available => fmr_b110_temporal_history_available
    procedure, public :: temporal_history_snapshot => fmr_b110_temporal_history_snapshot
  end type fmr_b110_temporal_indicator_state_t

  ! D7 physical optional-state family.  SWST exists only on feature-active
  ! columns; inactive B1.10 states retain their previous layout and footprint.
  type, extends(fmr_b110_physical_state_t), public :: fmr_b110_fixed_weir_surface_water_state_t
    type(fixed_weir_surface_water_state_t) :: surface_water
  contains
    procedure :: clone => fmr_b110_fixed_weir_surface_water_state_clone
  end type fmr_b110_fixed_weir_surface_water_state_t

  type, extends(kernel_parameters_t), public :: fmr_b110_physical_parameters_t
    integer(int64) :: parameter_set_id = 0_int64
    integer :: active_nodes = 0
    real(real64), allocatable :: z(:)
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: node_distance(:)
    real(real64), allocatable :: cofgen(:,:)
    integer :: bottom_mode = 7
    integer :: swkimpl = 0
    integer :: swkmean = 1
    integer :: swsophy = 0
    integer :: max_iterations = 8
    integer :: max_backtracking = 4
    real(real64) :: min_step_duration = 1.0e-6_real64
    real(real64) :: compartment_balance_tolerance = 1.0e-12_real64
    real(real64) :: total_balance_tolerance = 1.0e-12_real64
    real(real64) :: head_abs_tolerance = 1.0e-12_real64
    real(real64) :: head_rel_tolerance = 1.0e-12_real64
    real(real64) :: ponding_tolerance = 1.0e-12_real64
    logical :: root_extraction_active = .false.
    logical :: macropore_active = .false.
    logical :: snow_active = .false.
    logical :: hysteresis_active = .false.
    logical :: tabulated_hydraulics_active = .false.
    logical :: elasticity_active = .false.
    logical :: frost_active = .false.
    type(snow_parameters_t), allocatable :: snow
  end type fmr_b110_physical_parameters_t

  type, extends(canonical_forcing_t), public :: fmr_b110_physical_forcing_t
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: top_head = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: bottom_head = 0.0_real64
    real(real64), allocatable :: drainage_flux_by_level(:,:)
    real(real64), allocatable :: subsurface_irrigation_source(:)
    real(real64), allocatable :: root_extraction_sink(:)
    type(snow_forcing_t), allocatable :: snow
  end type fmr_b110_physical_forcing_t

  type, public :: fmr_serialized_physical_observation_t
    logical :: solver_executed = .false.
    integer :: solver_status = 0
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: solver_equation_residual = 0.0_real64
    logical :: solver_equation_residual_available = .false.
    type(soil_water_solver_diagnostics_t) :: solver_diagnostics
    logical :: temporal_indicator_enabled = .false.
    logical :: temporal_previous_derivative_available = .false.
    logical :: temporal_current_derivative_available = .false.
    integer :: temporal_indicator_status = SW_TEMPORAL_INDICATOR_NOT_RUN
    logical :: temporal_indicator_available = .false.
    character(len=40) :: temporal_indicator_route = 'not-run'
    real(real64) :: temporal_head_inf_bound = 0.0_real64
    logical :: temporal_head_budget_supplied = .false.
    logical :: temporal_head_budget_valid = .false.
    real(real64) :: temporal_head_budget = 0.0_real64
    logical :: temporal_certificate_available = .false.
    real(real64) :: temporal_normalized_indicator = 0.0_real64
    character(len=48) :: temporal_certificate_unavailable_reason = 'not-evaluated'
    integer :: temporal_additional_tridiagonal_solves = 0
    integer :: temporal_additional_full_nonlinear_solves = 0
    logical :: snow_active = .false.
    logical :: snow_event_prepared = .false.
    integer :: snow_status = 0
    real(real64) :: snow_melt_rate = 0.0_real64
    type(snow_flux_result_t) :: snow_fluxes
    type(snow_mass_contribution_t) :: snow_mass
    logical :: fixed_weir_surface_water_active = .false.
    integer :: fixed_weir_surface_water_status = 0
    real(real64) :: fixed_weir_surface_water_storage = 0.0_real64
    real(real64) :: fixed_weir_surface_water_level = 0.0_real64
    real(real64) :: fixed_weir_surface_water_supply_rate = 0.0_real64
    real(real64) :: fixed_weir_surface_water_discharge_rate = 0.0_real64
    real(real64) :: fixed_weir_surface_water_mass_residual = 0.0_real64
    real(real64) :: fixed_weir_surface_water_rating_residual = 0.0_real64
    integer :: fixed_weir_surface_water_iterations = 0
    character(len=32) :: fixed_weir_surface_water_route = 'not-run'
  end type fmr_serialized_physical_observation_t

  type, extends(kernel_model_t) :: fmr_serialized_reference_model_t
    type(soil_water_parameter_set_t), pointer :: soil_parameters => null()
    type(b110_default_mvg_parameters_t), pointer :: hydraulic_parameters => null()
    type(b110_default_mvg_provider_t), pointer :: constitutive => null()
    type(b110_source_sink_provider_t), pointer :: source_sink => null()
    type(b110_root_sink_provider_t), pointer :: root_sink => null()
    class(top_boundary_provider_t), pointer :: top_boundary => null()
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    real(real64), pointer :: qdra(:,:) => null()
    real(real64), pointer :: qssdi(:) => null()
    real(real64), pointer :: qrot(:) => null()
    integer :: bottom_mode = 7
    integer :: swkimpl = 0
    integer :: swkmean = 1
    integer :: max_iterations = 8
    integer :: max_backtracking = 4
    real(real64) :: min_step_duration = 1.0e-6_real64
    real(real64) :: compartment_balance_tolerance = 1.0e-12_real64
    real(real64) :: total_balance_tolerance = 1.0e-12_real64
    real(real64) :: head_abs_tolerance = 1.0e-12_real64
    real(real64) :: head_rel_tolerance = 1.0e-12_real64
    real(real64) :: ponding_tolerance = 1.0e-12_real64
    real(real64) :: top_flux = 0.0_real64
    real(real64) :: base_top_flux = 0.0_real64
    real(real64) :: top_head = 0.0_real64
    real(real64) :: bottom_flux = 0.0_real64
    real(real64) :: bottom_head = 0.0_real64
    logical :: forcing_admitted = .false.
    logical :: state_profile_admitted = .false.
    logical :: root_extraction_active = .false.
    logical :: temporal_indicator_history_enabled = .false.
    logical :: temporal_indicator_budget_supplied = .false.
    logical :: temporal_indicator_budget_valid = .false.
    real(real64) :: temporal_indicator_budget = 0.0_real64
    logical :: snow_active = .false.
    logical :: snow_event_prepared = .false.
    real(real64) :: snow_outer_t0 = 0.0_real64
    real(real64) :: snow_outer_t1 = 0.0_real64
    real(real64) :: snow_melt_rate = 0.0_real64
    type(snow_state_t) :: snow_candidate
    type(snow_flux_result_t) :: snow_fluxes
    type(snow_diagnostics_t) :: snow_diagnostics
    logical :: fixed_weir_surface_water_active = .false.
    logical :: fixed_weir_surface_water_configured = .false.
    type(fixed_weir_surface_water_parameters_t) :: fixed_weir_surface_water_parameters
    type(fixed_weir_surface_water_forcing_t) :: fixed_weir_surface_water_forcing
    type(fixed_weir_surface_water_numerical_config_t) :: fixed_weir_surface_water_numerical
    type(fixed_weir_surface_water_result_t) :: fixed_weir_surface_water_result
    type(fmr_serialized_physical_observation_t) :: last_observation
  contains
    procedure :: configure_parameters => fmr_serialized_configure_parameters
    procedure :: execution_admitted => fmr_serialized_execution_admitted
    procedure :: prepare_interval => fmr_serialized_prepare_interval
    procedure :: advance => fmr_serialized_advance
    procedure :: storage => fmr_serialized_storage
    procedure :: storage_accounting_status => fmr_serialized_storage_accounting_status
    procedure :: temporal_error => fmr_serialized_temporal_identity
  end type fmr_serialized_reference_model_t

  type, public :: fmr_serialized_reference_backend_t
    private
    type(fmr_serialized_reference_model_t) :: model
    type(kernel_executor_t) :: kernel
    logical :: initialized = .false.
  contains
    procedure, public :: initialize => fmr_serialized_backend_initialize
    procedure, public :: run_trial => fmr_serialized_backend_run_trial
    procedure, public :: observation => fmr_serialized_backend_observation
    procedure, public :: configure_fixed_weir_surface_water => fmr_serialized_backend_configure_fixed_weir_surface_water
    procedure, public :: clear_fixed_weir_surface_water => fmr_serialized_backend_clear_fixed_weir_surface_water
  end type fmr_serialized_reference_backend_t

  public :: fmr_new_b110_committed_state
  public :: fmr_new_b110_temporal_indicator_committed_state
  public :: fmr_new_b110_fixed_weir_surface_water_committed_state

contains

  subroutine copy_b110_physical_state(source, target)
    class(fmr_b110_physical_state_t), intent(in) :: source
    class(fmr_b110_physical_state_t), intent(inout) :: target
    target%active_nodes = source%active_nodes
    if (allocated(target%pressure_head)) deallocate(target%pressure_head)
    if (allocated(source%pressure_head)) then
      allocate(target%pressure_head(size(source%pressure_head)))
      target%pressure_head = source%pressure_head
    end if
    if (allocated(target%water_content)) deallocate(target%water_content)
    if (allocated(source%water_content)) then
      allocate(target%water_content(size(source%water_content)))
      target%water_content = source%water_content
    end if
    target%ponding_depth = source%ponding_depth
    target%groundwater_level = source%groundwater_level
    if (allocated(target%snow)) deallocate(target%snow)
    if (allocated(source%snow)) then
      allocate(target%snow)
      target%snow = source%snow
    end if
  end subroutine copy_b110_physical_state

  subroutine fmr_b110_state_clone(self, copy)
    class(fmr_b110_physical_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_physical_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_physical_state_t)
      call copy_b110_physical_state(self, typed_copy)
    end select
  end subroutine fmr_b110_state_clone

  subroutine fmr_b110_temporal_indicator_state_clone(self, copy)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    real(real64), allocatable :: derivative(:)
    logical :: available, ok
    allocate(fmr_b110_temporal_indicator_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_temporal_indicator_state_t)
      call copy_b110_physical_state(self, typed_copy)
      call self%temporal_history%snapshot(derivative, available)
      if (available) then
        call typed_copy%temporal_history%replace(derivative, ok)
        if (.not. ok) error stop 'F-KT10 temporal history clone rejected valid source'
      end if
    end select
  end subroutine fmr_b110_temporal_indicator_state_clone

  subroutine fmr_b110_fixed_weir_surface_water_state_clone(self, copy)
    class(fmr_b110_fixed_weir_surface_water_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(fmr_b110_fixed_weir_surface_water_state_t :: copy)
    select type (typed_copy => copy)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      call copy_b110_physical_state(self, typed_copy)
      typed_copy%surface_water = self%surface_water
    end select
  end subroutine fmr_b110_fixed_weir_surface_water_state_clone

  logical function fmr_b110_temporal_history_available(self) result(available)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    available = self%temporal_history%available(self%active_nodes)
  end function fmr_b110_temporal_history_available

  subroutine fmr_b110_temporal_history_snapshot(self, derivative, available)
    class(fmr_b110_temporal_indicator_state_t), intent(in) :: self
    real(real64), allocatable, intent(out) :: derivative(:)
    logical, intent(out) :: available
    available = self%temporal_history%available(self%active_nodes)
    if (.not. available) return
    call self%temporal_history%snapshot(derivative, available)
  end subroutine fmr_b110_temporal_history_snapshot

  subroutine fmr_new_b110_committed_state(committed, lineage_id, state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier
    allocate(fmr_b110_physical_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_physical_state_t)
      call copy_b110_physical_state(state, typed_carrier)
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_committed_state

  subroutine fmr_new_b110_temporal_indicator_committed_state(committed, lineage_id, state, initial_time, ok, &
                                                              initial_right_derivative)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_physical_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    real(real64), intent(in), optional :: initial_right_derivative(:)
    class(transaction_state_t), allocatable :: carrier
    logical :: seeded

    ok = .false.
    allocate(fmr_b110_temporal_indicator_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_temporal_indicator_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      call typed_carrier%temporal_history%clear()
      if (present(initial_right_derivative)) then
        if (state%active_nodes <= 0 .or. size(initial_right_derivative) /= state%active_nodes) return
        call typed_carrier%temporal_history%replace(initial_right_derivative, seeded)
        if (.not. seeded) return
      end if
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_temporal_indicator_committed_state

  subroutine fmr_new_b110_fixed_weir_surface_water_committed_state(committed, lineage_id, state, initial_time, ok)
    type(kernel_committed_state_t), intent(out) :: committed
    integer(int64), intent(in) :: lineage_id
    type(fmr_b110_fixed_weir_surface_water_state_t), intent(in) :: state
    real(real64), intent(in) :: initial_time
    logical, intent(out) :: ok
    class(transaction_state_t), allocatable :: carrier

    ok = .false.
    if (.not. ieee_is_finite(state%surface_water%storage)) return
    allocate(fmr_b110_fixed_weir_surface_water_state_t :: carrier)
    select type (typed_carrier => carrier)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      call copy_b110_physical_state(state, typed_carrier)
      typed_carrier%surface_water = state%surface_water
    end select
    call committed%initialize(lineage_id, carrier, ok, initial_time)
  end subroutine fmr_new_b110_fixed_weir_surface_water_committed_state

  logical function state_matches_numerical_continuation_layout(state, temporal_history_enabled, &
                                                               fixed_weir_surface_water_active) result(matches)
    class(transaction_state_t), intent(in) :: state
    logical, intent(in) :: temporal_history_enabled, fixed_weir_surface_water_active
    select type (state)
    type is (fmr_b110_temporal_indicator_state_t)
      matches = temporal_history_enabled .and. .not. fixed_weir_surface_water_active
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      matches = .not. temporal_history_enabled .and. fixed_weir_surface_water_active
    type is (fmr_b110_physical_state_t)
      matches = .not. temporal_history_enabled .and. .not. fixed_weir_surface_water_active
    class default
      matches = .false.
    end select
  end function state_matches_numerical_continuation_layout

  subroutine clear_snow_preparation(model)
    type(fmr_serialized_reference_model_t), intent(inout) :: model
    model%snow_active = .false.
    model%snow_event_prepared = .false.
    model%state_profile_admitted = .false.
    model%snow_outer_t0 = 0.0_real64
    model%snow_outer_t1 = 0.0_real64
    model%snow_melt_rate = 0.0_real64
    model%snow_candidate = snow_state_t()
    model%snow_fluxes = snow_flux_result_t()
    model%snow_diagnostics = snow_diagnostics_t()
  end subroutine clear_snow_preparation

  subroutine prepare_snow_outer_event(model, parameters, committed, forcing, t0, t1)
    type(fmr_serialized_reference_model_t), intent(inout) :: model
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    real(real64), intent(in) :: t0, t1
    class(transaction_state_t), allocatable :: snapshot
    logical :: available
    call clear_snow_preparation(model)
    model%snow_active = parameters%snow_active
    model%snow_outer_t0 = t0
    model%snow_outer_t1 = t1
    if (model%fixed_weir_surface_water_active .and. parameters%snow_active) return
    call committed%snapshot(snapshot, available)
    if (.not. available) return
    if (.not. state_matches_numerical_continuation_layout(snapshot, model%temporal_indicator_history_enabled, &
                                                           model%fixed_weir_surface_water_active)) return
    select type (physical => snapshot)
    class is (fmr_b110_physical_state_t)
      if (parameters%snow_active) then
        if (.not. allocated(parameters%snow) .or. .not. allocated(forcing%snow) .or. &
            .not. allocated(physical%snow)) return
        call evaluate_snow_reference_call(parameters%snow, physical%snow%process, forcing%snow, t0, t1, &
             model%snow_candidate, model%snow_fluxes, model%snow_diagnostics)
        if (model%snow_diagnostics%status /= SNOW_OK .or. .not. model%snow_diagnostics%mass%available) return
        model%snow_event_prepared = .true.
        model%snow_melt_rate = model%snow_fluxes%melt / (t1 - t0)
        model%state_profile_admitted = .true.
      else
        if (allocated(parameters%snow) .or. allocated(forcing%snow) .or. allocated(physical%snow)) return
        model%state_profile_admitted = .true.
      end if
    class default
      return
    end select
  end subroutine prepare_snow_outer_event

  subroutine fmr_serialized_backend_initialize(self, top_boundary)
    class(fmr_serialized_reference_backend_t), target, intent(inout) :: self
    class(top_boundary_provider_t), target, intent(in) :: top_boundary
    self%model%top_boundary => top_boundary
    self%model%temporal_indicator_history_enabled = .false.
    self%model%temporal_indicator_budget_supplied = .false.
    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    call self%clear_fixed_weir_surface_water()
    call self%kernel%bind_model(self%model)
    self%initialized = .true.
  end subroutine fmr_serialized_backend_initialize

  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water(self, parameters, forcing, numerical, ok)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(fixed_weir_surface_water_parameters_t), intent(in) :: parameters
    type(fixed_weir_surface_water_forcing_t), intent(in) :: forcing
    type(fixed_weir_surface_water_numerical_config_t), intent(in) :: numerical
    logical, intent(out) :: ok
    logical :: parameters_ok

    call self%clear_fixed_weir_surface_water()
    ok = .false.
    if (.not. self%initialized) return
    call validate_fixed_weir_surface_water_parameters(parameters, parameters_ok)
    if (.not. parameters_ok) return
    if (.not. ieee_is_finite(forcing%secondary_drainage_rate) .or. &
        .not. ieee_is_finite(forcing%supply_capacity_rate)) return
    if (forcing%secondary_drainage_rate < 0.0_real64 .or. forcing%supply_capacity_rate < 0.0_real64) return
    if (numerical%max_bisection_iterations <= 0 .or. &
        .not. ieee_is_finite(numerical%rating_storage_abs_tolerance) .or. &
        .not. ieee_is_finite(numerical%rating_storage_rel_tolerance)) return
    if (numerical%rating_storage_abs_tolerance <= 0.0_real64 .or. &
        numerical%rating_storage_rel_tolerance < 0.0_real64) return

    self%model%fixed_weir_surface_water_parameters = parameters
    self%model%fixed_weir_surface_water_forcing = forcing
    self%model%fixed_weir_surface_water_numerical = numerical
    self%model%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    self%model%fixed_weir_surface_water_configured = .true.
    self%model%fixed_weir_surface_water_active = .true.
    ok = .true.
  end subroutine fmr_serialized_backend_configure_fixed_weir_surface_water

  subroutine fmr_serialized_backend_clear_fixed_weir_surface_water(self)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    self%model%fixed_weir_surface_water_active = .false.
    self%model%fixed_weir_surface_water_configured = .false.
    self%model%fixed_weir_surface_water_parameters = fixed_weir_surface_water_parameters_t()
    self%model%fixed_weir_surface_water_forcing = fixed_weir_surface_water_forcing_t()
    self%model%fixed_weir_surface_water_numerical = fixed_weir_surface_water_numerical_config_t()
    self%model%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
  end subroutine fmr_serialized_backend_clear_fixed_weir_surface_water

  subroutine fmr_serialized_backend_run_trial(self, column, template, parameters, committed, forcing, config, &
                                               t0, t1, checkpoint, result, candidate, diagnostics)
    class(fmr_serialized_reference_backend_t), intent(inout) :: self
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: committed
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing
    type(canonical_numerical_config_t), intent(in) :: config
    real(real64), intent(in) :: t0, t1
    type(kernel_checkpoint_t), intent(in) :: checkpoint
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    self%model%temporal_indicator_history_enabled = .false.
    self%model%temporal_indicator_budget_supplied = .false.
    self%model%temporal_indicator_budget_valid = .false.
    self%model%temporal_indicator_budget = 0.0_real64
    if (.not. self%initialized .or. column%backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE .or. &
        column%template_id /= template%template_id .or. column%column_id <= 0_int64) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    if (self%model%fixed_weir_surface_water_active) then
      if (.not. self%model%fixed_weir_surface_water_configured .or. &
          template%optional_state_layout_id /= FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER .or. &
          template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .or. &
          config%transaction%temporal_mode /= TX_TEMPORAL_EXTERNAL_FULL_HALF .or. parameters%snow_active) then
        call reject_backend_trial(result, candidate, diagnostics)
        return
      end if
    else if (template%optional_state_layout_id == FMR_OPTIONAL_STATE_FIXED_WEIR_SURFACE_WATER) then
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end if
    select case (template%numerical_continuation_layout_id)
    case (FMR_NUMERICAL_CONTINUATION_NONE)
      self%model%temporal_indicator_history_enabled = .false.
    case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
      self%model%temporal_indicator_history_enabled = .true.
    case default
      call reject_backend_trial(result, candidate, diagnostics)
      return
    end select
    call prepare_snow_outer_event(self%model, parameters, committed, forcing, t0, t1)
    call fmr_trial_from_checkpoint(self%kernel, parameters, committed, forcing, config, t0, t1, checkpoint, &
         result, candidate, diagnostics)
  end subroutine fmr_serialized_backend_run_trial

  subroutine reject_backend_trial(result, candidate, diagnostics)
    type(kernel_result_t), intent(out) :: result
    type(kernel_candidate_state_t), intent(out) :: candidate
    type(kernel_diagnostics_t), intent(out) :: diagnostics
    result = kernel_result_t()
    result%status = KERNEL_STATUS_NOT_ADMITTED
    candidate = kernel_candidate_state_t()
    diagnostics = kernel_diagnostics_t()
    diagnostics%admission_rejections = 1
  end subroutine reject_backend_trial

  function fmr_serialized_backend_observation(self) result(obs)
    class(fmr_serialized_reference_backend_t), intent(in) :: self
    type(fmr_serialized_physical_observation_t) :: obs
    obs = self%model%last_observation
  end function fmr_serialized_backend_observation

  logical function fmr_serialized_execution_admitted(self, parameters, numerical_config)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    type(canonical_numerical_config_t), intent(in) :: numerical_config
    logical :: ok
    ok = associated(self%top_boundary) .and. numerical_config%max_committed_substeps > 0 .and. &
         self%state_profile_admitted
    if (self%fixed_weir_surface_water_active) then
      ok = ok .and. self%fixed_weir_surface_water_configured .and. .not. self%temporal_indicator_history_enabled .and. &
           numerical_config%transaction%temporal_mode == TX_TEMPORAL_EXTERNAL_FULL_HALF
    end if
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      ok = ok .and. parameters%parameter_set_id > 0_int64 .and. parameters%active_nodes > 0 .and. &
           allocated(parameters%z) .and. allocated(parameters%dz) .and. allocated(parameters%node_distance) .and. &
           allocated(parameters%cofgen)
      if (ok) ok = size(parameters%z) == parameters%active_nodes .and. &
           size(parameters%dz) == parameters%active_nodes .and. &
           size(parameters%node_distance) == parameters%active_nodes .and. &
           size(parameters%cofgen,1) >= 24 .and. size(parameters%cofgen,2) == parameters%active_nodes
      ok = ok .and. (parameters%bottom_mode == 7 .or. parameters%bottom_mode == -2 .or. parameters%bottom_mode == 5) .and. &
           parameters%swkimpl == 0 .and. parameters%swsophy == 0 .and. .not. parameters%macropore_active .and. &
           .not. parameters%hysteresis_active .and. .not. parameters%tabulated_hydraulics_active .and. &
           .not. parameters%elasticity_active .and. .not. parameters%frost_active
      if (parameters%snow_active) then
        ok = ok .and. allocated(parameters%snow) .and. self%snow_event_prepared .and. &
             .not. self%fixed_weir_surface_water_active
      else
        ok = ok .and. .not. allocated(parameters%snow) .and. .not. self%snow_event_prepared
      end if
    class default
      ok = .false.
    end select
    fmr_serialized_execution_admitted = ok
  end function fmr_serialized_execution_admitted

  subroutine fmr_serialized_configure_parameters(self, parameters)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(kernel_parameters_t), intent(in) :: parameters
    integer :: n
    select type (parameters)
    type is (fmr_b110_physical_parameters_t)
      n = parameters%active_nodes
      if (associated(self%soil_parameters)) deallocate(self%soil_parameters)
      if (associated(self%hydraulic_parameters)) deallocate(self%hydraulic_parameters)
      if (associated(self%constitutive)) deallocate(self%constitutive)
      if (associated(self%source_sink)) deallocate(self%source_sink)
      if (associated(self%root_sink)) deallocate(self%root_sink)
      allocate(self%soil_parameters, self%hydraulic_parameters, self%constitutive, self%source_sink, self%root_sink)
      self%soil_parameters%parameter_set_id = parameters%parameter_set_id
      self%soil_parameters%active_nodes = n
      allocate(self%soil_parameters%z(n), self%soil_parameters%dz(n), self%soil_parameters%node_distance(n))
      self%soil_parameters%z = parameters%z
      self%soil_parameters%dz = parameters%dz
      self%soil_parameters%node_distance = parameters%node_distance
      call initialize_b110_default_mvg_parameters(self%hydraulic_parameters, parameters%cofgen)
      self%bottom_mode = parameters%bottom_mode
      self%swkimpl = parameters%swkimpl
      self%swkmean = parameters%swkmean
      self%max_iterations = parameters%max_iterations
      self%max_backtracking = parameters%max_backtracking
      self%min_step_duration = parameters%min_step_duration
      self%compartment_balance_tolerance = parameters%compartment_balance_tolerance
      self%total_balance_tolerance = parameters%total_balance_tolerance
      self%head_abs_tolerance = parameters%head_abs_tolerance
      self%head_rel_tolerance = parameters%head_rel_tolerance
      self%ponding_tolerance = parameters%ponding_tolerance
      self%root_extraction_active = parameters%root_extraction_active
      self%snow_active = parameters%snow_active
    class default
      error stop 'F-MR06 serialized backend: unexpected parameter type'
    end select
  end subroutine fmr_serialized_configure_parameters

  subroutine fmr_serialized_prepare_interval(self, forcing, interval, config)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config
    integer :: n
    self%forcing_admitted = .false.
    self%last_observation = fmr_serialized_physical_observation_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%fixed_weir_surface_water_active = self%fixed_weir_surface_water_active
    self%temporal_indicator_budget_supplied = config%model_temporal_indicator_budget_available
    self%temporal_indicator_budget_valid = .false.
    if (self%temporal_indicator_budget_supplied) then
      self%temporal_indicator_budget = config%model_temporal_indicator_budget
      if (ieee_is_finite(self%temporal_indicator_budget)) then
        self%temporal_indicator_budget_valid = self%temporal_indicator_budget > 0.0_real64
      end if
    else
      self%temporal_indicator_budget = 0.0_real64
    end if
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    if (.not. self%temporal_indicator_history_enabled) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-service-disabled'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-not-evaluated'
    end if
    if (interval%t1 <= interval%t0 .or. config%max_committed_substeps <= 0) return
    if (.not. associated(self%soil_parameters)) return
    n = self%soil_parameters%active_nodes
    select type (forcing)
    type is (fmr_b110_physical_forcing_t)
      if (.not. allocated(forcing%drainage_flux_by_level) .or. .not. allocated(forcing%subsurface_irrigation_source) .or. &
          .not. allocated(forcing%root_extraction_sink)) return
      if (size(forcing%drainage_flux_by_level,1) <= 0 .or. size(forcing%drainage_flux_by_level,2) /= n .or. &
          size(forcing%subsurface_irrigation_source) /= n .or. size(forcing%root_extraction_sink) /= n) return
      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return
      if (self%root_extraction_active) then
        if (any(forcing%root_extraction_sink < 0.0_real64)) return
      else
        if (any(abs(forcing%root_extraction_sink) > 0.0_real64)) return
      end if
      if (self%snow_active) then
        if (.not. self%snow_event_prepared .or. .not. allocated(forcing%snow)) return
        if (.not. same_real_bits(interval%t0, self%snow_outer_t0) .or. .not. same_real_bits(interval%t1, self%snow_outer_t1)) return
      else
        if (allocated(forcing%snow)) return
      end if
      if (associated(self%qdra)) deallocate(self%qdra)
      if (associated(self%qssdi)) deallocate(self%qssdi)
      if (associated(self%qrot)) deallocate(self%qrot)
      allocate(self%qdra(size(forcing%drainage_flux_by_level,1),n), self%qssdi(n), self%qrot(n))
      self%qdra = forcing%drainage_flux_by_level
      self%qssdi = forcing%subsurface_irrigation_source
      self%qrot = forcing%root_extraction_sink
      self%base_top_flux = forcing%top_flux
      self%top_flux = forcing%top_flux
      if (self%snow_active) self%top_flux = self%base_top_flux - self%snow_melt_rate
      self%top_head = forcing%top_head
      self%bottom_flux = forcing%bottom_flux
      self%bottom_head = forcing%bottom_head
      self%forcing_admitted = .true.
    class default
      return
    end select
  end subroutine fmr_serialized_prepare_interval

  subroutine populate_snow_observation(self)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    self%last_observation%snow_active = self%snow_active
    self%last_observation%snow_event_prepared = self%snow_event_prepared
    self%last_observation%snow_melt_rate = self%snow_melt_rate
    if (self%snow_active) then
      self%last_observation%snow_status = self%snow_diagnostics%status
      self%last_observation%snow_fluxes = self%snow_fluxes
      self%last_observation%snow_mass = self%snow_diagnostics%mass
    end if
  end subroutine populate_snow_observation

  subroutine populate_fixed_weir_surface_water_observation(self)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    self%last_observation%fixed_weir_surface_water_active = self%fixed_weir_surface_water_active
    if (.not. self%fixed_weir_surface_water_active) return
    self%last_observation%fixed_weir_surface_water_status = self%fixed_weir_surface_water_result%status
    self%last_observation%fixed_weir_surface_water_storage = self%fixed_weir_surface_water_result%candidate_state%storage
    self%last_observation%fixed_weir_surface_water_level = self%fixed_weir_surface_water_result%water_level
    self%last_observation%fixed_weir_surface_water_supply_rate = self%fixed_weir_surface_water_result%supply_rate
    self%last_observation%fixed_weir_surface_water_discharge_rate = self%fixed_weir_surface_water_result%discharge_rate
    self%last_observation%fixed_weir_surface_water_mass_residual = self%fixed_weir_surface_water_result%mass_residual
    self%last_observation%fixed_weir_surface_water_rating_residual = &
         self%fixed_weir_surface_water_result%rating_storage_residual
    self%last_observation%fixed_weir_surface_water_iterations = self%fixed_weir_surface_water_result%bisection_iterations
    self%last_observation%fixed_weir_surface_water_route = self%fixed_weir_surface_water_result%route
  end subroutine populate_fixed_weir_surface_water_observation

  subroutine evaluate_temporal_history_service(self, state, request, solve_result, outcome, ok)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(trial_outcome_t), intent(inout) :: outcome
    logical, intent(out) :: ok
    type(soil_water_temporal_indicator_request_t) :: indicator_request
    type(soil_water_temporal_indicator_result_t) :: indicator_result
    real(real64), allocatable :: previous_derivative(:)
    real(real64) :: normalized_indicator
    logical :: previous_available, replaced
    integer :: n
    ok = .false.
    n = request%parameters%active_nodes
    previous_available = .false.
    select type (physical => state)
    type is (fmr_b110_temporal_indicator_state_t)
      call physical%temporal_history%snapshot(previous_derivative, previous_available)
      if (previous_available) previous_available = size(previous_derivative) == n .and. all(ieee_is_finite(previous_derivative))
    class default
      return
    end select
    indicator_request%previous_right_derivative_available = previous_available
    if (previous_available) then
      allocate(indicator_request%previous_right_derivative(n))
      indicator_request%previous_right_derivative = previous_derivative
    end if
    call self%solver%evaluate_temporal_indicator(request, solve_result, indicator_request, self%workspace, indicator_result)
    self%last_observation%temporal_indicator_enabled = .true.
    self%last_observation%temporal_previous_derivative_available = previous_available
    self%last_observation%temporal_indicator_status = indicator_result%status
    self%last_observation%temporal_indicator_available = indicator_result%available
    self%last_observation%temporal_indicator_route = indicator_result%route
    self%last_observation%temporal_head_inf_bound = indicator_result%head_inf_bound
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    self%last_observation%temporal_certificate_available = .false.
    self%last_observation%temporal_normalized_indicator = 0.0_real64
    self%last_observation%temporal_additional_tridiagonal_solves = indicator_result%additional_tridiagonal_solves
    self%last_observation%temporal_additional_full_nonlinear_solves = indicator_result%additional_full_nonlinear_solves
    outcome%linear_solves = outcome%linear_solves + indicator_result%additional_tridiagonal_solves
    if (indicator_result%additional_full_nonlinear_solves /= 0) return
    if (.not. allocated(indicator_result%current_right_derivative)) return
    if (size(indicator_result%current_right_derivative) /= n) return
    if (any(.not. ieee_is_finite(indicator_result%current_right_derivative))) return
    select type (physical => state)
    type is (fmr_b110_temporal_indicator_state_t)
      call physical%temporal_history%replace(indicator_result%current_right_derivative, replaced)
      if (.not. replaced) return
    class default
      return
    end select
    self%last_observation%temporal_current_derivative_available = .true.

    if (.not. previous_available) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-unavailable'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else if (.not. indicator_result%available) then
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-unavailable'
    else if (.not. ieee_is_finite(indicator_result%head_inf_bound) .or. indicator_result%head_inf_bound < 0.0_real64) then
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-invalid'
    else
      normalized_indicator = indicator_result%head_inf_bound / self%temporal_indicator_budget
      if (ieee_is_finite(normalized_indicator) .and. normalized_indicator >= 0.0_real64) then
        outcome%temporal_certificate_available = .true.
        outcome%temporal_indicator = normalized_indicator
        self%last_observation%temporal_certificate_available = .true.
        self%last_observation%temporal_normalized_indicator = normalized_indicator
        self%last_observation%temporal_certificate_unavailable_reason = 'available'
      else
        self%last_observation%temporal_certificate_unavailable_reason = 'normalized-indicator-invalid'
      end if
    end if
    ok = .true.
  end subroutine evaluate_temporal_history_service

  subroutine fmr_serialized_advance(self, state, t0, t1, outcome)
    class(fmr_serialized_reference_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: solve_result
    real(real64), allocatable, target :: source_sink_root_zero(:)
    real(real64) :: step_duration
    logical :: context_ok, snow_event_applied_this_call, temporal_history_ok
    outcome = trial_outcome_t()
    self%last_observation = fmr_serialized_physical_observation_t()
    self%fixed_weir_surface_water_result = fixed_weir_surface_water_result_t()
    self%last_observation%temporal_indicator_enabled = self%temporal_indicator_history_enabled
    self%last_observation%temporal_head_budget_supplied = self%temporal_indicator_budget_supplied
    self%last_observation%temporal_head_budget_valid = self%temporal_indicator_budget_valid
    self%last_observation%temporal_head_budget = self%temporal_indicator_budget
    if (.not. self%temporal_indicator_history_enabled) then
      self%last_observation%temporal_certificate_unavailable_reason = 'history-service-disabled'
    else if (.not. self%temporal_indicator_budget_supplied) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-not-supplied'
    else if (.not. self%temporal_indicator_budget_valid) then
      self%last_observation%temporal_certificate_unavailable_reason = 'budget-invalid'
    else
      self%last_observation%temporal_certificate_unavailable_reason = 'indicator-not-evaluated'
    end if
    call populate_snow_observation(self)
    call populate_fixed_weir_surface_water_observation(self)
    snow_event_applied_this_call = .false.
    if (.not. self%forcing_admitted .or. .not. associated(self%soil_parameters) .or. &
        .not. associated(self%hydraulic_parameters) .or. .not. associated(self%constitutive) .or. &
        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return
    if (self%root_extraction_active .and. .not. associated(self%root_sink)) return
    if (.not. state_matches_numerical_continuation_layout(state, self%temporal_indicator_history_enabled, &
                                                           self%fixed_weir_surface_water_active)) return
    step_duration = t1 - t0
    if (step_duration <= 0.0_real64) return
    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)
    if (self%root_extraction_active) then
      allocate(source_sink_root_zero(size(self%qrot)))
      source_sink_root_zero = 0.0_real64
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, source_sink_root_zero)
      call bind_b110_root_sink_provider(self%root_sink, self%qrot)
    else
      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)
    end if
    request%parameters => self%soil_parameters
    request%evaluation%constitutive => self%constitutive
    request%evaluation%source_sink => self%source_sink
    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink
    request%evaluation%top_boundary => self%top_boundary
    request%step_duration = step_duration
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = self%bottom_mode
    request%boundary%top_flux = self%top_flux
    request%boundary%top_head = self%top_head
    request%boundary%bottom_flux = self%bottom_flux
    request%boundary%bottom_head = self%bottom_head
    request%numerical%max_iterations = self%max_iterations
    request%numerical%max_backtracking = self%max_backtracking
    request%numerical%conductivity_implicit_mode = self%swkimpl
    request%numerical%conductivity_mean_method = self%swkmean
    request%numerical%min_step_duration = self%min_step_duration
    request%numerical%compartment_balance_tolerance = self%compartment_balance_tolerance
    request%numerical%total_balance_tolerance = self%total_balance_tolerance
    request%numerical%head_abs_tolerance = self%head_abs_tolerance
    request%numerical%head_rel_tolerance = self%head_rel_tolerance
    request%numerical%ponding_tolerance = self%ponding_tolerance
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      if (physical%active_nodes /= self%soil_parameters%active_nodes .or. .not. allocated(physical%pressure_head) .or. &
          .not. allocated(physical%water_content)) return
      if (self%snow_active) then
        if (.not. allocated(physical%snow) .or. .not. self%snow_event_prepared) return
        if (.not. physical%snow%event_applied .or. .not. same_real_bits(physical%snow%event_t0, self%snow_outer_t0)) then
          physical%snow%process = self%snow_candidate
          physical%snow%event_applied = .true.
          physical%snow%event_t0 = self%snow_outer_t0
          snow_event_applied_this_call = .true.
        end if
      else
        if (allocated(physical%snow)) return
      end if
      request%base_state%active_nodes = physical%active_nodes
      allocate(request%base_state%pressure_head(physical%active_nodes), request%base_state%water_content(physical%active_nodes))
      request%base_state%pressure_head = physical%pressure_head
      request%base_state%water_content = physical%water_content
      request%base_state%ponding_depth = physical%ponding_depth
      request%base_state%groundwater_level = physical%groundwater_level
    class default
      return
    end select
    call bind_b110_serialized_legacy_context(request, context_ok)
    if (.not. context_ok) return
    call self%solver%solve(request, self%workspace, solve_result)
    self%last_observation%solver_executed = .true.
    self%last_observation%solver_status = solve_result%status
    self%last_observation%top_flux = solve_result%top_flux
    self%last_observation%bottom_flux = solve_result%bottom_flux
    self%last_observation%solver_diagnostics = solve_result%diagnostics
    self%last_observation%solver_equation_residual_available = .false.
    call populate_snow_observation(self)
    outcome%nonlinear_iterations = solve_result%diagnostics%nonlinear_iterations
    outcome%internal_retries = solve_result%diagnostics%internal_retries
    outcome%headcalc_calls = 1
    outcome%jacobian_builds = solve_result%diagnostics%jacobian_builds
    outcome%linear_solves = solve_result%diagnostics%linear_solves
    outcome%backtracking_attempts = solve_result%diagnostics%backtracking_attempts
    outcome%alternative_solver_calls = solve_result%diagnostics%alternative_solver_calls
    if (solve_result%status /= SW_SOLVE_CONVERGED) return
    if (self%temporal_indicator_history_enabled) then
      call evaluate_temporal_history_service(self, state, request, solve_result, outcome, temporal_history_ok)
      if (.not. temporal_history_ok) return
    end if
    if (self%fixed_weir_surface_water_active) then
      select type (physical => state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        call evaluate_restricted_fixed_weir_surface_water(self%fixed_weir_surface_water_parameters, &
             self%fixed_weir_surface_water_numerical, physical%surface_water, &
             self%fixed_weir_surface_water_forcing, step_duration, self%fixed_weir_surface_water_result)
        call populate_fixed_weir_surface_water_observation(self)
        if (self%fixed_weir_surface_water_result%status /= FIXED_WEIR_AVAILABLE) return
      class default
        return
      end select
    end if
    select type (physical => state)
    class is (fmr_b110_physical_state_t)
      physical%active_nodes = solve_result%candidate_state%active_nodes
      physical%pressure_head = solve_result%candidate_state%pressure_head
      physical%water_content = solve_result%candidate_state%water_content
      physical%ponding_depth = solve_result%candidate_state%ponding_depth
      physical%groundwater_level = solve_result%candidate_state%groundwater_level
    class default
      return
    end select
    if (self%fixed_weir_surface_water_active) then
      select type (physical => state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        physical%surface_water = self%fixed_weir_surface_water_result%candidate_state
      class default
        return
      end select
    end if
    call account_external_fluxes(self, step_duration, solve_result%top_flux, solve_result%bottom_flux, &
         snow_event_applied_this_call, outcome%mass_in, outcome%mass_out)
    outcome%mass_accounting_complete = .true.
    outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
    outcome%solver_ok = .true.
  end subroutine fmr_serialized_advance

  subroutine account_external_fluxes(self, step_duration, solver_top_flux, bottom_flux, snow_event_applied, &
                                     total_in, total_out)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    real(real64), intent(in) :: step_duration, solver_top_flux, bottom_flux
    logical, intent(in) :: snow_event_applied
    real(real64), intent(out) :: total_in, total_out
    integer :: i, level
    real(real64) :: value, external_top_flux
    external_top_flux = solver_top_flux
    if (self%snow_active) external_top_flux = self%base_top_flux
    total_in = max(0.0_real64, -external_top_flux) * step_duration + max(0.0_real64, bottom_flux) * step_duration
    total_out = max(0.0_real64, external_top_flux) * step_duration + max(0.0_real64, -bottom_flux) * step_duration
    do i = 1, size(self%qssdi)
      value = self%qssdi(i) * step_duration
      if (value >= 0.0_real64) then
        total_in = total_in + value
      else
        total_out = total_out - value
      end if
    end do
    if (self%fixed_weir_surface_water_active) then
      total_in = total_in + self%fixed_weir_surface_water_result%supply_rate * step_duration
      total_out = total_out + self%fixed_weir_surface_water_result%discharge_rate * step_duration
    else
      do level = 1, size(self%qdra,1)
        do i = 1, size(self%qdra,2)
          value = self%qdra(level,i) * step_duration
          if (value >= 0.0_real64) then
            total_out = total_out + value
          else
            total_in = total_in - value
          end if
        end do
      end do
    end if
    do i = 1, size(self%qrot)
      value = self%qrot(i) * step_duration
      if (value >= 0.0_real64) then
        total_out = total_out + value
      else
        total_in = total_in - value
      end if
    end do
    if (self%snow_active .and. snow_event_applied) then
      total_in = total_in + self%snow_diagnostics%mass%snowfall_external_in + self%snow_diagnostics%mass%rain_external_in
      total_out = total_out + self%snow_diagnostics%mass%sublimation_external_out
    end if
  end subroutine account_external_fluxes

  real(real64) function fmr_serialized_storage(self, state) result(value)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    if (.not. associated(self%soil_parameters)) error stop 'F-MR06 storage requested before parameter binding'
    select type (physical => state)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      if (.not. self%fixed_weir_surface_water_active) error stop 'F-PM08D7 inactive model with fixed-weir state'
      if (.not. allocated(physical%water_content)) error stop 'F-MR06 physical storage state incomplete'
      if (allocated(physical%snow)) error stop 'F-PM08D7 fixed-weir state may not carry snow'
      value = sum(self%soil_parameters%dz * physical%water_content) + physical%ponding_depth + &
           physical%surface_water%storage
    class is (fmr_b110_physical_state_t)
      if (self%fixed_weir_surface_water_active) error stop 'F-PM08D7 active model missing fixed-weir state'
      if (.not. allocated(physical%water_content)) error stop 'F-MR06 physical storage state incomplete'
      value = sum(self%soil_parameters%dz * physical%water_content) + physical%ponding_depth
      if (self%snow_active) then
        if (.not. allocated(physical%snow)) error stop 'F-MR06 active snow storage state incomplete'
        value = value + physical%snow%process%snow_water_storage
      end if
    class default
      error stop 'F-MR06 physical storage type mismatch'
    end select
  end function fmr_serialized_storage

  subroutine fmr_serialized_storage_accounting_status(self, state, complete, missing_mask)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask
    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. associated(self%soil_parameters)) return
    select type (physical => state)
    type is (fmr_b110_fixed_weir_surface_water_state_t)
      if (.not. self%fixed_weir_surface_water_active) return
      complete = physical%active_nodes == self%soil_parameters%active_nodes .and. allocated(physical%pressure_head) .and. &
           allocated(physical%water_content) .and. .not. allocated(physical%snow) .and. &
           ieee_is_finite(physical%surface_water%storage)
      if (complete) complete = size(physical%pressure_head) == physical%active_nodes .and. &
           size(physical%water_content) == physical%active_nodes
    class is (fmr_b110_physical_state_t)
      if (self%fixed_weir_surface_water_active) return
      complete = physical%active_nodes == self%soil_parameters%active_nodes .and. allocated(physical%pressure_head) .and. &
           allocated(physical%water_content)
      if (complete) complete = size(physical%pressure_head) == physical%active_nodes .and. &
           size(physical%water_content) == physical%active_nodes
      if (complete .and. self%snow_active) complete = allocated(physical%snow)
      if (complete .and. .not. self%snow_active) complete = .not. allocated(physical%snow)
    class default
      complete = .false.
    end select
    if (complete) missing_mask = TX_MASS_MISSING_NONE
  end subroutine fmr_serialized_storage_accounting_status

  real(real64) function fmr_serialized_temporal_identity(self, full_state, half_state) result(value)
    class(fmr_serialized_reference_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    logical :: same
    if (self%bottom_mode /= 7 .and. self%bottom_mode /= -2 .and. self%bottom_mode /= 5) then
      value = huge(0.0_real64)
      return
    end if

    if (self%fixed_weir_surface_water_active) then
      value = huge(0.0_real64)
      select type (full => full_state)
      type is (fmr_b110_fixed_weir_surface_water_state_t)
        select type (half => half_state)
        type is (fmr_b110_fixed_weir_surface_water_state_t)
          same = base_physical_states_identical(full, half)
          if (same .and. ieee_is_finite(full%surface_water%storage) .and. &
              ieee_is_finite(half%surface_water%storage)) then
            value = abs(full%surface_water%storage - half%surface_water%storage)
          end if
        class default
          return
        end select
      class default
        return
      end select
      return
    end if

    same = .false.
    select type (full => full_state)
    class is (fmr_b110_physical_state_t)
      select type (half => half_state)
      class is (fmr_b110_physical_state_t)
        same = base_physical_states_identical(full, half)
      end select
    end select
    if (same) then
      value = 0.0_real64
    else
      value = huge(0.0_real64)
    end if
  end function fmr_serialized_temporal_identity

  logical function base_physical_states_identical(full, half) result(same)
    class(fmr_b110_physical_state_t), intent(in) :: full, half
    same = .false.
    if (full%active_nodes /= half%active_nodes) return
    if (.not. allocated(full%pressure_head) .or. .not. allocated(half%pressure_head)) return
    if (.not. allocated(full%water_content) .or. .not. allocated(half%water_content)) return
    if (size(full%pressure_head) /= size(half%pressure_head) .or. &
        size(full%water_content) /= size(half%water_content)) return
    same = all(same_real_bits(full%pressure_head, half%pressure_head)) .and. &
         all(same_real_bits(full%water_content, half%water_content)) .and. &
         same_real_bits(full%ponding_depth, half%ponding_depth) .and. &
         same_real_bits(full%groundwater_level, half%groundwater_level)
    if (.not. same) return
    same = allocated(full%snow) .eqv. allocated(half%snow)
    if (same .and. allocated(full%snow)) then
      same = same_real_bits(full%snow%process%snow_water_storage, half%snow%process%snow_water_storage) .and. &
           same_real_bits(full%snow%process%liquid_water_storage, half%snow%process%liquid_water_storage) .and. &
           (full%snow%event_applied .eqv. half%snow%event_applied) .and. &
           same_real_bits(full%snow%event_t0, half%snow%event_t0)
    end if
  end function base_physical_states_identical

  pure elemental logical function same_real_bits(a, b) result(same)
    real(real64), intent(in) :: a, b
    same = transfer(a, 0_int64) == transfer(b, 0_int64)
  end function same_real_bits

end module mod_fmr_serialized_reference_backend
