module mod_soil_water_solver_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  implicit none
  private

  integer, parameter, public :: SW_SOLVE_NOT_RUN = 0
  integer, parameter, public :: SW_SOLVE_CONVERGED = 1
  integer, parameter, public :: SW_SOLVE_RETRY_ADVISED = 2
  integer, parameter, public :: SW_SOLVE_FAILED = 3

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

  type, abstract, public :: top_boundary_provider_t
   contains
     procedure(top_boundary_evaluate_ifc), deferred :: evaluate
  end type top_boundary_provider_t

  type, abstract, public :: macropore_exchange_provider_t
   contains
     procedure(macropore_evaluate_ifc), deferred :: evaluate
  end type macropore_exchange_provider_t

  type, public :: hydraulic_evaluation_context_t
     class(constitutive_hydraulics_provider_t), pointer :: constitutive => null()
     class(source_sink_provider_t), pointer :: source_sink => null()
     class(root_sink_provider_t), pointer :: root_sink => null()
     class(top_boundary_provider_t), pointer :: top_boundary => null()
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
  end type soil_water_solve_request_t

  type, public :: soil_water_solver_diagnostics_t
     integer :: nonlinear_iterations = 0
     integer :: jacobian_builds = 0
     integer :: linear_solves = 0
     integer :: backtracking_attempts = 0
     integer :: alternative_solver_calls = 0
     integer :: internal_retries = 0
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

  type, abstract, public :: soil_water_solver_workspace_base_t
  end type soil_water_solver_workspace_base_t

  type, abstract, public :: soil_water_solver_t
   contains
     procedure(soil_water_solve_ifc), deferred :: solve
  end type soil_water_solver_t

  public :: validate_soil_water_request

  abstract interface
     subroutine constitutive_evaluate_ifc(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
       import :: constitutive_hydraulics_provider_t, real64
       class(constitutive_hydraulics_provider_t), intent(in) :: self
       real(real64), intent(in) :: pressure_head(:)
       real(real64), intent(out) :: water_content(:)
       real(real64), intent(out) :: conductivity(:)
       real(real64), intent(out) :: capacity(:)
       real(real64), intent(out) :: dconductivity_dhead(:)
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
       real(real64), intent(out) :: surface_head, runoff_flux

       ! Interface only; implementation supplied by the selected provider.
     end subroutine top_boundary_evaluate_ifc

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
    ! Existing common routes consume NN node distances. Boundary modes that
    ! physically require the lower face may supply NN+1; their solver-specific
    ! validator owns that stricter requirement.
    if (size(request%parameters%node_distance) /= n .and. &
        size(request%parameters%node_distance) /= n+1) return
    if (request%base_state%active_nodes /= n) return
    if (.not. allocated(request%base_state%pressure_head)) return
    if (.not. allocated(request%base_state%water_content)) return
    if (size(request%base_state%pressure_head) /= n) return
    if (size(request%base_state%water_content) /= n) return
    if (request%step_duration <= 0.0_real64) return
    if (.not. associated(request%evaluation%constitutive)) return
    ok = .true.
  end subroutine validate_soil_water_request

end module mod_soil_water_solver_contract
