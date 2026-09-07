program test_fsi09_b110_common_parallel
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use omp_lib, only: omp_get_max_threads, omp_get_thread_num
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use MOD_drain, only: qdra
  use MOD_irrigation, only: qssdi
  use variables
  use mod_soil_water_solver_contract
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  type(soil_water_parameter_set_t), target :: kernel_params
  type(b110_default_mvg_parameters_t), target :: hydraulic_params(8)
  type(b110_default_mvg_provider_t), target :: constitutive(8)
  type(fsi08_source_sink_provider_t), target :: source_sink(8)
  type(fsi07_flux_top_provider_t), target :: top_provider(8)
  type(soil_water_solve_request_t), allocatable :: requests(:)
  type(soil_water_solve_result_t), allocatable :: serial_results(:), parallel_results(:)
  type(reference_richards_legacy_solver_t), allocatable :: serial_solvers(:), parallel_solvers(:)
  type(reference_richards_legacy_workspace_t), allocatable :: serial_ws(:), parallel_ws(:)
  integer(int64), allocatable :: request_before(:), serial_fp(:), parallel_fp(:)
  integer(int64) :: globals_before, fp_a1, fp_a2
  integer :: nthreads, i, failures

  nthreads = omp_get_max_threads()
  if (.not. any(nthreads == [1,2,4,8])) error stop 'F-SI09 requires 1/2/4/8 workers'
  failures = 0
  call seed_shared_fixture()
  call configure_kernel_parameters()
  call configure_constitutive_providers()
  globals_before = global_state_fingerprint()

  allocate(requests(nthreads), serial_results(nthreads), parallel_results(nthreads))
  allocate(serial_solvers(nthreads), parallel_solvers(nthreads), serial_ws(nthreads), parallel_ws(nthreads))
  allocate(request_before(nthreads), serial_fp(nthreads), parallel_fp(nthreads))
  do i = 1, nthreads
     call make_request(requests(i), i)
     request_before(i) = request_fingerprint(requests(i))
  end do

  call run_serial_baseline(failures)
  call run_parallel(failures)
  call run_aba(failures, fp_a1, fp_a2)

  if (global_state_fingerprint() /= globals_before) failures = failures + 1
  do i = 1, nthreads
     if (request_fingerprint(requests(i)) /= request_before(i)) failures = failures + 1
  end do

  if (failures /= 0) then
     write(*,'(A,I0)') 'F-SI09_B110_COMMON_ROUTE FAIL failures=', failures
     error stop 1
  end if
  write(*,'(A,I0,A)') 'F-SI09_B110_COMMON_ROUTE_', nthreads, '_PASS'

contains

  subroutine configure_kernel_parameters()
    kernel_params%parameter_set_id = 4909_int64
    kernel_params%active_nodes = numnod
    allocate(kernel_params%z(numnod), kernel_params%dz(numnod), kernel_params%node_distance(numnod))
    kernel_params%z = z
    kernel_params%dz = dz
    kernel_params%node_distance = disnod(1:numnod)
  end subroutine configure_kernel_parameters

  subroutine configure_constitutive_providers()
    real(real64) :: input(24,numnod)
    integer :: column, node
    do column = 1, 8
       input = 0.0_real64
       do node = 1, numnod
          input(1,node) = 0.030_real64 + 0.002_real64*real(column,real64)
          input(2,node) = 0.420_real64 + 0.003_real64*real(column,real64)
          input(3,node) = 4.000_real64 + 0.750_real64*real(column,real64)
          input(4,node) = 0.012_real64 + 0.0015_real64*real(column,real64)
          input(5,node) = 0.35_real64 + 0.015_real64*real(column,real64)
          input(6,node) = 1.42_real64 + 0.035_real64*real(column,real64)
          input(7,node) = 1.0_real64 - 1.0_real64/input(6,node)
          input(8,node) = input(4,node)
          input(9,node) = 0.0_real64
          input(10,node) = input(3,node)
          input(11,node) = 0.999_real64
          input(12,node) = 0.99_real64*input(3,node)
          input(22,node) = -1.0e6_real64
          input(23,node) = 1.0e-12_real64
       end do
       call initialize_b110_default_mvg_parameters(hydraulic_params(column), input)
       call bind_b110_default_mvg_provider(constitutive(column), hydraulic_params(column), dt)
       source_sink(column)%source_value = 0.0_real64
       source_sink(column)%sink_value = 0.0_real64
       top_provider(column)%surface_tracks_head = .true.
    end do
  end subroutine configure_constitutive_providers

  subroutine seed_shared_fixture()
    swmacro = 0; swbotb = 7; swkimpl = 0; swkmean = 1; fldtmin = .false.; fldaystart = .false.
    maxit = 8; maxbacktr = 4
    CritDevBalCp = 1.0e-12_real64; CritDevBalTot = 1.0e-12_real64
    critdevh2cp = 1.0e-12_real64; critdevh1cp = 1.0e-12_real64; critdevponddt = 1.0e-12_real64
    h = -999.0_real64; theta = 0.41_real64; hm1 = -888.0_real64; thetm1 = 0.42_real64
    pond = 9.0_real64; pondm1 = 8.0_real64; gwl = -9.0_real64; gwlm1 = -8.0_real64
    gwlinp = -77.0_real64; qtop = 7.0_real64; qbot = -7.0_real64; hbot = -99.0_real64
    dtold = 0.125_real64; runots = 5.0_real64; k = 11.0_real64; kmean = 12.0_real64; dimoca = 13.0_real64
    itnumb = 3; numbit = 99; fllowgwl = .true.; fldecdt = .true.
    q0 = 6.0_real64; hsurf = 0.4_real64; flrunoff = .true.; ftoph = .true.
    qdra = 1000000.0_real64
    qssdi = -2000000.0_real64
    qrot = 3000000.0_real64
  end subroutine seed_shared_fixture

  subroutine make_request(request, column)
    type(soil_water_solve_request_t), intent(out) :: request
    integer, intent(in) :: column
    integer :: node
    real(real64) :: head_value
    real(real64) :: heads(numnod), water(numnod), kval(numnod), capacity(numnod), dkdh(numnod)

    head_value = -50.0_real64 - 25.0_real64*real(column,real64)
    heads = head_value
    call constitutive(column)%evaluate(heads, water, kval, capacity, dkdh)
    do node = 2, numnod
       if (transfer(kval(node),0_int64) /= transfer(kval(1),0_int64)) &
            error stop 'F-SI09 fixture requires bitwise uniform within-column K'
    end do

    top_provider(column)%fixed_flux = -kval(1)
    request%parameters => kernel_params
    request%evaluation%constitutive => constitutive(column)
    request%evaluation%source_sink => source_sink(column)
    request%evaluation%top_boundary => top_provider(column)
    request%step_duration = dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 7
    request%boundary%top_flux = -kval(1)
    request%boundary%top_head = head_value
    request%boundary%bottom_flux = -kval(1)
    request%boundary%bottom_head = -100.0_real64
    request%numerical%max_iterations = maxit
    request%numerical%max_backtracking = maxbacktr
    request%numerical%conductivity_implicit_mode = swkimpl
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
    request%base_state%ponding_depth = 0.001_real64*real(column,real64)
    request%base_state%groundwater_level = -2.0_real64 - 0.1_real64*real(column,real64)
  end subroutine make_request

  subroutine prepare_workspace(ws, column)
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    integer, intent(in) :: column
    call initialize_reference_workspace(ws%richards, numnod)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes = 0
    ws%legacy_worker%worker_id = column
  end subroutine prepare_workspace

  subroutine run_serial_baseline(fails)
    integer, intent(inout) :: fails
    integer :: j
    real(real64) :: residual
    do j = 1, nthreads
       call prepare_workspace(serial_ws(j), j)
       call serial_solvers(j)%solve(requests(j), serial_ws(j), serial_results(j))
       serial_fp(j) = result_fingerprint(serial_results(j), serial_ws(j))
       if (serial_results(j)%status /= SW_SOLVE_CONVERGED) fails = fails + 1
       if (trim(serial_results(j)%diagnostics%route) /= 'legacy-reference-bound') fails = fails + 1
       if (.not. same_real(serial_results(j)%top_flux, requests(j)%boundary%top_flux)) fails = fails + 1
       if (.not. same_real(serial_results(j)%bottom_flux, requests(j)%boundary%bottom_flux)) fails = fails + 1
       if (.not. all(same_vector(serial_results(j)%candidate_state%water_content, &
            requests(j)%base_state%water_content))) fails = fails + 1
       if (serial_results(j)%diagnostics%nonlinear_iterations /= 1) fails = fails + 1
       residual = focused_residual(requests(j), serial_results(j))
       if (.not. ieee_is_finite(residual) .or. abs(residual) > 16.0_real64*epsilon(1.0_real64)) fails = fails + 1
       if (request_fingerprint(requests(j)) /= request_before(j)) fails = fails + 1
    end do
  end subroutine run_serial_baseline

  subroutine run_parallel(fails)
    integer, intent(inout) :: fails
    integer :: j
    do j = 1, nthreads
       call prepare_workspace(parallel_ws(j), j)
    end do
!$omp parallel default(shared) private(j)
    j = omp_get_thread_num() + 1
    if (j <= nthreads) call parallel_solvers(j)%solve(requests(j), parallel_ws(j), parallel_results(j))
!$omp end parallel
    do j = 1, nthreads
       parallel_fp(j) = result_fingerprint(parallel_results(j), parallel_ws(j))
       if (parallel_fp(j) /= serial_fp(j)) fails = fails + 1
       if (request_fingerprint(requests(j)) /= request_before(j)) fails = fails + 1
    end do
  end subroutine run_parallel

  subroutine run_aba(fails, first_fp, second_fp)
    integer, intent(inout) :: fails
    integer(int64), intent(out) :: first_fp, second_fp
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    type(soil_water_solve_result_t) :: a1, b, a2
    call prepare_workspace(ws, 1)
    call solver%solve(requests(1), ws, a1)
    first_fp = result_fingerprint(a1, ws)
    if (nthreads >= 2) then
       call prepare_workspace(ws, 2)
       call solver%solve(requests(2), ws, b)
    end if
    call prepare_workspace(ws, 1)
    call solver%solve(requests(1), ws, a2)
    second_fp = result_fingerprint(a2, ws)
    if (first_fp /= second_fp) fails = fails + 1
  end subroutine run_aba

  real(real64) function focused_residual(request, result) result(residual)
    type(soil_water_solve_request_t), intent(in) :: request
    type(soil_water_solve_result_t), intent(in) :: result
    residual = sum(dz*(result%candidate_state%water_content-request%base_state%water_content)) + &
         result%top_flux - result%bottom_flux
  end function focused_residual

  integer(int64) function result_fingerprint(result, ws) result(fp)
    type(soil_water_solve_result_t), intent(in) :: result
    type(reference_richards_legacy_workspace_t), intent(in) :: ws
    integer :: j
    fp = 1469598103934665603_int64
    do j = 1, numnod
       fp = ieor(fp, transfer(result%candidate_state%pressure_head(j), fp))
       fp = ieor(fp, transfer(result%candidate_state%water_content(j), fp))
    end do
    fp = ieor(fp, transfer(result%top_flux, fp)); fp = ieor(fp, transfer(result%bottom_flux, fp))
    fp = ieor(fp, int(result%status,int64)); fp = ieor(fp, int(ws%legacy_worker%control%last_numbit,int64))
    fp = ieor(fp, int(result%diagnostics%nonlinear_iterations,int64))
    fp = ieor(fp, int(result%diagnostics%jacobian_builds,int64)); fp = ieor(fp, int(result%diagnostics%linear_solves,int64))
  end function result_fingerprint

  integer(int64) function request_fingerprint(request) result(fp)
    type(soil_water_solve_request_t), intent(in) :: request
    integer :: j
    fp = 1469598103934665603_int64
    do j = 1, numnod
       fp = ieor(fp, transfer(request%base_state%pressure_head(j), fp))
       fp = ieor(fp, transfer(request%base_state%water_content(j), fp))
    end do
    fp = ieor(fp, transfer(request%boundary%top_flux, fp)); fp = ieor(fp, transfer(request%boundary%bottom_flux, fp))
  end function request_fingerprint

  integer(int64) function global_state_fingerprint() result(fp)
    integer :: j
    fp = 1469598103934665603_int64
    do j = 1, numnod
       fp = ieor(fp, transfer(h(j), fp)); fp = ieor(fp, transfer(theta(j), fp)); fp = ieor(fp, transfer(qrot(j), fp))
       fp = ieor(fp, transfer(qssdi(j), fp)); fp = ieor(fp, transfer(qdra(1,j), fp))
    end do
    fp = ieor(fp, transfer(qtop, fp)); fp = ieor(fp, transfer(qbot, fp)); fp = ieor(fp, int(numbit,int64))
  end function global_state_fingerprint

  elemental logical function same_vector(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    same_vector = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function same_vector

  logical function same_real(a, b)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    scale = max(1.0_real64, abs(a), abs(b))
    same_real = abs(a-b) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function same_real

end program test_fsi09_b110_common_parallel
