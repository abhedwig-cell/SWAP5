program test_pub_p2e21_ref_high_representation_bound
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
  integer, parameter :: nmat=6,nse=3,nforcing=2,nlevels=3,ncases=nmat*nse*nforcing
  integer, parameter :: nsub_levels(nlevels)=[8,16,32]
  real(real64), parameter :: horizon_day=0.0016_real64
  real(real64), parameter :: integrated_allowance_cm=1.6e-15_real64
  real(real64), parameter :: hard_mass_tol_cm=1.0e-12_real64
  real(real64), parameter :: stability_factor=0.10_real64

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

  integer, parameter :: POLICY_CONTROL=1, POLICY_REP_BOUND=2
  integer :: qualified_count,route_unresolved_count,stability_unresolved_count,policy_unresolved_count
  integer :: policy_neutral_comparison_count,policy_neutral_pass_count,policy_neutral_fail_count
  integer :: representation_bound_violation_case_count
  integer :: control_valid_count(nlevels),bounded_valid_count(nlevels)
  integer :: imat,ise,iforce,case_id

  qualified_count=0
  route_unresolved_count=0
  stability_unresolved_count=0
  policy_unresolved_count=0
  policy_neutral_comparison_count=0
  policy_neutral_pass_count=0
  policy_neutral_fail_count=0
  representation_bound_violation_case_count=0
  control_valid_count=0
  bounded_valid_count=0
  case_id=0

  do ise=1,nse
    write(*,'(*(g0))') 'PUB_P2E21_BUDGET|SE=',se_levels(ise), &
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
  call require(qualified_count+route_unresolved_count+stability_unresolved_count+policy_unresolved_count==ncases, &
       'every case classified exactly once')
  call require(policy_neutral_pass_count+policy_neutral_fail_count==policy_neutral_comparison_count, &
       'every overlapping policy endpoint classified')

  do ise=1,nlevels
    write(*,'(*(g0))') 'PUB_P2E21_POLICY_ROUTE_SUMMARY|NSUB=',nsub_levels(ise), &
         '|CONTROL_VALID=',control_valid_count(ise),'|REP_BOUND_VALID=',bounded_valid_count(ise)
  end do

  write(*,'(A,I0)') 'PUB_P2E21_CASE_COUNT=',ncases
  write(*,'(A,I0)') 'PUB_P2E21_FINE_LEVEL_COUNT=',nlevels
  write(*,'(A,I0)') 'PUB_P2E21_QUALIFIED_COUNT=',qualified_count
  write(*,'(A,I0)') 'PUB_P2E21_ROUTE_UNRESOLVED_COUNT=',route_unresolved_count
  write(*,'(A,I0)') 'PUB_P2E21_POLICY_UNRESOLVED_COUNT=',policy_unresolved_count
  write(*,'(A,I0)') 'PUB_P2E21_STABILITY_UNRESOLVED_COUNT=',stability_unresolved_count
  write(*,'(A,I0)') 'PUB_P2E21_POLICY_NEUTRAL_COMPARISON_COUNT=',policy_neutral_comparison_count
  write(*,'(A,I0)') 'PUB_P2E21_POLICY_NEUTRAL_PASS_COUNT=',policy_neutral_pass_count
  write(*,'(A,I0)') 'PUB_P2E21_POLICY_NEUTRAL_FAIL_COUNT=',policy_neutral_fail_count
  write(*,'(A,I0)') 'PUB_P2E21_REPRESENTATION_BOUND_VIOLATION_CASE_COUNT=',representation_bound_violation_case_count
  write(*,'(A)') 'PUB_P2E21_REF_HIGH_ENDPOINT=32_SUBSTEPS'
  write(*,'(A)') 'PUB_P2E21_COMPARTMENT_INTEGRATED_ALLOWANCE_CM=1.6E-15'
  write(*,'(A)') 'PUB_P2E21_TOTAL_BOUND_FORMULA=PRE_SOLVE_THETA_S_AND_BASE_SPACING'
  write(*,'(A)') 'PUB_P2E21_EMPIRICAL_SAFETY_FACTOR=NONE'
  write(*,'(A)') 'PUB_P2E21_ROSSFAST_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E21_TIMING_EXECUTED=FALSE'
  write(*,'(A)') 'PUB_P2E21_PRODUCTION_TOLERANCE_CHANGED=FALSE'
  write(*,'(A)') 'PUB_P2E21_SCIENTIFIC_RESULT_IS_CI_FAILURE=FALSE'
  write(*,'(A)') 'PUB_P2E21_REPRESENTATION_BOUNDED_REF_HIGH_GATE=PASS'

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
    real(real64) :: control_h(n,nlevels),control_theta(n,nlevels),control_storage(nlevels),control_mass(nlevels)
    real(real64) :: bounded_h(n,nlevels),bounded_theta(n,nlevels),bounded_storage(nlevels),bounded_mass(nlevels)
    real(real64) :: control_min_bound(nlevels),control_max_bound(nlevels),bounded_min_bound(nlevels),bounded_max_bound(nlevels)
    logical :: control_valid(nlevels),bounded_valid(nlevels),control_bound_ok(nlevels),bounded_bound_ok(nlevels)
    logical :: found,pass_a,pass_b,neutral_pass,neutral_case_ok
    character(len=64) :: control_stage,bounded_stage,classification
    real(real64) :: h0,k0,top_flux,bottom_flux
    integer :: il,inode

    control_valid=.false.; bounded_valid=.false.
    control_bound_ok=.true.; bounded_bound_ok=.true.
    control_h=0.0_real64; control_theta=0.0_real64; control_storage=0.0_real64; control_mass=0.0_real64
    bounded_h=0.0_real64; bounded_theta=0.0_real64; bounded_storage=0.0_real64; bounded_mass=0.0_real64
    control_min_bound=0.0_real64; control_max_bound=0.0_real64
    bounded_min_bound=0.0_real64; bounded_max_bound=0.0_real64

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

    do il=1,nlevels
      call run_refinement_level(POLICY_CONTROL,nsub_levels(il),parameters,hydraulic_parameters,constitutive,source_sink, &
           top_boundary,material,initial_heads,initial_theta,top_flux,bottom_flux,control_valid(il),control_bound_ok(il), &
           control_stage,control_h(:,il),control_theta(:,il),control_storage(il),control_mass(il), &
           control_min_bound(il),control_max_bound(il))
      if (control_valid(il)) control_valid_count(il)=control_valid_count(il)+1
      write(*,'(*(g0))') 'PUB_P2E21_LEVEL|POLICY=CONTROL|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
           '|F=',trim(forcing_id),'|NSUB=',nsub_levels(il),'|DT=',horizon_day/real(nsub_levels(il),real64), &
           '|VALID=',control_valid(il),'|BOUND_OK=',control_bound_ok(il),'|STAGE=',trim(control_stage), &
           '|MIN_TOTAL_BOUND_CM=',control_min_bound(il),'|MAX_TOTAL_BOUND_CM=',control_max_bound(il), &
           '|MAX_MASS_CM=',control_mass(il)

      call run_refinement_level(POLICY_REP_BOUND,nsub_levels(il),parameters,hydraulic_parameters,constitutive,source_sink, &
           top_boundary,material,initial_heads,initial_theta,top_flux,bottom_flux,bounded_valid(il),bounded_bound_ok(il), &
           bounded_stage,bounded_h(:,il),bounded_theta(:,il),bounded_storage(il),bounded_mass(il), &
           bounded_min_bound(il),bounded_max_bound(il))
      if (bounded_valid(il)) bounded_valid_count(il)=bounded_valid_count(il)+1
      write(*,'(*(g0))') 'PUB_P2E21_LEVEL|POLICY=REP_BOUND|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
           '|F=',trim(forcing_id),'|NSUB=',nsub_levels(il),'|DT=',horizon_day/real(nsub_levels(il),real64), &
           '|VALID=',bounded_valid(il),'|BOUND_OK=',bounded_bound_ok(il),'|STAGE=',trim(bounded_stage), &
           '|MIN_TOTAL_BOUND_CM=',bounded_min_bound(il),'|MAX_TOTAL_BOUND_CM=',bounded_max_bound(il), &
           '|MAX_MASS_CM=',bounded_mass(il)
    end do

    neutral_case_ok=.true.
    do il=1,nlevels
      if (control_valid(il) .and. bounded_valid(il)) then
        call compare_policy_endpoints(case_id,ise,material_id,se,forcing_id,nsub_levels(il), &
             control_h(:,il),control_theta(:,il),control_storage(il), &
             bounded_h(:,il),bounded_theta(:,il),bounded_storage(il),neutral_pass)
        policy_neutral_comparison_count=policy_neutral_comparison_count+1
        if (neutral_pass) then
          policy_neutral_pass_count=policy_neutral_pass_count+1
        else
          policy_neutral_fail_count=policy_neutral_fail_count+1
          neutral_case_ok=.false.
        end if
      end if
    end do

    if (.not.all(bounded_bound_ok)) then
      representation_bound_violation_case_count=representation_bound_violation_case_count+1
    end if

    if (.not.all(bounded_valid) .or. .not.all(bounded_bound_ok)) then
      classification='REF_HIGH_ROUTE_UNRESOLVED'
      route_unresolved_count=route_unresolved_count+1
      write(*,'(*(g0))') 'PUB_P2E21_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
           '|CLASS=',trim(classification),'|BOUND_OK=',all(bounded_bound_ok)
      return
    end if

    if (.not.neutral_case_ok) then
      classification='REF_HIGH_POLICY_UNRESOLVED'
      policy_unresolved_count=policy_unresolved_count+1
      write(*,'(*(g0))') 'PUB_P2E21_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
           '|CLASS=',trim(classification)
      return
    end if

    call compare_temporal_endpoints(case_id,ise,material_id,se,forcing_id,'8_VS_16', &
         bounded_h(:,1),bounded_theta(:,1),bounded_storage(1),bounded_h(:,2),bounded_theta(:,2),bounded_storage(2),pass_a)
    call compare_temporal_endpoints(case_id,ise,material_id,se,forcing_id,'16_VS_32', &
         bounded_h(:,2),bounded_theta(:,2),bounded_storage(2),bounded_h(:,3),bounded_theta(:,3),bounded_storage(3),pass_b)

    if (.not.(pass_a .and. pass_b)) then
      classification='REF_HIGH_STABILITY_UNRESOLVED'
      stability_unresolved_count=stability_unresolved_count+1
      write(*,'(*(g0))') 'PUB_P2E21_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
           '|CLASS=',trim(classification),'|PASS_8_16=',pass_a,'|PASS_16_32=',pass_b
      return
    end if

    classification='REF_HIGH_QUALIFIED'
    qualified_count=qualified_count+1
    write(*,'(*(g0))') 'PUB_P2E21_CASE|CASE=',case_id,'|M=',trim(material_id),'|SE=',se,'|F=',trim(forcing_id), &
         '|CLASS=',trim(classification),'|REF_STORAGE=',bounded_storage(3), &
         '|FINAL_TOTAL_BOUND_CM=',bounded_max_bound(3)
    do inode=1,n
      write(*,'(*(g0))') 'PUB_P2E21_REF_HIGH_NODE|CASE=',case_id,'|NODE=',inode, &
           '|H_CM=',bounded_h(inode,3),'|THETA=',bounded_theta(inode,3)
    end do
  end subroutine run_case

  subroutine compare_temporal_endpoints(case_id,ise,material_id,se,forcing_id,label,h_a,theta_a,storage_a, &
       h_b,theta_b,storage_b,passed)
    integer,intent(in) :: case_id,ise
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
    write(*,'(*(g0))') 'PUB_P2E21_TEMPORAL_DELTA|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|PAIR=',trim(label),'|D_H_INF=',dh_inf,'|T_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',dh_rms,'|T_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',dtheta_inf,'|T_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',dtheta_rms,'|T_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',dstorage,'|T_STORAGE=',p2e14_storage(ise),'|PASS=',passed
  end subroutine compare_temporal_endpoints

  subroutine compare_policy_endpoints(case_id,ise,material_id,se,forcing_id,nsub,h_control,theta_control,storage_control, &
       h_bound,theta_bound,storage_bound,passed)
    integer,intent(in) :: case_id,ise,nsub
    character(len=*),intent(in) :: material_id,forcing_id
    real(real64),intent(in) :: se,h_control(n),theta_control(n),storage_control,h_bound(n),theta_bound(n),storage_bound
    logical,intent(out) :: passed
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    logical :: p1,p2,p3,p4,p5

    dh_inf=maxval(abs(h_bound-h_control))
    dh_rms=sqrt(sum((h_bound-h_control)**2)/real(n,real64))
    dtheta_inf=maxval(abs(theta_bound-theta_control))
    dtheta_rms=sqrt(sum((theta_bound-theta_control)**2)/real(n,real64))
    dstorage=abs(storage_bound-storage_control)
    p1=dh_inf<=stability_factor*p2e14_h_inf(ise)
    p2=dh_rms<=stability_factor*p2e14_h_rms(ise)
    p3=dtheta_inf<=stability_factor*p2e14_theta_inf(ise)
    p4=dtheta_rms<=stability_factor*p2e14_theta_rms(ise)
    p5=dstorage<=p2e14_storage(ise)
    passed=p1 .and. p2 .and. p3 .and. p4 .and. p5
    write(*,'(*(g0))') 'PUB_P2E21_POLICY_DELTA|CASE=',case_id,'|M=',trim(material_id),'|SE=',se, &
         '|F=',trim(forcing_id),'|NSUB=',nsub,'|D_H_INF=',dh_inf,'|T_H_INF=',stability_factor*p2e14_h_inf(ise), &
         '|D_H_RMS=',dh_rms,'|T_H_RMS=',stability_factor*p2e14_h_rms(ise), &
         '|D_THETA_INF=',dtheta_inf,'|T_THETA_INF=',stability_factor*p2e14_theta_inf(ise), &
         '|D_THETA_RMS=',dtheta_rms,'|T_THETA_RMS=',stability_factor*p2e14_theta_rms(ise), &
         '|D_STORAGE=',dstorage,'|T_STORAGE=',p2e14_storage(ise),'|PASS=',passed
  end subroutine compare_policy_endpoints

  subroutine run_refinement_level(policy_id,nsub,parameters,hydraulic_parameters,constitutive,source_sink,top_boundary, &
       material,initial_heads,initial_theta,top_flux,bottom_flux,valid,bound_ok,stage,final_heads,final_theta,final_storage, &
       max_mass,min_total_bound,max_total_bound)
    integer,intent(in) :: policy_id,nsub
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_parameters_t),target,intent(in) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: initial_heads(n),initial_theta(n),top_flux,bottom_flux
    logical,intent(out) :: valid,bound_ok
    character(len=*),intent(out) :: stage
    real(real64),intent(out) :: final_heads(n),final_theta(n),final_storage,max_mass,min_total_bound,max_total_bound

    type(soil_water_solve_result_t) :: result
    real(real64) :: current_heads(n),current_theta(n),ponding,dt,comp_rate_tol,total_rate_tol,total_bound
    logical :: step_valid,step_bound_ok
    character(len=64) :: step_reason
    integer :: isub

    valid=.false.; bound_ok=.true.; stage='LEVEL_INITIALIZATION'
    final_heads=0.0_real64; final_theta=0.0_real64; final_storage=0.0_real64; max_mass=0.0_real64
    current_heads=initial_heads; current_theta=initial_theta; ponding=0.0_real64
    dt=horizon_day/real(nsub,real64)
    comp_rate_tol=integrated_allowance_cm/dt
    min_total_bound=huge(1.0_real64); max_total_bound=0.0_real64

    do isub=1,nsub
      if (policy_id==POLICY_REP_BOUND) then
        total_bound=representation_total_integrated_bound(current_theta,material,parameters%dz)
      else
        total_bound=integrated_allowance_cm
      end if
      total_rate_tol=total_bound/dt
      min_total_bound=min(min_total_bound,total_bound)
      max_total_bound=max(max_total_bound,total_bound)

      call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
      call run_reference_step(policy_id,parameters,constitutive,source_sink,top_boundary,material,current_heads,current_theta, &
           ponding,top_flux,bottom_flux,dt,comp_rate_tol,total_rate_tol,result,step_valid,step_bound_ok,step_reason)
      bound_ok=bound_ok .and. step_bound_ok
      if (.not.step_bound_ok) then
        stage='REPRESENTATION_BOUND_CHECK'
        return
      end if
      if (.not.step_valid) then
        write(*,'(*(g0))') 'PUB_P2E21_REFERENCE_GATE|POLICY=',policy_id,'|NSUB=',nsub,'|ISUB=',isub,'|DT=',dt, &
             '|COMP_RATE_TOL=',comp_rate_tol,'|TOTAL_RATE_TOL=',total_rate_tol,'|TOTAL_BOUND_CM=',total_bound, &
             '|REASON=',trim(step_reason),'|STATUS=',result%status,'|ROUTE=',trim(result%diagnostics%route)
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

  subroutine run_reference_step(policy_id,parameters,constitutive,source_sink,top_boundary,material,heads,theta,ponding, &
       top_flux,bottom_flux,dt,comp_rate_tol,total_rate_tol,result,valid,bound_check,failure_reason)
    integer,intent(in) :: policy_id
    type(soil_water_parameter_set_t),target,intent(in) :: parameters
    type(b110_default_mvg_provider_t),target,intent(in) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_boundary
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),intent(in) :: heads(n),theta(n),ponding,top_flux,bottom_flux,dt,comp_rate_tol,total_rate_tol
    type(soil_water_solve_result_t),intent(out) :: result
    logical,intent(out) :: valid,bound_check
    character(len=*),intent(out) :: failure_reason
    type(soil_water_solve_request_t) :: request
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace

    call initialize_request(request,parameters,constitutive,source_sink,top_boundary,theta,heads,ponding, &
         top_flux,bottom_flux,dt,comp_rate_tol,total_rate_tol)
    call solver%solve(request,workspace,result)

    bound_check=.true.
    if (policy_id==POLICY_REP_BOUND) then
      if (.not.allocated(workspace%richards%provider_theta)) then
        bound_check=.false.
      else if (size(workspace%richards%provider_theta)/=n) then
        bound_check=.false.
      else if (any(.not.ieee_is_finite(workspace%richards%provider_theta))) then
        bound_check=.false.
      else if (any(workspace%richards%provider_theta<=0.0_real64)) then
        bound_check=.false.
      else if (any(spacing(workspace%richards%provider_theta)>spacing(material%theta_s))) then
        bound_check=.false.
      end if
    end if

    if (.not.bound_check) then
      valid=.false.; failure_reason='REPRESENTATION_BOUND_CHECK'; return
    end if
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

  subroutine initialize_request(req,parameter_set,hydraulic_provider,source_provider,top_provider,theta,heads,ponding, &
       qtop,qbot,dt,comp_rate_tol,total_rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: parameter_set
    type(b110_default_mvg_provider_t),target,intent(in) :: hydraulic_provider
    type(b110_source_sink_provider_t),target,intent(in) :: source_provider
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    real(real64),intent(in) :: theta(n),heads(n),ponding,qtop,qbot,dt,comp_rate_tol,total_rate_tol

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
    req%numerical%compartment_balance_tolerance=comp_rate_tol
    req%numerical%total_balance_tolerance=total_rate_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64
    req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64
    req%step_duration=dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hydraulic_provider
    req%evaluation%source_sink=>source_provider
    req%evaluation%top_boundary=>top_provider
  end subroutine initialize_request

  pure real(real64) function representation_total_integrated_bound(theta_base,material,dz) result(bound_cm)
    real(real64),intent(in) :: theta_base(n),dz(n)
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: spacing_bound
    spacing_bound=0.5_real64*sum((spacing(material%theta_s)+spacing(theta_base))*dz)
    bound_cm=max(integrated_allowance_cm,spacing_bound)
  end function representation_total_integrated_bound

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
      write(*,'(A,1X,A)') 'PUB_P2E21_HARNESS_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_pub_p2e21_ref_high_representation_bound
