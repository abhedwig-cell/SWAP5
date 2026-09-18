program test_pub_p2e19_reference_balance_scaling_diagnostic
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id, &
       ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: n=ROSSFAST_D3R_N_CELLS
  integer, parameter :: nmat=6,nse=3,nforcing=2,nlevels=6,npolicies=2,ncases=nmat*nse*nforcing
  integer, parameter :: POLICY_FIXED_RATE=1,POLICY_INTEGRATED_INVARIANT=2
  integer, parameter :: nsub_levels(nlevels)=[1,2,4,8,16,32]
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: fixed_rate_tol=1.0e-12_real64
  real(real64), parameter :: integrated_allowance_cm=1.6e-15_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: stability_factor=0.10_real64

  character(len=20), parameter :: policy_ids(npolicies)=[character(len=20) :: &
       'FIXED_RATE','INTEGRATED_INVARIANT']
  character(len=3), parameter :: material_ids(nmat)=[character(len=3) :: 'B01','B12','O01','O05','O14','O18']
  character(len=7), parameter :: forcing_ids(nforcing)=[character(len=7) :: 'DRYING ','NOMINAL']
  real(real64), parameter :: se_levels(nse)=[0.65_real64,0.85_real64,0.96_real64]
  real(real64), parameter :: qtop_factor(nforcing)=[-0.005_real64,0.010_real64]
  real(real64), parameter :: qbot_factor(nforcing)=[-0.019_real64,-0.004_real64]

  real(real64), parameter :: p2e14_h_inf(nse)=[ &
       0.009310899886486368_real64,0.05684414280500505_real64,0.7386357920248865_real64]
  real(real64), parameter :: p2e14_h_rms(nse)=[ &
       0.004264337561059986_real64,0.02309047189054667_real64,0.19122530959872563_real64]
  real(real64), parameter :: p2e14_theta_inf(nse)=[ &
       0.000017908123244203544_real64,0.00024393588764148877_real64,0.0012274135237608785_real64]
  real(real64), parameter :: p2e14_theta_rms(nse)=[ &
       0.000006578609068585418_real64,0.00008095278187597767_real64,0.00035749599085978164_real64]
  real(real64), parameter :: p2e14_storage(nse)=[ &
       2.1316282072803006e-14_real64,2.842170943040401e-14_real64,2.8421709430404007e-14_real64]

  integer :: valid_counts(npolicies,nlevels)
  integer :: neutrality_count,neutrality_pass_count,neutrality_fail_count
  integer :: scaled_fine_available_count,scaled_stable_count,scaled_unstable_count
  integer :: imat,ise,iforce,case_id

  valid_counts=0
  neutrality_count=0; neutrality_pass_count=0; neutrality_fail_count=0
  scaled_fine_available_count=0; scaled_stable_count=0; scaled_unstable_count=0
  case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E19_BUDGET|SE=',se_levels(ise), &
         '|D_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',p2e14_storage(ise)
  end do

  do imat=1,nmat
    do ise=1,nse
      do iforce=1,nforcing
        case_id=case_id+1
        call run_case(case_id,ise,material_ids(imat),se_levels(ise),forcing_ids(iforce), &
             qtop_factor(iforce),qbot_factor(iforce))
      end do
    end do
  end do

  call require(case_id==ncases,'exact 36 cases attempted')
  call require(valid_counts(POLICY_FIXED_RATE,1)==36,'P2E18 fixed-rate 1-substep reproduction')
  call require(valid_counts(POLICY_FIXED_RATE,2)==29,'P2E18 fixed-rate 2-substep reproduction')
  call require(valid_counts(POLICY_FIXED_RATE,3)==7,'P2E18 fixed-rate 4-substep reproduction')
  call require(valid_counts(POLICY_FIXED_RATE,4)==0,'P2E18 fixed-rate 8-substep reproduction')
  call require(valid_counts(POLICY_FIXED_RATE,5)==0,'P2E18 fixed-rate 16-substep reproduction')
  call require(valid_counts(POLICY_FIXED_RATE,6)==0,'P2E18 fixed-rate 32-substep reproduction')

  write(*,'(A,I0)') 'PUB_P2E19_CASE_COUNT=',ncases
  write(*,'(A,I0)') 'PUB_P2E19_POLICY_COUNT=',npolicies
  write(*,'(A,I0)') 'PUB_P2E19_REFINEMENT_LEVEL_COUNT=',nlevels
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N1=',valid_counts(POLICY_FIXED_RATE,1)
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N2=',valid_counts(POLICY_FIXED_RATE,2)
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N4=',valid_counts(POLICY_FIXED_RATE,3)
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N8=',valid_counts(POLICY_FIXED_RATE,4)
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N16=',valid_counts(POLICY_FIXED_RATE,5)
  write(*,'(A,I0)') 'PUB_P2E19_FIXED_VALID_N32=',valid_counts(POLICY_FIXED_RATE,6)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N1=',valid_counts(POLICY_INTEGRATED_INVARIANT,1)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N2=',valid_counts(POLICY_INTEGRATED_INVARIANT,2)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N4=',valid_counts(POLICY_INTEGRATED_INVARIANT,3)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N8=',valid_counts(POLICY_INTEGRATED_INVARIANT,4)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N16=',valid_counts(POLICY_INTEGRATED_INVARIANT,5)
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_VALID_N32=',valid_counts(POLICY_INTEGRATED_INVARIANT,6)
  write(*,'(A,I0)') 'PUB_P2E19_NEUTRALITY_COMPARISON_COUNT=',neutrality_count
  write(*,'(A,I0)') 'PUB_P2E19_NEUTRALITY_PASS_COUNT=',neutrality_pass_count
  write(*,'(A,I0)') 'PUB_P2E19_NEUTRALITY_FAIL_COUNT=',neutrality_fail_count
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_FINE_AVAILABLE_COUNT=',scaled_fine_available_count
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_STABLE_COUNT=',scaled_stable_count
  write(*,'(A,I0)') 'PUB_P2E19_SCALED_UNSTABLE_COUNT=',scaled_unstable_count
  write(*,'(A)') 'PUB_P2E19_INTEGRATED_ALLOWANCE_CM=1.6E-15'
  write(*,'(A)') 'PUB_P2E19_ROSSFAST_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E19_TIMING_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E19_PRODUCTION_TOLERANCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E19_P2E18_RECLASSIFIED=FALSE'
  write(*,'(A)') 'PUB_P2E19_REFERENCE_BALANCE_SCALING_DIAGNOSTIC_GATE=PASS'

contains

  subroutine run_case(case_id,ise,material_id,se,forcing_id,top_factor,bottom_factor)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,top_factor,bottom_factor

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),initial_heads(n),initial_theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: final_h(n,nlevels,npolicies),final_theta(n,nlevels,npolicies)
    real(real64) :: storage(nlevels,npolicies),max_mass(nlevels,npolicies)
    logical :: level_valid(nlevels,npolicies),found,neutral_pass,scaled_stable
    character(len=40) :: level_stage
    real(real64) :: h0,k0,top_flux,bottom_flux
    integer :: ip,il

    level_valid=.false.; final_h=0.0_real64; final_theta=0.0_real64
    storage=0.0_real64; max_mass=0.0_real64

    call rossfast_d3r_material_from_id(material_id,material,found)
    call require(found,'material authority available')
    h0=head_from_effective_saturation(se,material)
    call require(ieee_is_finite(h0) .and. h0>ROSSFAST_D3R_H_MIN_CM .and. h0<ROSSFAST_D3R_H_MAX_CM, &
         'initial head in common domain')

    call initialize_parameter_contract(parameters,cofgen,material,case_id)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,horizon_day)
    initial_heads=h0
    call constitutive%evaluate(initial_heads,initial_theta,conductivity,capacity,dkdh)
    call require(all(ieee_is_finite(initial_theta)) .and. all(ieee_is_finite(conductivity)) .and. &
         all(conductivity>0.0_real64),'initial constitutive state valid')
    k0=conductivity(1)
    top_flux=top_factor*k0
    bottom_flux=bottom_factor*k0
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    do ip=1,npolicies
      do il=1,nlevels
        call run_refinement_level(ip,nsub_levels(il),parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
             material,initial_heads,initial_theta,top_flux,bottom_flux,level_valid(il,ip),level_stage, &
             final_h(:,il,ip),final_theta(:,il,ip),storage(il,ip),max_mass(il,ip))
        if (level_valid(il,ip)) valid_counts(ip,il)=valid_counts(ip,il)+1
        write(*,'(*(g0))') 'PUB_P2E19_LEVEL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
             '|POLICY=',trim(policy_ids(ip)),'|NSUB=',nsub_levels(il), &
             '|DT=',horizon_day/real(nsub_levels(il),real64), &
             '|RATE_TOL=',policy_rate_tol(ip,horizon_day/real(nsub_levels(il),real64)), &
             '|VALID=',level_valid(il,ip),'|STAGE=',trim(level_stage),'|MAX_MASS_CM=',max_mass(il,ip)
      end do
    end do

    do il=1,nlevels
      if (level_valid(il,POLICY_FIXED_RATE) .and. level_valid(il,POLICY_INTEGRATED_INVARIANT)) then
        call compare_endpoints(case_id,ise,material_id,se,forcing_id,'POLICY_NEUTRALITY',nsub_levels(il), &
             final_h(:,il,POLICY_FIXED_RATE),final_theta(:,il,POLICY_FIXED_RATE),storage(il,POLICY_FIXED_RATE), &
             final_h(:,il,POLICY_INTEGRATED_INVARIANT),final_theta(:,il,POLICY_INTEGRATED_INVARIANT), &
             storage(il,POLICY_INTEGRATED_INVARIANT),neutral_pass)
        neutrality_count=neutrality_count+1
        if (neutral_pass) then
          neutrality_pass_count=neutrality_pass_count+1
        else
          neutrality_fail_count=neutrality_fail_count+1
        end if
      end if
    end do

    if (level_valid(4,POLICY_INTEGRATED_INVARIANT) .and. level_valid(5,POLICY_INTEGRATED_INVARIANT) .and. &
        level_valid(6,POLICY_INTEGRATED_INVARIANT)) then
      scaled_fine_available_count=scaled_fine_available_count+1
      call scaled_stability(case_id,ise,material_id,se,forcing_id,final_h,final_theta,storage,scaled_stable)
      if (scaled_stable) then
        scaled_stable_count=scaled_stable_count+1
      else
        scaled_unstable_count=scaled_unstable_count+1
      end if
    else
      write(*,'(*(g0))') 'PUB_P2E19_SCALED_STABILITY|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
           '|F=',trim(forcing_id),'|AVAILABLE=F|STABLE=F'
    end if
  end subroutine run_case

  subroutine scaled_stability(case_id,ise,material_id,se,forcing_id,final_h,final_theta,storage,stable)
    integer,intent(in) :: case_id,ise
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se
    real(real64),intent(in) :: final_h(n,nlevels,npolicies),final_theta(n,nlevels,npolicies)
    real(real64),intent(in) :: storage(nlevels,npolicies)
    logical,intent(out) :: stable
    logical :: pass_a,pass_b

    call compare_endpoints(case_id,ise,material_id,se,forcing_id,'SCALED_8_VS_16',16, &
         final_h(:,4,POLICY_INTEGRATED_INVARIANT),final_theta(:,4,POLICY_INTEGRATED_INVARIANT), &
         storage(4,POLICY_INTEGRATED_INVARIANT), &
         final_h(:,5,POLICY_INTEGRATED_INVARIANT),final_theta(:,5,POLICY_INTEGRATED_INVARIANT), &
         storage(5,POLICY_INTEGRATED_INVARIANT),pass_a)
    call compare_endpoints(case_id,ise,material_id,se,forcing_id,'SCALED_16_VS_32',32, &
         final_h(:,5,POLICY_INTEGRATED_INVARIANT),final_theta(:,5,POLICY_INTEGRATED_INVARIANT), &
         storage(5,POLICY_INTEGRATED_INVARIANT), &
         final_h(:,6,POLICY_INTEGRATED_INVARIANT),final_theta(:,6,POLICY_INTEGRATED_INVARIANT), &
         storage(6,POLICY_INTEGRATED_INVARIANT),pass_b)
    stable=pass_a .and. pass_b
    write(*,'(*(g0))') 'PUB_P2E19_SCALED_STABILITY|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|AVAILABLE=T|STABLE=',stable
  end subroutine scaled_stability

  subroutine compare_endpoints(case_id,ise,material_id,se,forcing_id,label,nsub, &
       h_a,theta_a,storage_a,h_b,theta_b,storage_b,passed)
    integer,intent(in) :: case_id,ise,nsub
    character(len=*),intent(in) :: material_id,forcing_id,label
    real(real64),intent(in) :: se,h_a(n),theta_a(n),storage_a,h_b(n),theta_b(n),storage_b
    logical,intent(out) :: passed
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    logical :: p1,p2,p3,p4,p5

    dh_inf=maxval(abs(h_b-h_a))
    dh_rms=sqrt(sum((h_b-h_a)**2)/real(n,real64))
    dtheta_inf=maxval(abs(theta_b-theta_a))
    dtheta_rms=sqrt(sum((theta_b-theta_a)**2)/real(n,real64))
    dstorage=abs(storage_b-storage_a)
    p1=dh_inf<=stability_factor*p2e14_h_inf(ise)
    p2=dh_rms<=stability_factor*p2e14_h_rms(ise)
    p3=dtheta_inf<=stability_factor*p2e14_theta_inf(ise)
    p4=dtheta_rms<=stability_factor*p2e14_theta_rms(ise)
    p5=dstorage<=p2e14_storage(ise)
    passed=p1 .and. p2 .and. p3 .and. p4 .and. p5

    write(*,'(*(g0))') 'PUB_P2E19_DELTA|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|LABEL=',trim(label),'|NSUB=',nsub,'|D_H_INF=',dh_inf,'|T_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',dh_rms,'|T_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',dtheta_inf,'|T_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',dtheta_rms,'|T_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',dstorage,'|T_STORAGE=',p2e14_storage(ise),'|PASS=',passed
  end subroutine compare_endpoints

  subroutine run_refinement_level(policy,nsub,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       material,initial_heads,initial_theta,top_flux,bottom_flux,valid,stage,final_heads,final_theta,final_storage,max_mass)
    integer,intent(in) :: policy,nsub
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid
    character(len=*),intent(out) :: stage
    real(real64),intent(out) :: final_heads(n),final_theta(n),final_storage,max_mass

    type(soil_water_solve_result_t) :: result
    real(real64) :: current_heads(n),current_theta(n),ponding,dt,rate_tol
    logical :: step_valid
    character(len=64) :: step_reason
    integer :: isub

    valid=.false.; stage='LEVEL_INITIALIZATION'
    final_heads=0.0_real64; final_theta=0.0_real64; final_storage=0.0_real64; max_mass=0.0_real64
    current_heads=initial_heads; current_theta=initial_theta; ponding=0.0_real64
    dt=horizon_day/real(nsub,real64)
    rate_tol=policy_rate_tol(policy,dt)

    do isub=1,nsub
      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call run_reference_step(parameters,constitutive,source_sink,top_boundary,material,current_heads,current_theta, &
           ponding,top_flux,bottom_flux,dt,rate_tol,result,step_valid,step_reason)
      if (.not.step_valid) then
        write(*,'(*(g0))') 'PUB_P2E19_REFERENCE_GATE|POLICY=',trim(policy_ids(policy)),'|NSUB=',nsub, &
             '|ISUB=',isub,'|DT=',dt,'|RATE_TOL=',rate_tol,'|REASON=',trim(step_reason), &
             '|STATUS=',result%status,'|ROUTE=',trim(result%diagnostics%route), &
             '|MASS_AVAILABLE=',result%integrated_mass_balance_residual_available, &
             '|RATE_AVAILABLE=',result%native_balance_rate_residual_available
        write(stage,'(A,I0)') 'SUBSTEP_REFERENCE_GATE_',isub
        return
      end if
      max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
      current_heads=result%candidate_state%pressure_head
      current_theta=result%candidate_state%water_content
      ponding=result%candidate_state%ponding_depth
    end do

    final_heads=current_heads
    final_theta=current_theta
    final_storage=sum(parameters%dz*current_theta)+ponding
    valid=.true.; stage='NONE'
  end subroutine run_refinement_level

  subroutine run_reference_step(parameters,constitutive,source_sink,top_boundary,material,heads,theta,ponding, &
       top_flux,bottom_flux,dt,rate_tol,result,valid,failure_reason)
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_provider_t),target,intent(in) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: heads(n),theta(n),ponding,top_flux,bottom_flux,dt,rate_tol
    type(soil_water_solve_result_t),intent(out) :: result
    logical,intent(out) :: valid
    character(len=*),intent(out) :: failure_reason

    type(soil_water_solve_request_t) :: request
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace

    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta,heads,ponding, &
         top_flux,bottom_flux,dt,rate_tol)
    call solver%solve(request,workspace,result)
    valid=reference_result_valid(result,request,material,failure_reason)
  end subroutine run_reference_step

  logical function reference_result_valid(result,request,material,reason) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(soil_water_solve_request_t),intent(in) :: request
    type(rossfast_d3r_material_t),intent(in) :: material
    character(len=*),intent(out) :: reason
    ok=.false.; reason='UNKNOWN'
    if (result%status/=SW_SOLVE_CONVERGED) then; reason='STATUS_NOT_CONVERGED'; return; end if
    if (trim(result%diagnostics%route)/='legacy-reference-bound') then; reason='ROUTE_MISMATCH'; return; end if
    if (.not.result%integrated_mass_balance_residual_available) then; reason='MASS_UNAVAILABLE'; return; end if
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) then; reason='MASS_NONFINITE'; return; end if
    if (abs(result%integrated_mass_balance_residual_cm)>hard_mass_tol_cm) then; reason='HARD_MASS_LIMIT'; return; end if
    if (.not.result%native_balance_rate_residual_available) then; reason='RATE_UNAVAILABLE'; return; end if
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) then; reason='RATE_NONFINITE'; return; end if
    if (result%candidate_state%active_nodes/=n) then; reason='ACTIVE_NODE_COUNT'; return; end if
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) then
      reason='STATE_UNALLOCATED'; return
    end if
    if (size(result%candidate_state%pressure_head)/=n .or. size(result%candidate_state%water_content)/=n) then
      reason='STATE_SIZE'; return
    end if
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head)) .or. &
        any(.not.ieee_is_finite(result%candidate_state%water_content))) then; reason='STATE_NONFINITE'; return; end if
    if (any(result%candidate_state%pressure_head<=ROSSFAST_D3R_H_MIN_CM) .or. &
        any(result%candidate_state%pressure_head>=ROSSFAST_D3R_H_MAX_CM)) then; reason='HEAD_DOMAIN'; return; end if
    if (any(result%candidate_state%water_content<=material%theta_r) .or. &
        any(result%candidate_state%water_content>=material%theta_s)) then; reason='THETA_DOMAIN'; return; end if
    if (.not.same_real(result%top_flux,request%boundary%top_flux)) then; reason='TOP_FLUX_IDENTITY'; return; end if
    if (.not.same_real(result%bottom_flux,request%boundary%bottom_flux)) then; reason='BOTTOM_FLUX_IDENTITY'; return; end if
    ok=.true.; reason='NONE'
  end function reference_result_valid

  pure real(real64) function policy_rate_tol(policy,dt) result(value)
    integer,intent(in) :: policy
    real(real64),intent(in) :: dt
    if (policy==POLICY_FIXED_RATE) then
      value=fixed_rate_tol
    else
      value=integrated_allowance_cm/dt
    end if
  end function policy_rate_tol

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine initialize_parameter_contract(parameter_set,cofgen_out,mat,case_id)
    type(soil_water_parameter_set_t),target,intent(out) :: parameter_set
    real(real64),intent(out) :: cofgen_out(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    integer,intent(in) :: case_id
    real(real64) :: m
    integer :: i
    m=1.0_real64-1.0_real64/mat%n
    parameter_set%parameter_set_id=924000+case_id
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

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,heads,ponding, &
       qtop,qbot,dt,rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt,rate_tol

    req%parameters=>parameter_set
    req%base_state%active_nodes=n
    allocate(req%base_state%pressure_head(n),req%base_state%water_content(n))
    req%base_state%pressure_head=heads
    req%base_state%water_content=theta
    req%base_state%ponding_depth=ponding
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
    req%numerical%compartment_balance_tolerance=rate_tol
    req%numerical%total_balance_tolerance=rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  pure logical function same_real(a,b)
    real(real64),intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    same_real=abs(a-b)<=32.0_real64*epsilon(1.0_real64)*scale
  end function same_real

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'PUB_P2E19_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e19_reference_balance_scaling_diagnostic
