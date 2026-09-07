module mod_fsi02_test_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  public :: dummy_constitutive_t

  type, extends(constitutive_hydraulics_provider_t) :: dummy_constitutive_t
     integer :: marker = 1
   contains
     procedure :: evaluate => dummy_evaluate
  end type dummy_constitutive_t

contains

  subroutine dummy_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(dummy_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:)
    real(real64), intent(out) :: conductivity(:)
    real(real64), intent(out) :: capacity(:)
    real(real64), intent(out) :: dconductivity_dhead(:)

    if (self%marker < 0 .or. size(pressure_head) < 0) error stop 'unreachable'
    water_content = 0.3_real64
    conductivity = 1.0_real64
    capacity = 0.01_real64
    dconductivity_dhead = 0.0_real64
  end subroutine dummy_evaluate

end module mod_fsi02_test_provider

program test_fsi02_solver_contract
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract
  use mod_reference_richards_workspace
  use mod_fsi02_test_provider, only: dummy_constitutive_t
  implicit none

  integer, parameter :: n = 12, nworkers = 8
  type(soil_water_parameter_set_t), target :: params
  type(soil_water_solve_request_t) :: request_a, request_b
  type(soil_water_physical_state_t) :: clone
  type(reference_richards_workspace_t) :: workspaces(nworkers)
  type(dummy_constitutive_t), target :: constitutive
  logical :: ok
  integer :: i, failures
  integer(int64) :: bytes_one

  failures = 0
  params%parameter_set_id = 42_int64
  params%active_nodes = n
  allocate(params%z(n), params%dz(n), params%node_distance(n))
  do i = 1, n
     params%z(i) = -real(i, real64)
     params%dz(i) = 1.0_real64
     params%node_distance(i) = 1.0_real64
  end do

  call setup_request(request_a, params, constitutive)
  call setup_request(request_b, params, constitutive)

  call validate_soil_water_request(request_a, ok)
  if (.not. ok) failures = failures + 1
  if (.not. associated(request_a%parameters, request_b%parameters)) failures = failures + 1

  clone = request_a%base_state
  clone%pressure_head(1) = clone%pressure_head(1) - 100.0_real64
  if (abs(request_a%base_state%pressure_head(1)-clone%pressure_head(1)) < 1.0_real64) failures = failures + 1

  do i = 1, nworkers
     call initialize_reference_workspace(workspaces(i), n)
     workspaces(i)%residual = real(i, real64)
     workspaces(i)%diagnostics%nonlinear_iterations = i
  end do
  bytes_one = reference_workspace_payload_bytes(workspaces(1))
  if (bytes_one <= 0_int64) failures = failures + 1

!$omp parallel do default(none) shared(workspaces) reduction(+:failures) private(i)
  do i = 1, nworkers
     call poison_reference_workspace(workspaces(i))
     if (.not. workspaces(i)%poisoned) failures = failures + 1
     if (.not. all(ieee_is_nan(workspaces(i)%residual))) failures = failures + 1
     call reset_reference_workspace(workspaces(i))
     if (workspaces(i)%poisoned) failures = failures + 1
     workspaces(i)%residual = real(1000+i, real64)
  end do
!$omp end parallel do

  do i = 1, nworkers
     if (maxval(abs(workspaces(i)%residual-real(1000+i, real64))) > 0.0_real64) failures = failures + 1
  end do

  workspaces(1)%warm_start_head = -999.0_real64
  workspaces(1)%has_warm_start = .true.
  call reset_reference_workspace(workspaces(1))
  if (workspaces(1)%has_warm_start) failures = failures + 1
  if (maxval(abs(workspaces(1)%warm_start_head)) > 0.0_real64) failures = failures + 1

  do i = 1, nworkers
     call release_reference_workspace(workspaces(i))
     if (workspaces(i)%active_nodes /= 0) failures = failures + 1
  end do

  if (failures /= 0) then
     print '(A,I0)', 'F-SI02_CONTRACT_GATE FAIL failures=', failures
     error stop 1
  end if
  print '(A)', 'F-SI02_CONTRACT_GATE PASS'
  print '(A,I0)', 'workers=', nworkers
  print '(A,I0)', 'workspace_payload_bytes=', bytes_one
  print '(A,I0)', 'parameter_set_id=', params%parameter_set_id

contains

  subroutine setup_request(request, shared_params, provider)
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_parameter_set_t), target, intent(in) :: shared_params
    type(dummy_constitutive_t), target, intent(in) :: provider
    integer :: j

    request%parameters => shared_params
    request%evaluation%constitutive => provider
    request%step_duration = 0.25_real64
    request%numerical%max_iterations = 20
    request%numerical%max_backtracking = 6
    request%base_state%active_nodes = shared_params%active_nodes
    allocate(request%base_state%pressure_head(shared_params%active_nodes))
    allocate(request%base_state%water_content(shared_params%active_nodes))
    do j = 1, shared_params%active_nodes
       request%base_state%pressure_head(j) = -10.0_real64 * real(j, real64)
       request%base_state%water_content(j) = 0.30_real64
    end do
  end subroutine setup_request

end program test_fsi02_solver_contract
