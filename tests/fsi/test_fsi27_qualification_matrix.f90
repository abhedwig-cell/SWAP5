module mod_fsi27_qualification_fixture
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, source_sink_provider_t, &
       root_sink_provider_t, top_boundary_provider_t, soil_water_boundary_conditions_t
  implicit none
  private

  type, extends(constitutive_hydraulics_provider_t), public :: fsi27_constitutive_t
   contains
     procedure :: evaluate => evaluate_constitutive
  end type fsi27_constitutive_t

  type, extends(source_sink_provider_t), public :: fsi27_source_sink_t
   contains
     procedure :: evaluate => evaluate_source_sink
  end type fsi27_source_sink_t

  type, extends(root_sink_provider_t), public :: fsi27_root_sink_t
   contains
     procedure :: evaluate => evaluate_root_sink
  end type fsi27_root_sink_t

  type, extends(top_boundary_provider_t), public :: fsi27_top_t
   contains
     procedure :: evaluate => evaluate_top
  end type fsi27_top_t

contains

  subroutine evaluate_constitutive(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi27_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    if (storage_size(self) <= 0) error stop 'invalid fixture object'
    water_content = 0.30_real64 + 0.001_real64*(pressure_head + 75.0_real64)
    conductivity = 1.0_real64
    capacity = 0.001_real64
    dconductivity_dhead = 0.0_real64
  end subroutine evaluate_constitutive

  subroutine evaluate_source_sink(self, pressure_head, water_content, source, sink)
    class(fsi27_source_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: source(:), sink(:)
    if (size(pressure_head) /= size(water_content) .or. storage_size(self) <= 0) error stop 'bad source fixture'
    source = 0.0_real64
    sink = 0.0_real64
  end subroutine evaluate_source_sink

  subroutine evaluate_root_sink(self, pressure_head, water_content, root_sink)
    class(fsi27_root_sink_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), water_content(:)
    real(real64), intent(out) :: root_sink(:)
    if (size(pressure_head) /= size(water_content) .or. storage_size(self) <= 0) error stop 'bad root fixture'
    root_sink = 0.0_real64
  end subroutine evaluate_root_sink

  subroutine evaluate_top(self, pressure_head_top, water_content_top, requested, actual_top_flux, surface_head, runoff_flux)
    class(fsi27_top_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head_top, water_content_top
    type(soil_water_boundary_conditions_t), intent(in) :: requested
    real(real64), intent(out) :: actual_top_flux, surface_head, runoff_flux
    if (storage_size(self) <= 0 .or. pressure_head_top > huge(pressure_head_top) .or. &
        water_content_top > huge(water_content_top)) error stop 'bad top fixture'
    actual_top_flux = requested%top_flux
    surface_head = 0.0_real64
    runoff_flux = 0.0_real64
  end subroutine evaluate_top

end module mod_fsi27_qualification_fixture

program test_fsi27_qualification_matrix
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use variables, only: legacy_qbot => qbot, legacy_hbot => hbot, legacy_swbotb => swbotb, legacy_qtop => qtop
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_fsi27_qualification_fixture, only: fsi27_constitutive_t, fsi27_source_sink_t, fsi27_root_sink_t, fsi27_top_t
  implicit none

  integer, parameter :: ncases = 3
  integer, parameter :: worker_counts(4) = [1,2,4,8]
  real(real64), parameter :: dt_case = 1.0e-3_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: qtop_values(ncases) = [-0.80_real64, -0.60_real64, -0.70_real64]
  real(real64), parameter :: qbot_values(ncases) = [ 0.20_real64,  0.00_real64, -0.40_real64]
  type(soil_water_parameter_set_t), target :: parameters
  type(fsi27_constitutive_t), target :: constitutive
  type(fsi27_source_sink_t), target :: source_sink
  type(fsi27_root_sink_t), target :: root_sink
  type(fsi27_top_t), target :: top_boundary
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: ref_ws(ncases), worker_ws(8), aba_ws, reject_ws
  type(soil_water_solve_request_t) :: request(ncases), before(ncases), rejected
  type(soil_water_solve_result_t) :: ref_result(ncases), worker_result, aba_result, reject_result
  integer :: i, j, k, idx, calls_before
  integer :: failures
  real(real64) :: qnan, max_mass, state_response

  failures = 0
  call configure_parameters()
  do i = 1, ncases
    call make_request(request(i), qtop_values(i), qbot_values(i))
    before(i) = request(i)
  end do

  qnan = ieee_value(0.0_real64, ieee_quiet_nan)

  ! Reference executions for positive, zero and negative prescribed qbot.
  do i = 1, ncases
    call poison_legacy_globals(qnan)
    call prepare_poisoned_workspace(ref_ws(i))
    call solver%solve(request(i), ref_ws(i), ref_result(i))
    call require(ref_result(i)%status == SW_SOLVE_CONVERGED, 'reference case converged', failures)
    call require(same_bits(ref_result(i)%bottom_flux, qbot_values(i)), 'qbot output equals request bitwise', failures)
    call require(same_bits(ref_result(i)%top_flux, qtop_values(i)), 'qtop output equals request bitwise', failures)
    call require(ieee_is_finite(ref_result(i)%unrounded_mass_balance_residual), 'solver mass residual finite', failures)
    call require(abs(ref_result(i)%unrounded_mass_balance_residual) <= hard_mass_gate, 'solver mass residual gate', failures)
    max_mass = abs(external_mass_residual(request(i), ref_result(i)))
    call require(max_mass <= hard_mass_gate, 'whole-step external mass gate', failures)
    call require_request_equal(request(i), before(i), 'reference request immutability', failures)
    call require_legacy_poison_preserved(qnan, 'reference global poison', failures)
    write(*,'(A,I0,A,ES26.17E3,A,ES26.17E3,A,I0,A,ES26.17E3)') &
         'FSI27_MATRIX_CASE=',i,':QTOP=',qtop_values(i),':QBOT=',qbot_values(i), &
         ':ITER=',ref_result(i)%diagnostics%nonlinear_iterations,':MASS=',max_mass
  end do

  call require(qbot_values(1) > 0.0_real64 .and. qbot_values(2) == 0.0_real64 .and. qbot_values(3) < 0.0_real64, &
       'positive zero negative qbot coverage', failures)
  call require(all(qtop_values /= qbot_values), 'top and bottom flux independently prescribed', failures)
  state_response = maxval(abs(ref_result(1)%candidate_state%pressure_head - request(1)%base_state%pressure_head))
  call require(state_response > 1024.0_real64*epsilon(1.0_real64), 'nontrivial nonlinear state update', failures)
  call require(ref_result(1)%diagnostics%nonlinear_iterations > 0, 'nontrivial case has nonlinear iteration', failures)
  write(*,'(A,ES26.17E3)') 'FSI27_MATRIX_NONTRIVIAL_RESPONSE=',state_response

  ! ABA replay with the same workspace. B is deliberately different. Poison
  ! scratch before each solve so A2 can only reproduce A1 after a correct reset.
  call prepare_poisoned_workspace(aba_ws)
  call poison_legacy_globals(qnan)
  call solver%solve(request(1), aba_ws, aba_result)
  call require_result_equal(aba_result, ref_result(1), 'ABA A1 reference', failures)
  call poison_reference_workspace(aba_ws%richards)
  call poison_legacy_globals(qnan)
  call solver%solve(request(3), aba_ws, aba_result)
  call require_result_equal(aba_result, ref_result(3), 'ABA B reference', failures)
  call poison_reference_workspace(aba_ws%richards)
  call poison_legacy_globals(qnan)
  call solver%solve(request(1), aba_ws, aba_result)
  call require_result_equal(aba_result, ref_result(1), 'ABA A2 identity', failures)
  call require_request_equal(request(1), before(1), 'ABA request immutability', failures)
  write(*,'(A)') 'FSI27_MATRIX_ABA_REPLAY=PASS'

  ! Serialized worker isolation: independent workspace instances, mixed qbot
  ! signs/order, counts 1/2/4/8. This does not claim parallel backend admission.
  do j = 1, size(worker_counts)
    do k = 1, worker_counts(j)
      idx = 1 + mod(2*k + j, ncases)
      call prepare_poisoned_workspace(worker_ws(k))
      worker_ws(k)%legacy_worker%worker_id = 2700 + 10*j + k
      call poison_legacy_globals(qnan)
      call solver%solve(request(idx), worker_ws(k), worker_result)
      call require_result_equal(worker_result, ref_result(idx), 'serialized worker identity', failures)
      call require_request_equal(request(idx), before(idx), 'serialized request immutability', failures)
      call require_legacy_poison_preserved(qnan, 'serialized global poison', failures)
    end do
    write(*,'(A,I0,A)') 'FSI27_MATRIX_SERIALIZED_WORKERS_',worker_counts(j),'=PASS'
  end do

  ! Explicitly unowned modes still fail before HeadCalc. Modes 2, 5, 7 and -2
  ! are owned elsewhere/currently and therefore excluded from this negative set.
  do i = 1, 5
    select case (i)
    case (1); idx = 1
    case (2); idx = 3
    case (3); idx = 6
    case (4); idx = 8
    case (5); idx = 9
    end select
    rejected = request(2)
    rejected%boundary%bottom_mode = idx
    call prepare_poisoned_workspace(reject_ws)
    calls_before = reject_ws%legacy_worker%diagnostics%headcalc_calls
    call solver%solve(rejected, reject_ws, reject_result)
    call require(reject_result%status == SW_SOLVE_FAILED, 'unsupported mode fails', failures)
    call require(trim(reject_result%diagnostics%route) == 'legacy-bottom-mode-deferred', 'unsupported route', failures)
    call require(reject_ws%legacy_worker%diagnostics%headcalc_calls == calls_before, 'unsupported fails before HeadCalc', failures)
  end do
  write(*,'(A)') 'FSI27_MATRIX_UNSUPPORTED_BOTTOM_MODES=PASS'

  if (failures /= 0) then
    write(*,'(A,I0)') 'FSI27_QUALIFICATION_MATRIX FAIL failures=',failures
    error stop 1
  end if
  write(*,'(A)') 'FSI27_MATRIX_QBOT_SIGN_COVERAGE=PASS'
  write(*,'(A)') 'FSI27_MATRIX_REQUEST_AUTHORITY=PASS'
  write(*,'(A)') 'FSI27_MATRIX_REQUEST_IMMUTABILITY=PASS'
  write(*,'(A)') 'FSI27_MATRIX_GLOBAL_POISON=PASS'
  write(*,'(A)') 'FSI27_MATRIX_SCRATCH_POISON=PASS'
  write(*,'(A)') 'FSI27_QUALIFICATION_MATRIX PASS'

contains

  subroutine configure_parameters()
    integer :: m
    parameters%parameter_set_id = 270027_int64
    parameters%active_nodes = numnod
    allocate(parameters%z(numnod), parameters%dz(numnod), parameters%node_distance(numnod))
    parameters%z = z
    parameters%dz = dz
    parameters%node_distance = disnod(1:numnod)
    do m = 1, numnod
      if (parameters%dz(m) <= 0.0_real64) error stop 'invalid fixture dz'
    end do
  end subroutine configure_parameters

  subroutine make_request(r, top_flux, bottom_flux)
    type(soil_water_solve_request_t), intent(out) :: r
    real(real64), intent(in) :: top_flux, bottom_flux
    r = soil_water_solve_request_t()
    r%parameters => parameters
    r%base_state%active_nodes = numnod
    allocate(r%base_state%pressure_head(numnod), r%base_state%water_content(numnod))
    r%base_state%pressure_head = -75.0_real64
    r%base_state%water_content = 0.30_real64
    r%base_state%ponding_depth = 0.0_real64
    r%base_state%groundwater_level = -2.0_real64
    r%step_duration = dt_case
    r%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    r%boundary%bottom_mode = 2
    r%boundary%top_flux = top_flux
    r%boundary%bottom_flux = bottom_flux
    r%boundary%top_head = -75.0_real64
    r%boundary%bottom_head = 987654.321_real64
    r%physical%macropore_active = .false.
    r%numerical%max_iterations = 16
    r%numerical%max_backtracking = 8
    r%numerical%conductivity_implicit_mode = 0
    r%numerical%conductivity_mean_method = 1
    r%numerical%min_step_duration = 1.0e-8_real64
    r%numerical%compartment_balance_tolerance = hard_mass_gate
    r%numerical%total_balance_tolerance = hard_mass_gate
    r%numerical%head_abs_tolerance = 1.0e-12_real64
    r%numerical%head_rel_tolerance = 1.0e-12_real64
    r%numerical%ponding_tolerance = 1.0e-12_real64
    r%evaluation%constitutive => constitutive
    r%evaluation%source_sink => source_sink
    r%evaluation%root_sink => root_sink
    r%evaluation%top_boundary => top_boundary
  end subroutine make_request

  subroutine prepare_poisoned_workspace(ws)
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    call initialize_reference_workspace(ws%richards, numnod)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes = 0
  end subroutine prepare_poisoned_workspace

  subroutine poison_legacy_globals(nan_value)
    real(real64), intent(in) :: nan_value
    legacy_swbotb = 3
    legacy_qbot = nan_value
    legacy_hbot = nan_value
    legacy_qtop = nan_value
  end subroutine poison_legacy_globals

  subroutine require_legacy_poison_preserved(nan_value, label, nfail)
    real(real64), intent(in) :: nan_value
    character(len=*), intent(in) :: label
    integer, intent(inout) :: nfail
    call require(legacy_swbotb == 3, label//' swbotb', nfail)
    call require(same_bits(legacy_qbot,nan_value), label//' qbot', nfail)
    call require(same_bits(legacy_hbot,nan_value), label//' hbot', nfail)
    call require(same_bits(legacy_qtop,nan_value), label//' qtop', nfail)
  end subroutine require_legacy_poison_preserved

  subroutine require_request_equal(a, b, label, nfail)
    type(soil_water_solve_request_t), intent(in) :: a,b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: nfail
    call require(a%base_state%active_nodes == b%base_state%active_nodes, label//' active nodes', nfail)
    call require(vector_same_bits(a%base_state%pressure_head,b%base_state%pressure_head), label//' heads', nfail)
    call require(vector_same_bits(a%base_state%water_content,b%base_state%water_content), label//' water', nfail)
    call require(same_bits(a%base_state%ponding_depth,b%base_state%ponding_depth), label//' pond', nfail)
    call require(same_bits(a%base_state%groundwater_level,b%base_state%groundwater_level), label//' gwl', nfail)
    call require(a%boundary%top_mode == b%boundary%top_mode .and. a%boundary%bottom_mode == b%boundary%bottom_mode, &
         label//' modes', nfail)
    call require(same_bits(a%boundary%top_flux,b%boundary%top_flux), label//' top flux', nfail)
    call require(same_bits(a%boundary%bottom_flux,b%boundary%bottom_flux), label//' bottom flux', nfail)
    call require(same_bits(a%boundary%top_head,b%boundary%top_head), label//' top head', nfail)
    call require(same_bits(a%boundary%bottom_head,b%boundary%bottom_head), label//' bottom head', nfail)
    call require(same_bits(a%step_duration,b%step_duration), label//' dt', nfail)
    call require(a%numerical%max_iterations == b%numerical%max_iterations, label//' maxit', nfail)
    call require(a%numerical%max_backtracking == b%numerical%max_backtracking, label//' maxbacktr', nfail)
    call require(a%numerical%conductivity_implicit_mode == b%numerical%conductivity_implicit_mode, label//' swkimpl', nfail)
    call require(a%numerical%conductivity_mean_method == b%numerical%conductivity_mean_method, label//' swkmean', nfail)
    call require(same_bits(a%numerical%total_balance_tolerance,b%numerical%total_balance_tolerance), label//' baltol', nfail)
    call require(a%physical%macropore_active .eqv. b%physical%macropore_active, label//' macro', nfail)
  end subroutine require_request_equal

  subroutine require_result_equal(a, b, label, nfail)
    type(soil_water_solve_result_t), intent(in) :: a,b
    character(len=*), intent(in) :: label
    integer, intent(inout) :: nfail
    call require(a%status == b%status, label//' status', nfail)
    call require(trim(a%diagnostics%route) == trim(b%diagnostics%route), label//' route', nfail)
    call require(vector_same_bits(a%candidate_state%pressure_head,b%candidate_state%pressure_head), label//' heads', nfail)
    call require(vector_same_bits(a%candidate_state%water_content,b%candidate_state%water_content), label//' water', nfail)
    call require(same_bits(a%top_flux,b%top_flux), label//' qtop', nfail)
    call require(same_bits(a%bottom_flux,b%bottom_flux), label//' qbot', nfail)
    call require(same_bits(a%unrounded_mass_balance_residual,b%unrounded_mass_balance_residual), label//' mass', nfail)
    call require(a%diagnostics%nonlinear_iterations == b%diagnostics%nonlinear_iterations, label//' iter', nfail)
    call require(a%diagnostics%jacobian_builds == b%diagnostics%jacobian_builds, label//' jac', nfail)
    call require(a%diagnostics%linear_solves == b%diagnostics%linear_solves, label//' linear', nfail)
    call require(a%diagnostics%backtracking_attempts == b%diagnostics%backtracking_attempts, label//' backtrack', nfail)
    call require(a%diagnostics%internal_retries == b%diagnostics%internal_retries, label//' retries', nfail)
  end subroutine require_result_equal

  real(real64) function external_mass_residual(r, result) result(value)
    type(soil_water_solve_request_t), intent(in) :: r
    type(soil_water_solve_result_t), intent(in) :: result
    real(real64) :: storage0, storage1, total_in, total_out
    storage0 = sum(r%base_state%water_content*r%parameters%dz) + r%base_state%ponding_depth
    storage1 = sum(result%candidate_state%water_content*r%parameters%dz) + result%candidate_state%ponding_depth
    total_in = max(0.0_real64,-result%top_flux)*r%step_duration + max(0.0_real64,result%bottom_flux)*r%step_duration
    total_out = max(0.0_real64,result%top_flux)*r%step_duration + max(0.0_real64,-result%bottom_flux)*r%step_duration
    value = storage1-storage0-(total_in-total_out)
  end function external_mass_residual

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits = transfer(a,0_int64) == transfer(b,0_int64)
  end function same_bits

  pure logical function vector_same_bits(a,b)
    real(real64), intent(in) :: a(:),b(:)
    integer :: m
    vector_same_bits = size(a)==size(b)
    if (.not.vector_same_bits) return
    do m=1,size(a)
      if (.not.same_bits(a(m),b(m))) then
        vector_same_bits=.false.
        return
      end if
    end do
  end function vector_same_bits

  subroutine require(condition,label,nfail)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    integer, intent(inout) :: nfail
    if (.not.condition) then
      nfail=nfail+1
      write(*,'(A,1X,A)') 'FSI27_MATRIX_FAIL',trim(label)
    end if
  end subroutine require

end program test_fsi27_qualification_matrix
