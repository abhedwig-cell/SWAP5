module mod_ross12_selection_test_providers
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: dummy_constitutive_t
  contains
    procedure :: evaluate => dummy_constitutive_evaluate
  end type dummy_constitutive_t

  type, extends(source_sink_provider_t), public :: zero_source_sink_t
  contains
    procedure :: evaluate => zero_source_sink_evaluate
  end type zero_source_sink_t

contains

  subroutine dummy_constitutive_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(dummy_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (same_type_as(self, self) .and. size(pressure_head) >= 0) then
      water_content = 0.0_real64
      conductivity = 0.0_real64
      capacity = 0.0_real64
      dconductivity_dhead = 0.0_real64
    end if
  end subroutine dummy_constitutive_evaluate

  subroutine zero_source_sink_evaluate(self, pressure_head, water_content, source, sink)
    class(zero_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (.not. same_type_as(self, self) .or. size(pressure_head) /= size(water_content)) error stop 91
    source = 0.0_real64
    sink = 0.0_real64
  end subroutine zero_source_sink_evaluate

end module mod_ross12_selection_test_providers

program test_ross12_solver_selection_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_soil_water_application_host, only: FMR_SOIL_WATER_MODEL_REFERENCE
  use mod_fmr_rossfast_solver_selection_binding, only: fmr_rossfast_solver_selection_binding_t, &
       FMR_ROSSFAST_SOLVER_MODEL_KEY, FMR_ROSSFAST_BIND_OK, &
       FMR_ROSSFAST_BIND_SELECTION_FAILED, FMR_ROSSFAST_BIND_CONFIGURATION_MISSING, &
       FMR_ROSSFAST_BIND_INITIALIZATION_FAILED
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM
  use mod_ross12_selection_test_providers, only: dummy_constitutive_t, zero_source_sink_t
  implicit none

  character(len=512) :: asset_root
  integer :: failures

  call get_command_argument(1, asset_root)
  if (len_trim(asset_root) == 0) error stop 'usage: test_ross12_solver_selection_binding ASSET_ROOT'

  failures = 0
  call test_reference_selection(failures)
  call test_fail_closed_selection(trim(asset_root), failures)
  call test_real_rossfast_selection(trim(asset_root), failures)

  if (failures /= 0) then
    write(*,'(a,i0)') 'ROSS12_SOLVER_SELECTION_BINDING FAIL failures=', failures
    error stop 1
  end if
  write(*,'(a)') 'ROSS12_SOLVER_SELECTION_BINDING PASS'

contains

  subroutine test_reference_selection(failures)
    integer, intent(inout) :: failures
    type(fmr_rossfast_solver_selection_binding_t) :: binding
    logical :: ok
    integer :: status

    call binding%configure('', ok, status)
    call expect_true(ok .and. status == FMR_ROSSFAST_BIND_OK, 'blank selection resolves', failures)
    call expect_true(binding%execution_ready(), 'blank Reference is execution-ready', failures)
    call expect_true(binding%uses_reference() .and. .not. binding%uses_rossfast(), &
         'blank selection remains Reference', failures)
    call expect_true(.not. binding%selection_is_explicit(), 'blank Reference is not explicit', failures)
    call expect_true(trim(binding%selected_model_key()) == FMR_SOIL_WATER_MODEL_REFERENCE, &
         'blank Reference key', failures)

    call binding%configure(FMR_SOIL_WATER_MODEL_REFERENCE, ok, status)
    call expect_true(ok .and. status == FMR_ROSSFAST_BIND_OK, 'explicit Reference resolves', failures)
    call expect_true(binding%uses_reference() .and. binding%selection_is_explicit(), &
         'explicit Reference retained', failures)
  end subroutine test_reference_selection

  subroutine test_fail_closed_selection(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_solver_selection_binding_t) :: binding
    logical :: ok
    integer :: status

    call binding%configure('NOT_A_MODEL', ok, status)
    call expect_true(.not. ok .and. status == FMR_ROSSFAST_BIND_SELECTION_FAILED, &
         'unknown model fails selection', failures)
    call expect_true(.not. binding%execution_ready() .and. .not. binding%uses_reference(), &
         'unknown model cannot fall back to Reference', failures)

    call binding%configure(FMR_ROSSFAST_SOLVER_MODEL_KEY, ok, status)
    call expect_true(.not. ok .and. status == FMR_ROSSFAST_BIND_CONFIGURATION_MISSING, &
         'RossFast without assets fails configuration', failures)
    call expect_true(binding%uses_rossfast() .and. .not. binding%execution_ready(), &
         'failed RossFast identity retained without fallback', failures)

    call binding%configure(FMR_ROSSFAST_SOLVER_MODEL_KEY, ok, status, &
         asset_root='definitely-missing-rossfast-assets', material_id='B01')
    call expect_true(.not. ok .and. status == FMR_ROSSFAST_BIND_INITIALIZATION_FAILED, &
         'missing RossFast assets fail initialization', failures)
    call expect_true(binding%uses_rossfast() .and. .not. binding%uses_reference(), &
         'missing assets do not select Reference', failures)

    call binding%configure(FMR_ROSSFAST_SOLVER_MODEL_KEY, ok, status, asset_root=root, material_id='XXX')
    call expect_true(.not. ok .and. status == FMR_ROSSFAST_BIND_INITIALIZATION_FAILED, &
         'unsupported material fails initialization', failures)
    call expect_true(.not. binding%execution_ready(), 'unsupported material cannot execute', failures)
  end subroutine test_fail_closed_selection

  subroutine test_real_rossfast_selection(root, failures)
    character(len=*), intent(in) :: root
    integer, intent(inout) :: failures
    type(fmr_rossfast_solver_selection_binding_t) :: binding
    type(soil_water_parameter_set_t), target :: parameters
    type(dummy_constitutive_t), target :: constitutive
    type(zero_source_sink_t), target :: zero_terms
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(rossfast_d3r_material_t) :: material
    logical :: ok, found, certificate_available
    integer :: status
    real(real64) :: certificate

    call binding%configure(FMR_ROSSFAST_SOLVER_MODEL_KEY, ok, status, asset_root=root, material_id='B01')
    call expect_true(ok .and. status == FMR_ROSSFAST_BIND_OK, 'B01 RossFast binding initializes', failures)
    call expect_true(binding%execution_ready() .and. binding%uses_rossfast() .and. &
         .not. binding%uses_reference(), 'B01 RossFast becomes sole selected solver', failures)
    call expect_true(binding%selection_is_explicit(), 'RossFast selection is explicit', failures)
    call expect_true(trim(binding%selected_model_key()) == FMR_ROSSFAST_SOLVER_MODEL_KEY, &
         'RossFast model key retained', failures)

    call rossfast_d3r_material_from_id('B01', material, found)
    call expect_true(found, 'B01 material exists', failures)
    call build_request(parameters, constitutive, zero_terms, material, request)
    call binding%solve(request, result)
    call expect_true(result%status == SW_SOLVE_CONVERGED, 'selected RossFast solves through binding', failures)
    call expect_true(trim(result%diagnostics%route) == 'rossfast-d3r', 'selected solver route is RossFast', failures)
    call expect_true(result%diagnostics%linear_solves >= 24 .and. mod(result%diagnostics%linear_solves, 24) == 0, &
         'real D3R kernel executes through binding', failures)

    call binding%temporal_certificate_snapshot(certificate_available, certificate)
    call expect_true(certificate_available .and. certificate >= 0.0_real64, &
         'RossFast certificate passes through binding', failures)

    call binding%configure(FMR_SOIL_WATER_MODEL_REFERENCE, ok, status)
    call expect_true(ok .and. binding%uses_reference() .and. .not. binding%uses_rossfast(), &
         'explicit reconfiguration restores Reference identity', failures)
  end subroutine test_real_rossfast_selection

  subroutine build_request(parameters, constitutive, zero_terms, material, request)
    type(soil_water_parameter_set_t), target, intent(out) :: parameters
    type(dummy_constitutive_t), target, intent(inout) :: constitutive
    type(zero_source_sink_t), target, intent(inout) :: zero_terms
    type(rossfast_d3r_material_t), intent(in) :: material
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64) :: conductivity, theta
    integer :: i

    parameters%parameter_set_id = 12001
    parameters%active_nodes = ROSSFAST_D3R_N_CELLS
    allocate(parameters%z(ROSSFAST_D3R_N_CELLS), parameters%dz(ROSSFAST_D3R_N_CELLS), &
         parameters%node_distance(ROSSFAST_D3R_N_CELLS))
    do i = 1, ROSSFAST_D3R_N_CELLS
      parameters%z(i) = -ROSSFAST_D3R_DZ_CM * (real(i, real64) - 0.5_real64)
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
    request%evaluation%source_sink => zero_terms
  end subroutine build_request

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

end program test_ross12_solver_selection_binding
