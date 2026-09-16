program test_ross12_soil_water_solver_adapter
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       soil_water_parameter_set_t, soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  implicit none

  type, extends(constitutive_hydraulics_provider_t) :: dummy_constitutive_t
  contains
    procedure :: evaluate => dummy_constitutive_evaluate
  end type dummy_constitutive_t

  type, extends(source_sink_provider_t) :: test_source_sink_t
    logical :: nonzero = .false.
  contains
    procedure :: evaluate => test_source_sink_evaluate
  end type test_source_sink_t

  character(len=512) :: asset_root
  integer :: failures

  call get_command_argument(1, asset_root)
  if (len_trim(asset_root) == 0) error stop 'usage: test_ross12 ASSET_ROOT'
  failures = 0
  call test_real_kernel_route(trim(asset_root), failures)
  call test_fail_closed_envelope(trim(asset_root), failures)
  call test_provider_preflight(failures)
  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS12_SOIL_WATER_SOLVER_ADAPTER FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS12_SOIL_WATER_SOLVER_ADAPTER PASS'

contains

  subroutine test_real_kernel_route(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(rossfast_d3r_soil_water_solver_t) :: solver
    type(rossfast_d3r_soil_water_workspace_t) :: workspace
    type(soil_water_parameter_set_t), target :: parameters
    type(dummy_constitutive_t), target :: constitutive
    type(test_source_sink_t), target :: zero_terms
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    logical :: valid, found, certificate_available
    integer :: provider_status
    real(real64) :: certificate
    type(rossfast_d3r_material_t) :: material

    call solver%initialize(root, 'B01', valid, provider_status)
    call expect_true(valid, 'adapter initializes from immutable B01 table', failures)
    call rossfast_d3r_material_from_id('B01', material, found)
    call expect_true(found, 'B01 material exists', failures)
    call build_request(parameters, constitutive, zero_terms, material, request)
    call solver%solve(request, workspace, result)
    call expect_true(result%status == SW_SOLVE_CONVERGED, 'RossFast solve converges through soil-water ABI', failures)
    call expect_true(trim(result%diagnostics%route) == 'rossfast-d3r', 'RossFast route diagnostic', failures)
    call expect_true(result%diagnostics%linear_solves >= 24 .and. &
         mod(result%diagnostics%linear_solves, 24) == 0, 'real D3R table kernel executed', failures)
    call expect_true(result%candidate_state%active_nodes == ROSSFAST_D3R_N_CELLS, 'candidate node count', failures)
    call expect_true(allocated(result%candidate_state%pressure_head) .and. &
         allocated(result%candidate_state%water_content), 'candidate arrays returned', failures)
    call expect_true(abs(result%unrounded_mass_balance_residual) <= 1.0e-12_real64, &
         'adapter mass residual bounded', failures)
    call solver%temporal_certificate_snapshot(certificate_available, certificate)
    call expect_true(certificate_available .and. certificate >= 0.0_real64, &
         'qualified RossFast temporal certificate retained', failures)
  end subroutine test_real_kernel_route

  subroutine test_fail_closed_envelope(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(rossfast_d3r_soil_water_solver_t) :: solver
    type(rossfast_d3r_soil_water_workspace_t) :: workspace
    type(soil_water_parameter_set_t), target :: parameters
    type(dummy_constitutive_t), target :: constitutive
    type(test_source_sink_t), target :: terms
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    logical :: valid, found
    integer :: provider_status

    call solver%initialize(root, 'B01', valid, provider_status)
    call expect_true(valid, 'rejection fixture initializes', failures)
    call rossfast_d3r_material_from_id('B01', material, found)
    call build_request(parameters, constitutive, terms, material, request)

    request%boundary%bottom_mode = 5
    call solver%solve(request, workspace, result)
    call expect_true(result%status /= SW_SOLVE_CONVERGED, 'bottom-head mode rejected', failures)

    request%boundary%bottom_mode = 2
    request%request_interface_sensitivity = .true.
    call solver%solve(request, workspace, result)
    call expect_true(result%status /= SW_SOLVE_CONVERGED, 'whole-window sensitivity request rejected', failures)

    request%request_interface_sensitivity = .false.
    request%base_state%ponding_depth = 0.1_real64
    call solver%solve(request, workspace, result)
    call expect_true(result%status /= SW_SOLVE_CONVERGED, 'ponded surface rejected', failures)

    request%base_state%ponding_depth = 0.0_real64
    terms%nonzero = .true.
    call solver%solve(request, workspace, result)
    call expect_true(result%status /= SW_SOLVE_CONVERGED, 'distributed source term rejected', failures)
  end subroutine test_fail_closed_envelope

  subroutine test_provider_preflight(failures)
    integer, intent(inout) :: failures
    type(rossfast_d3r_soil_water_solver_t) :: solver
    logical :: valid
    integer :: status
    call solver%initialize('definitely-missing-rossfast-assets', 'B01', valid, status)
    call expect_true(.not. valid, 'missing table asset fails before solve', failures)
    call solver%initialize('assets/rossfast', 'XXX', valid, status)
    call expect_true(.not. valid, 'unsupported material fails before solve', failures)
  end subroutine test_provider_preflight

  subroutine build_request(parameters, constitutive, terms, material, request)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    type(dummy_constitutive_t), target, intent(inout) :: constitutive
    type(test_source_sink_t), target, intent(inout) :: terms
    type(rossfast_d3r_material_t), intent(in) :: material
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64) :: conductivity, theta
    integer :: i

    parameters%parameter_set_id = 12001
    parameters%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(parameters%z(ROSSFAST_D3R_N_CELLS), parameters%dz(ROSSFAST_D3R_N_CELLS), &
         parameters%node_distance(ROSSFAST_D3R_N_CELLS))
    do i = 1, ROSSFAST_D3R_N_CELLS
      parameters%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i,real64) - 0.5_real64)
    end do
    parameters%dz = ROSSFAST_D3R_DZ_CM
    parameters%node_distance = ROSSFAST_D3R_DZ_CM

    request = soil_water_solve_request_t()
    request%parameters => parameters
    request%base_state%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(request%base_state%pressure_head(ROSSFAST_D3R_N_CELLS), &
         request%base_state%water_content(ROSSFAST_D3R_N_CELLS))
    request%base_state%pressure_head = -101.0_real64
    theta = theta_from_head(-101.0_real64, material)
    request%base_state%water_content = theta
    request%base_state%ponding_depth = 0.0_real64
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 2
    conductivity = conductivity_from_head(-101.0_real64, material)
    request%boundary%top_flux = 0.01_real64 * conductivity
    request%boundary%bottom_flux = -0.004_real64 * conductivity
    request%step_duration = ROSSFAST_D3R_OUTER_HORIZON_DAY
    request%evaluation%constitutive => constitutive
    terms%nonzero = .false.
    request%evaluation%source_sink => terms
  end subroutine build_request

  subroutine dummy_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(dummy_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (same_type_as(self,self) .and. size(pressure_head) >= 0) then
      water_content = 0.0_real64
      conductivity = 0.0_real64
      capacity = 0.0_real64
      dconductivity_dhead = 0.0_real64
    end if
  end subroutine dummy_constitutive_evaluate

  subroutine test_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(test_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    source = 0.0_real64
    sink = 0.0_real64
    if (size(pressure_head) /= size(water_content)) error stop 91
    if (self%nonzero .and. size(source) > 0) source(1) = 1.0e-6_real64
  end subroutine test_source_sink_evaluate

  pure real(real64) function theta_from_head(head_cm, material) result(theta)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, s
    m = 1.0_real64 - 1.0_real64 / material%n
    s = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    theta = material%theta_r + (material%theta_s - material%theta_r) * s
  end function theta_from_head

  pure real(real64) function conductivity_from_head(head_cm, material) result(conductivity)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m, s, term
    m = 1.0_real64 - 1.0_real64 / material%n
    s = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
    term = (1.0_real64 - s**(1.0_real64 / m))**m
    conductivity = material%ksatfit_cm_per_day * s**material%lambda * (1.0_real64 - term)**2
  end function conductivity_from_head

  subroutine expect_true(condition, label, failures)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: failures
    if (.not. condition) then
      failures = failures + 1
      write(*,'(a,a)') 'FAIL ', trim(label)
    end if
  end subroutine expect_true

end program test_ross12_soil_water_solver_adapter
