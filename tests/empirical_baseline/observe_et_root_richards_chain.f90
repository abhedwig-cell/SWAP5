program observe_et_root_richards_chain
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_new_b110_committed_state
  use mod_reference_et_demand_process, only: reference_et_demand_parameters_t, reference_et_demand_canopy_view_t, &
       reference_et_demand_result_t, reference_et_demand_diagnostics_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_forcing_span_t, &
       fmr_reference_et_binding_diagnostics_t, fmr_evaluate_reference_et_demand, FMR_REFERENCE_ET_BINDING_OK
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_reference_et_root_uptake_composition, only: fmr_reference_et_root_uptake_diagnostics_t, &
       fmr_evaluate_reference_et_root_uptake, FMR_REFERENCE_ET_ROOT_UPTAKE_OK
  implicit none

  real(real64), parameter :: step_dt = 0.025_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  real(real64), parameter :: nonlinear_head_tol = 1.0e-12_real64
  real(real64), parameter :: h0 = -110.0_real64
  real(real64), parameter :: head_jump = 0.05_real64

  type(soil_water_parameter_set_t), target :: parameters
  type(b110_default_mvg_parameters_t), target :: hydraulic_parameters
  type(b110_default_mvg_provider_t), target :: constitutive
  type(b110_source_sink_provider_t), target :: source_sink
  type(b110_root_sink_provider_t), target :: root_provider, zero_root_provider
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_physical_state_t) :: initial, root_endpoint, control_endpoint, replay_endpoint
  type(fmr_b110_physical_state_t) :: process_physical
  type(kernel_committed_state_t) :: committed
  type(canonical_interval_t) :: interval
  type(reference_et_demand_parameters_t) :: et_parameters
  type(reference_et_demand_canopy_view_t) :: canopy
  type(reference_et_demand_result_t) :: et_result
  type(reference_et_demand_diagnostics_t) :: et_process_diag
  type(fmr_reference_et_forcing_span_t) :: forcing_span
  type(fmr_reference_et_binding_diagnostics_t) :: et_diag
  type(crop_root_uptake_input_t) :: crop_input
  type(root_water_uptake_parameters_t) :: root_parameters
  type(root_water_uptake_flux_result_t) :: root_flux
  type(root_water_uptake_diagnostics_t) :: root_process_diag
  type(fmr_ptra_root_input_binding_diagnostics_t) :: ptra_diag
  type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter_diag
  type(fmr_root_uptake_binding_diagnostics_t) :: root_bind_diag
  type(fmr_reference_et_root_uptake_diagnostics_t) :: composition_diag
  real(real64), allocatable, target :: drainage(:,:), subsurface(:), zero_legacy_root(:), zero_root(:)
  real(real64), allocatable :: cofgen(:,:)
  real(real64) :: k0, storage0
  real(real64) :: root_in, root_boundary_out, root_depth, root_residual, root_solver_res
  real(real64) :: control_in, control_boundary_out, control_depth, control_residual, control_solver_res
  real(real64) :: replay_in, replay_boundary_out, replay_depth, replay_residual, replay_solver_res
  integer(int64) :: root_fp, control_fp, replay_fp
  logical :: ok

  call configure_hydraulics(parameters, hydraulic_parameters, constitutive, source_sink, top_provider, &
       drainage, subsurface, zero_legacy_root, zero_root, cofgen, initial, k0, storage0)

  process_physical%active_nodes = numnod
  allocate(process_physical%pressure_head(numnod), process_physical%water_content(numnod))
  process_physical%pressure_head = initial%pressure_head
  process_physical%water_content = initial%water_content
  process_physical%ponding_depth = initial%ponding_depth
  process_physical%groundwater_level = initial%groundwater_level
  call fmr_new_b110_committed_state(committed, 6001_int64, process_physical, 0.0_real64, ok)
  call require(ok, 'committed process state initialized')

  interval%t0 = 0.0_real64
  interval%t1 = step_dt
  forcing_span%t0 = 0.0_real64
  forcing_span%t1 = step_dt
  forcing_span%reference_et_mm_per_day = 5.2_real64
  et_parameters%pond_evaporation_factor = 1.2_real64
  canopy%crop_emerged = .true.
  canopy%vegetation_cover_fraction = 0.65_real64
  canopy%crop_factor = 1.1_real64
  canopy%co2_transpiration_factor = 0.9_real64
  call fmr_evaluate_reference_et_demand(interval, forcing_span, et_parameters, canopy, et_result, et_process_diag, et_diag)
  call require(et_diag%status == FMR_REFERENCE_ET_BINDING_OK .and. et_diag%result_produced, 'current ET binding produced result')
  call require(et_result%potential_transpiration_cm_per_day > 0.0_real64, 'ET produced positive PTRA')

  root_parameters%active_nodes = numnod
  root_parameters%hlim3l = -800.0_real64
  root_parameters%hlim3h = -400.0_real64
  root_parameters%hlim4 = -16000.0_real64
  root_parameters%adcrl = 0.10_real64
  root_parameters%adcrh = 0.50_real64
  crop_input%crop_emerged = .true.
  crop_input%potential_transpiration = 9.5_real64
  crop_input%rooted_nodes = 3
  allocate(crop_input%cumulative_root_fraction(4))
  crop_input%cumulative_root_fraction = [0.0_real64, 0.15_real64, 0.50_real64, 1.0_real64]

  call fmr_evaluate_reference_et_root_uptake(committed, root_parameters, crop_input, et_result, et_diag, &
       root_flux, root_process_diag, ptra_diag, adapter_diag, root_bind_diag, composition_diag)
  call require(composition_diag%status == FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. composition_diag%result_produced, &
       'current ET root composition produced sink')
  call require(allocated(root_flux%root_extraction_sink), 'root sink allocated')
  call require(root_flux%actual_uptake_total > 0.0_real64, 'root uptake positive')
  call require(abs(sum(root_flux%root_extraction_sink)-root_flux%actual_uptake_total) <= epsilon(1.0_real64), &
       'root sink sum equals actual uptake')

  call bind_b110_root_sink_provider(root_provider, root_flux%root_extraction_sink)
  call bind_b110_root_sink_provider(zero_root_provider, zero_root)

  call run_case(parameters, hydraulic_parameters, constitutive, source_sink, root_provider, top_provider, solver, workspace, &
       initial, k0, root_flux%actual_uptake_total, root_endpoint, root_in, root_boundary_out, root_depth, root_residual, root_solver_res)
  call run_case(parameters, hydraulic_parameters, constitutive, source_sink, zero_root_provider, top_provider, solver, workspace, &
       initial, k0, 0.0_real64, control_endpoint, control_in, control_boundary_out, control_depth, control_residual, control_solver_res)
  call run_case(parameters, hydraulic_parameters, constitutive, source_sink, root_provider, top_provider, solver, workspace, &
       initial, k0, root_flux%actual_uptake_total, replay_endpoint, replay_in, replay_boundary_out, replay_depth, replay_residual, replay_solver_res)

  root_fp = state_fingerprint(root_endpoint)
  control_fp = state_fingerprint(control_endpoint)
  replay_fp = state_fingerprint(replay_endpoint)

  call require(root_fp /= control_fp, 'positive root sink changes Richards endpoint')
  call require(root_fp == replay_fp, 'positive root sink replay endpoint identity')
  call require(same_real(root_in,replay_in) .and. same_real(root_boundary_out,replay_boundary_out) .and. &
       same_real(root_depth,replay_depth) .and. same_real(root_residual,replay_residual), 'positive root sink replay ledger identity')
  call require(root_depth > 0.0_real64 .and. same_real(control_depth,0.0_real64), 'root depth only on active route')
  call require(abs(root_residual) <= hard_mass_gate .and. abs(control_residual) <= hard_mass_gate, 'manual mass closure')
  call require(root_solver_res <= hard_mass_gate .and. control_solver_res <= hard_mass_gate, 'solver mass closure')

  write(*,'(A)') 'case_id,ptra_cm_per_day,actual_uptake_cm_per_day,root_depth,storage_start,storage_end,boundary_in,boundary_out,residual,solver_res,endpoint_fingerprint'
  write(*,'(A,9(",",ES25.17E3),",",I0)') 'et_root_active', et_result%potential_transpiration_cm_per_day, &
       root_flux%actual_uptake_total, root_depth, storage0, final_storage(root_endpoint,parameters), root_in, &
       root_boundary_out, root_residual, root_solver_res, root_fp
  write(*,'(A,9(",",ES25.17E3),",",I0)') 'zero_root_control', et_result%potential_transpiration_cm_per_day, &
       0.0_real64, control_depth, storage0, final_storage(control_endpoint,parameters), control_in, &
       control_boundary_out, control_residual, control_solver_res, control_fp
  write(*,'(A)') 'EB_R06_ET_TO_ROOT_SINK_POSITIVE=PASS'
  write(*,'(A)') 'EB_R06_ROOT_SINK_CHANGES_RICHARDS_ENDPOINT=PASS'
  write(*,'(A)') 'EB_R06_ROOT_AWARE_MASS_CLOSURE=PASS'
  write(*,'(A)') 'EB_R06_ROOT_SINK_REPLAY_IDENTITY=PASS'
  write(*,'(A)') 'EB_R06_CURRENT_CANONICAL_ET_ROOT_RICHARDS_CHAIN PASS'

contains

  subroutine configure_hydraulics(p, hp, cp, sp, tp, qdra, qssdi, qlegacyroot, qzero, c, initial_state, k_initial, storage_initial)
    type(soil_water_parameter_set_t), target, intent(out) :: p
    type(b110_default_mvg_parameters_t), target, intent(out) :: hp
    type(b110_default_mvg_provider_t), target, intent(out) :: cp
    type(b110_source_sink_provider_t), target, intent(out) :: sp
    type(fmr04_fixed_flux_top_provider_t), target, intent(out) :: tp
    real(real64), allocatable, target, intent(out) :: qdra(:,:), qssdi(:), qlegacyroot(:), qzero(:)
    real(real64), allocatable, intent(out) :: c(:,:)
    type(soil_water_physical_state_t), intent(out) :: initial_state
    real(real64), intent(out) :: k_initial, storage_initial
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: k

    p%parameter_set_id = 206001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod))
    p%z = z; p%dz = dz; p%node_distance = disnod(1:numnod)

    allocate(c(24,numnod)); c = 0.0_real64
    do k = 1, numnod
      c(1,k)=0.032_real64; c(2,k)=0.423_real64; c(3,k)=4.75_real64
      c(4,k)=0.0135_real64; c(5,k)=0.365_real64; c(6,k)=1.455_real64
      c(7,k)=1.0_real64-1.0_real64/c(6,k); c(8,k)=c(4,k)
      c(9,k)=0.0_real64; c(10,k)=c(3,k); c(11,k)=0.999_real64
      c(12,k)=0.99_real64*c(3,k); c(22,k)=-1.0e6_real64; c(23,k)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,c)
    call bind_b110_default_mvg_provider(cp,hp,step_dt)

    allocate(qdra(1,numnod), qssdi(numnod), qlegacyroot(numnod), qzero(numnod))
    qdra=0.0_real64; qssdi=0.0_real64; qlegacyroot=0.0_real64; qzero=0.0_real64
    call bind_b110_source_sink_provider(sp,qdra,qssdi,qlegacyroot)
    if (.not. same_type_as(tp,tp)) error stop 'unreachable top provider type'

    heads = h0
    call cp%evaluate(heads,water,conductivity,capacity,dkdh)
    k_initial = conductivity(1)
    initial_state%active_nodes=numnod
    allocate(initial_state%pressure_head(numnod),initial_state%water_content(numnod))
    initial_state%pressure_head=heads; initial_state%water_content=water
    initial_state%ponding_depth=0.0_real64; initial_state%groundwater_level=-2.0_real64
    storage_initial=final_storage(initial_state,p)
  end subroutine configure_hydraulics

  subroutine run_case(p,hp,cp,sp,rp,tp,s,ws,initial_state,k_initial,uptake_rate,endpoint,total_in,boundary_out,root_out,residual,solver_residual)
    type(soil_water_parameter_set_t), target, intent(in) :: p
    type(b110_default_mvg_parameters_t), target, intent(in) :: hp
    type(b110_default_mvg_provider_t), target, intent(inout) :: cp
    type(b110_source_sink_provider_t), target, intent(in) :: sp
    type(b110_root_sink_provider_t), target, intent(in) :: rp
    type(fmr04_fixed_flux_top_provider_t), target, intent(in) :: tp
    type(reference_richards_legacy_solver_t), intent(inout) :: s
    type(reference_richards_legacy_workspace_t), intent(inout) :: ws
    type(soil_water_physical_state_t), intent(in) :: initial_state
    real(real64), intent(in) :: k_initial, uptake_rate
    type(soil_water_physical_state_t), intent(out) :: endpoint
    real(real64), intent(out) :: total_in, boundary_out, root_out, residual, solver_residual
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    real(real64) :: storage_start, storage_end

    call bind_b110_default_mvg_provider(cp,hp,step_dt)
    request=soil_water_solve_request_t()
    request%parameters=>p
    request%base_state=initial_state
    request%step_duration=step_dt
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=5
    request%boundary%top_flux=-k_initial
    request%boundary%top_head=h0
    request%boundary%bottom_flux=12345.678_real64
    request%boundary%bottom_head=h0+head_jump
    request%physical%macropore_active=.false.
    request%numerical%max_iterations=8
    request%numerical%max_backtracking=4
    request%numerical%conductivity_implicit_mode=0
    request%numerical%conductivity_mean_method=1
    request%numerical%min_step_duration=1.0e-6_real64
    request%numerical%compartment_balance_tolerance=hard_mass_gate
    request%numerical%total_balance_tolerance=hard_mass_gate
    request%numerical%head_abs_tolerance=nonlinear_head_tol
    request%numerical%head_rel_tolerance=nonlinear_head_tol
    request%numerical%ponding_tolerance=nonlinear_head_tol
    request%evaluation%constitutive=>cp
    request%evaluation%source_sink=>sp
    request%evaluation%root_sink=>rp
    request%evaluation%top_boundary=>tp

    storage_start=final_storage(initial_state,p)
    call s%solve(request,ws,result)
    call require(result%status==SW_SOLVE_CONVERGED,'Richards case converged')
    storage_end=final_storage(result%candidate_state,p)
    total_in=max(0.0_real64,-result%top_flux)*step_dt+max(0.0_real64,result%bottom_flux)*step_dt
    boundary_out=max(0.0_real64,result%top_flux)*step_dt+max(0.0_real64,-result%bottom_flux)*step_dt
    root_out=uptake_rate*step_dt
    residual=storage_end-storage_start-(total_in-boundary_out-root_out)
    solver_residual=abs(result%unrounded_mass_balance_residual)
    endpoint=result%candidate_state
  end subroutine run_case

  real(real64) function final_storage(state,p) result(storage)
    type(soil_water_physical_state_t), intent(in) :: state
    type(soil_water_parameter_set_t), intent(in) :: p
    storage=sum(state%water_content*p%dz)+state%ponding_depth
  end function final_storage

  integer(int64) function state_fingerprint(state) result(fp)
    type(soil_water_physical_state_t), intent(in) :: state
    integer(int64) :: word
    integer :: k
    fp=int(z'CBF29CE484222325',int64)
    do k=1,size(state%pressure_head)
      word=transfer(state%pressure_head(k),word); fp=ieor(fp,word); fp=fp*int(z'00000100000001B3',int64)
      word=transfer(state%water_content(k),word); fp=ieor(fp,word); fp=fp*int(z'00000100000001B3',int64)
    end do
    word=transfer(state%ponding_depth,word); fp=ieor(fp,word); fp=fp*int(z'00000100000001B3',int64)
  end function state_fingerprint

  logical function same_real(a,b) result(same)
    real(real64), intent(in) :: a,b
    same=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_real

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'EB_R06_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program observe_et_root_richards_chain
