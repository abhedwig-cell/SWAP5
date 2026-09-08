program test_lmfp05_refined_fullrichards_reference
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: max_nodes => numnod
  use MOD_swap_base, only: swmacro
  use MOD_top, only: q0, flrunoff, ftoph, hsurf
  use MOD_drain, only: qdra
  use MOD_irrigation, only: qssdi
  use variables
  use mod_soil_water_solver_contract
  use mod_reference_richards_workspace, only: initialize_reference_workspace, poison_reference_workspace
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_fsi07_top_provider, only: fsi07_flux_top_provider_t
  use mod_fsi08_provider_fixture, only: fsi08_source_sink_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  integer, parameter :: ngrids = 5
  integer, parameter :: grid_nodes(ngrids) = [4, 6, 12, 24, 48]
  integer :: case_id, igrid, temporal_ref, failures

  if (max_nodes < 48) error stop 'F-LMFP05 fixture requires capacity for at least 48 nodes'
  failures = 0
  call seed_shared_fixture()

  do case_id = 1, 3
     do igrid = 1, ngrids
        do temporal_ref = 1, 2
           call run_case(case_id, grid_nodes(igrid), temporal_ref, failures)
        end do
     end do
  end do

  if (failures /= 0) then
     write(*,'(A,1X,I0)') 'F-LMFP05_REFINED_FULLRICHARDS_FAIL', failures
     error stop 1
  end if
  write(*,'(A)') 'F-LMFP05_REFINED_FULLRICHARDS_PASS'

contains

  subroutine seed_shared_fixture()
    swmacro = 0
    swbotb = 7
    swkimpl = 0
    swkmean = 1
    fldtmin = .false.
    fldaystart = .false.
    maxit = 40
    maxbacktr = 16
    dtmin = 1.0e-10_real64
    CritDevBalCp = 1.0e-11_real64
    CritDevBalTot = 1.0e-11_real64
    critdevh2cp = 1.0e-9_real64
    critdevh1cp = 1.0e-9_real64
    critdevponddt = 1.0e-11_real64
    q0 = 0.0_real64
    hsurf = 0.0_real64
    flrunoff = .false.
    ftoph = .false.
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    pond = 0.0_real64
    pondm1 = 0.0_real64
    gwl = -999.0_real64
    gwlm1 = -999.0_real64
    fllowgwl = .false.
    fldecdt = .false.
    itnumb = 0
    numbit = 0
  end subroutine seed_shared_fixture

  subroutine fill_material(code, input, node)
    integer, intent(in) :: code, node
    real(real64), intent(inout) :: input(:,:)
    real(real64) :: tr, ts, ks, alpha, lambda, nn, mm
    select case(code)
    case(1)
       tr = 0.045_real64; ts = 0.430_real64; ks = 20.0_real64
       alpha = 0.040_real64; lambda = 0.50_real64; nn = 1.80_real64
    case(2)
       tr = 0.080_real64; ts = 0.500_real64; ks = 0.20_real64
       alpha = 0.010_real64; lambda = 0.50_real64; nn = 1.30_real64
    case default
       error stop 'unknown F-LMFP05 material code'
    end select
    mm = 1.0_real64 - 1.0_real64/nn
    input(1,node) = tr
    input(2,node) = ts
    input(3,node) = ks
    input(4,node) = alpha
    input(5,node) = lambda
    input(6,node) = nn
    input(7,node) = mm
    input(8,node) = alpha
    input(9,node) = 0.0_real64
    input(10,node) = ks
    input(11,node) = 0.999_real64
    input(12,node) = 0.99_real64*ks
    input(22,node) = -1.0e6_real64
    input(23,node) = 1.0e-12_real64
  end subroutine fill_material

  real(real64) function anchor_head(case_id, depth) result(head)
    integer, intent(in) :: case_id
    real(real64), intent(in) :: depth
    real(real64) :: d(4), hv(4), slope
    integer :: j
    d = [5.0_real64, 15.0_real64, 30.0_real64, 50.0_real64]
    select case(case_id)
    case(1)
       hv = [-200.0_real64, -120.0_real64, -60.0_real64, -30.0_real64]
    case(2,3)
       hv = [-150.0_real64, -100.0_real64, -70.0_real64, -50.0_real64]
    case default
       error stop 'unknown F-LMFP05 profile case'
    end select
    if (depth <= d(1)) then
       slope = (hv(2)-hv(1))/(d(2)-d(1))
       head = hv(1) + slope*(depth-d(1))
       return
    end if
    if (depth >= d(4)) then
       slope = (hv(4)-hv(3))/(d(4)-d(3))
       head = hv(4) + slope*(depth-d(4))
       return
    end if
    do j = 1, 3
       if (depth >= d(j) .and. depth <= d(j+1)) then
          slope = (hv(j+1)-hv(j))/(d(j+1)-d(j))
          head = hv(j) + slope*(depth-d(j))
          return
       end if
    end do
    error stop 'F-LMFP05 interpolation failure'
  end function anchor_head

  subroutine make_grid(case_id, n, dzx, depth, zx, node_distance, heads, codes)
    integer, intent(in) :: case_id, n
    real(real64), intent(out) :: dzx(n), depth(n), zx(n), node_distance(n), heads(n)
    integer, intent(out) :: codes(n)
    real(real64) :: width
    integer :: i

    if (n == 4) then
       dzx = [10.0_real64, 10.0_real64, 20.0_real64, 20.0_real64]
       depth = [5.0_real64, 15.0_real64, 30.0_real64, 50.0_real64]
       node_distance = [5.0_real64, 10.0_real64, 15.0_real64, 20.0_real64]
    else
       width = 60.0_real64/real(n,real64)
       dzx = width
       do i = 1, n
          depth(i) = (real(i,real64)-0.5_real64)*width
       end do
       node_distance(1) = 0.5_real64*width
       if (n > 1) node_distance(2:n) = width
    end if
    zx = -depth
    do i = 1, n
       heads(i) = anchor_head(case_id, depth(i))
       select case(case_id)
       case(1)
          codes(i) = 1
       case(2)
          if (depth(i) < 20.0_real64) then
             codes(i) = 1
          else
             codes(i) = 2
          end if
       case(3)
          if (depth(i) < 20.0_real64) then
             codes(i) = 2
          else
             codes(i) = 1
          end if
       end select
    end do
  end subroutine make_grid

  subroutine initialize_request(request, params, constitutive, source_sink, top_provider, heads, step_dt)
    type(soil_water_solve_request_t), intent(out) :: request
    type(soil_water_parameter_set_t), target, intent(in) :: params
    type(b110_default_mvg_provider_t), target, intent(in) :: constitutive
    type(fsi08_source_sink_provider_t), target, intent(in) :: source_sink
    type(fsi07_flux_top_provider_t), target, intent(in) :: top_provider
    real(real64), intent(in) :: heads(:), step_dt
    real(real64), allocatable :: water(:), kval(:), cap(:), dk(:)
    integer :: n
    n = size(heads)
    allocate(water(n), kval(n), cap(n), dk(n))
    call constitutive%evaluate(heads, water, kval, cap, dk)
    request%parameters => params
    request%evaluation%constitutive => constitutive
    request%evaluation%source_sink => source_sink
    request%evaluation%top_boundary => top_provider
    request%step_duration = step_dt
    request%boundary%top_mode = FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode = 7
    request%boundary%top_flux = 0.0_real64
    request%boundary%top_head = heads(1)
    request%boundary%bottom_flux = 0.0_real64
    request%boundary%bottom_head = 0.0_real64
    request%numerical%max_iterations = 40
    request%numerical%max_backtracking = 16
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-10_real64
    request%numerical%compartment_balance_tolerance = 1.0e-11_real64
    request%numerical%total_balance_tolerance = 1.0e-11_real64
    request%numerical%head_abs_tolerance = 1.0e-9_real64
    request%numerical%head_rel_tolerance = 1.0e-9_real64
    request%numerical%ponding_tolerance = 1.0e-11_real64
    request%base_state%active_nodes = n
    allocate(request%base_state%pressure_head(n), request%base_state%water_content(n))
    request%base_state%pressure_head = heads
    request%base_state%water_content = water
    request%base_state%ponding_depth = 0.0_real64
    request%base_state%groundwater_level = -999.0_real64
  end subroutine initialize_request

  subroutine run_case(case_id, n, temporal_ref, fails)
    integer, intent(in) :: case_id, n, temporal_ref
    integer, intent(inout) :: fails
    real(real64), allocatable :: dzx(:), depth(:), zx(:), node_distance(:), heads(:)
    real(real64), allocatable :: water0(:), kval(:), cap(:), dk(:)
    real(real64), allocatable :: input(:,:)
    integer, allocatable :: codes(:)
    real(real64) :: step_dt, initial_storage, final_storage, residual, delta_storage, bottom_down
    integer :: i
    character(len=32) :: name
    type(soil_water_parameter_set_t), target :: params
    type(b110_default_mvg_parameters_t), target :: hydraulic_params
    type(b110_default_mvg_provider_t), target :: constitutive
    type(fsi08_source_sink_provider_t), target :: source_sink
    type(fsi07_flux_top_provider_t), target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: ws
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result

    if (n > max_nodes) error stop 'F-LMFP05 active grid exceeds fixture capacity'
    allocate(dzx(n), depth(n), zx(n), node_distance(n), heads(n), codes(n))
    allocate(water0(n), kval(n), cap(n), dk(n), input(24,n))
    call make_grid(case_id, n, dzx, depth, zx, node_distance, heads, codes)
    select case(case_id)
    case(1); name = 'redistribution_sand'
    case(2); name = 'sand_over_clay'
    case(3); name = 'clay_over_sand'
    end select

    step_dt = 2.0e-4_real64/real(temporal_ref,real64)
    params%parameter_set_id = 4310500 + 100*case_id + n
    params%active_nodes = n
    allocate(params%z(n), params%dz(n), params%node_distance(n))
    params%z = zx
    params%dz = dzx
    params%node_distance = node_distance

    input = 0.0_real64
    do i = 1, n
       call fill_material(codes(i), input, i)
    end do
    call initialize_b110_default_mvg_parameters(hydraulic_params, input)
    call bind_b110_default_mvg_provider(constitutive, hydraulic_params, step_dt)
    call constitutive%evaluate(heads, water0, kval, cap, dk)

    source_sink%source_value = 0.0_real64
    source_sink%sink_value = 0.0_real64
    top_provider%fixed_flux = 0.0_real64
    top_provider%surface_tracks_head = .true.
    call initialize_request(request, params, constitutive, source_sink, top_provider, heads, step_dt)

    initial_storage = sum(dzx*request%base_state%water_content)
    call initialize_reference_workspace(ws%richards, n)
    call poison_reference_workspace(ws%richards)
    ws%legacy_worker%active_nodes = 0
    ws%legacy_worker%worker_id = 43105
    call solver%solve(request, ws, result)

    if (result%status /= SW_SOLVE_CONVERGED) then
       fails = fails + 1
       write(*,'(A,1X,I0,1X,I0,1X,I0,1X,A)') 'RETRY_OR_FAIL', case_id, n, temporal_ref, trim(result%diagnostics%route)
       return
    end if
    if (result%diagnostics%alternative_solver_calls /= 0) then
       fails = fails + 1
       write(*,'(A,1X,I0,1X,I0,1X,I0)') 'BANDED_FALLBACK_USED', case_id, n, temporal_ref
       return
    end if
    if (.not. all(ieee_is_finite(result%candidate_state%pressure_head)) .or. &
        .not. all(ieee_is_finite(result%candidate_state%water_content))) then
       fails = fails + 1
       return
    end if

    delta_storage = sum(dzx*(result%candidate_state%water_content-request%base_state%water_content))
    residual = delta_storage + step_dt*(result%top_flux-result%bottom_flux)
    final_storage = sum(dzx*result%candidate_state%water_content)
    bottom_down = -result%bottom_flux

    write(*,'(A,1X,I0,1X,I0,1X,I0,1X,A,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,I0)') &
         'RUN', case_id, n, temporal_ref, trim(name), step_dt, initial_storage, final_storage, bottom_down, &
         result%diagnostics%nonlinear_iterations
    write(*,'(A,1X,I0,1X,I0,1X,I0,1X,ES24.16)') 'MASS', case_id, n, temporal_ref, residual
    do i = 1, n
       write(*,'(A,1X,I0,1X,I0,1X,I0,1X,I0,1X,I0,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16,1X,ES24.16)') &
            'NODE', case_id, n, temporal_ref, i, codes(i), depth(i), dzx(i), heads(i), water0(i), &
            result%candidate_state%pressure_head(i), result%candidate_state%water_content(i)
    end do
  end subroutine run_case

end program test_lmfp05_refined_fullrichards_reference
