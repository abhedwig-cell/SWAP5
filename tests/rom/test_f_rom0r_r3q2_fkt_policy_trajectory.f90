program test_f_rom0r_r3q2_fkt_policy_trajectory
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
       soil_water_solve_request_t, soil_water_solve_result_t, SW_SOLVE_CONVERGED
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
  real(real64), parameter :: representation_floor_min_cm=1.6e-15_real64
  integer(int64), parameter :: column_id=965101_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  integer :: imat,icase

  call require(numnod==16,'R3Q2 geometry frozen')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3Q2 depth frozen')
  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_case(trim(materials(imat)),trim(cases(icase)))
    end do
  end do
  write(*,'(A)') 'F_ROM0R_R3Q2_MATRIX_COMPLETE=PASS'

contains

  subroutine run_case(material_id,case_id)
    character(len=*),intent(in) :: material_id,case_id
    type(fmr_b110_physical_parameters_t) :: base_parameters,policy_parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    type(soil_water_parameter_set_t),target :: pset
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    real(real64) :: h0,k0,qeq,hbot,t0,t1,mass,bex,bflux
    real(real64) :: cumulative_bottom_exchange,max_abs_mass,total_storage,upper_storage,lower_storage
    integer :: i,solver_status,nl,internal_retries,backtracking
    character(len=96) :: solver_route
    logical :: ok

    call initialize_parameters(material_id,base_parameters)
    call initialize_state(base_parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE'); hbot=0.75_real64*h0
    case('BOTTOM_HEAD_FALL'); hbot=1.25_real64*h0
    case default
      call require(.false.,'R3Q2 known case'); hbot=h0
    end select

    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),'R3Q2 committed seed initialized')
    call backend%initialize(top_provider)

    base_parameters%bottom_mode=2
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=h0
      call execute_seed_sample(backend,column,template,base_parameters,committed,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,solver_route,nl,internal_retries,backtracking)
      call require(ok,'R3Q2 qualified seed sample')
      t0=t1
    end do

    call initialize_solver_contract(base_parameters,pset,hydraulic_parameters,constitutive,source_sink, &
         drainage,irrigation,root_sink)
    forcing%top_flux=qeq;forcing%bottom_flux=qeq;forcing%bottom_head=hbot
    cumulative_bottom_exchange=0.0_real64
    max_abs_mass=0.0_real64

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      policy_parameters=base_parameters
      policy_parameters%bottom_mode=5
      call qualify_fkt_step(material_id,case_id,i,policy_parameters,pset,hydraulic_parameters,constitutive,source_sink, &
           top_provider,backend,column,template,committed,forcing,t0,t1,mass,bex,bflux,ok)
      call require(ok,'R3Q2 F-KT step qualified')
      cumulative_bottom_exchange=cumulative_bottom_exchange+bex
      max_abs_mass=max(max_abs_mass,abs(mass))
      t0=t1
    end do

    call committed_metrics(committed,total_storage,upper_storage,lower_storage,ok)
    call require(ok,'R3Q2 final committed metrics')
    write(*,'(*(g0))') 'F_ROM0R_R3Q2_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_bottom_exchange,'|MAX_ABS_MASS=',max_abs_mass, &
         '|FINAL_REV=',committed%current_revision(),'|FINAL_T=',t0
  end subroutine run_case

  subroutine qualify_fkt_step(material_id,case_id,step,parameters,pset,hydraulic_parameters,constitutive,source_sink, &
                              top_provider,backend,column,template,committed,forcing,t0,t1,mass_residual,bottom_exchange, &
                              terminal_bottom_flux,ok)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(in) :: step
    type(fmr_b110_physical_parameters_t),intent(inout) :: parameters
    type(soil_water_parameter_set_t),target,intent(in) :: pset
    type(b110_default_mvg_parameters_t),target,intent(inout) :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target,intent(inout) :: constitutive
    type(b110_source_sink_provider_t),target,intent(inout) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(inout) :: top_provider
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    real(real64),intent(out) :: mass_residual,bottom_exchange,terminal_bottom_flux
    logical,intent(out) :: ok

    class(transaction_state_t),allocatable :: base_snapshot,candidate_snapshot,committed_snapshot
    type(soil_water_physical_state_t) :: base_solver_state
    type(soil_water_solve_request_t) :: direct_request
    type(soil_water_solve_result_t) :: direct_result
    type(reference_richards_legacy_solver_t) :: direct_solver
    type(reference_richards_legacy_workspace_t) :: direct_workspace
    type(kernel_reference_floor_result_t) :: sample_result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    integer(int64) :: lineage_before,revision_before
    real(real64) :: time_before,time_after,dt,rep_formula,rep_bound,origin_t0,origin_t1
    logical :: got,time_ok,context_ok,origin_ok,did_commit
    integer :: commit_status

    ok=.false.;mass_residual=huge(0.0_real64);bottom_exchange=0.0_real64;terminal_bottom_flux=0.0_real64
    lineage_before=committed%current_lineage_id()
    revision_before=committed%current_revision()
    call committed%current_time(time_before,time_ok)
    call require(time_ok.and.same_bits(time_before,t0),'R3Q2 committed origin time')
    call committed%snapshot(base_snapshot,got)
    call require(got,'R3Q2 committed base snapshot')
    call fmr_to_solver_state(base_snapshot,base_solver_state,got)
    call require(got,'R3Q2 solver base materialization')

    dt=t1-t0
    call require(all(spacing(base_solver_state%water_content)<=spacing(parameters%cofgen(2,1))), &
         'R3Q2 representation runtime check')
    rep_formula=0.5_real64*sum((spacing(parameters%cofgen(2,1))+spacing(base_solver_state%water_content))*parameters%dz)
    rep_bound=max(representation_floor_min_cm,rep_formula)
    parameters%total_balance_tolerance=rep_bound/dt

    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    call build_direct_request(direct_request,pset,constitutive,source_sink,top_provider,base_solver_state,forcing,parameters,dt)
    call bind_b110_serialized_legacy_context(direct_request,context_ok)
    call require(context_ok,'R3Q2 direct context')
    call direct_solver%solve(direct_request,direct_workspace,direct_result)
    call require(direct_result%status==SW_SOLVE_CONVERGED,'R3Q2 direct candidate converged')
    call require(trim(direct_result%diagnostics%route)=='legacy-reference-bound','R3Q2 direct candidate route')
    call require(direct_result%integrated_mass_balance_residual_available,'R3Q2 direct mass available')
    call require(abs(direct_result%integrated_mass_balance_residual_cm)<=hard_mass_gate,'R3Q2 direct hard mass')

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         sample_result,candidate,diagnostics)
    observation=backend%observation()
    call require(sample_result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK,'R3Q2 sample status')
    call require(sample_result%sample_valid.and.candidate%ready(),'R3Q2 sample candidate ready')
    call require(sample_result%physical_advances==1,'R3Q2 one physical advance')
    call require(sample_result%internal_retries==0.and.diagnostics%retries==0,'R3Q2 zero retries')
    call require(sample_result%mass%complete.and.abs(sample_result%mass%residual)<=hard_mass_gate,'R3Q2 canonical hard mass')
    call require(candidate%current_lineage_id()==lineage_before,'R3Q2 candidate lineage')
    call require(candidate%origin_revision()==revision_before,'R3Q2 candidate revision')
    call candidate%origin_interval(origin_t0,origin_t1,origin_ok)
    call require(origin_ok.and.same_bits(origin_t0,t0).and.same_bits(origin_t1,t1),'R3Q2 candidate interval')
    call require(observation%solver_status==SW_SOLVE_CONVERGED,'R3Q2 FMR solver converged')
    call require(observation%solver_diagnostics%nonlinear_iterations==direct_result%diagnostics%nonlinear_iterations, &
         'R3Q2 nonlinear identity')
    call require(observation%solver_diagnostics%backtracking_attempts==direct_result%diagnostics%backtracking_attempts, &
         'R3Q2 backtracking identity')
    call require(sample_result%bottom_interface_exchange_available,'R3Q2 bottom exchange available')
    call require(same_bits(sample_result%bottom_outward_exchange_native,-direct_result%bottom_flux*dt), &
         'R3Q2 bottom exchange sign/value identity')

    call candidate%snapshot(candidate_snapshot,got)
    call require(got,'R3Q2 candidate snapshot')
    call require(fmr_vs_solver_bits_equal(candidate_snapshot,direct_result%candidate_state),'R3Q2 candidate state identity')

    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'R3Q2 candidate commit')
    call require(.not.candidate%ready(),'R3Q2 candidate consumed')
    call require(committed%current_lineage_id()==lineage_before,'R3Q2 committed lineage stable')
    call require(committed%current_revision()==revision_before+1_int64,'R3Q2 revision increments one')
    call committed%current_time(time_after,time_ok)
    call require(time_ok.and.same_bits(time_after,t1),'R3Q2 committed time')
    call committed%snapshot(committed_snapshot,got)
    call require(got.and.fmr_vs_solver_bits_equal(committed_snapshot,direct_result%candidate_state), &
         'R3Q2 committed state identity')

    mass_residual=sample_result%mass%residual
    bottom_exchange=sample_result%bottom_outward_exchange_native
    terminal_bottom_flux=sample_result%terminal_bottom_outward_flux_native
    ok=.true.
    write(*,'(*(g0))') 'F_ROM0R_R3Q2_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|STEP=',step, &
         '|REP_BOUND_CM=',rep_bound,'|RATE_TOL=',parameters%total_balance_tolerance, &
         '|MASS_CM=',mass_residual,'|DIRECT_MASS_CM=',direct_result%integrated_mass_balance_residual_cm, &
         '|BOTTOM_EXCHANGE=',bottom_exchange,'|BOTTOM_FLUX=',terminal_bottom_flux, &
         '|NL=',sample_result%nonlinear_iterations,'|BACKTRACK=',sample_result%backtracking_attempts, &
         '|REV=',committed%current_revision(),'|T=',t1,'|IDENTITY=T'
  end subroutine qualify_fkt_step

  subroutine build_direct_request(req,pset,constitutive,source_sink,top_provider,state,forcing,parameters,dt)
    type(soil_water_solve_request_t),intent(out) :: req
    type(soil_water_parameter_set_t),target,intent(in) :: pset
    type(b110_default_mvg_provider_t),target,intent(in) :: constitutive
    type(b110_source_sink_provider_t),target,intent(in) :: source_sink
    type(fixed_flux_top_boundary_provider_t),target,intent(in) :: top_provider
    type(soil_water_physical_state_t),intent(in) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    real(real64),intent(in) :: dt
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
    req%numerical%total_balance_tolerance=parameters%total_balance_tolerance
    req%numerical%head_abs_tolerance=parameters%head_abs_tolerance
    req%numerical%head_rel_tolerance=parameters%head_rel_tolerance
    req%numerical%ponding_tolerance=parameters%ponding_tolerance
    req%step_duration=dt
    req%evaluation%constitutive=>constitutive
    req%evaluation%source_sink=>source_sink
    req%evaluation%top_boundary=>top_provider
  end subroutine build_direct_request

  subroutine fmr_to_solver_state(snapshot,state,ok)
    class(transaction_state_t),allocatable,intent(in) :: snapshot
    type(soil_water_physical_state_t),intent(out) :: state
    logical,intent(out) :: ok
    ok=.false.
    select type(s=>snapshot)
    type is(fmr_b110_physical_state_t)
      state%active_nodes=s%active_nodes
      allocate(state%pressure_head(numnod),state%water_content(numnod))
      state%pressure_head=s%pressure_head;state%water_content=s%water_content
      state%ponding_depth=s%ponding_depth;state%groundwater_level=s%groundwater_level
      ok=.true.
    end select
  end subroutine fmr_to_solver_state

  logical function fmr_vs_solver_bits_equal(snapshot,state) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: snapshot
    type(soil_water_physical_state_t),intent(in) :: state
    equal=.false.
    select type(s=>snapshot)
    type is(fmr_b110_physical_state_t)
      equal=s%active_nodes==state%active_nodes.and.array_bits_equal(s%pressure_head,state%pressure_head).and. &
           array_bits_equal(s%water_content,state%water_content).and.same_bits(s%ponding_depth,state%ponding_depth).and. &
           same_bits(s%groundwater_level,state%groundwater_level)
    end select
  end function fmr_vs_solver_bits_equal

  subroutine committed_metrics(committed,total_storage,upper_storage,lower_storage,ok)
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(out) :: total_storage,upper_storage,lower_storage
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snapshot
    logical :: got
    ok=.false.;total_storage=0.0_real64;upper_storage=0.0_real64;lower_storage=0.0_real64
    call committed%snapshot(snapshot,got)
    if(.not.got)return
    select type(s=>snapshot)
    type is(fmr_b110_physical_state_t)
      total_storage=sum(s%water_content*dz(1:numnod))
      upper_storage=sum(s%water_content(1:4)*dz(1:4))
      lower_storage=sum(s%water_content(5:numnod)*dz(5:numnod))
      ok=.true.
    end select
  end subroutine committed_metrics

  pure logical function array_bits_equal(a,b)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    array_bits_equal=size(a)==size(b)
    if(.not.array_bits_equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i))) then
        array_bits_equal=.false.;return
      end if
    end do
  end function array_bits_equal

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

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
    if(.not.ok)return
    mass_residual=result%mass%residual;bottom_exchange=result%bottom_outward_exchange_native
    terminal_bottom_flux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED
  end subroutine execute_seed_sample

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
      call require(.false.,'R3Q2 known material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=965101_int64;p%active_nodes=numnod
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
    tmpl%template_id=965101_int64;tmpl%physics_topology_id=965102_int64;tmpl%vertical_layout_id=965103_int64
    tmpl%state_layout_id=965104_int64;tmpl%solver_interface_id=965105_int64
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
      write(*,'(A,1X,A)') 'F_ROM0R_R3Q2_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3q2_fkt_policy_trajectory
