  ! PRIVATE RESEARCH: four incumbent backward-Euler heat solves per water trial.
  ! The caller's full/half gate, water/heat tolerances and physical laws are fixed.
  subroutine trial_restricted_soil_temperature(parameters,numerical,forcing,hydraulic_start,hydraulic_end, &
       committed_state,t0,t1,workspace,trial_state,result,diagnostics)
    type(soil_temperature_parameters_t), intent(in) :: parameters
    type(soil_temperature_numerical_config_t), intent(in) :: numerical
    type(soil_temperature_forcing_t), intent(in) :: forcing
    type(process_hydraulic_view_t), intent(in) :: hydraulic_start,hydraulic_end
    type(soil_temperature_state_t), intent(in) :: committed_state
    real(real64), intent(in) :: t0,t1
    type(soil_temperature_workspace_t), intent(inout) :: workspace
    type(soil_temperature_state_t), intent(out) :: trial_state
    type(soil_temperature_result_t), intent(out) :: result
    type(soil_temperature_diagnostics_t), intent(out) :: diagnostics
    type(soil_temperature_state_t) :: local_state,local_trial
    type(soil_temperature_result_t) :: step_result
    type(soil_temperature_diagnostics_t) :: step_diagnostics
    real(real64), allocatable :: start_temperature(:),face_energy(:)
    real(real64) :: dt,a,b,subdt,storage,boundary,residual
    integer :: k,i,n,status,constitutive_count,solve_count

    if(allocated(workspace%substep_conductive_face_energy_j_cm2)) &
      deallocate(workspace%substep_conductive_face_energy_j_cm2)
    if(.not.parameters%ready().or.parameters%solution_mode/=SOIL_TEMP_SOLUTION_NUMERIC.or. &
       .not.ieee_is_finite(t0).or..not.ieee_is_finite(t1).or.t1<=t0)then
      call trial_restricted_soil_temperature_single(parameters,numerical,forcing,hydraulic_start,hydraulic_end, &
           committed_state,t0,t1,workspace,trial_state,result,diagnostics)
      return
    end if
    call copy_soil_temperature_profile(committed_state,start_temperature,status)
    if(status/=SOIL_TEMP_OK)then
      call trial_restricted_soil_temperature_single(parameters,numerical,forcing,hydraulic_start,hydraulic_end, &
           committed_state,t0,t1,workspace,trial_state,result,diagnostics)
      return
    end if
    result=soil_temperature_result_t();diagnostics=soil_temperature_diagnostics_t()
    local_state=committed_state;n=parameters%node_count();dt=t1-t0
    allocate(face_energy(n+1));face_energy=0.0_real64
    constitutive_count=0;solve_count=0
    do k=1,4
      a=t0+dt*real(k-1,real64)/4.0_real64
      b=t0+dt*real(k,real64)/4.0_real64
      if(k==4)b=t1
      subdt=b-a
      ! Each subsolve uses exactly the same outer midpoint hydraulic state,
      ! so C and K retain the incumbent outer-trial coefficient convention.
      call trial_restricted_soil_temperature_single(parameters,numerical,forcing,hydraulic_start,hydraulic_end, &
           local_state,a,b,workspace,local_trial,step_result,step_diagnostics)
      constitutive_count=constitutive_count+step_diagnostics%constitutive_evaluations
      solve_count=solve_count+step_diagnostics%tridiagonal_solves
      if(step_result%status/=SOIL_TEMP_OK.or..not.step_result%produced)then
        result=step_result;diagnostics=step_diagnostics
        diagnostics%constitutive_evaluations=constitutive_count
        diagnostics%tridiagonal_solves=solve_count
        return
      end if
      face_energy(1)=face_energy(1)+subdt*step_result%top_heat_flux_into_soil_j_cm2_day
      face_energy(n+1)=face_energy(n+1)-subdt*step_result%bottom_heat_flux_into_soil_j_cm2_day
      do i=2,n
        face_energy(i)=face_energy(i)+subdt*workspace%face_conductivity_j_cm_k_day(i)* &
          (workspace%solution(i-1)-workspace%solution(i))/parameters%distance_above_cm(i)
      end do
      local_state=local_trial
    end do
    storage=sum(workspace%heat_capacity_j_cm3_k*parameters%dz_cm*(workspace%solution-start_temperature))
    boundary=face_energy(1)-face_energy(n+1);residual=storage-boundary
    if(.not.ieee_is_finite(residual).or.abs(residual)>numerical%energy_abs_tolerance_j_cm2)then
      result%status=SOIL_TEMP_ENERGY_CLOSURE_FAILURE;diagnostics%status=result%status
      return
    end if
    trial_state=local_state;result=step_result;diagnostics=step_diagnostics
    result%top_heat_flux_into_soil_j_cm2_day=face_energy(1)/dt
    result%bottom_heat_flux_into_soil_j_cm2_day=-face_energy(n+1)/dt
    result%sensible_storage_change_j_cm2=storage
    result%boundary_energy_into_soil_j_cm2=boundary
    result%energy_residual_j_cm2=residual
    diagnostics%constitutive_evaluations=constitutive_count
    diagnostics%tridiagonal_solves=solve_count
    workspace%old_temperature_c=start_temperature
    workspace%substep_conductive_face_energy_j_cm2=face_energy
  end subroutine trial_restricted_soil_temperature
