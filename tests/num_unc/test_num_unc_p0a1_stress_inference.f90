program test_num_unc_p0a1_stress_inference
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, build_process_hydraulic_view
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  implicit none

  integer, parameter :: n=16, rooted_nodes=6, blocks=192, ncases=3
  integer, parameter :: STRESS_BEFORE_RESCUE=1, NOT_BEFORE_RESCUE=2, INADMISSIBLE=9
  integer, parameter :: rescue_start_block=65, rescue_end_block=80
  real(real64), parameter :: dz_cm=10.0_real64, dt0=0.0064_real64, dt1=0.0032_real64
  real(real64), parameter :: ptra=0.1806735915459957_real64
  real(real64), parameter :: rescue_time=0.4096_real64
  real(real64), parameter :: stress_ratio_threshold=0.999999999999_real64
  real(real64), parameter :: mass_tol=1.0e-12_real64
  real(real64), parameter :: hlim3h=-325.0_real64, hlim3l=-600.0_real64, hlim4=-8000.0_real64
  real(real64), parameter :: adcrh=0.5_real64, adcrl=0.1_real64
  real(real64), parameter :: se_cases(ncases)=[0.16270876169331827_real64, &
       0.16520876169331827_real64,0.16770876169331828_real64]
  character(len=7), parameter :: case_ids(ncases)=[character(len=7)::'A_MINUS','A_ZERO ','A_PLUS ']

  real(real64) :: h0s(n,blocks),h1s(n,blocks),th0s(n,blocks),th1s(n,blocks)
  real(real64) :: p0s(blocks),p1s(blocks),s0s(blocks),s1s(blocks),ta0s(blocks),ta1s(blocks)
  real(real64) :: dtheta_rms(ncases,blocks),dtheta_inf(ncases,blocks),dh_rms(ncases,blocks)
  real(real64) :: dh_inf(ncases,blocks),dstorage(ncases,blocks),dpond(ncases,blocks),dta(ncases,blocks)
  real(real64) :: maxpond0(ncases),maxpond1(ncases),maxmass0(ncases),maxmass1(ncases)
  real(real64) :: minratio0(ncases),minratio1(ncases),firsttime0(ncases),firsttime1(ncases)
  integer :: class0(ncases),class1(ncases),firstblock0(ncases),firstblock1(ncases),c,k
  logical :: valid0(ncases),valid1(ncases)
  character(len=64) :: fail0(ncases),fail1(ncases)
  real(real64) :: floor_theta,dpre,dpost,amp,fp_floor
  character(len=48) :: outcome

  write(*,'(A)') 'NUM_UNC_P0A1_STAGE=FROZEN_N0_N1_STRESS_COMPARISON'
  write(*,'(A)') 'NUM_UNC_P0A1_CASE_RELOCATION=FALSE'
  write(*,'(*(g0))') 'NUM_UNC_P0A1_N0_DT_DAY=',dt0
  write(*,'(*(g0))') 'NUM_UNC_P0A1_N1_DT_DAY=',dt1
  write(*,'(*(g0))') 'NUM_UNC_P0A1_RESCUE_TIME_DAY=',rescue_time

  do c=1,ncases
    call run_route(se_cases(c),dt0,1,class0(c),valid0(c),minratio0(c),firstblock0(c),firsttime0(c), &
         maxpond0(c),maxmass0(c),fail0(c),h0s,th0s,p0s,s0s,ta0s)
    call run_route(se_cases(c),dt1,2,class1(c),valid1(c),minratio1(c),firstblock1(c),firsttime1(c), &
         maxpond1(c),maxmass1(c),fail1(c),h1s,th1s,p1s,s1s,ta1s)

    call report_route(trim(case_ids(c)),'N0',se_cases(c),class0(c),valid0(c),minratio0(c), &
         firstblock0(c),firsttime0(c),maxmass0(c),fail0(c))
    call report_route(trim(case_ids(c)),'N1',se_cases(c),class1(c),valid1(c),minratio1(c), &
         firstblock1(c),firsttime1(c),maxmass1(c),fail1(c))

    do k=1,blocks
      dtheta_rms(c,k)=sqrt(sum((th0s(:,k)-th1s(:,k))**2)/real(n,real64))
      dtheta_inf(c,k)=maxval(abs(th0s(:,k)-th1s(:,k)))
      dh_rms(c,k)=sqrt(sum((h0s(:,k)-h1s(:,k))**2)/real(n,real64))
      dh_inf(c,k)=maxval(abs(h0s(:,k)-h1s(:,k)))
      dstorage(c,k)=abs(s0s(k)-s1s(k))
      dpond(c,k)=abs(p0s(k)-p1s(k))
      dta(c,k)=abs(ta0s(k)-ta1s(k))
      write(*,'(*(g0))') 'NUM_UNC_P0A1_COMMON|CASE=',trim(case_ids(c)),'|BLOCK=',k, &
           '|D_THETA_RMS=',dtheta_rms(c,k),'|D_THETA_INF=',dtheta_inf(c,k), &
           '|D_H_RMS_CM=',dh_rms(c,k),'|D_H_INF_CM=',dh_inf(c,k), &
           '|D_STORAGE_CM=',dstorage(c,k),'|D_POND_CM=',dpond(c,k), &
           '|D_TA_CM_PER_DAY=',dta(c,k),'|TA_N0=',ta0s(k),'|TA_N1=',ta1s(k)
    end do
  end do

  if (.not.all(valid0) .or. .not.all(valid1)) then
    outcome='NUMERICAL_FAILURE_ONLY'
  else if (class0(1)/=STRESS_BEFORE_RESCUE .or. class0(2)/=STRESS_BEFORE_RESCUE .or. &
           class0(3)/=NOT_BEFORE_RESCUE) then
    outcome='UNRESOLVED_N0_REPLAY_MISMATCH'
  else if (class1(1)/=STRESS_BEFORE_RESCUE .or. class1(3)/=NOT_BEFORE_RESCUE) then
    outcome='UNRESOLVED_REFERENCE_ENVELOPE'
  else
    floor_theta=maxval(dtheta_rms(3,1:64))
    dpre=maxval(dtheta_rms(2,1:62))
    dpost=maxval(dtheta_rms(2,63:80))
    fp_floor=1024.0_real64*epsilon(1.0_real64)
    amp=dpost/max(dpre,floor_theta,fp_floor)

    if (class1(2)==class0(2)) then
      outcome='INVARIANT'
    else if (amp>=4.0_real64 .and. dpost>2.0_real64*floor_theta) then
      outcome='AMPLIFIED_INFERENCE_FRAGILITY'
    else
      outcome='THRESHOLD_PROXIMITY_ONLY'
    end if

    write(*,'(*(g0))') 'NUM_UNC_P0A1_AMPLIFICATION|FLOOR_A_PLUS=',floor_theta, &
         '|D_PRE_A_ZERO=',dpre,'|D_POST_A_ZERO=',dpost,'|FP_FLOOR=',fp_floor, &
         '|A=',amp,'|POST_GT_2_FLOOR=',dpost>2.0_real64*floor_theta, &
         '|MAX_DTA_PRE=',maxval(dta(2,1:63)),'|MAX_DTA_POST=',maxval(dta(2,64:81))
  end if

  write(*,'(A,A)') 'NUM_UNC_P0A1_OUTCOME=',trim(outcome)
  write(*,'(A)') 'NUM_UNC_P0A1_GATE=PASS'

contains

  subroutine run_route(initial_se,step_dt,substeps,class_id,is_valid,min_actual_ratio,first_stress_block, &
       first_stress_time,max_pond,max_mass_residual,failure_stage,h_series,theta_series,pond_series,storage_series,ta_series)
    real(real64),intent(in) :: initial_se,step_dt
    integer,intent(in) :: substeps
    integer,intent(out) :: class_id,first_stress_block
    logical,intent(out) :: is_valid
    real(real64),intent(out) :: min_actual_ratio,first_stress_time,max_pond,max_mass_residual
    character(len=*),intent(out) :: failure_stage
    real(real64),intent(out) :: h_series(n,blocks),theta_series(n,blocks),pond_series(blocks),storage_series(blocks),ta_series(blocks)

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(b110_root_sink_provider_t),target :: root_provider
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_physical_state_t) :: state
    type(process_hydraulic_view_t) :: hydraulic_view
    type(root_water_uptake_parameters_t) :: root_parameters
    type(root_water_uptake_request_t) :: root_request
    type(root_water_uptake_flux_result_t) :: root_fluxes
    type(root_water_uptake_diagnostics_t) :: root_diagnostics
    real(real64),target :: drainage(1,n),irrigation(n),source_root_zero(n),root_sink_vec(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: hinit,qtop,ratio,current_time
    integer :: block,sub,j
    logical :: found,view_ok

    class_id=INADMISSIBLE; is_valid=.false.; min_actual_ratio=huge(1.0_real64)
    first_stress_block=0; first_stress_time=-1.0_real64; max_pond=0.0_real64
    max_mass_residual=0.0_real64; failure_stage='INITIALIZATION'
    h_series=0.0_real64; theta_series=0.0_real64; pond_series=0.0_real64
    storage_series=0.0_real64; ta_series=0.0_real64

    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then; failure_stage='MATERIAL_LOOKUP'; return; end if
    call initialize_parameters(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
    hinit=head_from_effective_saturation(initial_se,material)
    heads=hinit
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity))) then
      failure_stage='INITIAL_CONSTITUTIVE'; return
    end if
    if (any(theta<=material%theta_r) .or. any(theta>=material%theta_s)) then
      failure_stage='INITIAL_THETA_DOMAIN'; return
    end if

    state%active_nodes=n
    allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64

    drainage=0.0_real64; irrigation=0.0_real64; source_root_zero=0.0_real64; root_sink_vec=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,source_root_zero)

    root_parameters%active_nodes=n
    root_parameters%hlim3l=hlim3l; root_parameters%hlim3h=hlim3h; root_parameters%hlim4=hlim4
    root_parameters%adcrl=adcrl; root_parameters%adcrh=adcrh
    root_request%potential_transpiration=ptra; root_request%rooted_nodes=rooted_nodes
    allocate(root_request%cumulative_root_fraction(rooted_nodes+1))
    do j=1,rooted_nodes+1
      root_request%cumulative_root_fraction(j)=real(j-1,real64)/real(rooted_nodes,real64)
    end do

    do block=1,blocks
      if (block>=rescue_start_block .and. block<=rescue_end_block) then
        qtop=ptra
      else
        qtop=0.0_real64
      end if

      do sub=1,substeps
        current_time=real(block-1,real64)*dt0+real(sub-1,real64)*step_dt
        call build_process_hydraulic_view(state,hydraulic_view,view_ok)
        if (.not.view_ok) then; failure_stage='HYDRAULIC_VIEW'; return; end if

        call evaluate_macro_feddes_drought_uptake(root_parameters,hydraulic_view,root_request,root_fluxes,root_diagnostics)
        if (root_diagnostics%status/=ROOT_UPTAKE_OK .or. .not.root_diagnostics%evaluated) then
          failure_stage='ROOT_PROCESS'; return
        end if
        if (.not.allocated(root_fluxes%root_extraction_sink)) then
          failure_stage='ROOT_SINK_MISSING'; return
        end if
        if (size(root_fluxes%root_extraction_sink)/=n .or. any(.not.ieee_is_finite(root_fluxes%root_extraction_sink))) then
          failure_stage='ROOT_SINK_INVALID'; return
        end if
        if (any(root_fluxes%root_extraction_sink<0.0_real64) .or. .not.ieee_is_finite(root_fluxes%actual_uptake_total)) then
          failure_stage='ROOT_SINK_DOMAIN'; return
        end if
        if (root_fluxes%actual_uptake_total>ptra+1.0e-12_real64) then
          failure_stage='ROOT_UPTAKE_EXCEEDS_POTENTIAL'; return
        end if

        ratio=root_fluxes%actual_uptake_total/ptra
        min_actual_ratio=min(min_actual_ratio,ratio)
        if (sub==1) ta_series(block)=root_fluxes%actual_uptake_total
        if (first_stress_block==0 .and. ratio<stress_ratio_threshold) then
          first_stress_block=block
          first_stress_time=current_time
        end if

        root_sink_vec=root_fluxes%root_extraction_sink
        call bind_b110_root_sink_provider(root_provider,root_sink_vec)
        call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
        call initialize_request(request,parameters,constitutive,source_sink,root_provider,top_provider,state,qtop,step_dt)
        call solver%solve(request,workspace,result)
        if (.not.result_valid(result,material)) then; failure_stage='REFERENCE_GATE'; return; end if
        max_mass_residual=max(max_mass_residual,abs(result%integrated_mass_balance_residual_cm))
        max_pond=max(max_pond,result%candidate_state%ponding_depth)
        state=result%candidate_state
      end do

      h_series(:,block)=state%pressure_head
      theta_series(:,block)=state%water_content
      pond_series(block)=state%ponding_depth
      storage_series(block)=sum(parameters%dz*state%water_content)+state%ponding_depth
    end do

    if (first_stress_block>0 .and. first_stress_time<rescue_time) then
      class_id=STRESS_BEFORE_RESCUE
    else
      class_id=NOT_BEFORE_RESCUE
    end if
    is_valid=.true.; failure_stage='NONE'
  end subroutine run_route

  logical function result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),parameter :: eps_theta=1.0e-12_real64
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
    if (result%diagnostics%internal_retries/=0 .or. result%diagnostics%alternative_solver_calls/=0) return
    if (.not.result%integrated_mass_balance_residual_available) return
    if (.not.ieee_is_finite(result%integrated_mass_balance_residual_cm)) return
    if (abs(result%integrated_mass_balance_residual_cm)>mass_tol) return
    if (.not.result%native_balance_rate_residual_available) return
    if (.not.ieee_is_finite(result%native_balance_rate_residual_cm_per_day)) return
    if (result%candidate_state%active_nodes/=n) return
    if (.not.allocated(result%candidate_state%pressure_head) .or. .not.allocated(result%candidate_state%water_content)) return
    if (any(.not.ieee_is_finite(result%candidate_state%pressure_head))) return
    if (any(.not.ieee_is_finite(result%candidate_state%water_content))) return
    if (.not.ieee_is_finite(result%candidate_state%ponding_depth)) return
    if (any(result%candidate_state%water_content<material%theta_r-eps_theta)) return
    if (any(result%candidate_state%water_content>material%theta_s+eps_theta)) return
    ok=.true.
  end function result_valid

  subroutine initialize_request(req,p,hyd,source,root,top,base,qtop,step_dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: p
    type(b110_default_mvg_provider_t),target,intent(in) :: hyd
    type(b110_source_sink_provider_t),target,intent(in) :: source
    type(b110_root_sink_provider_t),target,intent(in) :: root
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top
    type(soil_water_physical_state_t),intent(in) :: base
    real(real64),intent(in) :: qtop,step_dt

    req%parameters=>p; req%base_state=base
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2
    req%boundary%top_flux=qtop; req%boundary%top_head=base%pressure_head(1)
    req%boundary%bottom_flux=0.0_real64; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=mass_tol; req%numerical%total_balance_tolerance=mass_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64; req%step_duration=step_dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd; req%evaluation%source_sink=>source
    req%evaluation%root_sink=>root; req%evaluation%top_boundary=>top
  end subroutine initialize_request

  subroutine initialize_parameters(p,c,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: p
    real(real64),intent(out) :: c(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=926203; p%active_nodes=n
    allocate(p%z(n),p%dz(n),p%node_distance(n))
    do j=1,n; p%z(j)=-dz_cm*(real(j,real64)-0.5_real64); end do
    p%dz=dz_cm; p%node_distance=dz_cm; p%node_distance(1)=0.5_real64*dz_cm
    c=0.0_real64
    do j=1,n
      c(1,j)=mat%theta_r; c(2,j)=mat%theta_s; c(3,j)=mat%ksatfit_cm_per_day
      c(4,j)=mat%alpha_per_cm; c(5,j)=mat%lambda; c(6,j)=mat%n; c(7,j)=m
      c(8,j)=mat%alpha_per_cm; c(9,j)=mat%h_enpr_cm; c(10,j)=mat%ksatfit_cm_per_day
      c(11,j)=0.999_real64; c(12,j)=0.99_real64*mat%ksatfit_cm_per_day
      c(22,j)=-1.0e6_real64; c(23,j)=1.0e-12_real64
    end do
  end subroutine initialize_parameters

  pure real(real64) function head_from_effective_saturation(se,material) result(head_cm)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64) :: m
    m=1.0_real64-1.0_real64/material%n
    head_cm=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/material%n)/material%alpha_per_cm
  end function head_from_effective_saturation

  subroutine report_route(id,route,se0,class_id,valid,min_ratio,first_block,first_time,max_mass,failure)
    character(len=*),intent(in) :: id,route,failure
    real(real64),intent(in) :: se0,min_ratio,first_time,max_mass
    integer,intent(in) :: class_id,first_block
    logical,intent(in) :: valid
    write(*,'(*(g0))') 'NUM_UNC_P0A1_ROUTE|CASE=',trim(id),'|ROUTE=',trim(route),'|SE0=',se0, &
         '|CLASS=',trim(class_name(class_id)),'|VALID=',valid,'|MIN_TA_TP=',min_ratio, &
         '|FIRST_STRESS_BLOCK=',first_block,'|FIRST_STRESS_TIME_DAY=',first_time, &
         '|MAX_MASS_CM=',max_mass,'|FAILURE=',trim(failure)
  end subroutine report_route

  pure function class_name(class_id) result(name)
    integer,intent(in) :: class_id
    character(len=24) :: name
    select case(class_id)
    case(STRESS_BEFORE_RESCUE); name='STRESS_BEFORE_RESCUE'
    case(NOT_BEFORE_RESCUE); name='NOT_BEFORE_RESCUE'
    case default; name='INADMISSIBLE'
    end select
  end function class_name
end program test_num_unc_p0a1_stress_inference
