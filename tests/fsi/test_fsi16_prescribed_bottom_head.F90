program test_fsi16_prescribed_bottom_head
  use, intrinsic :: ieee_arithmetic, only: ieee_is_nan, ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use variables
  use mod_soil_water_solver_contract
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  implicit none

  type(soil_water_parameter_set_t), target :: kernel_params
  type(b110_default_mvg_parameters_t), target :: hydraulic_params
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_root_sink_provider_t), target :: root_sink
  type(fsi07_flux_top_provider_t), target :: top_provider
  type(soil_water_solve_request_t) :: request_a, request_b, request_c, rejected
  type(soil_water_solve_result_t) :: result_a, result_b, result_c, reject_result
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  real(real64), target :: drainage(2,numnod), irrigation(numnod), zero_root(numnod), roots(numnod)
  real(real64) :: head_value, expected_qbot, qnan, head_tolerance
  integer(int64) :: request_a_before, request_b_before, request_c_before
  integer :: mode, failures, calls_before

  failures = 0
  call seed_fixture()
  call configure_kernel_parameters()
  call configure_providers(head_value)
  call make_request(request_a, head_value, 123.456_real64)
  call make_request(request_b, head_value, -987.654_real64)
  request_c = request_a
  request_c%boundary%bottom_head = head_value + 0.01_real64
  request_c%boundary%bottom_flux = 314.159_real64
  request_a_before = request_fingerprint(request_a)
  request_b_before = request_fingerprint(request_b)
  request_c_before = request_fingerprint(request_c)

  ! After request construction these legacy lower-boundary duplicates are poison.
  ! The explicit common route must not recover authority from them.
  qnan = ieee_value(0.0_real64, ieee_quiet_nan)
  swbotb = 3
  hbot = qnan
  gwlinp = qnan
  qbot = qnan

  call prepare_workspace(workspace)
  call solver%solve(request_a, workspace, result_a)
  if (result_a%status /= SW_SOLVE_CONVERGED) failures = failures + 1
  if (trim(result_a%diagnostics%route) /= 'legacy-reference-bound') failures = failures + 1
  expected_qbot = continuity_qbot(request_a, result_a)
  if (transfer(result_a%bottom_flux,0_int64) /= transfer(expected_qbot,0_int64)) failures = failures + 1
  if (transfer(result_a%bottom_flux,0_int64) == transfer(request_a%boundary%bottom_flux,0_int64)) failures = failures + 1

  call prepare_workspace(workspace)
  call solver%solve(request_b, workspace, result_b)
  if (result_b%status /= SW_SOLVE_CONVERGED) failures = failures + 1
  if (transfer(result_b%bottom_flux,0_int64) /= transfer(result_a%bottom_flux,0_int64)) failures = failures + 1
  if (.not. all(bitwise_same(result_b%candidate_state%pressure_head, result_a%candidate_state%pressure_head))) failures = failures + 1
  if (.not. all(bitwise_same(result_b%candidate_state%water_content, result_a%candidate_state%water_content))) failures = failures + 1

  ! A nontrivial prescribed-head perturbation must control the solved lower node.
  ! It starts from the same base state as request_a, so this checks boundary
  ! authority rather than merely replaying an already-satisfied boundary value.
  call prepare_workspace(workspace)
  call solver%solve(request_c, workspace, result_c)
  if (result_c%status /= SW_SOLVE_CONVERGED) failures = failures + 1
  if (trim(result_c%diagnostics%route) /= 'legacy-reference-bound') failures = failures + 1
  head_tolerance = max(1.0e-10_real64, 64.0_real64*epsilon(1.0_real64) * &
       max(1.0_real64, abs(request_c%boundary%bottom_head)))
  if (abs(result_c%candidate_state%pressure_head(numnod)-request_c%boundary%bottom_head) > head_tolerance) &
       failures = failures + 1
  if (transfer(result_c%candidate_state%pressure_head(numnod),0_int64) == &
      transfer(result_a%candidate_state%pressure_head(numnod),0_int64)) failures = failures + 1
  expected_qbot = continuity_qbot(request_c, result_c)
  if (transfer(result_c%bottom_flux,0_int64) /= transfer(expected_qbot,0_int64)) failures = failures + 1
  if (transfer(result_c%bottom_flux,0_int64) == transfer(request_c%boundary%bottom_flux,0_int64)) failures = failures + 1

  if (request_fingerprint(request_a) /= request_a_before) failures = failures + 1
  if (request_fingerprint(request_b) /= request_b_before) failures = failures + 1
  if (request_fingerprint(request_c) /= request_c_before) failures = failures + 1
  if (swbotb /= 3) failures = failures + 1
  if (.not. ieee_is_nan(hbot)) failures = failures + 1
  if (.not. ieee_is_nan(gwlinp)) failures = failures + 1
  if (.not. ieee_is_nan(qbot)) failures = failures + 1

  ! Modes not owned by F-SI16 remain fail closed before HeadCalc.
  do mode = 1, 9
     if (mode == 5 .or. mode == 7) cycle
     rejected = request_a
     rejected%boundary%bottom_mode = mode
     call prepare_workspace(workspace)
     calls_before = workspace%legacy_worker%diagnostics%headcalc_calls
     call solver%solve(rejected, workspace, reject_result)
     if (reject_result%status /= SW_SOLVE_FAILED) failures = failures + 1
     if (trim(reject_result%diagnostics%route) /= 'legacy-bottom-mode-deferred') failures = failures + 1
     if (workspace%legacy_worker%diagnostics%headcalc_calls /= calls_before) failures = failures + 1
  end do

  ! F-SI14 geometry remains NN-sized; the B1.10 lower face is derived from dz(NN).
  if (size(request_a%parameters%node_distance) /= numnod) failures = failures + 1
  if (size(request_b%parameters%node_distance) /= numnod) failures = failures + 1
  if (size(request_c%parameters%node_distance) /= numnod) failures = failures + 1

  if (failures /= 0) then
     write(*,'(A,I0)') 'F-SI16_PRESCRIBED_BOTTOM_HEAD FAIL failures=', failures
     error stop 1
  end if

  write(*,'(A,Z16.16)') 'F-SI16_QBOT_BITS ', transfer(result_a%bottom_flux,0_int64)
  write(*,'(A,Z16.16)') 'F-SI16_HEAD_BITS ', transfer(result_a%candidate_state%pressure_head(numnod),0_int64)
  write(*,'(A,Z16.16)') 'F-SI16_PERTURBED_HEAD_BITS ', transfer(result_c%candidate_state%pressure_head(numnod),0_int64)
  print *, 'F-SI16_BOTTOM_FLUX_SEED_INDEPENDENCE PASS'
  print *, 'F-SI16_BOTTOM_HEAD_RESPONSE PASS'
  print *, 'F-SI16_LEGACY_BOTTOM_GLOBAL_POISON PASS'
  print *, 'F-SI16_CONTINUITY_QBOT_IDENTITY PASS'
  print *, 'F-SI16_UNOWNED_BOTTOM_MODES_FAIL_CLOSED PASS'
  print *, 'F-SI16_DERIVED_BOTTOM_DISTANCE PASS'
  print *, 'F-SI16_PRESCRIBED_BOTTOM_HEAD_GATE PASS'

contains

  subroutine seed_fixture()
    swmacro = 0
    swbotb = 5
    swkimpl = 0
    swkmean = 1
    fldtmin = .false.
    fldaystart = .false.
    dt = 0.25_real64
    dtmin = 1.0e-6_real64
    maxit = 8
    maxbacktr = 4
    CritDevBalCp = 1.0e-12_real64
    CritDevBalTot = 1.0e-12_real64
    critdevh2cp = 1.0e-12_real64
    critdevh1cp = 1.0e-12_real64
    critdevponddt = 1.0e-12_real64
  end subroutine seed_fixture

  subroutine configure_kernel_parameters()
    kernel_params%parameter_set_id = 516_int64
    kernel_params%active_nodes = numnod
    allocate(kernel_params%z(numnod), kernel_params%dz(numnod), kernel_params%node_distance(numnod))
    kernel_params%z = z
    kernel_params%dz = dz
    kernel_params%node_distance = disnod(1:numnod)
  end subroutine configure_kernel_parameters

  subroutine configure_providers(reference_head)
    real(real64), intent(out) :: reference_head
    real(real64) :: input(24,numnod), heads(numnod), water(numnod), kval(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    input = 0.0_real64
    do i = 1, numnod
       input(1,i) = 0.032_real64
       input(2,i) = 0.423_real64
       input(3,i) = 4.75_real64
       input(4,i) = 0.0135_real64
       input(5,i) = 0.365_real64
       input(6,i) = 1.455_real64
       input(7,i) = 1.0_real64 - 1.0_real64/input(6,i)
       input(8,i) = input(4,i)
       input(9,i) = 0.0_real64
       input(10,i) = input(3,i)
       input(11,i) = 0.999_real64
       input(12,i) = 0.99_real64*input(3,i)
       input(22,i) = -1.0e6_real64
       input(23,i) = 1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_params, input)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_params, dt)

    do i = 1, numnod
       drainage(1,i) = scale(real(i,real64),-12)
       drainage(2,i) = -scale(real(i+1,real64),-14)
       roots(i) = scale(real(2*i+1,real64),-15)
       zero_root(i) = 0.0_real64
       irrigation(i) = drainage(1,i) + drainage(2,i) + roots(i)
    end do
    call bind_b110_source_sink_provider(source_sink, drainage, irrigation, zero_root)
    call bind_b110_root_sink_provider(root_sink, roots)

    reference_head = -75.0_real64
    heads = reference_head
    call constitutive%evaluate(heads, water, kval, capacity, dkdh)
    do i = 2, numnod
       if (transfer(kval(i),0_int64) /= transfer(kval(1),0_int64)) &
            error stop 'F-SI16 fixture requires uniform within-column conductivity'
    end do
    top_provider%fixed_flux = -kval(1)
    top_provider%surface_tracks_head = .true.
  end subroutine configure_providers

  subroutine make_request(request, reference_head, bottom_flux_seed)
    type(soil_water_solve_request_t), intent(out) :: request
    real(real64), intent(in) :: reference_head, bottom_flux_seed
    real(real64) :: heads(numnod), water(numnod), kval(numnod), capacity(numnod), dkdh(numnod)

    heads = reference_head
    call constitutive%evaluate(heads, water, kval, capacity, dkdh)
    request%parameters => kernel_params
    request%physical%macropore_active = .false.
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%root_sink => root_sink
    request%evaluation%top_boundary => top_provider
    request%step_duration = dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 5
    request%boundary%top_flux = top_provider%fixed_flux
    request%boundary%top_head = reference_head
    request%boundary%bottom_flux = bottom_flux_seed
    request%boundary%bottom_head = reference_head
    request%numerical%max_iterations = maxit
    request%numerical%max_backtracking = maxbacktr
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = swkmean
    request%numerical%min_step_duration = dtmin
    request%numerical%compartment_balance_tolerance = CritDevBalCp
    request%numerical%total_balance_tolerance = CritDevBalTot
    request%numerical%head_abs_tolerance = critdevh2cp
    request%numerical%head_rel_tolerance = critdevh1cp
    request%numerical%ponding_tolerance = critdevponddt
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%base_state%pressure_head = heads
    request%base_state%water_content = water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -2.0_real64
  end subroutine make_request

  subroutine prepare_workspace(ws)
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    call initialize_reference_workspace(ws%richards, numnod)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes = 0
    ws%legacy_worker%worker_id = 516
  end subroutine prepare_workspace

  real(real64) function continuity_qbot(request, result) result(value)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: result
    real(real64) :: sink_value
    integer :: i, level

    value = result%top_flux
    do i = 1, numnod
       sink_value = 0.0_real64
       do level = 1, size(drainage,1)
          sink_value = sink_value + drainage(level,i)
       end do
       value = value + request%parameters%dz(i) * &
            (result%candidate_state%water_content(i)-request%base_state%water_content(i)) / request%step_duration + &
            sink_value - irrigation(i) + roots(i)
    end do
  end function continuity_qbot

  integer(int64) function request_fingerprint(request) result(fp)
    type(soil_water_solve_request_t), intent(in) :: request
    integer :: i
    fp = 1469598103934665603_int64
    fp = ieor(fp, int(request%boundary%bottom_mode,int64))
    fp = ieor(fp, transfer(request%boundary%bottom_head,fp))
    fp = ieor(fp, transfer(request%boundary%bottom_flux,fp))
    do i = 1, numnod
       fp = ieor(fp, transfer(request%base_state%pressure_head(i),fp))
       fp = ieor(fp, transfer(request%base_state%water_content(i),fp))
    end do
  end function request_fingerprint

  elemental logical function bitwise_same(a,b)
    real(real64), intent(in) :: a,b
    bitwise_same = transfer(a,0_int64) == transfer(b,0_int64)
  end function bitwise_same

end program test_fsi16_prescribed_bottom_head
