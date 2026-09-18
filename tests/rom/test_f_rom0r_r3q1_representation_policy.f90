program test_f_rom0r_r3q1_representation_policy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_physical_state_t, &
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_b110_serialized_context_binding, only: bind_b110_serialized_legacy_context
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: control_total_rate_tol=1.0e-12_real64
  real(real64), parameter :: representation_floor_min_cm=1.6e-15_real64
  real(real64), parameter :: budget_h_inf=0.005684414280500505_real64
  real(real64), parameter :: budget_h_rms=0.002309047189054667_real64
  real(real64), parameter :: budget_theta_inf=0.00002439358876414888_real64
  real(real64), parameter :: budget_theta_rms=0.000008095278187597767_real64
  real(real64), parameter :: budget_storage=2.842170943040401e-14_real64
  integer(int64), parameter :: column_id=964101_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  integer :: imat,icase

  call require(numnod==16,'R3Q1 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3Q1 depth frozen at 160 cm')
  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_case(trim(materials(imat)),trim(cases(icase)))
    end do
  end do
  write(*,'(A)') 'F_ROM0R_R3Q1_MATRIX_COMPLETE=PASS'

contains

  subroutine run_case(material_id,case_id)
    character(len=*),intent(in) :: material_id,case_id
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: seed_top
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    class(transaction_state_t),allocatable :: seed_snapshot
    type(soil_water_physical_state_t) :: current_state
    type(soil_water_parameter_set_t),target :: pset
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    real(real64) :: h0,k0,qeq,hbot,t0,t1,mass,bex,bflux
    real(real64) :: cumulative_bottom_exchange,max_abs_mass
    real(real64) :: total_storage,upper_storage,lower_storage
    integer :: i,solver_status,nl,internal_retries,backtracking
    integer :: control_converged_count,control_total_retry_count
    character(len=96) :: solver_route
    logical :: ok,got

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE'); hbot=0.75_real64*h0
    case('BOTTOM_HEAD_FALL'); hbot=1.25_real64*h0
    case default
      call require(.false.,'R3Q1 known case'); hbot=h0
    end select

    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),'R3Q1 committed seed initialized')
    call backend%initialize(seed_top)

    parameters%bottom_mode=2
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=h0
      call execute_seed_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,solver_route,nl,internal_retries,backtracking)
      call require(ok,'R3Q1 qualified seed sample')
      t0=t1
    end do

    call committed%snapshot(seed_snapshot,got)
    call require(got,'R3Q1 seed snapshot')
    select type(s=>seed_snapshot)
    type is(fmr_b110_physical_state_t)
      call copy_to_solver_state(s,current_state)
    class default
      call require(.false.,'R3Q1 expected B110 seed state')
    end select

    call initialize_solver_contract(parameters,pset,hydraulic_parameters,constitutive,source_sink, &
         drainage,irrigation,root_sink)
    parameters%bottom_mode=5
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    cumulative_bottom_exchange=0.0_real64
    max_abs_mass=0.0_real64
    control_converged_count=0
    control_total_retry_count=0

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call qualify_step(material_id,case_id,i,parameters,pset,hydraulic_parameters,constitutive,source_sink,top_provider, &
           current_state,forcing,t0,t1,bflux,mass,ok,control_converged_count,control_total_retry_count)
      call require(ok,'R3Q1 candidate step qualified')
      cumulative_bottom_exchange=cumulative_bottom_exchange+bflux*(t1-t0)
      max_abs_mass=max(max_abs_mass,abs(mass))
      t0=t1
    end do

    call state_metrics(current_state,total_storage,upper_storage,lower_storage)
    write(*,'(*(g0))') 'F_ROM0R_R3Q1_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_bottom_exchange,'|MAX_ABS_MASS=',max_abs_mass, &
         '|CONTROL_CONVERGED=',control_converged_count,'|CONTROL_TOTAL_RETRY=',control_total_retry_count, &
         '|FINAL_T=',t0
  end subroutine run_case

  subroutine qualify_step(material_id,case_id,step,parameters,pset,hydraulic_parameters,constitutive,source_sink,top_provider, &
                          current_state,forcing,t0,t1,bottom_flux,mass_residual,ok,control_converged_count,control_total_retry_count)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(in) :: step
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(soil_water_parameter_set_t),target,intent(in) :: pset
    type(b110_default_mvg_parameters_t),target,intent(inout) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(inout) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(inout) :: top_provider
    type(soil_water_physical_state_t),intent(inout) :: current_state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    real(real64),intent(out) :: bottom_flux,mass_residual
    logical,intent(out) :: ok
    integer,intent(inout) :: control_converged_count,control_total_retry_count

    type(soil_water_solve_request_t) :: control_request,candidate_request
    type(soil_water_solve_result_t) :: control_result,candidate_result
    type(reference_richards_legacy_solver_t) :: control_solver,candidate_solver
    type(reference_richards_legacy_workspace_t) :: control_workspace,candidate_workspace
    real(real64) :: dt,rep_formula,rep_bound,candidate_total_rate
    real(real64) :: control_rsum,control_rmax,control_integrated
    real(real64) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    integer :: bal_flags,head_flags
    logical :: context_ok,neutral,control_total_only,runtime_bound_ok
    character(len=24) :: control_class

    ok=.false.;bottom_flux=0.0_real64;mass_residual=huge(0.0_real64)
    dt=t1-t0
    runtime_bound_ok=all(spacing(current_state%water_content)<=spacing(parameters%cofgen(2,1)))
    call require(runtime_bound_ok,'R3Q1 representation bound runtime check')
    rep_formula=0.5_real64*sum((spacing(parameters%cofgen(2,1))+spacing(current_state%water_content))*parameters%dz)
    rep_bound=max(representation_floor_min_cm,rep_formula)
    candidate_total_rate=rep_bound/dt

    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    call build_request(control_request,pset,constitutive,source_sink,top_provider,current_state,forcing,parameters,dt, &
         control_total_rate_tol)
    call bind_b110_serialized_legacy_context(control_request,context_ok)
    call require(context_ok,'R3Q1 control context')
    call control_solver%solve(control_request,control_workspace,control_result)

    call build_request(candidate_request,pset,constitutive,source_sink,top_provider,current_state,forcing,parameters,dt, &
         candidate_total_rate)
    call bind_b110_serialized_legacy_context(candidate_request,context_ok)
    call require(context_ok,'R3Q1 candidate context')
    call candidate_solver%solve(candidate_request,candidate_workspace,candidate_result)

    if(candidate_result%status/=SW_SOLVE_CONVERGED) return
    if(trim(candidate_result%diagnostics%route)/='legacy-reference-bound') return
    if(.not.candidate_result%integrated_mass_balance_residual_available) return
    if(.not.ieee_is_finite(candidate_result%integrated_mass_balance_residual_cm)) return
    if(abs(candidate_result%integrated_mass_balance_residual_cm)>hard_mass_gate) return
    if(.not.allocated(candidate_result%candidate_state%pressure_head)) return
    if(.not.allocated(candidate_result%candidate_state%water_content)) return
    if(any(.not.ieee_is_finite(candidate_result%candidate_state%pressure_head))) return
    if(any(.not.ieee_is_finite(candidate_result%candidate_state%water_content))) return

    control_class='CONTROL_OTHER'
    neutral=.false.
    control_total_only=.false.
    dh_inf=-1.0_real64;dh_rms=-1.0_real64;dtheta_inf=-1.0_real64;dtheta_rms=-1.0_real64;dstorage=-1.0_real64

    if(control_result%status==SW_SOLVE_CONVERGED.and.trim(control_result%diagnostics%route)=='legacy-reference-bound') then
      control_class='CONTROL_CONVERGED'
      control_converged_count=control_converged_count+1
      call endpoint_difference(control_result%candidate_state,candidate_result%candidate_state,dh_inf,dh_rms, &
           dtheta_inf,dtheta_rms,dstorage)
      neutral=dh_inf<=budget_h_inf.and.dh_rms<=budget_h_rms.and.dtheta_inf<=budget_theta_inf.and. &
           dtheta_rms<=budget_theta_rms.and.dstorage<=budget_storage
      if(.not.neutral) return
    else if(control_result%status==SW_SOLVE_RETRY_ADVISED) then
      if(.not.allocated(control_workspace%richards%residual)) return
      bal_flags=count(control_workspace%richards%nonconverged_balance)
      head_flags=count(control_workspace%richards%nonconverged_head)
      control_rsum=sum(control_workspace%richards%residual)
      control_rmax=maxval(abs(control_workspace%richards%residual))
      control_integrated=abs(control_rsum)*dt
      control_total_only=bal_flags==0.and.head_flags==0.and.ieee_is_finite(control_rsum).and.ieee_is_finite(control_rmax).and. &
           control_rmax<=control_total_rate_tol.and.abs(control_rsum)>control_total_rate_tol.and.control_integrated<=rep_bound
      if(.not.control_total_only) return
      control_class='CONTROL_TOTAL_ONLY'
      control_total_retry_count=control_total_retry_count+1
      neutral=.true.
    else
      return
    end if

    bottom_flux=candidate_result%bottom_flux
    mass_residual=candidate_result%integrated_mass_balance_residual_cm
    current_state=candidate_result%candidate_state
    ok=.true.

    write(*,'(*(g0))') 'F_ROM0R_R3Q1_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|STEP=',step, &
         '|CONTROL=',trim(control_class),'|REP_BOUND_CM=',rep_bound,'|CAND_TOTAL_RATE_TOL=',candidate_total_rate, &
         '|MASS_CM=',mass_residual,'|BOTTOM_FLUX=',bottom_flux,'|DH_INF=',dh_inf,'|DH_RMS=',dh_rms, &
         '|DTHETA_INF=',dtheta_inf,'|DTHETA_RMS=',dtheta_rms,'|DSTORAGE=',dstorage,'|NEUTRAL=',neutral
  end subroutine qualify_step

  subroutine endpoint_difference(control,candidate,dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage)
    type(soil_water_physical_state_t),intent(in) :: control,candidate
    real(real64),intent(out) :: dh_inf,dh_rms,dtheta_inf,dtheta_rms,dstorage
    real(real64) :: dh(numnod),dtc(numnod)
    dh=candidate%pressure_head-control%pressure_head
    dtc=candidate%water_content-control%water_content
    dh_inf=maxval(abs(dh));dh_rms=sqrt(sum(dh*dh)/real(numnod,real64))
    dtheta_inf=maxval(abs(dtc));dtheta_rms=sqrt(sum(dtc*dtc)/real(numnod,real64))
    dstorage=abs(sum(dtc*dz(1:numnod)))
  end subroutine endpoint_difference

  subroutine state_metrics(state,total_storage,upper_storage,lower_storage)
    type(soil_water_physical_state_t),intent(in) :: state
    real(real64),intent(out) :: total_storage,upper_storage,lower_storage
    total_storage=sum(state%water_content*dz(1:numnod))
    upper_storage=sum(state%water_content(1:4)*dz(1:4))
    lower_storage=sum(state%water_content(5:numnod)*dz(5:numnod))
  end subroutine state_metrics

  subroutine build_request(req,pset,constitutive,source_sink,top_provider,state,forcing,parameters,dt,total_rate_tol)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: pset
    type(b110_default_mvg_provider_t),target,intent(in) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    type(soil_water_physical_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    real(real64),intent(in) :: dt,total_rate_tol
    req%parameters=>pset
    req%base_state=state
    req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    req%boundary%bottom_mode=5
    req%boundary%top_flux=forcing%top_flux
    req%boundary%top_head=forcing%top_head
    req%boundary%bottom_flux=forcing%bottom_flux
    req%boundary%bottom_head=forcing%bottom_head
    req%physical%macropore_active=.false.
    req%numerical%max_iterations=parameters%max_iterations
    req%numerical%max_backtracking=parameters%max_backtracking
    req%numerical%conductivity_implicit_mode=parameters%swkimpl
    req%numerical%conductivity_mean_method=parameters%swkmean
    req%numerical%min_step_duration=parameters%min_step_duration
    req%numerical%compartment_balance_tolerance=parameters%compartment_balance_tolerance
    req%numerical%total_balance_tolerance=total_rate_tol
    req%numerical%head_abs_tolerance=parameters%head_abs_tolerance
    req%numerical%head_rel_tolerance=parameters%head_rel_tolerance
    req%numerical%ponding_tolerance=parameters%ponding_tolerance
    req%step_duration=dt
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine build_request

  subroutine initialize_solver_contract(parameters,pset,hydraulic_parameters,constitutive,source_sink,drainage,irrigation,root_sink)
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(soil_water_parameter_set_t),target,intent(out) :: pset
    type(b110_default_mvg_parameters_t),target,intent(out) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(out) :: constitutive
    type(b110_source_sink_provider_t),target,intent(out) :: source_sink
    real(real64),target,intent(out) :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    pset%parameter_set_id=parameters%parameter_set_id;pset%active_nodes=numnod
    allocate(pset%z(numnod),pset%dz(numnod),pset%node_distance(numnod))
    pset%z=parameters%z;pset%dz=parameters%dz;pset%node_distance=parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,parameters%cofgen)
    drainage=0.0_real64;irrigation=0.0_real64;root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)
  end subroutine initialize_solver_contract

  subroutine copy_to_solver_state(source,target)
    type(fmr_b110_physical_state_t),intent(in) :: source
    type(soil_water_physical_state_t),intent(out) :: target
    target%active_nodes=source%active_nodes
    allocate(target%pressure_head(numnod),target%water_content(numnod))
    target%pressure_head=source%pressure_head;target%water_content=source%water_content
    target%ponding_depth=source%ponding_depth;target%groundwater_level=source%groundwater_level
  end subroutine copy_to_solver_state

  subroutine execute_seed_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass_residual,bottom_exchange, &
                                 terminal_bottom_flux,solver_status,solver_route,nonlinear_iterations,internal_retries,backtracking)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass_residual,bottom_exchange,terminal_bottom_flux
    integer,intent(out) :: solver_status,nonlinear_iterations,internal_retries,backtracking
    character(len=*),intent(out) :: solver_route
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status
    mass_residual=huge(0.0_real64);bottom_exchange=0.0_real64;terminal_bottom_flux=0.0_real64
    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    solver_status=observation%solver_status;solver_route=trim(observation%solver_diagnostics%route)
    nonlinear_iterations=result%nonlinear_iterations;internal_retries=result%internal_retries;backtracking=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate.and.observation%solver_status==SW_SOLVE_CONVERGED
    if(.not.ok) return
    mass_residual=result%mass%residual;bottom_exchange=result%bottom_outward_exchange_native
    terminal_bottom_flux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED
  end subroutine execute_seed_sample

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64;nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64;nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'R3Q1 known material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=964101_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lam;p%cofgen(6,k)=nn;p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks;p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=1.0e-12_real64;p%total_balance_tolerance=1.0e-12_real64
    p%head_abs_tolerance=1.0e-12_real64;p%head_rel_tolerance=1.0e-12_real64;p%ponding_tolerance=1.0e-12_real64
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,seed_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qt,qb,hb)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qt,qb,hb
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qb;f%bottom_head=hb
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=964101_int64;tmpl%physics_topology_id=964102_int64;tmpl%vertical_layout_id=964103_int64
    tmpl%state_layout_id=964104_int64;tmpl%solver_interface_id=964105_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0R_R3Q1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3q1_representation_policy
