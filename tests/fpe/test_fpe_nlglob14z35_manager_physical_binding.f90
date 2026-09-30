program test_fpe_nlglob14z35_manager_physical_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       derive_moving_interface_active_view, build_moving_interface_reduced_request, &
       materialize_moving_interface_full_candidate, choose_moving_interface_result, &
       MI_MANAGER_ROUTE_REDUCED, MI_MANAGER_ROUTE_FULL_FALLBACK, MI_MANAGER_ROUTE_FULL_BYPASS
  use mod_fpe_nlglob14z35_fixture
  implicit none

  type(soil_water_parameter_set_t), target :: full_parameters, reduced_parameters
  type(soil_water_solve_request_t) :: full_request, reduced_request
  type(soil_water_solve_result_t) :: full_result, reduced_result, materialized, selected
  type(reference_richards_workspace_t) :: reduced_workspace
  type(moving_interface_active_view_t) :: view, bypass_view
  type(moving_interface_manager_diagnostics_t) :: diagnostics
  real(real64) :: origin_h_copy(z35_full_nodes), origin_th_copy(z35_full_nodes)
  real(real64) :: max_h_diff, max_th_diff
  logical :: ok
  character(len=96) :: reason
  integer :: i

  origin_h_copy=z35_origin_h
  origin_th_copy=z35_origin_th

  full_parameters%parameter_set_id=3501_int64
  full_parameters%active_nodes=z35_full_nodes
  allocate(full_parameters%z(z35_full_nodes),full_parameters%dz(z35_full_nodes), &
           full_parameters%node_distance(z35_full_nodes))
  do i=1,z35_full_nodes
     full_parameters%z(i)=-10.0_real64*real(i,real64)
     full_parameters%dz(i)=10.0_real64
     full_parameters%node_distance(i)=10.0_real64
  end do

  full_request%parameters=>full_parameters
  full_request%step_duration=6.25e-5_real64
  full_request%base_state%active_nodes=z35_full_nodes
  allocate(full_request%base_state%pressure_head(z35_full_nodes), &
           full_request%base_state%water_content(z35_full_nodes))
  full_request%base_state%pressure_head=z35_origin_h
  full_request%base_state%water_content=z35_origin_th
  full_request%base_state%ponding_depth=0.0_real64
  full_request%base_state%groundwater_level=-120.0_real64

  call derive_moving_interface_active_view(full_request%base_state,z35_active_nodes,view,ok,reason)
  if (.not.ok .or. .not.view%eligible) error stop 'Z35 eligible view failed'
  if (view%active_nodes/=z35_active_nodes .or. view%full_nodes/=z35_full_nodes) &
       error stop 'Z35 view dimension mismatch'

  call build_moving_interface_reduced_request(full_request,view,reduced_parameters,reduced_request,ok,reason)
  if (.not.ok) error stop 'Z35 reduced request build failed'
  call initialize_reference_workspace(reduced_workspace,z35_active_nodes)
  if (reduced_workspace%active_nodes/=z35_active_nodes) error stop 'Z35 reduced workspace mismatch'

  full_result%status=SW_SOLVE_CONVERGED
  full_result%candidate_state%active_nodes=z35_full_nodes
  allocate(full_result%candidate_state%pressure_head(z35_full_nodes), &
           full_result%candidate_state%water_content(z35_full_nodes))
  full_result%candidate_state%pressure_head=z35_full_h
  full_result%candidate_state%water_content=z35_full_th
  full_result%candidate_state%ponding_depth=0.0_real64
  full_result%candidate_state%groundwater_level=-120.0_real64
  full_result%top_flux=z35_top_flux
  full_result%bottom_flux=0.0_real64
  full_result%integrated_mass_balance_residual_available=.true.
  full_result%integrated_mass_balance_residual_cm=z35_full_ledger
  full_result%diagnostics%route='z35-full-physical'

  reduced_result%status=SW_SOLVE_CONVERGED
  reduced_result%candidate_state%active_nodes=z35_active_nodes
  allocate(reduced_result%candidate_state%pressure_head(z35_active_nodes), &
           reduced_result%candidate_state%water_content(z35_active_nodes))
  reduced_result%candidate_state%pressure_head=z35_reduced_h
  reduced_result%candidate_state%water_content=z35_reduced_th
  reduced_result%candidate_state%ponding_depth=0.0_real64
  reduced_result%candidate_state%groundwater_level=-120.0_real64
  reduced_result%top_flux=z35_top_flux
  reduced_result%bottom_flux=0.0_real64
  reduced_result%integrated_mass_balance_residual_available=.true.
  reduced_result%integrated_mass_balance_residual_cm=z35_reduced_ledger
  reduced_result%diagnostics%route='z35-reduced-physical'

  call materialize_moving_interface_full_candidate(full_request%base_state,reduced_result, &
       z35_tail_h,z35_tail_th,materialized,ok,reason)
  if (.not.ok) error stop 'Z35 materialization failed'
  if (materialized%candidate_state%active_nodes/=z35_full_nodes) error stop 'Z35 full shape lost'

  max_h_diff=maxval(abs(materialized%candidate_state%pressure_head- &
       full_result%candidate_state%pressure_head))
  max_th_diff=maxval(abs(materialized%candidate_state%water_content- &
       full_result%candidate_state%water_content))
  if (max_h_diff>5e-7_real64) error stop 'Z35 physical head mismatch'
  if (max_th_diff>5e-10_real64) error stop 'Z35 physical theta mismatch'
  if (abs(materialized%top_flux-full_result%top_flux)>5e-10_real64) error stop 'Z35 top flux mismatch'
  if (abs(z35_reduced_ledger-z35_full_ledger)>5e-8_real64) error stop 'Z35 ledger mismatch'

  call choose_moving_interface_result(full_result,materialized,.true.,view,reduced_workspace%generation, &
       'none',selected,diagnostics)
  if (diagnostics%route/=MI_MANAGER_ROUTE_REDUCED) error stop 'Z35 reduced route not selected'
  if (.not.diagnostics%reduced_accepted) error stop 'Z35 reduced acceptance missing'
  if (selected%candidate_state%active_nodes/=z35_full_nodes) error stop 'Z35 selected candidate not full shaped'

  reduced_result%status=SW_SOLVE_FAILED
  call choose_moving_interface_result(full_result,materialized,.false.,view,reduced_workspace%generation, &
       'forced-z35-failure',selected,diagnostics)
  if (diagnostics%route/=MI_MANAGER_ROUTE_FULL_FALLBACK) error stop 'Z35 fallback route failed'
  if (.not.diagnostics%fallback_used) error stop 'Z35 fallback flag missing'
  if (trim(diagnostics%fallback_reason)/='forced-z35-failure') error stop 'Z35 fallback reason mismatch'
  if (maxval(abs(selected%candidate_state%pressure_head-z35_full_h))/=0.0_real64) &
       error stop 'Z35 fallback full candidate mismatch'
  if (maxval(abs(full_request%base_state%pressure_head-origin_h_copy))/=0.0_real64) &
       error stop 'Z35 accepted head leaked'
  if (maxval(abs(full_request%base_state%water_content-origin_th_copy))/=0.0_real64) &
       error stop 'Z35 accepted theta leaked'

  call derive_moving_interface_active_view(full_request%base_state,z35_full_nodes,bypass_view,ok,reason)
  if (ok .or. bypass_view%eligible) error stop 'Z35 bypass eligibility incorrect'
  call choose_moving_interface_result(full_result,materialized,.false.,bypass_view,0_int64, &
       'not-eligible',selected,diagnostics)
  if (diagnostics%route/=MI_MANAGER_ROUTE_FULL_BYPASS) error stop 'Z35 bypass route failed'

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z35_RESULT={', &
       '"full_nodes":',z35_full_nodes,',"active_nodes":',z35_active_nodes, &
       ',"max_head_diff":',max_h_diff,',"max_theta_diff":',max_th_diff, &
       ',"full_residual":',z35_full_residual,',"reduced_residual":',z35_reduced_residual, &
       ',"reduced_route":true,"fallback_route":true,"bypass_route":true,', &
       '"rollback_no_leak":true,"aggregate":"QUALIFIED_Z35_MANAGER_PHYSICAL_BINDING_SMOKE"}'
  write(*,'(a)') 'F_PE_NLGLOB14Z35=PASS'
end program test_fpe_nlglob14z35_manager_physical_binding
