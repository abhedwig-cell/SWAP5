program test_fpe_nlglob14z43f_manager_admission
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_FAILED
  use mod_reference_richards_workspace, only: reference_richards_workspace_t, initialize_reference_workspace
  use mod_moving_interface_manager, only: moving_interface_active_view_t, moving_interface_manager_diagnostics_t, &
       derive_moving_interface_active_view, build_moving_interface_reduced_request, &
       materialize_moving_interface_full_candidate, choose_moving_interface_result, &
       MI_MANAGER_ROUTE_REDUCED, MI_MANAGER_ROUTE_FULL_FALLBACK, MI_MANAGER_ROUTE_FULL_BYPASS
  implicit none

  integer, parameter :: nf=16, na=13
  type(soil_water_parameter_set_t), target :: full_parameters, reduced_parameters
  type(soil_water_solve_request_t) :: full_request, reduced_request
  type(soil_water_solve_result_t) :: full_result, reduced_result, materialized, selected
  type(reference_richards_workspace_t) :: reduced_workspace
  type(moving_interface_active_view_t) :: view, bypass_view
  type(moving_interface_manager_diagnostics_t) :: diagnostics
  real(real64) :: origin_h(nf), origin_th(nf), origin_h_copy(nf), origin_th_copy(nf)
  real(real64) :: tail_h(nf-na), tail_th(nf-na)
  logical :: ok
  character(len=96) :: reason
  integer :: i

  do i=1,nf
     origin_h(i) = -100.0_real64 + real(i,real64)
     origin_th(i) = 0.20_real64 + 0.001_real64*real(i,real64)
  end do
  origin_h_copy = origin_h
  origin_th_copy = origin_th

  full_parameters%parameter_set_id = 3401_int64
  full_parameters%active_nodes = nf
  allocate(full_parameters%z(nf), full_parameters%dz(nf), full_parameters%node_distance(nf))
  do i=1,nf
     full_parameters%z(i) = -10.0_real64*real(i,real64)
     full_parameters%dz(i) = 10.0_real64
     full_parameters%node_distance(i) = 10.0_real64
  end do

  full_request%parameters => full_parameters
  full_request%step_duration = 0.25_real64
  full_request%base_state%active_nodes = nf
  allocate(full_request%base_state%pressure_head(nf), full_request%base_state%water_content(nf))
  full_request%base_state%pressure_head = origin_h
  full_request%base_state%water_content = origin_th
  full_request%base_state%ponding_depth = 0.125_real64
  full_request%base_state%groundwater_level = -120.0_real64

  call derive_moving_interface_active_view(full_request%base_state, na, view, ok, reason)
  if (.not. ok) error stop 'Z43F active view derivation failed'
  if (.not. view%eligible .or. view%full_nodes /= nf .or. view%active_nodes /= na) &
       error stop 'Z43F active view shape mismatch'

  call build_moving_interface_reduced_request(full_request, view, reduced_parameters, reduced_request, ok, reason)
  if (.not. ok) error stop 'Z43F reduced request build failed'
  if (reduced_request%base_state%active_nodes /= na) error stop 'Z43F reduced state dimension mismatch'
  if (reduced_request%parameters%active_nodes /= na) error stop 'Z43F reduced parameter dimension mismatch'
  if (size(reduced_request%base_state%pressure_head) /= na) error stop 'Z43F reduced head shape mismatch'
  if (maxval(abs(reduced_request%base_state%pressure_head-origin_h(1:na))) /= 0.0_real64) &
       error stop 'Z43F reduced request origin mismatch'

  call initialize_reference_workspace(reduced_workspace, na)
  if (reduced_workspace%active_nodes /= na) error stop 'Z43F reduced workspace dimension mismatch'
  if (reduced_workspace%active_nodes >= nf) error stop 'Z43F workspace was not reduced'

  full_result%status = SW_SOLVE_CONVERGED
  full_result%candidate_state%active_nodes = nf
  allocate(full_result%candidate_state%pressure_head(nf), full_result%candidate_state%water_content(nf))
  full_result%candidate_state%pressure_head = origin_h + 0.01_real64
  full_result%candidate_state%water_content = origin_th + 1.0e-5_real64
  full_result%candidate_state%ponding_depth = 0.124_real64
  full_result%candidate_state%groundwater_level = -119.9_real64
  full_result%top_flux = -0.2_real64
  full_result%bottom_flux = 0.0_real64
  full_result%diagnostics%route = 'full-reference-smoke'

  reduced_result%status = SW_SOLVE_CONVERGED
  reduced_result%candidate_state%active_nodes = na
  allocate(reduced_result%candidate_state%pressure_head(na), reduced_result%candidate_state%water_content(na))
  reduced_result%candidate_state%pressure_head = full_result%candidate_state%pressure_head(1:na)
  reduced_result%candidate_state%water_content = full_result%candidate_state%water_content(1:na)
  reduced_result%candidate_state%ponding_depth = full_result%candidate_state%ponding_depth
  reduced_result%candidate_state%groundwater_level = full_result%candidate_state%groundwater_level
  reduced_result%top_flux = full_result%top_flux
  reduced_result%bottom_flux = full_result%bottom_flux
  reduced_result%diagnostics%route = 'reduced-smoke'

  tail_h = full_result%candidate_state%pressure_head(na+1:nf)
  tail_th = full_result%candidate_state%water_content(na+1:nf)
  call materialize_moving_interface_full_candidate(full_request%base_state, reduced_result, tail_h, tail_th, &
       materialized, ok, reason)
  if (.not. ok) error stop 'Z43F full candidate materialization failed'
  if (materialized%candidate_state%active_nodes /= nf) error stop 'Z43F materialized full shape mismatch'
  if (maxval(abs(materialized%candidate_state%pressure_head-full_result%candidate_state%pressure_head)) /= 0.0_real64) &
       error stop 'Z43F materialized head mismatch'
  if (maxval(abs(materialized%candidate_state%water_content-full_result%candidate_state%water_content)) /= 0.0_real64) &
       error stop 'Z43F materialized theta mismatch'

  call choose_moving_interface_result(full_result, materialized, .true., view, reduced_workspace%generation, &
       'none', selected, diagnostics)
  if (diagnostics%route /= MI_MANAGER_ROUTE_REDUCED) error stop 'Z43F reduced route not selected'
  if (.not. diagnostics%reduced_attempted .or. .not. diagnostics%reduced_accepted) &
       error stop 'Z43F reduced diagnostics incomplete'
  if (diagnostics%active_nodes /= na .or. diagnostics%full_nodes /= nf) &
       error stop 'Z43F dimension diagnostics mismatch'
  if (selected%candidate_state%active_nodes /= nf) error stop 'Z43F selected reduced candidate not full-shaped'

  ! Force reduced failure. Full fallback must be selected exactly and the
  ! original accepted state must remain unchanged.
  reduced_result%status = SW_SOLVE_FAILED
  call choose_moving_interface_result(full_result, materialized, .false., view, reduced_workspace%generation, &
       'forced-smoke-failure', selected, diagnostics)
  if (diagnostics%route /= MI_MANAGER_ROUTE_FULL_FALLBACK) error stop 'Z43F fallback route not selected'
  if (.not. diagnostics%fallback_used) error stop 'Z43F fallback diagnostic missing'
  if (trim(diagnostics%fallback_reason) /= 'forced-smoke-failure') error stop 'Z43F fallback reason mismatch'
  if (maxval(abs(selected%candidate_state%pressure_head-full_result%candidate_state%pressure_head)) /= 0.0_real64) &
       error stop 'Z43F fallback did not reproduce full candidate'
  if (maxval(abs(full_request%base_state%pressure_head-origin_h_copy)) /= 0.0_real64) &
       error stop 'Z43F accepted head leaked across failed reduced trial'
  if (maxval(abs(full_request%base_state%water_content-origin_th_copy)) /= 0.0_real64) &
       error stop 'Z43F accepted theta leaked across failed reduced trial'

  call derive_moving_interface_active_view(full_request%base_state, nf, bypass_view, ok, reason)
  if (ok .or. bypass_view%eligible) error stop 'Z43F full-dimension view should bypass'
  call choose_moving_interface_result(full_result, materialized, .false., bypass_view, 0_int64, &
       'not-eligible', selected, diagnostics)
  if (diagnostics%route /= MI_MANAGER_ROUTE_FULL_BYPASS) error stop 'Z43F bypass route not selected'

  write(*,'(*(g0))') 'F_PE_NLGLOB14Z43F_RESULT={', &
       '"full_nodes":',nf,',"active_nodes":',na,',"workspace_generation":',reduced_workspace%generation, &
       ',"reduced_route":true,"fallback_route":true,"bypass_route":true,"rollback_no_leak":true,', &
       '"aggregate":"QUALIFIED_Z43F_MANAGER_SEAM_READY"}'
  write(*,'(a)') 'F_PE_NLGLOB14Z43F=PASS'
end program test_fpe_nlglob14z43f_manager_admission
