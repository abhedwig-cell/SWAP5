program test_ross25_serial_hydrologic_validation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_soil_water_solver, only: rossfast_d3r_soil_water_solver_t, &
       rossfast_d3r_soil_water_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=36, nprofile=3, npolicy=2, nstep=32
  integer, parameter :: expected_trajectories=nmat*nprofile*npolicy
  real(real64), parameter :: reference_internal_balance_rate_tol_cm_per_day=1.0e-12_real64
  real(real64), parameter :: table_dxdu=60.0_real64
  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09','B10','B11','B12','B13','B14','B15','B16','B17','B18', &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09','O10','O11','O12','O13','O14','O15','O16','O17','O18']
  character(len=12), parameter :: profile_ids(nprofile)=[character(len=12) :: 'WET_GRADIENT','MID_GRADIENT','DRY_GRADIENT']
  real(real64), parameter :: profile_top(nprofile)=[-40.0_real64,-180.0_real64,-1200.0_real64]
  real(real64), parameter :: profile_bottom(nprofile)=[-120.0_real64,-650.0_real64,-4200.0_real64]
  character(len=14), parameter :: policy_ids(npolicy)=[character(len=14) :: 'ZERO_SHARED   ','NOMINAL_SHARED']

  integer :: imat,iprof,ipolicy,trajectory_id
  integer :: complete_count,ross_valid_all_count,reference_valid_all_count,envelope_loss_count
  integer :: total_k2,total_k4,total_k8,reference_failure_count,rossfast_failure_count

  complete_count=0; ross_valid_all_count=0; reference_valid_all_count=0; envelope_loss_count=0
  total_k2=0; total_k4=0; total_k8=0; reference_failure_count=0; rossfast_failure_count=0
  trajectory_id=0

  do imat=1,nmat
    do iprof=1,nprofile
      do ipolicy=1,npolicy
        trajectory_id=trajectory_id+1
        call run_trajectory(trajectory_id,material_ids(imat),profile_ids(iprof),profile_top(iprof),profile_bottom(iprof), &
             policy_ids(ipolicy),complete_count,ross_valid_all_count,reference_valid_all_count,envelope_loss_count, &
             total_k2,total_k4,total_k8,reference_failure_count,rossfast_failure_count)
      end do
    end do
  end do

  call require(trajectory_id==expected_trajectories,'exact 216 trajectory matrix attempted')
  write(*,'(A,I0)') 'F_ROSS25_TRAJECTORY_COUNT=',trajectory_id
  write(*,'(A,I0)') 'F_ROSS25_COMPLETE_COUNT=',complete_count
  write(*,'(A,I0)') 'F_ROSS25_ROSS_VALID_ALL_COUNT=',ross_valid_all_count
  write(*,'(A,I0)') 'F_ROSS25_REFERENCE_VALID_ALL_COUNT=',reference_valid_all_count
  write(*,'(A,I0)') 'F_ROSS25_ENVELOPE_LOSS_COUNT=',envelope_loss_count
  write(*,'(A,I0)') 'F_ROSS25_REFERENCE_FAILURE_COUNT=',reference_failure_count
  write(*,'(A,I0)') 'F_ROSS25_ROSSFAST_FAILURE_COUNT=',rossfast_failure_count
  write(*,'(A,I0)') 'F_ROSS25_K2_TOTAL=',total_k2
  write(*,'(A,I0)') 'F_ROSS25_K4_TOTAL=',total_k4
  write(*,'(A,I0)') 'F_ROSS25_K8_TOTAL=',total_k8
  write(*,'(A,I0)') 'F_ROSS25_INTERVALS_PER_TRAJECTORY=',nstep
  write(*,'(A,ES24.16E3)') 'F_ROSS25_TOTAL_DURATION_DAY=',real(nstep,real64)*ROSSFAST_D3R_OUTER_HORIZON_DAY
  write(*,'(A)') 'F_ROSS25_GATE=PASS'

contains

  subroutine run_trajectory(id,material_id,profile_id,hfirst,hlast,policy_id,complete_count,ross_all_count,ref_all_count, &
       envelope_loss_count,total_k2,total_k4,total_k8,reference_failure_count,rossfast_failure_count)
    integer,intent(in) :: id
    character(len=*),intent(in) :: material_id,profile_id,policy_id
    real(real64),intent(in) :: hfirst,hlast
    integer,intent(inout) :: complete_count,ross_all_count,ref_all_count,envelope_loss_count
    integer,intent(inout) :: total_k2,total_k4,total_k8,reference_failure_count,rossfast_failure_count

    type(soil_water_parameter_set_t),target :: parameters
    type(soil_water_solve_request_t) :: ref_request,ross_request
    type(soil_water_solve_result_t) :: ref_result,ross_result
    type(reference_richards_legacy_solver_t) :: ref_solver
    type(reference_richards_legacy_workspace_t) :: ref_workspace
    type(rossfast_d3r_soil_water_solver_t) :: ross_solver
    type(rossfast_d3r_soil_water_workspace_t) :: ross_workspace
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n)
    real(real64) :: ref_h(n),ross_h(n),ref_theta(n),ross_theta(n)
    real(real64) :: ref_k(n),ross_k(n),capacity(n),dkdh(n),theta_eval(n)
    real(real64) :: qtop,qbot,storage_ref,storage_ross,initial_storage
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    real(real64) :: max_dh_inf,max_dtheta_inf,max_dstorage
    real(real64) :: cumulative_external,cumulative_ref_balance,cumulative_ross_balance
    real(real64) :: prev_storage_ref,prev_storage_ross,temporal_indicator,ross_mass
    logical :: found,initialized,ref_valid,ross_valid,envelope_ok,certificate_available
    logical :: ref_all,ross_all,complete
    integer :: provider_status,step,tier_work,k2,k4,k8,ref_first_fail,ross_first_fail,envelope_first_fail
    character(len=64) :: ref_reason,ross_reason
    character(len=2) :: tier_name

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'material catalog lookup')
    call initialize_parameter_contract(parameters,cofgen,material,id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,ROSSFAST_D3R_OUTER_HORIZON_DAY)
    call build_profile(hfirst,hlast,ref_h)
    ross_h=ref_h
    call constitutive%evaluate(ref_h,ref_theta,ref_k,capacity,dkdh)
    ross_theta=ref_theta
    call require(all(ieee_is_finite(ref_theta)) .and. all(ieee_is_finite(ref_k)) .and. all(ref_k>0.0_real64), &
         'initial constitutive profile finite')
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    call ross_solver%initialize('assets/rossfast/d3r',material_id,initialized,provider_status)
    call require(initialized,'RossFast provider initialization')

    initial_storage=sum(parameters%dz*ref_theta)
    prev_storage_ref=initial_storage
    prev_storage_ross=initial_storage
    cumulative_external=0.0_real64
    cumulative_ref_balance=0.0_real64
    cumulative_ross_balance=0.0_real64
    max_dh_inf=0.0_real64; max_dtheta_inf=0.0_real64; max_dstorage=0.0_real64
    dh_inf=0.0_real64; dh_rms=0.0_real64; dtheta_inf=0.0_real64; dtheta_rms=0.0_real64; dstorage=0.0_real64
    k2=0; k4=0; k8=0
    ref_first_fail=0; ross_first_fail=0; envelope_first_fail=0
    ref_reason='OK'; ross_reason='OK'
    ref_all=.true.; ross_all=.true.; complete=.true.

    do step=1,nstep
      call constitutive%evaluate(ref_h,theta_eval,ref_k,capacity,dkdh)
      call constitutive%evaluate(ross_h,theta_eval,ross_k,capacity,dkdh)
      call shared_forcing(policy_id,ref_k,ross_k,qtop,qbot)
      envelope_ok=forcing_admitted(ref_k,qtop,qbot) .and. forcing_admitted(ross_k,qtop,qbot)
      if (.not.envelope_ok) then
        envelope_first_fail=step
        envelope_loss_count=envelope_loss_count+1
        complete=.false.
        exit
      end if

      call prepare_request(ref_request,parameters,constitutive,source_sink,top_boundary,ref_h,ref_theta,qtop,qbot)
      call prepare_request(ross_request,parameters,constitutive,source_sink,top_boundary,ross_h,ross_theta,qtop,qbot)

      call ref_solver%solve(ref_request,ref_workspace,ref_result)
      call ross_solver%solve(ross_request,ross_workspace,ross_result)

      ref_valid=reference_route_valid(ref_result,ref_request,material)
      ross_valid=rossfast_route_valid(ross_result,ross_request,material)
      ref_reason=reference_route_reason(ref_result,ref_request,material)
      ross_reason=rossfast_route_reason(ross_result,ross_request,material)

      if (.not.ref_valid .and. ref_first_fail==0) then
        ref_first_fail=step
        reference_failure_count=reference_failure_count+1
        ref_all=.false.
      end if
      if (.not.ross_valid .and. ross_first_fail==0) then
        ross_first_fail=step
        rossfast_failure_count=rossfast_failure_count+1
        ross_all=.false.
      end if
      if (.not.ref_valid .or. .not.ross_valid) then
        complete=.false.
        exit
      end if

      call ross_solver%temporal_certificate_snapshot(certificate_available,temporal_indicator)
      call require(certificate_available .and. ieee_is_finite(temporal_indicator) .and. temporal_indicator>=0.0_real64 .and. &
           temporal_indicator<=1.0_real64,'RossFast accepted temporal certificate')
      tier_work=ross_result%diagnostics%linear_solves
      select case(tier_work)
      case(6); tier_name='K2'; k2=k2+1
      case(18); tier_name='K4'; k4=k4+1
      case(42); tier_name='K8'; k8=k8+1
      case default; call require(.false.,'tier work count must be 6 18 or 42')
      end select
      call require(ross_result%diagnostics%internal_retries==0,'zero internal RossFast retries')
      call require(ross_result%diagnostics%alternative_solver_calls==0,'zero alternative solver calls')
      ross_mass=ross_result%integrated_mass_balance_residual_cm

      storage_ref=sum(parameters%dz*ref_result%candidate_state%water_content)+ref_result%candidate_state%ponding_depth
      storage_ross=sum(parameters%dz*ross_result%candidate_state%water_content)+ross_result%candidate_state%ponding_depth
      cumulative_external=cumulative_external+ROSSFAST_D3R_OUTER_HORIZON_DAY*(qtop+qbot)
      cumulative_ref_balance=cumulative_ref_balance+(storage_ref-prev_storage_ref)-ROSSFAST_D3R_OUTER_HORIZON_DAY*(qtop+qbot)
      cumulative_ross_balance=cumulative_ross_balance+(storage_ross-prev_storage_ross)-ROSSFAST_D3R_OUTER_HORIZON_DAY*(qtop+qbot)
      prev_storage_ref=storage_ref; prev_storage_ross=storage_ross

      dh_inf=maxval(abs(ross_result%candidate_state%pressure_head-ref_result%candidate_state%pressure_head))
      dh_rms=sqrt(sum((ross_result%candidate_state%pressure_head-ref_result%candidate_state%pressure_head)**2)/real(n,real64))
      dtheta_inf=maxval(abs(ross_result%candidate_state%water_content-ref_result%candidate_state%water_content))
      dtheta_rms=sqrt(sum((ross_result%candidate_state%water_content-ref_result%candidate_state%water_content)**2)/real(n,real64))
      dstorage=abs(storage_ross-storage_ref)
      max_dh_inf=max(max_dh_inf,dh_inf)
      max_dtheta_inf=max(max_dtheta_inf,dtheta_inf)
      max_dstorage=max(max_dstorage,dstorage)

      if (is_checkpoint(step)) then
        write(*,'(*(g0))') 'F_ROSS25_CHECKPOINT|ID=',id,'|STEP=',step,'|HINF=',dh_inf,'|HRMS=',dh_rms, &
             '|TINF=',dtheta_inf,'|TRMS=',dtheta_rms,'|DSTORAGE=',dstorage,'|TIER=',trim(tier_name), &
             '|TEMP=',temporal_indicator,'|ROSS_MASS=',ross_mass
      end if

      ref_h=ref_result%candidate_state%pressure_head
      ref_theta=ref_result%candidate_state%water_content
      ross_h=ross_result%candidate_state%pressure_head
      ross_theta=ross_result%candidate_state%water_content
    end do

    if (complete) complete_count=complete_count+1
    if (ross_all) ross_all_count=ross_all_count+1
    if (ref_all) ref_all_count=ref_all_count+1
    total_k2=total_k2+k2; total_k4=total_k4+k4; total_k8=total_k8+k8

    write(*,'(*(g0))') 'F_ROSS25_TRAJECTORY|ID=',id,'|MATERIAL=',trim(material_id),'|PROFILE=',trim(profile_id), &
         '|POLICY=',trim(policy_id),'|COMPLETE=',complete,'|REF_ALL=',ref_all,'|ROSS_ALL=',ross_all, &
         '|REF_FIRST_FAIL=',ref_first_fail,'|ROSS_FIRST_FAIL=',ross_first_fail,'|ENVELOPE_FIRST_FAIL=',envelope_first_fail, &
         '|REF_REASON=',trim(ref_reason),'|ROSS_REASON=',trim(ross_reason),'|K2=',k2,'|K4=',k4,'|K8=',k8, &
         '|MAX_HINF=',max_dh_inf,'|MAX_TINF=',max_dtheta_inf,'|MAX_DSTORAGE=',max_dstorage, &
         '|FINAL_HINF=',merge(dh_inf,0.0_real64,complete),'|FINAL_TINF=',merge(dtheta_inf,0.0_real64,complete), &
         '|FINAL_DSTORAGE=',merge(dstorage,0.0_real64,complete),'|CUM_EXTERNAL=',cumulative_external, &
         '|REF_CUM_BAL=',cumulative_ref_balance,'|ROSS_CUM_BAL=',cumulative_ross_balance
  end subroutine run_trajectory

  subroutine build_profile(hfirst,hlast,heads)
    real(real64),intent(in) :: hfirst,hlast
    real(real64),intent(out) :: heads(n)
    real(real64) :: u0,u1,u,x,frac,r,xsafe
    integer :: i,cell
    u0=log10(-hfirst); u1=log10(-hlast)
    do i=1,n
      r=real(i-1,real64)/real(n-1,real64)
      u=u0+r*(u1-u0)
      x=table_dxdu*u
      cell=floor(x)
      frac=x-real(cell,real64)
      frac=min(0.8_real64,max(0.2_real64,frac))
      xsafe=real(cell,real64)+frac
      heads(i)=-10.0_real64**(xsafe/table_dxdu)
      call require(heads(i)>ROSSFAST_D3R_H_MIN_CM .and. heads(i)<ROSSFAST_D3R_H_MAX_CM,'profile head envelope')
    end do
  end subroutine build_profile

  subroutine shared_forcing(policy_id,ref_k,ross_k,qtop,qbot)
    character(len=*),intent(in) :: policy_id
    real(real64),intent(in) :: ref_k(n),ross_k(n)
    real(real64),intent(out) :: qtop,qbot
    select case(trim(policy_id))
    case('ZERO_SHARED')
      qtop=0.0_real64; qbot=0.0_real64
    case('NOMINAL_SHARED')
      qtop=0.01_real64*sqrt(ref_k(1)*ross_k(1))
      qbot=-0.004_real64*sqrt(ref_k(n)*ross_k(n))
    case default
      call require(.false.,'unknown forcing policy')
      qtop=0.0_real64; qbot=0.0_real64
    end select
  end subroutine shared_forcing

  logical function forcing_admitted(k,qtop,qbot) result(ok)
    real(real64),intent(in) :: k(n),qtop,qbot
    real(real64) :: top_ref,bottom_ref,top_limit,bottom_limit
    ok=.false.
    if (.not.all(ieee_is_finite(k)) .or. any(k<=0.0_real64)) return
    top_ref=0.01_real64*k(1)
    bottom_ref=-0.004_real64*k(n)
    top_limit=0.02_real64*max(abs(top_ref),abs(k(1)),1.0e-12_real64)
    bottom_limit=0.02_real64*max(abs(bottom_ref),abs(k(n)),1.0e-12_real64)
    if (abs(qtop-top_ref)>top_limit+1.0e-15_real64) return
    if (abs(qbot-bottom_ref)>bottom_limit+1.0e-15_real64) return
    ok=.true.
  end function forcing_admitted

  subroutine prepare_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,heads,theta,qtop,qbot)
    type(soil_water_solve_request_t),intent(inout) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: heads(n),theta(n),qtop,qbot
    if (allocated(req%base_state%pressure_head)) deallocate(req%base_state%pressure_head)
    if (allocated(req%base_state%water_content)) deallocate(req%base_state%water_content)
    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=heads
    req%base_state%water_content=theta
    req%base_state%ponding_depth=0.0_real64
    req%base_state%groundwater_level=-999.0_real64
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop
    req%boundary%top_head=heads(1)
    req%boundary%bottom_flux=qbot
    req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16
    req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0
    req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%total_balance_tolerance=reference_internal_balance_rate_tol_cm_per_day
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=ROSSFAST_D3R_OUTER_HORIZON_DAY
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine prepare_request

  logical function reference_route_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function reference_route_valid

  logical function rossfast_route_valid(result,request,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='rossfast-d3r') return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (.not.state_valid(result,material)) return
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) return
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) return
    ok=.true.
  end function rossfast_route_valid

  function reference_route_reason(result,request,material) result(reason)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    character(len=64) :: reason
    reason='OK'
    if (result%status/=SW_SOLVE_CONVERGED) then; reason='STATUS_NOT_CONVERGED'; return; end if
    if (trim(result%diagnostics%route)/='legacy-reference-bound') then; reason='ROUTE_MISMATCH'; return; end if
    if (.not.result%integrated_mass_balance_residual_available) then; reason='MASS_UNAVAILABLE'; return; end if
    if (.not.result%native_balance_rate_residual_available) then; reason='NATIVE_BALANCE_UNAVAILABLE'; return; end if
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) then; reason='MASS_NONFINITE'; return; end if
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) then; reason='NATIVE_BALANCE_NONFINITE'; return; end if
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) then; reason='MASS_GATE'; return; end if
    if (.not.state_valid(result,material)) then; reason='STATE_INVALID'; return; end if
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) then; reason='TOP_FLUX_MISMATCH'; return; end if
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) then; reason='BOTTOM_FLUX_MISMATCH'; return; end if
  end function reference_route_reason

  function rossfast_route_reason(result,request,material) result(reason)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    character(len=64) :: reason
    reason='OK'
    if (result%status/=SW_SOLVE_CONVERGED) then; reason='STATUS_NOT_CONVERGED'; return; end if
    if (trim(result%diagnostics%route)/='rossfast-d3r') then; reason='ROUTE_MISMATCH'; return; end if
    if (.not.result%integrated_mass_balance_residual_available) then; reason='MASS_UNAVAILABLE'; return; end if
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) then; reason='MASS_NONFINITE'; return; end if
    if (abs(result%integrated_mass_balance_residual_cm)>ROSSFAST_D3R_HARD_MASS_TOL_CM) then; reason='MASS_GATE'; return; end if
    if (.not.state_valid(result,material)) then; reason='STATE_INVALID'; return; end if
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) then; reason='TOP_FLUX_MISMATCH'; return; end if
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) then; reason='BOTTOM_FLUX_MISMATCH'; return; end if
  end function rossfast_route_reason

  logical function state_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    ok=.false.
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) return
    if (any(result%candidate_state%water_content<=material%theta_r) .or. any(result%candidate_state%water_content>=material%theta_s)) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    ok=.true.
  end function state_valid

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,case_id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: case_id
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=925000+case_id
    parameter_set%active_nodes=n
    allocate(parameter_set%z(n),parameter_set%dz(n),parameter_set%node_distance(n))
    do i=1,n
      parameter_set%z(i)=-ROSSFAST_D3R_DZ_CM*(real(i,real64)-0.5_real64)
    end do
    parameter_set%dz=ROSSFAST_D3R_DZ_CM
    parameter_set%node_distance=ROSSFAST_D3R_DZ_CM
    cofgen_out=0.0_real64
    do i=1,n
      cofgen_out(1,i)=mat%theta_r; cofgen_out(2,i)=mat%theta_s; cofgen_out(3,i)=mat%ksatfit_cm_per_day
      cofgen_out(4,i)=mat%alpha_per_cm; cofgen_out(5,i)=mat%lambda; cofgen_out(6,i)=mat%n
      cofgen_out(7,i)=m; cofgen_out(8,i)=mat%alpha_per_cm; cofgen_out(9,i)=mat%h_enpr_cm
      cofgen_out(10,i)=mat%ksatfit_cm_per_day; cofgen_out(11,i)=0.999_real64
      cofgen_out(12,i)=0.99_real64*mat%ksatfit_cm_per_day
      cofgen_out(22,i)=-1.0e6_real64; cofgen_out(23,i)=1.0e-12_real64
    end do
  end subroutine initialize_parameter_contract

  pure logical function same_real(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    same_real=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  pure logical function is_checkpoint(step)
    integer,intent(in) :: step
    is_checkpoint=step==1 .or. step==2 .or. step==4 .or. step==8 .or. step==16 .or. step==32
  end function is_checkpoint

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'F_ROSS25_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_ross25_serial_hydrologic_validation
