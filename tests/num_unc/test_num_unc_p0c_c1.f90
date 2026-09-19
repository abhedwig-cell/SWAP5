program test_num_unc_p0c_c1
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, soil_water_top_boundary_result_t, &
       SW_SOLVE_CONVERGED, SW_TOP_BOUNDARY_AVAILABLE
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_DYNAMIC_PROVIDER
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_material_t, rossfast_d3r_material_from_id
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, &
       evaluate_b110_default_mvg_conductivity
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t, &
       bind_b110_dynamic_top_boundary_solver_provider
  implicit none

  integer, parameter :: n=16, ncases=3, blocks=16, pulse_blocks=8
  integer, parameter :: NO_PONDING=0, PONDING=1, INADMISSIBLE=2
  real(real64), parameter :: dz_cm=10.0_real64, initial_se=0.85_real64
  real(real64), parameter :: dt0=0.0064_real64, dt1=0.0032_real64
  real(real64), parameter :: mass_tol=1.0e-12_real64, pond_event=1.0e-10_real64
  real(real64), parameter :: mult(ncases)=[1.0006347656250001_real64,1.11181640625_real64,1.2229980468750001_real64]
  character(len=7), parameter :: case_id(ncases)=[character(len=7)::'C_MINUS','C_ZERO ','C_PLUS ']
  real(real64), parameter :: pulse_fraction(pulse_blocks)=[0.25_real64,0.5_real64,0.75_real64, &
       1.0_real64,1.0_real64,1.0_real64,1.0_real64,1.0_real64]

  real(real64) :: h0_series(n,blocks),h1_series(n,blocks),th0_series(n,blocks),th1_series(n,blocks)
  real(real64) :: p0_series(blocks),p1_series(blocks),s0_series(blocks),s1_series(blocks)
  real(real64) :: dtheta_rms(ncases,blocks),dh_rms(ncases,blocks),dh_inf(ncases,blocks)
  real(real64) :: dtheta_inf(ncases,blocks),dstorage(ncases,blocks),dpond(ncases,blocks)
  real(real64) :: maxpond0(ncases),maxpond1(ncases),maxmass0(ncases),maxmass1(ncases)
  integer :: class0(ncases),class1(ncases),c,k
  logical :: valid0(ncases),valid1(ncases)
  character(len=48) :: fail0(ncases),fail1(ncases)
  real(real64) :: floor_theta,dpre,dpost,amp,fp_floor
  character(len=40) :: outcome

  write(*,'(A)') 'NUM_UNC_P0C_C1_STAGE=FROZEN_N0_N1_COMPARISON'
  write(*,'(A)') 'NUM_UNC_P0C_C1_CASE_RELOCATION=FALSE'
  write(*,'(*(g0))') 'NUM_UNC_P0C_C1_N0_DT_DAY=',dt0
  write(*,'(*(g0))') 'NUM_UNC_P0C_C1_N1_DT_DAY=',dt1

  do c=1,ncases
    call run_route(mult(c),dt0,1,class0(c),valid0(c),maxpond0(c),maxmass0(c),fail0(c), &
         h0_series,th0_series,p0_series,s0_series)
    call run_route(mult(c),dt1,2,class1(c),valid1(c),maxpond1(c),maxmass1(c),fail1(c), &
         h1_series,th1_series,p1_series,s1_series)

    call report_route(trim(case_id(c)),'N0',mult(c),class0(c),valid0(c),maxpond0(c),maxmass0(c),fail0(c))
    call report_route(trim(case_id(c)),'N1',mult(c),class1(c),valid1(c),maxpond1(c),maxmass1(c),fail1(c))

    do k=1,blocks
      dtheta_rms(c,k)=sqrt(sum((th0_series(:,k)-th1_series(:,k))**2)/real(n,real64))
      dh_rms(c,k)=sqrt(sum((h0_series(:,k)-h1_series(:,k))**2)/real(n,real64))
      dh_inf(c,k)=maxval(abs(h0_series(:,k)-h1_series(:,k)))
      dtheta_inf(c,k)=maxval(abs(th0_series(:,k)-th1_series(:,k)))
      dstorage(c,k)=abs(s0_series(k)-s1_series(k))
      dpond(c,k)=abs(p0_series(k)-p1_series(k))
      write(*,'(*(g0))') 'NUM_UNC_P0C_C1_COMMON|CASE=',trim(case_id(c)),'|BLOCK=',k, &
           '|D_THETA_RMS=',dtheta_rms(c,k),'|D_THETA_INF=',dtheta_inf(c,k), &
           '|D_H_RMS_CM=',dh_rms(c,k),'|D_H_INF_CM=',dh_inf(c,k), &
           '|D_STORAGE_CM=',dstorage(c,k),'|D_POND_CM=',dpond(c,k), &
           '|POND_N0_CM=',p0_series(k),'|POND_N1_CM=',p1_series(k)
    end do
  end do

  if (.not.all(valid0) .or. .not.all(valid1)) then
    outcome='NUMERICAL_FAILURE_ONLY'
  else if (class0(1)/=NO_PONDING .or. class0(2)/=PONDING .or. class0(3)/=PONDING) then
    outcome='UNRESOLVED_N0_REPLAY_MISMATCH'
  else if (class1(1)/=class0(1) .or. class1(3)/=class0(3)) then
    outcome='UNRESOLVED_REFERENCE_ENVELOPE'
  else
    floor_theta=maxval(dtheta_rms(1,:))
    dpre=maxval(dtheta_rms(2,1:7))
    dpost=maxval(dtheta_rms(2,8:16))
    fp_floor=1024.0_real64*epsilon(1.0_real64)
    amp=dpost/max(dpre,floor_theta,fp_floor)
    if (class1(2)==class0(2)) then
      outcome='INVARIANT'
    else if (amp>=4.0_real64 .and. dpost>2.0_real64*floor_theta) then
      outcome='AMPLIFIED_INFERENCE_FRAGILITY'
    else
      outcome='THRESHOLD_PROXIMITY_ONLY'
    end if
    write(*,'(*(g0))') 'NUM_UNC_P0C_C1_AMPLIFICATION|FLOOR_C_MINUS=',floor_theta, &
         '|D_PRE_C_ZERO=',dpre,'|D_POST_C_ZERO=',dpost,'|FP_FLOOR=',fp_floor,'|A=',amp, &
         '|POST_GT_2_FLOOR=',dpost>2.0_real64*floor_theta
  end if

  write(*,'(A,A)') 'NUM_UNC_P0C_C1_OUTCOME=',trim(outcome)
  write(*,'(A)') 'NUM_UNC_P0C_C1_GATE=PASS'

contains

  subroutine run_route(multiplier,step_dt,substeps,class_id,is_valid,max_pond,max_mass,failure_stage, &
       h_series,theta_series,pond_series,storage_series)
    real(real64),intent(in) :: multiplier,step_dt
    integer,intent(in) :: substeps
    integer,intent(out) :: class_id
    logical,intent(out) :: is_valid
    real(real64),intent(out) :: max_pond,max_mass
    character(len=*),intent(out) :: failure_stage
    real(real64),intent(out) :: h_series(n,blocks),theta_series(n,blocks),pond_series(blocks),storage_series(blocks)

    type(soil_water_parameter_set_t),target :: parameters
    type(rossfast_d3r_material_t) :: material
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(b110_dynamic_top_boundary_solver_provider_t),target :: dynamic_top
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: result
    type(soil_water_top_boundary_result_t) :: top_result
    type(soil_water_physical_state_t) :: state
    real(real64),target :: drainage(1,n),irrigation(n),root_sink(n)
    real(real64) :: cofgen(24,n),heads(n),theta(n),conductivity(n),capacity(n),dkdh(n)
    real(real64) :: hinit,precip,ktop
    integer :: block,sub
    logical :: found,k_ok

    class_id=INADMISSIBLE; is_valid=.false.; max_pond=0.0_real64; max_mass=0.0_real64
    failure_stage='INITIALIZATION'; h_series=0.0_real64; theta_series=0.0_real64
    pond_series=0.0_real64; storage_series=0.0_real64

    call rossfast_d3r_material_from_id('B01',material,found)
    if (.not.found) then; failure_stage='MATERIAL_LOOKUP'; return; end if
    call initialize_parameters(parameters,cofgen,material)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
    hinit=head_from_effective_saturation(initial_se,material); heads=hinit
    call constitutive%evaluate(heads,theta,conductivity,capacity,dkdh)
    if (any(.not.ieee_is_finite(theta)) .or. any(.not.ieee_is_finite(conductivity))) then
      failure_stage='INITIAL_CONSTITUTIVE'; return
    end if

    state%active_nodes=n; allocate(state%pressure_head(n),state%water_content(n))
    state%pressure_head=heads; state%water_content=theta
    state%ponding_depth=0.0_real64; state%groundwater_level=-999.0_real64
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
    class_id=NO_PONDING

    do block=1,blocks
      if (block<=pulse_blocks) then
        precip=multiplier*material%ksatfit_cm_per_day*pulse_fraction(block)
      else
        precip=0.0_real64
      end if
      do sub=1,substeps
        call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,step_dt)
        call evaluate_b110_default_mvg_conductivity(hydraulic_parameters,1,state%pressure_head(1),ktop,k_ok)
        if (.not.k_ok) then; failure_stage='START_TOP_CONDUCTIVITY'; class_id=INADMISSIBLE; return; end if
        call bind_b110_dynamic_top_boundary_solver_provider(dynamic_top,parameters,hydraulic_parameters, &
             1,state%ponding_depth,step_dt,precip,0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64, &
             10.0_real64,1.0_real64,1.0_real64,fixed_top_node_conductivity=ktop)
        call initialize_request(request,parameters,constitutive,source_sink,dynamic_top,state,step_dt)
        call solver%solve(request,workspace,result)
        if (.not.result_valid(result,material)) then; failure_stage='REFERENCE_GATE'; class_id=INADMISSIBLE; return; end if
        if (result%diagnostics%internal_retries/=0) then; failure_stage='INTERNAL_RETRY'; class_id=INADMISSIBLE; return; end if
        if (result%diagnostics%alternative_solver_calls/=0) then
          failure_stage='ALTERNATIVE_LINEAR_SOLVER'; class_id=INADMISSIBLE; return
        end if
        call dynamic_top%evaluate(result%candidate_state%pressure_head(1),result%candidate_state%water_content(1), &
             result%candidate_state%ponding_depth,request%boundary,top_result)
        if (top_result%status/=SW_TOP_BOUNDARY_AVAILABLE) then
          failure_stage='FINAL_TOP_DIAGNOSTIC'; class_id=INADMISSIBLE; return
        end if
        if (abs(top_result%runoff_depth)>0.0_real64) then; failure_stage='RUNOFF_NONZERO'; class_id=INADMISSIBLE; return; end if
        max_pond=max(max_pond,result%candidate_state%ponding_depth)
        max_mass=max(max_mass,abs(result%integrated_mass_balance_residual_cm))
        if (result%candidate_state%ponding_depth>pond_event) class_id=PONDING
        state=result%candidate_state
      end do
      h_series(:,block)=state%pressure_head
      theta_series(:,block)=state%water_content
      pond_series(block)=state%ponding_depth
      storage_series(block)=sum(parameters%dz*state%water_content)+state%ponding_depth
    end do
    is_valid=.true.; failure_stage='NONE'
  end subroutine run_route

  logical function result_valid(result,material) result(ok)
    type(soil_water_solve_result_t),intent(in) :: result
    type(rossfast_d3r_material_t),intent(in) :: material
    real(real64),parameter :: eps_theta=1.0e-12_real64
    ok=.false.
    if (result%status/=SW_SOLVE_CONVERGED) return
    if (trim(result%diagnostics%route)/='legacy-reference-bound') return
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
    if (result%candidate_state%ponding_depth<0.0_real64) return
    if (any(result%candidate_state%water_content<material%theta_r-eps_theta)) return
    if (any(result%candidate_state%water_content>material%theta_s+eps_theta)) return
    ok=.true.
  end function result_valid

  subroutine initialize_request(req,p,hyd,source,top,base,step_dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: p
    type(b110_default_mvg_provider_t),target,intent(in) :: hyd
    type(b110_source_sink_provider_t),target,intent(in) :: source
    type(b110_dynamic_top_boundary_solver_provider_t),target,intent(in) :: top
    type(soil_water_physical_state_t),intent(in) :: base
    real(real64),intent(in) :: step_dt
    req%parameters=>p; req%base_state=base
    req%boundary%top_mode=FSI_TOP_MODE_DYNAMIC_PROVIDER; req%boundary%bottom_mode=2
    req%boundary%top_flux=0.0_real64; req%boundary%top_head=base%pressure_head(1)
    req%boundary%bottom_flux=0.0_real64; req%boundary%bottom_head=-999999.0_real64
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=16; req%numerical%max_backtracking=8
    req%numerical%conductivity_implicit_mode=0; req%numerical%conductivity_mean_method=1
    req%numerical%min_step_duration=1.0e-8_real64
    req%numerical%compartment_balance_tolerance=mass_tol; req%numerical%total_balance_tolerance=mass_tol
    req%numerical%head_abs_tolerance=1.0e-12_real64; req%numerical%head_rel_tolerance=1.0e-12_real64
    req%numerical%ponding_tolerance=1.0e-12_real64; req%step_duration=step_dt
    req%request_interface_sensitivity=.false.
    req%evaluation%constitutive=>hyd; req%evaluation%source_sink=>source; req%evaluation%dynamic_top_boundary=>top
  end subroutine initialize_request

  subroutine initialize_parameters(p,c,mat)
    type(soil_water_parameter_set_t),target,intent(out) :: p
    real(real64),intent(out) :: c(24,n)
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    integer :: j
    m=1.0_real64-1.0_real64/mat%n
    p%parameter_set_id=926003; p%active_nodes=n
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

  pure real(real64) function head_from_effective_saturation(se,mat) result(h)
    real(real64),intent(in) :: se
    type(rossfast_d3r_material_t),intent(in) :: mat
    real(real64) :: m
    m=1.0_real64-1.0_real64/mat%n
    h=-(se**(-1.0_real64/m)-1.0_real64)**(1.0_real64/mat%n)/mat%alpha_per_cm
  end function head_from_effective_saturation

  subroutine report_route(id,route,multiplier,class_id,valid,maxpond,maxmass,failure)
    character(len=*),intent(in) :: id,route,failure
    real(real64),intent(in) :: multiplier,maxpond,maxmass
    integer,intent(in) :: class_id
    logical,intent(in) :: valid
    write(*,'(*(g0))') 'NUM_UNC_P0C_C1_ROUTE|CASE=',trim(id),'|ROUTE=',trim(route),'|MULT=',multiplier, &
         '|CLASS=',trim(class_name(class_id)),'|VALID=',valid,'|MAX_POND_CM=',maxpond, &
         '|MAX_MASS_CM=',maxmass,'|FAILURE=',trim(failure)
  end subroutine report_route

  pure function class_name(class_id) result(name)
    integer,intent(in) :: class_id
    character(len=16) :: name
    select case(class_id)
    case(NO_PONDING); name='NO_PONDING'
    case(PONDING); name='PONDING'
    case default; name='INADMISSIBLE'
    end select
  end function class_name
end program test_num_unc_p0c_c1
