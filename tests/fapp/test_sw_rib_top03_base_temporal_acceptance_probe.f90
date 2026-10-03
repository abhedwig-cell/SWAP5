! Research-only exact FAPP09 BASE temporal acceptance probe.
! No kernel acceptance, receipt, commit or production source is changed here.
program top03_base_temporal_acceptance_probe
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  use mod_fmr_top_surface_exchange, only: fmr_top_surface_exchange_t, materialize_fmr_top_surface_exchange, &
       FMR_TOP_EXCHANGE_OK
  implicit none

  type path_result_t
    logical :: complete = .false.
    integer :: stop_step = 0
    integer :: solver_status = 0
    integer :: nonlinear_iterations = 0
    real(real64) :: top_transfer_cm = 0.0_real64
    real(real64) :: bottom_transfer_cm = 0.0_real64
    real(real64) :: storage_change_cm = 0.0_real64
    real(real64) :: ledger_residual_cm = huge(0.0_real64)
    real(real64) :: max_soil_mass_residual_cm = 0.0_real64
    real(real64) :: ponding_cm = 0.0_real64
    real(real64) :: groundwater_level_cm = 0.0_real64
    real(real64), allocatable :: pressure_head(:)
    real(real64), allocatable :: water_content(:)
  end type path_result_t

  type(soil_water_parameter_set_t), target :: params
  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t), target :: hyd
  type(b110_source_sink_provider_t), target :: source
  type(b110_dynamic_top_boundary_solver_provider_t), target :: top
  type(reference_richards_legacy_solver_t) :: solver
  type(soil_water_solve_request_t) :: request
  type(path_result_t) :: paths(8)
  real(real64), allocatable, target :: qdra(:,:), qssdi(:), qrot(:)
  real(real64) :: cofgen(24,numnod), h0(numnod), theta0(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
  real(real64), parameter :: initial_head_cm = -123.0_real64
  real(real64), parameter :: initial_ponding_cm = 0.0_real64
  real(real64), parameter :: initial_gwl_cm = -2.25_real64
  real(real64), parameter :: external_head_cm = 0.02_real64
  real(real64), parameter :: external_sill_cm = 0.01_real64
  real(real64), parameter :: soil_mass_tol_cm = 1.0e-10_real64
  real(real64), parameter :: surface_closure_tol_cm = 1.0e-12_real64
  real(real64), parameter :: ledger_tol_cm = 1.0e-10_real64
  real(real64), parameter :: horizons(4) = [0.25_real64, 0.125_real64, 0.0625_real64, 0.03125_real64]
  integer, parameter :: refinements(8) = [1,2,4,8,16,32,64,128]
  real(real64) :: bottom_rate
  real(real64) :: transition_width_cm
  character(len=64) :: width_argument
  integer :: i, j

  transition_width_cm = 0.0_real64
  call get_command_argument(1,width_argument)
  if (len_trim(width_argument) > 0) then
    read(width_argument,*,iostat=i) transition_width_cm
    if (i /= 0) error stop 'invalid optional near-saturation transition width'
  end if
  if (.not.ieee_is_finite(transition_width_cm) .or. transition_width_cm < 0.0_real64) &
       error stop 'invalid optional near-saturation transition width'

  call initialize_fixture(transition_width_cm)

  write(*,'(A)') 'TOP03_BASE_TEMPORAL_PROBE_VERSION=4'
  write(*,'(A,1X,ES24.16)') 'TOP03_BASE_TEMPORAL_TRANSITION_WIDTH_CM=',transition_width_cm
  do i = 1, size(horizons)
    do j = 1, size(refinements)
      call run_path(horizons(i), refinements(j), paths(j))
      call print_path(horizons(i), refinements(j), paths(j))
    end do
    do j = 1, size(refinements)-1
      call print_pair(horizons(i), refinements(j), refinements(j+1), paths(j), paths(j+1))
    end do
  end do
  write(*,'(A)') 'TOP03_BASE_TEMPORAL_PROBE=COMPLETED'

contains

  subroutine initialize_fixture(transition_width)
    real(real64), intent(in) :: transition_width
    integer :: k

    allocate(params%z(numnod), params%dz(numnod), params%node_distance(numnod))
    params%parameter_set_id = 49009_int64
    params%active_nodes = numnod
    params%z = z
    params%dz = dz
    params%node_distance = disnod(1:numnod)

    cofgen = 0.0_real64
    do k = 1, numnod
      cofgen(1,k)=0.032_real64
      cofgen(2,k)=0.423_real64
      cofgen(3,k)=4.75_real64
      cofgen(4,k)=0.0135_real64
      cofgen(5,k)=0.365_real64
      cofgen(6,k)=1.455_real64
      cofgen(7,k)=1.0_real64-1.0_real64/cofgen(6,k)
      cofgen(8,k)=cofgen(4,k)
      cofgen(9,k)=0.0_real64
      cofgen(10,k)=cofgen(3,k)
      cofgen(11,k)=0.999_real64
      cofgen(12,k)=0.99_real64*cofgen(3,k)
      cofgen(22,k)=-1.0e6_real64
      cofgen(23,k)=1.0e-12_real64
    end do

    call initialize_b110_default_mvg_parameters(hp,cofgen, &
         near_saturation_transition_width_cm=transition_width)
    call bind_b110_default_mvg_provider(hyd,hp,0.25_real64)
    h0 = initial_head_cm
    call hyd%evaluate(h0,theta0,conductivity,capacity,dkdh)
    bottom_rate = -conductivity(1)

    allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
    qdra = 0.0_real64
    qssdi = 0.0_real64
    qrot = 0.0_real64
    call bind_b110_source_sink_provider(source,qdra,qssdi,qrot)

    request%parameters => params
    request%base_state%active_nodes = numnod
    allocate(request%base_state%pressure_head(numnod), request%base_state%water_content(numnod))
    request%boundary%top_mode = FSI_TOP_MODE_DYNAMIC_PROVIDER
    request%boundary%bottom_mode = 7
    request%boundary%bottom_head = -321.0_real64
    request%numerical%max_iterations = 80
    request%numerical%max_backtracking = 16
    request%numerical%conductivity_implicit_mode = 0
    request%numerical%conductivity_mean_method = 1
    request%numerical%min_step_duration = 1.0e-6_real64
    request%numerical%head_abs_tolerance = 1.0e-12_real64
    request%numerical%head_rel_tolerance = 1.0e-12_real64
    request%numerical%ponding_tolerance = 1.0e-12_real64
    request%evaluation%constitutive => hyd
    request%evaluation%source_sink => source
    request%evaluation%dynamic_top_boundary => top
  end subroutine initialize_fixture

  subroutine run_path(horizon, nsteps, result)
    real(real64), intent(in) :: horizon
    integer, intent(in) :: nsteps
    type(path_result_t), intent(out) :: result
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_result_t) :: solve_result
    type(fmr_top_surface_exchange_t) :: exchange
    real(real64) :: dt, storage0
    integer :: step

    result = path_result_t()
    allocate(result%pressure_head(numnod), result%water_content(numnod))
    result%pressure_head = initial_head_cm
    result%water_content = theta0
    result%ponding_cm = initial_ponding_cm
    result%groundwater_level_cm = initial_gwl_cm

    request%base_state%pressure_head = initial_head_cm
    request%base_state%water_content = theta0
    request%base_state%ponding_depth = initial_ponding_cm
    request%base_state%groundwater_level = initial_gwl_cm

    dt = horizon / real(nsteps,real64)
    storage0 = sum(theta0*dz) + initial_ponding_cm
    request%step_duration = dt
    request%boundary%bottom_flux = bottom_rate
    request%numerical%compartment_balance_tolerance = max(1.0e-12_real64,1.0e-12_real64/dt)
    request%numerical%total_balance_tolerance = request%numerical%compartment_balance_tolerance
    call bind_b110_default_mvg_provider(hyd,hp,dt)

    do step = 1, nsteps
      call bind_b110_dynamic_top_boundary_solver_provider(top,params,hp,1,request%base_state%ponding_depth,dt, &
           0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64,1.0_real64,1.0_real64,1.0_real64)
      top%external_surface_water_head_supplied = .true.
      top%external_surface_water_head_cm = external_head_cm
      top%external_flooding_sill_head_cm = external_sill_cm

      call solver%solve(request,workspace,solve_result)
      result%solver_status = solve_result%status
      result%nonlinear_iterations = result%nonlinear_iterations + solve_result%diagnostics%nonlinear_iterations
      if (solve_result%status /= SW_SOLVE_CONVERGED) then
        result%stop_step = step
        return
      end if

      if (.not. solve_result%integrated_mass_balance_residual_available) then
        result%stop_step = step
        result%solver_status = -901
        return
      end if
      result%max_soil_mass_residual_cm = max(result%max_soil_mass_residual_cm, &
           abs(solve_result%integrated_mass_balance_residual_cm))
      if (abs(solve_result%integrated_mass_balance_residual_cm) > soil_mass_tol_cm) then
        result%stop_step = step
        result%solver_status = -902
        return
      end if
      if (solve_result%top_flux > 0.0_real64) then
        result%stop_step = step
        result%solver_status = -903
        return
      end if

      call materialize_fmr_top_surface_exchange(request%base_state%ponding_depth, &
           solve_result%candidate_state%ponding_depth,0.0_real64,0.0_real64, &
           -solve_result%top_flux*dt,0.0_real64,exchange)
      if (exchange%status /= FMR_TOP_EXCHANGE_OK .or. &
          abs(exchange%closure_residual_cm) > surface_closure_tol_cm) then
        result%stop_step = step
        result%solver_status = -904
        return
      end if

      result%top_transfer_cm = result%top_transfer_cm + exchange%signed_swap_to_external_cm
      result%bottom_transfer_cm = result%bottom_transfer_cm + solve_result%bottom_flux*dt
      request%base_state = solve_result%candidate_state
    end do

    result%pressure_head = request%base_state%pressure_head
    result%water_content = request%base_state%water_content
    result%ponding_cm = request%base_state%ponding_depth
    result%groundwater_level_cm = request%base_state%groundwater_level
    result%storage_change_cm = sum(result%water_content*dz) + result%ponding_cm - storage0
    result%ledger_residual_cm = result%storage_change_cm + result%top_transfer_cm - result%bottom_transfer_cm
    if (abs(result%ledger_residual_cm) > ledger_tol_cm) then
      result%solver_status = -905
      return
    end if

    result%complete = .true.
    result%stop_step = nsteps
  end subroutine run_path

  subroutine print_path(horizon,nsteps,result)
    real(real64), intent(in) :: horizon
    integer, intent(in) :: nsteps
    type(path_result_t), intent(in) :: result

    write(*,'(A,1X,ES24.16,1X,I0,1X,L1,1X,I0,1X,I0,1X,I0,5(1X,ES24.16))') &
         'PATH',horizon,nsteps,result%complete,result%stop_step,result%solver_status,result%nonlinear_iterations, &
         result%top_transfer_cm,result%bottom_transfer_cm,result%storage_change_cm,result%ledger_residual_cm, &
         result%max_soil_mass_residual_cm
  end subroutine print_path

  subroutine print_pair(horizon,coarse_steps,fine_steps,coarse,fine)
    real(real64), intent(in) :: horizon
    integer, intent(in) :: coarse_steps, fine_steps
    type(path_result_t), intent(in) :: coarse, fine
    logical :: available
    real(real64) :: head_inf, water_l1, water_cell, pond_diff, gwl_diff, top_diff, bottom_diff

    available = coarse%complete .and. fine%complete
    head_inf = huge(0.0_real64)
    water_l1 = huge(0.0_real64)
    water_cell = huge(0.0_real64)
    pond_diff = huge(0.0_real64)
    gwl_diff = huge(0.0_real64)
    top_diff = huge(0.0_real64)
    bottom_diff = huge(0.0_real64)
    if (available) then
      head_inf = maxval(abs(coarse%pressure_head-fine%pressure_head))
      water_l1 = sum(abs(coarse%water_content-fine%water_content)*dz)
      water_cell = maxval(abs((coarse%water_content-fine%water_content)*dz))
      pond_diff = abs(coarse%ponding_cm-fine%ponding_cm)
      gwl_diff = abs(coarse%groundwater_level_cm-fine%groundwater_level_cm)
      top_diff = abs(coarse%top_transfer_cm-fine%top_transfer_cm)
      bottom_diff = abs(coarse%bottom_transfer_cm-fine%bottom_transfer_cm)
    end if

    write(*,'(A,1X,ES24.16,1X,I0,1X,I0,1X,L1,7(1X,ES24.16))') &
         'PAIR',horizon,coarse_steps,fine_steps,available,head_inf,water_l1,water_cell,pond_diff,gwl_diff,top_diff,bottom_diff
  end subroutine print_pair

end program top03_base_temporal_acceptance_probe
