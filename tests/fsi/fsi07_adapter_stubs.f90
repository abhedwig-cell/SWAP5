module MOD_swap_base
  implicit none
  integer :: swmacro = 0
end module MOD_swap_base

module MOD_grid
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  integer, parameter :: numnod = 4
  real(real64), parameter :: z(numnod) = [-0.25_real64, -0.75_real64, -1.50_real64, -2.50_real64]
  real(real64), parameter :: dz(numnod) = [0.50_real64, 0.50_real64, 1.00_real64, 1.00_real64]
  real(real64), parameter :: disnod(numnod+1) = [0.25_real64, 0.50_real64, 0.75_real64, 1.00_real64, 0.50_real64]
end module MOD_grid

module variables
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  implicit none
  real(real64) :: h(numnod)=0.0_real64, theta(numnod)=0.0_real64
  real(real64) :: hm1(numnod)=0.0_real64, thetm1(numnod)=0.0_real64
  real(real64) :: k(numnod)=1.0_real64, kmean(numnod+1)=1.0_real64, dimoca(numnod)=0.0_real64
  real(real64) :: pond=0.0_real64, gwl=0.0_real64, pondm1=0.0_real64, gwlm1=0.0_real64
  real(real64) :: gwlinp=-5.0_real64, hbot=-100.0_real64, dtold=0.25_real64, runots=0.0_real64
  integer :: itnumb(100,2)=0
  logical :: fllowgwl=.false.
  real(real64) :: dt=0.25_real64
  integer :: swbotb=7, maxit=20, maxbacktr=6, swkimpl=0, swkmean=2
  real(real64) :: dtmin=1.0e-4_real64
  real(real64) :: CritDevBalCp=1.0e-8_real64, CritDevBalTot=1.0e-8_real64
  real(real64) :: critdevh2cp=1.0e-4_real64, critdevh1cp=1.0e-4_real64, critdevponddt=1.0e-8_real64
  logical :: fldtmin=.false., fldecdt=.false.
  real(real64) :: qtop=0.0_real64, qbot=0.0_real64
  integer :: numbit=0
end module variables

module MOD_top
  use, intrinsic :: iso_fortran_env, only: real64
  implicit none
  real(real64) :: q0=0.0_real64, hsurf=0.0_real64
  logical :: flrunoff=.false., ftoph=.false.
end module MOD_top

module fsi07_stub_control
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  implicit none
  integer :: headcalc_calls=0
  logical :: request_retry=.false.
  real(real64) :: observed_head(numnod)=0.0_real64, observed_theta(numnod)=0.0_real64
  real(real64) :: observed_pond=0.0_real64, observed_gwl=0.0_real64
end module fsi07_stub_control

subroutine headcalc(worker, fsi_workspace, history, state_binding, evaluation_context, boundary_conditions)
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t, a23bu_solver_history_t
  use mod_reference_richards_workspace, only: reference_richards_workspace_t
  use mod_reference_richards_state_binding, only: reference_richards_state_binding_t, FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_soil_water_solver_contract, only: hydraulic_evaluation_context_t, soil_water_boundary_conditions_t
  use fsi07_stub_control, only: headcalc_calls, request_retry, observed_head, observed_theta, observed_pond, observed_gwl
  implicit none
  type(a23bu_worker_context_t), intent(inout), optional :: worker
  type(reference_richards_workspace_t), target, intent(inout), optional :: fsi_workspace
  type(a23bu_solver_history_t), target, intent(inout), optional :: history
  type(reference_richards_state_binding_t), target, intent(inout), optional :: state_binding
  type(hydraulic_evaluation_context_t), intent(in), optional :: evaluation_context
  type(soil_water_boundary_conditions_t), intent(in), optional :: boundary_conditions

  headcalc_calls = headcalc_calls + 1
  if (.not. present(state_binding)) error stop 'F-SI07 adapter stub requires explicit state binding'
  if (.not. present(evaluation_context)) error stop 'F-SI07 adapter stub requires evaluation context'
  if (.not. present(boundary_conditions)) error stop 'F-SI07 adapter stub requires boundary conditions'
  if (.not. associated(evaluation_context%top_boundary)) error stop 'F-SI07 adapter stub requires top-boundary provider'
  if (boundary_conditions%top_mode /= FSI_TOP_MODE_EXPLICIT_FLUX) error stop 'F-SI07 adapter stub requires explicit flux top mode'
  observed_head = state_binding%h
  observed_theta = state_binding%theta
  observed_pond = state_binding%pond
  observed_gwl = state_binding%gwl

  state_binding%h = state_binding%h - 1.0_real64
  state_binding%theta = state_binding%theta + 0.01_real64
  state_binding%pond = state_binding%pond + 0.02_real64
  state_binding%gwl = state_binding%gwl - 0.03_real64
  state_binding%qtop = 1.25_real64
  state_binding%qbot = -0.75_real64
  state_binding%numbit = 4

  if (present(history)) then
     history%flwarn = .not. history%flwarn
     history%iwarn = history%iwarn + 1000
     history%nstep = history%nstep + 1000
  end if
  if (present(fsi_workspace)) then
     if (fsi_workspace%active_nodes < 0) error stop 'invalid workspace marker'
  end if
  if (present(worker)) then
     worker%diagnostics%headcalc_calls = worker%diagnostics%headcalc_calls + 1
     worker%diagnostics%nonlinear_iterations = 4
     worker%diagnostics%jacobian_builds = 4
     worker%diagnostics%linear_solves = 4
     worker%diagnostics%backtracking_attempts = 6
     if (request_retry) then
        worker%control%request_dt_reduction = .true.
        worker%diagnostics%internal_retries = 1
     end if
  end if
  if (request_retry) state_binding%fldecdt = .true.
end subroutine headcalc
