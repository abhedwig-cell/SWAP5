module mod_soil_water_solver_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: SW_SOLVE_NOT_RUN = 0
  integer, parameter, public :: SW_SOLVE_CONVERGED = 1
  integer, parameter, public :: SW_SOLVE_RETRY_ADVISED = 2
  integer, parameter, public :: SW_SOLVE_FAILED = 3

  integer, parameter, public :: SW_TEMPORAL_INDICATOR_NOT_RUN = 0
  integer, parameter, public :: SW_TEMPORAL_INDICATOR_AVAILABLE = 1
  integer, parameter, public :: SW_TEMPORAL_INDICATOR_UNAVAILABLE = 2
  integer, parameter, public :: SW_TEMPORAL_INDICATOR_FAILED = 3

  integer, parameter, public :: SW_TOP_BOUNDARY_NOT_RUN = 0
  integer, parameter, public :: SW_TOP_BOUNDARY_AVAILABLE = 1
  integer, parameter, public :: SW_TOP_BOUNDARY_UNAVAILABLE = 2
  integer, parameter, public :: SW_TOP_BOUNDARY_REGIME_NONE = 0
  integer, parameter, public :: SW_TOP_BOUNDARY_REGIME_FLUX = 1
  integer, parameter, public :: SW_TOP_BOUNDARY_REGIME_HEAD = 2

  type, public :: soil_water_parameter_set_t
     integer(int64) :: parameter_set_id = 0_int64
     integer :: active_nodes = 0
     real(real64), allocatable :: z(:)
     real(real64), allocatable :: dz(:)
     real(real64), allocatable :: node_distance(:)
  end type soil_water_parameter_set_t

  type, public :: soil_water_physical_state_t
     integer :: active_nodes = 0
     real(real64), allocatable :: pressure_head(:)
     real(real64), allocatable :: water_content(:)
     real(real64) :: ponding_depth = 0.0_real64
     real(real64) :: groundwater_level = 0.0_real64
  end type soil_water_physical_state_t

  type, public :: soil_water_boundary_conditions_t
     integer :: top_mode = 0
     integer :: bottom_mode = 0
     real(real64) :: top_flux = 0.0_real64
     real(real64) :: top_head = 0.0_real64
     real(real64) :: bottom_flux = 0.0_real64
     real(real64) :: bottom_head = 0.0_real64
  end type soil_water_boundary_conditions_t

  type, public :: soil_water_physical_config_t
     logical :: macropore_active = .false.
  end type soil_water_physical_config_t

  type, public :: soil_water_numerical_config_t
     integer :: max_iterations = 0
     integer :: max_backtracking = 0
     integer :: conductivity_implicit_mode = 0
     integer :: conductivity_mean_method = 0
     real(real64) :: min_step_duration = 0.0_real64
     real(real64) :: compartment_balance_tolerance = 0.0_real64
     real(real64) :: total_balance_tolerance = 0.0_real64
     real(real64) :: head_abs_tolerance = 0.0_real64
     real(real64) :: head_rel_tolerance = 0.0_real64
     real(real64) :: ponding_tolerance = 0.0_real64
  end type soil_water_numerical_config_t

  type, public :: soil_water_top_boundary_result_t
     integer :: status = SW_TOP_BOUNDARY_NOT_RUN
     integer :: regime = SW_TOP_BOUNDARY_REGIME_NONE
     real(real64) :: actual_top_flux = 0.0_real64
     real(real64) :: surface_head = 0.0_real64
     real(real64) :: surface_face_conductivity = 0.0_real64
     real(real64) :: candidate_ponding_depth = 0.0_real64
     real(real64) :: bare_soil_evaporation = 0.0_real64
     real(real64) :: ponded_water_evaporation = 0.0_real64
     real(real64) :: runoff_depth = 0.0_real64
     real(real64) :: net_potential_surface_flux = 0.0_real64
     logical :: carries_surface_mass_terms = .false.
     logical :: runoff_potential = .false.
     logical :: runoff_resolved = .false.
     character(len=48) :: route = 'not-run'
  end type soil_water_top_boundary_result_t

  type, abstract, public :: constitutive_hydraulics_provider_t
   contains
     procedure(constitutive_evaluate_ifc), deferred :: evaluate
  end type constitutive_hydraulics_provider_t

  type, abstract, public :: source_sink_provider_t
   contains
     procedure(source_sink_evaluate_ifc), deferred :: evaluate
  end type source_sink_provider_t

  type, abstract, public :: root_sink_provider_t
   contains
     procedure(root_sink_evaluate_ifc), deferred :: evaluate
  end type root_sink_provider_t

  ! Frozen F-SI28 ABI: simple providers remain flux-only and keep the exact
  ! legacy explicit-provider signature.
  type, abstract, public :: top_boundary_provider_t
   contains
     procedure(top_boundary_evaluate_ifc), deferred :: evaluate
  end type top_boundary_provider_t

  ! F-SI30 opt-in sibling. Rich dynamic surface physics is isolated from the
  ! already-qualified fixed-flux provider ABI and pays no cost when unused.
  type, abstract, public :: dynamic_top_boundary_provider_t
   contains
     procedure(dynamic_top_boundary_evaluate_ifc), deferred :: evaluate
  end type dynamic_top_boundary_provider_t

  type, abstract, public :: macropore_exchange_provider_t
   contains
     procedure(macropore_evaluate_ifc), deferred :: evaluate
  end type macropore_exchange_provider_t

  type, public :: hydraulic_evaluation_context_t
     class(constitutive_hydraulics_provider_t), pointer :: constitutive => null()
     class(source_sink_provider_t), pointer :: source_sink => null()
     class(root_sink_provider_t), pointer :: root_sink => null()
     class(top_boundary_provider_t), pointer :: top_boundary => null()
     class(dynamic_top_boundary_provider_t), pointer :: dynamic_top_boundary => null()
     class(macropore_exchange_provider_t), pointer :: macropore => null()
  end type hydraulic_evaluation_context_t

  type, public :: soil_water_solve_request_t
     type(soil_water_parameter_set_t), pointer :: parameters => null()
     type(soil_water_physical_state_t) :: base_state
     type(soil_water_boundary_conditions_t) :: boundary
     type(soil_water_physical_config_t) :: physical
     type(soil_water_numerical_config_t) :: numerical
     type(hydraulic_evaluation_context_t) :: evaluation
     real(real64) :: step_duration = 0.0_real64
     logical :: request_interface_sensitivity = .false.
  end type soil_water_solve_request_t

  type, public :: soil_water_solver_diagnostics_t
     integer :: nonlinear_iterations = 0
     integer :: jacobian_builds = 0
     integer :: linear_solves = 0
     integer :: backtracking_attempts = 0
     integer :: alternative_solver_calls = 0
     integer :: internal_retries = 0
     integer :: interface_sensitivity_backsolves = 0
     character(len=32) :: route = 'not-run'
  end type soil_water_solver_diagnostics_t

  type, public :: soil_water_interface_sensitivity_t
     logical :: available = .false.
     real(real64) :: dh_bottom_dq_bottom = 0.0_real64
     character(len=24) :: method = 'not-available'
  end type soil_water_interface_sensitivity_t

  type, public :: soil_water_solve_result_t
     integer :: status = SW_SOLVE_NOT_RUN
     logical :: retry_advised = .false.
     type(soil_water_physical_state_t) :: candidate_state
     real(real64) :: top_flux = 0.0_real64
     real(real64) :: bottom_flux = 0.0_real64
     real(real64) :: unrounded_mass_balance_residual = 0.0_real64
     type(soil_water_solver_diagnostics_t) :: diagnostics
     type(soil_water_interface_sensitivity_t) :: interface_sensitivity
  end type soil_water_solve_result_t

  type, public :: soil_water_temporal_indicator_request_t
     logical :: previous_right_derivative_available = .false.
     real(real64), allocatable :: previous_right_derivative(:)
  end type soil_water_temporal_indicator_request_t

  type, public :: soil_water_temporal_indicator_result_t
     integer :: status = SW_TEMPORAL_INDICATOR_NOT_RUN
     logical :: available = .false.
     character(len=40) :: route = 'not-run'
     integer :: additional_full_nonlinear_solves = 0
     integer :: additional_tridiagonal_solves = 0
     real(real64) :: raw_m_norm = 0.0_real64
     real(real64) :: defect_m_norm = 0.0_real64
     real(real64) :: bounded_m_norm = 0.0_real64
     real(real64) :: head_inf_bound = 0.0_real64
     real(real64) :: min_mass_weight = 0.0_real64
     real(real64), allocatable :: current_right_derivative(:)
  end type soil_water_temporal_indicator_result_t

  type, abstract, public :: soil_water_solver_workspace_base_t
  end type soil_water_solver_workspace_base_t

  type, abstract, public :: soil_water_solver_t
   contains
     procedure(soil_water_solve_ifc), deferred :: solve
     procedure :: evaluate_temporal_indicator => soil_water_temporal_indicator_unavailable
  end type soil_water_solver_t

  public :: validate_soil_water_request

  abstract interface
     subroutine constitutive_evaluate_ifc(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
       import :: constitutive_hydraulics_provider_t, real64
       class(constitutive_hydraulics_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
     end subroutine constitutive_evaluate_ifc

     subroutine source_sink_evaluate_ifc(self, pressure_head, water_content, source, sink)
       import :: source_sink_provider_t, real64
       class(source_sink_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(in) :: water_content(:)
       real(real64), intent(out) :: source(:)
       real(real64), intent(out) :: sink(:)
     end subroutine source_sink_evaluate_ifc

     subroutine root_sink_evaluate_ifc(self, pressure_head, water_content, root_sink)
       import :: root_sink_provider_t, real64
       class(root_sink_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(in) :: water_content(:)
       real(real64), intent(out) :: root_sink(:)
     end subroutine root_sink_evaluate_ifc

     subroutine top_boundary_evaluate_ifc(self, pressure_head_top, water_content_top, requested, &
                                           actual_top_flux, surface_head, runoff_flux)
       import :: top_boundary_provider_t, soil_water_boundary_conditions_t, real64
       class(top_boundary_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head_top
       real(real64), intent(in) :: water_content_top
       type(soil_water_boundary_conditions_t), intent(in) :: requested
       real(real64), intent(out) :: actual_top_flux
       real(real64), intent(out) :: surface_head
       real(real64), intent(out) :: runoff_flux
     end subroutine top_boundary_evaluate_ifc

     subroutine dynamic_top_boundary_evaluate_ifc(self, pressure_head_top, water_content_top, candidate_ponding_depth, &
                                                   requested, result)
       import :: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
            soil_water_top_boundary_result_t, real64
       class(dynamic_top_boundary_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head_top
       real(real64), intent(in) :: water_content_top
       real(real64), intent(in) :: candidate_ponding_depth
       type(soil_water_boundary_conditions_t), intent(in) :: requested
       type(soil_water_top_boundary_result_t), intent(out) :: result
     end subroutine dynamic_top_boundary_evaluate_ifc

     subroutine macropore_evaluate_ifc(self, pressure_head, exchange_flux, active)
       import :: macropore_exchange_provider_t, real64
       class(macropore_exchange_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(out) :: exchange_flux(:)
       logical, intent(out) :: active
     end subroutine macropore_evaluate_ifc

     subroutine soil_water_solve_ifc(self, request, workspace, result)
       import :: soil_water_solver_t, soil_water_solve_request_t, soil_water_solve_result_t
       import :: soil_water_solver_workspace_base_t
       class(soil_water_solver_t), intent(inout) :: self
       type(soil_water_solve_request_t), intent(in) :: request
       class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
       type(soil_water_solve_result_t), intent(out) :: result
     end subroutine soil_water_solve_ifc
  end interface

contains

  subroutine validate_soil_water_request(request, ok)
    type(soil_water_solve_request_t), intent(in) :: request
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    if (.not. associated(request%parameters)) return
    n = request%parameters%active_nodes
    if (n <= 0) return
    if (.not. allocated(request%parameters%z)) return
    if (.not. allocated(request%parameters%dz)) return
    if (.not. allocated(request%parameters%node_distance)) return
    if (size(request%parameters%z) /= n) return
    if (size(request%parameters%dz) /= n) return
    if (size(request%parameters%node_distance) /= n) return
    if (request%base_state%active_nodes /= n) return
    if (.not. allocated(request%base_state%pressure_head)) return
    if (.not. allocated(request%base_state%water_content)) return
    if (size(request%base_state%pressure_head) /= n) return
    if (size(request%base_state%water_content) /= n) return
    if (request%step_duration <= 0.0_real64) return
    if (.not. associated(request%evaluation%constitutive)) return
    ok = .true.
  end subroutine validate_soil_water_request

  subroutine soil_water_temporal_indicator_unavailable(self, request, solve_result, indicator_request, workspace, indicator_result)
    class(soil_water_solver_t), intent(inout) :: self
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: solve_result
    type(soil_water_temporal_indicator_request_t), intent(in) :: indicator_request
    class(soil_water_solver_workspace_base_t), intent(inout) :: workspace
    type(soil_water_temporal_indicator_result_t), intent(out) :: indicator_result

    indicator_result = soil_water_temporal_indicator_result_t()
    if (indicator_request%previous_right_derivative_available .and. &
        .not. allocated(indicator_request%previous_right_derivative)) then
       indicator_result%status = SW_TEMPORAL_INDICATOR_FAILED
       indicator_result%route = 'indicator-history-invalid'
       return
    end if

    ! Fail closed by default. This deliberate no-op leaves request, solve result,
    ! solver and worker workspace untouched; alternative soil-water solvers are
    ! not required to emulate a Richards-specific operator.
    indicator_result%status = SW_TEMPORAL_INDICATOR_UNAVAILABLE
    indicator_result%route = 'solver-indicator-unavailable'
  end subroutine soil_water_temporal_indicator_unavailable

end module mod_soil_water_solver_contract
