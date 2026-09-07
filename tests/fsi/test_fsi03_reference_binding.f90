module mod_fsi03_test_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  public :: fsi03_constitutive_t

  type, extends(constitutive_hydraulics_provider_t) :: fsi03_constitutive_t
   contains
     procedure :: evaluate => fsi03_evaluate
  end type fsi03_constitutive_t

contains

  subroutine fsi03_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(fsi03_constitutive_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:)
    real(real64), intent(out) :: conductivity(:)
    real(real64), intent(out) :: capacity(:)
    real(real64), intent(out) :: dconductivity_dhead(:)

    if (storage_size(self) <= 0 .or. size(pressure_head) <= 0) error stop 'invalid test provider use'
    water_content = 0.30_real64
    conductivity = 1.0_real64
    capacity = 0.01_real64
    dconductivity_dhead = 0.0_real64
  end subroutine fsi03_evaluate
end module mod_fsi03_test_provider

program test_fsi03_reference_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, poison_reference_workspace
  use mod_reference_richards_legacy_binding
  use mod_fsi03_test_provider, only: fsi03_constitutive_t
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use variables
  use fsi03_stub_control
  implicit none

  type(soil_water_parameter_set_t), target :: params
  type(fsi03_constitutive_t), target :: provider
  type(soil_water_solve_request_t) :: request_a, request_b
  type(soil_water_solve_result_t) :: result_a1, result_a2, result_b, result_retry, result_reject
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(reference_richards_workspace_t) :: wrong_workspace
  real(real64) :: saved_h(numnod), saved_theta(numnod), saved_hm1(numnod), saved_thetam1(numnod)
  real(real64) :: saved_pond, saved_gwl, saved_pondm1, saved_gwlm1, saved_qtop, saved_qbot
  logical :: saved_fldecdt
  integer :: saved_numbit, failures, calls_before

  failures = 0
  call configure_parameters(params)
  call seed_request_origin()
  call build_legacy_reference_request(request_a, params, provider)
  request_b = request_a
  request_b%base_state%pressure_head = request_a%base_state%pressure_head - 20.0_real64
  request_b%base_state%water_content = request_a%base_state%water_content + 0.05_real64
  request_b%base_state%ponding_depth = request_a%base_state%ponding_depth + 0.10_real64
  request_b%base_state%groundwater_level = request_a%base_state%groundwater_level - 0.50_real64

  call seed_legacy_sentinels()
  call capture_legacy(saved_h, saved_theta, saved_hm1, saved_thetam1, saved_pond, saved_gwl, &
       saved_pondm1, saved_gwlm1, saved_qtop, saved_qbot, saved_fldecdt, saved_numbit)

  call solver%solve(request_a, workspace, result_a1)
  call expect(result_a1%status == SW_SOLVE_CONVERGED, failures)
  call expect(.not. result_a1%retry_advised, failures)
  call expect(trim(result_a1%diagnostics%route) == 'legacy-reference-bound', failures)
  call expect(near_vector(observed_head, request_a%base_state%pressure_head), failures)
  call expect(near_vector(observed_theta, request_a%base_state%water_content), failures)
  call expect(near_scalar(observed_pond, request_a%base_state%ponding_depth), failures)
  call expect(near_scalar(observed_gwl, request_a%base_state%groundwater_level), failures)
  call expect(near_vector(result_a1%candidate_state%pressure_head, &
       request_a%base_state%pressure_head-1.0_real64), failures)
  call expect(near_vector(result_a1%candidate_state%water_content, &
       request_a%base_state%water_content+0.01_real64), failures)
  call expect(near_scalar(result_a1%top_flux, 1.25_real64), failures)
  call expect(near_scalar(result_a1%bottom_flux, -0.75_real64), failures)
  call expect(ieee_is_nan(result_a1%unrounded_mass_balance_residual), failures)
  call expect(result_a1%diagnostics%nonlinear_iterations == 4, failures)
  call expect(result_a1%diagnostics%backtracking_attempts == 6, failures)
  call expect_legacy_restored(saved_h, saved_theta, saved_hm1, saved_thetam1, saved_pond, saved_gwl, &
       saved_pondm1, saved_gwlm1, saved_qtop, saved_qbot, saved_fldecdt, saved_numbit, failures)

  call poison_reference_workspace(workspace%richards)
  call solver%solve(request_a, workspace, result_a2)
  call expect_same_candidate(result_a1, result_a2, failures)

  call solver%solve(request_b, workspace, result_b)
  call expect(near_vector(result_b%candidate_state%pressure_head, &
       request_b%base_state%pressure_head-1.0_real64), failures)
  call solver%solve(request_a, workspace, result_a2)
  call expect_same_candidate(result_a1, result_a2, failures)

  request_retry = .true.
  call solver%solve(request_a, workspace, result_retry)
  call expect(result_retry%status == SW_SOLVE_RETRY_ADVISED, failures)
  call expect(result_retry%retry_advised, failures)
  call expect(trim(result_retry%diagnostics%route) == 'legacy-reference-retry', failures)
  call expect(result_retry%diagnostics%internal_retries == 1, failures)
  request_retry = .false.
  call expect_legacy_restored(saved_h, saved_theta, saved_hm1, saved_thetam1, saved_pond, saved_gwl, &
       saved_pondm1, saved_gwlm1, saved_qtop, saved_qbot, saved_fldecdt, saved_numbit, failures)

  calls_before = headcalc_calls
  swmacro = 1
  call solver%solve(request_a, workspace, result_reject)
  call expect(result_reject%status == SW_SOLVE_FAILED, failures)
  call expect(trim(result_reject%diagnostics%route) == 'legacy-macropore-deferred', failures)
  call expect(headcalc_calls == calls_before, failures)
  swmacro = 0

  calls_before = headcalc_calls
  swkimpl = 1
  call solver%solve(request_a, workspace, result_reject)
  call expect(result_reject%status == SW_SOLVE_FAILED, failures)
  call expect(trim(result_reject%diagnostics%route) == 'legacy-implicit-k-deferred', failures)
  call expect(headcalc_calls == calls_before, failures)
  swkimpl = 0

  call solver%solve(request_a, wrong_workspace, result_reject)
  call expect(result_reject%status == SW_SOLVE_FAILED, failures)
  call expect(trim(result_reject%diagnostics%route) == 'legacy-workspace-type-error', failures)

  if (failures /= 0) then
     print '(A,I0)', 'F-SI03_REFERENCE_BINDING FAIL failures=', failures
     error stop 1
  end if
  print '(A)', 'F-SI03_REFERENCE_BINDING PASS'
  print '(A,I0)', 'headcalc_stub_calls=', headcalc_calls
  print '(A,I0)', 'parameter_set_id=', params%parameter_set_id

contains

  subroutine configure_parameters(p)
    type(soil_water_parameter_set_t), intent(out), target :: p
    p%parameter_set_id = 4301_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
  end subroutine configure_parameters

  subroutine seed_request_origin()
    integer :: i
    do i = 1, numnod
       h(i) = -real(i, real64)
       theta(i) = 0.20_real64 + 0.01_real64*real(i, real64)
    end do
    pond = 0.03_real64
    gwl = -2.25_real64
    hm1 = h
    thetm1 = theta
    pondm1 = pond
    gwlm1 = gwl
    qtop = 0.0_real64
    qbot = 0.0_real64
    fldecdt = .false.
    numbit = 0
  end subroutine seed_request_origin

  subroutine seed_legacy_sentinels()
    integer :: i
    do i = 1, numnod
       h(i) = 100.0_real64 + real(i, real64)
       theta(i) = 0.40_real64 + 0.01_real64*real(i, real64)
       hm1(i) = 200.0_real64 + real(i, real64)
       thetm1(i) = 0.50_real64 + 0.01_real64*real(i, real64)
    end do
    pond = 9.0_real64
    gwl = -9.0_real64
    pondm1 = 8.0_real64
    gwlm1 = -8.0_real64
    qtop = 7.0_real64
    qbot = -7.0_real64
    fldecdt = .true.
    numbit = 99
  end subroutine seed_legacy_sentinels

  subroutine capture_legacy(sh, st, shm1, stm1, sp, sg, spm1, sgm1, sqt, sqb, sfd, sn)
    real(real64), intent(out) :: sh(:), st(:), shm1(:), stm1(:)
    real(real64), intent(out) :: sp, sg, spm1, sgm1, sqt, sqb
    logical, intent(out) :: sfd
    integer, intent(out) :: sn
    sh = h
    st = theta
    shm1 = hm1
    stm1 = thetm1
    sp = pond
    sg = gwl
    spm1 = pondm1
    sgm1 = gwlm1
    sqt = qtop
    sqb = qbot
    sfd = fldecdt
    sn = numbit
  end subroutine capture_legacy

  subroutine expect_legacy_restored(sh, st, shm1, stm1, sp, sg, spm1, sgm1, sqt, sqb, sfd, sn, fails)
    real(real64), intent(in) :: sh(:), st(:), shm1(:), stm1(:)
    real(real64), intent(in) :: sp, sg, spm1, sgm1, sqt, sqb
    logical, intent(in) :: sfd
    integer, intent(in) :: sn
    integer, intent(inout) :: fails
    call expect(near_vector(h, sh), fails)
    call expect(near_vector(theta, st), fails)
    call expect(near_vector(hm1, shm1), fails)
    call expect(near_vector(thetm1, stm1), fails)
    call expect(near_scalar(pond, sp), fails)
    call expect(near_scalar(gwl, sg), fails)
    call expect(near_scalar(pondm1, spm1), fails)
    call expect(near_scalar(gwlm1, sgm1), fails)
    call expect(near_scalar(qtop, sqt), fails)
    call expect(near_scalar(qbot, sqb), fails)
    call expect(fldecdt .eqv. sfd, fails)
    call expect(numbit == sn, fails)
  end subroutine expect_legacy_restored

  subroutine expect_same_candidate(a, b, fails)
    type(soil_water_solve_result_t), intent(in) :: a, b
    integer, intent(inout) :: fails
    call expect(a%status == b%status, fails)
    call expect(near_vector(a%candidate_state%pressure_head, b%candidate_state%pressure_head), fails)
    call expect(near_vector(a%candidate_state%water_content, b%candidate_state%water_content), fails)
    call expect(near_scalar(a%candidate_state%ponding_depth, b%candidate_state%ponding_depth), fails)
    call expect(near_scalar(a%candidate_state%groundwater_level, b%candidate_state%groundwater_level), fails)
    call expect(near_scalar(a%top_flux, b%top_flux), fails)
    call expect(near_scalar(a%bottom_flux, b%bottom_flux), fails)
  end subroutine expect_same_candidate

  logical function near_scalar(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    near_scalar = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function near_scalar

  logical function near_vector(a, b)
    real(real64), intent(in) :: a(:), b(:)
    integer :: i
    near_vector = size(a) == size(b)
    if (.not. near_vector) return
    do i = 1, size(a)
       if (.not. near_scalar(a(i), b(i))) then
          near_vector = .false.
          return
       end if
    end do
  end function near_vector

  subroutine expect(condition, fails)
    logical, intent(in) :: condition
    integer, intent(inout) :: fails
    if (.not. condition) fails = fails + 1
  end subroutine expect

end program test_fsi03_reference_binding
