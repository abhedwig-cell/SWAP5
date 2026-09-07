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
  real(real64) :: h(numnod) = 0.0_real64
  real(real64) :: theta(numnod) = 0.0_real64
  real(real64) :: hm1(numnod) = 0.0_real64
  real(real64) :: thetm1(numnod) = 0.0_real64
  real(real64) :: pond = 0.0_real64
  real(real64) :: gwl = 0.0_real64
  real(real64) :: pondm1 = 0.0_real64
  real(real64) :: gwlm1 = 0.0_real64
  real(real64) :: dt = 0.25_real64
  integer :: swbotb = 7
  integer :: maxit = 20
  integer :: maxbacktr = 6
  integer :: swkimpl = 0
  integer :: swkmean = 2
  real(real64) :: dtmin = 1.0e-4_real64
  real(real64) :: CritDevBalCp = 1.0e-8_real64
  real(real64) :: CritDevBalTot = 1.0e-8_real64
  real(real64) :: critdevh2cp = 1.0e-4_real64
  real(real64) :: critdevh1cp = 1.0e-4_real64
  real(real64) :: critdevponddt = 1.0e-8_real64
  logical :: fldtmin = .false.
  real(real64) :: qtop = 0.0_real64
  real(real64) :: qbot = 0.0_real64
  logical :: fldecdt = .false.
  integer :: numbit = 0
end module variables

module fsi03_stub_control
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: numnod
  implicit none
  integer :: headcalc_calls = 0
  logical :: request_retry = .false.
  real(real64) :: observed_head(numnod) = 0.0_real64
  real(real64) :: observed_theta(numnod) = 0.0_real64
  real(real64) :: observed_pond = 0.0_real64
  real(real64) :: observed_gwl = 0.0_real64
end module fsi03_stub_control

subroutine headcalc(worker)
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_a23bu_worker_execution_context, only: a23bu_worker_context_t
  use variables, only: h, theta, pond, gwl, qtop, qbot, fldecdt, numbit
  use fsi03_stub_control, only: headcalc_calls, request_retry, observed_head, observed_theta, &
       observed_pond, observed_gwl
  implicit none
  type(a23bu_worker_context_t), intent(inout), optional :: worker

  headcalc_calls = headcalc_calls + 1
  observed_head = h
  observed_theta = theta
  observed_pond = pond
  observed_gwl = gwl

  h = h - 1.0_real64
  theta = theta + 0.01_real64
  pond = pond + 0.02_real64
  gwl = gwl - 0.03_real64
  qtop = 1.25_real64
  qbot = -0.75_real64
  numbit = 4

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
  if (request_retry) fldecdt = .true.
end subroutine headcalc
