program test_f_rom0r_r3d1_retry_cause
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t, soil_water_solve_request_t, &
       soil_water_solve_result_t, SW_SOLVE_CONVERGED, SW_SOLVE_RETRY_ADVISED
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
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=963101_int64
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']
  integer :: icase

  call require(numnod==16,'R3D1 geometry frozen')
  do icase=1,size(cases)
    call diagnose_case(trim(cases(icase)))
  end do
  write(*,'(A)') 'F_ROM0R_R3D1_DIAGNOSTIC_GATE=PASS'

contains

  subroutine diagnose_case(case_id)
    character(len=*),intent(in) :: case_id
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,hbot,t0,t1,mass,bex,bflux
    integer :: i,pre_steps,solver_status,nl,internal_retries,backtracking
    character(len=96) :: solver_route
    logical :: ok

    call initialize_parameters(parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE')
      hbot=0.75_real64*h0
      pre_steps=10
    case('BOTTOM_HEAD_FALL')
      hbot=1.25_real64*h0
      pre_steps=9
    case default
      call require(.false.,'known R3D1 case')
      hbot=h0; pre_steps=0
    end select

    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),'initial committed state')
    call backend%initialize(top_boundary)

    parameters%bottom_mode=2
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq; forcing%bottom_flux=qeq; forcing%bottom_head=h0
      call execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,solver_route,nl,internal_retries,backtracking)
      call require(ok,'steady seed sample')
      t0=t1
    end do

    parameters%bottom_mode=5
    forcing%top_flux=qeq; forcing%bottom_flux=qeq; forcing%bottom_head=hbot
    do i=1,pre_steps
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass,bex,bflux, &
           solver_status,solver_route,nl,internal_retries,backtracking)
      call require(ok,'accepted predecessor sample')
      t0=t1
    end do
    t1=t0+perturb_dt

    call direct_diagnostic(case_id,parameters,forcing,committed,t0,t1,backend,column,template)

    write(*,'(*(g0))') 'F_ROM0R_R3D1_CASE_COMPLETE|CASE=',trim(case_id),'|PRE_STEPS=',pre_steps, &
         '|T0=',t0,'|T1=',t1,'|REV=',committed%current_revision()
  end subroutine diagnose_case

  subroutine direct_diagnostic(case_id,parameters,forcing,committed,t0,t1,backend,column,template)
    character(len=*),intent(in) :: case_id
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(in) :: t0,t1
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template

    type(soil_water_parameter_set_t),target :: pset
    type(b110_default_mvg_parameters_t),target :: hydraulic_parameters
    type(b110_default_mvg_provider_t),target :: constitutive
    type(b110_source_sink_provider_t),target :: source_sink
    type(fixed_flux_top_boundary_provider_t),target :: top_provider
    real(real64),target :: drainage(1,numnod),irrigation(numnod),root_sink(numnod)
    type(soil_water_solve_request_t) :: request
    type(soil_water_solve_result_t) :: direct_result
    type(reference_richards_legacy_solver_t) :: solver
    type(reference_richards_legacy_workspace_t) :: workspace
    class(transaction_state_t),allocatable :: snapshot_before,snapshot_after
    type(kernel_reference_floor_result_t) :: fmr_result
    type(kernel_reference_floor_candidate_t) :: fmr_candidate
    type(kernel_diagnostics_t) :: fmr_diag
    type(fmr_serialized_physical_observation_t) :: obs
    integer(int64) :: rev_before,lineage_before
    real(real64) :: time_before,time_after,rsum,rmax
    integer :: bal_count,head_count,imax
    logical :: got,time_ok,context_ok
    character(len=24) :: class_name

    rev_before=committed%current_revision()
    lineage_before=committed%current_lineage_id()
    call committed%current_time(time_before,time_ok)
    call require(time_ok.and.same_bits(time_before,t0),'predecessor time')
    call committed%snapshot(snapshot_before,got)
    call require(got,'predecessor snapshot')

    pset%parameter_set_id=parameters%parameter_set_id
    pset%active_nodes=numnod
    allocate(pset%z(numnod),pset%dz(numnod),pset%node_distance(numnod))
    pset%z=parameters%z; pset%dz=parameters%dz; pset%node_distance=parameters%node_distance
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,parameters%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,t1-t0)
    drainage=0.0_real64; irrigation=0.0_real64; root_sink=0.0_real64
    call bind_b110_source_sink_provider(source_sink,drainage,irrigation,root_sink)

    request%parameters=>pset
    request%step_duration=t1-t0
    request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
    request%boundary%bottom_mode=5
    request%boundary%top_flux=forcing%top_flux
    request%boundary%top_head=forcing%top_head
    request%boundary%bottom_flux=forcing%bottom_flux
    request%boundary%bottom_head=forcing%bottom_head
    request%numerical%max_iterations=parameters%max_iterations
    request%numerical%max_backtracking=parameters%max_backtracking
    request%numerical%conductivity_implicit_mode=parameters%swkimpl
    request%numerical%conductivity_mean_method=parameters%swkmean
    request%numerical%min_step_duration=parameters%min_step_duration
    request%numerical%compartment_balance_tolerance=parameters%compartment_balance_tolerance
    request%numerical%total_balance_tolerance=parameters%total_balance_tolerance
    request%numerical%head_abs_tolerance=parameters%head_abs_tolerance
    request%numerical%head_rel_tolerance=parameters%head_rel_tolerance
    request%numerical%ponding_tolerance=parameters%ponding_tolerance
    request%physical%macropore_active=.false.
    request%evaluation%constitutive=>constitutive
    request%evaluation%source_sink=>source_sink
    request%evaluation%top_boundary=>top_provider

    select type(physical=>snapshot_before)
    type is(fmr_b110_physical_state_t)
      request%base_state%active_nodes=physical%active_nodes
      allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
      request%base_state%pressure_head=physical%pressure_head
      request%base_state%water_content=physical%water_content
      request%base_state%ponding_depth=physical%ponding_depth
      request%base_state%groundwater_level=physical%groundwater_level
    class default
      call require(.false.,'expected B110 predecessor state')
    end select

    call bind_b110_serialized_legacy_context(request,context_ok)
    call require(context_ok,'serialized legacy context')
    call solver%solve(request,workspace,direct_result)

    call require(direct_result%status==SW_SOLVE_RETRY_ADVISED,'direct retry advised')
    call require(trim(direct_result%diagnostics%route)=='legacy-reference-retry','direct retry route')
    call require(direct_result%diagnostics%nonlinear_iterations==16,'direct iteration exhaustion')
    call require(allocated(workspace%richards%residual),'workspace residual available')
    call require(allocated(workspace%richards%nonconverged_balance),'balance flags available')
    call require(allocated(workspace%richards%nonconverged_head),'head flags available')

    bal_count=count(workspace%richards%nonconverged_balance)
    head_count=count(workspace%richards%nonconverged_head)
    rsum=sum(workspace%richards%residual)
    rmax=maxval(abs(workspace%richards%residual))
    imax=maxloc(abs(workspace%richards%residual),dim=1)

    if(bal_count>0.and.head_count>0) then
      class_name='RETRY_MIXED'
    else if(bal_count>0) then
      class_name='RETRY_LOCAL_BALANCE'
    else if(head_count>0) then
      class_name='RETRY_HEAD'
    else if(ieee_is_finite(rsum).and.ieee_is_finite(rmax).and. &
            rmax<=parameters%total_balance_tolerance.and.abs(rsum)>parameters%total_balance_tolerance) then
      class_name='RETRY_TOTAL_ONLY'
    else
      class_name='RETRY_OTHER'
    end if

    call require(committed%current_revision()==rev_before,'direct diagnostic revision immutable')
    call require(committed%current_lineage_id()==lineage_before,'direct diagnostic lineage immutable')
    call committed%current_time(time_after,time_ok)
    call require(time_ok.and.same_bits(time_after,time_before),'direct diagnostic time immutable')
    call committed%snapshot(snapshot_after,got)
    call require(got,'post diagnostic snapshot')
    call require(state_bits_equal(snapshot_before,snapshot_after),'direct diagnostic physical state immutable')

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         fmr_result,fmr_candidate,fmr_diag)
    obs=backend%observation()
    call require(fmr_result%status==KERNEL_REFERENCE_FLOOR_STATUS_SOLVER_FAILED,'FMR reproduces solver failure')
    call require(.not.fmr_result%sample_valid.and..not.fmr_candidate%ready(),'FMR failed candidate not materialized')
    call require(obs%solver_status==SW_SOLVE_RETRY_ADVISED,'FMR retry status')
    call require(trim(obs%solver_diagnostics%route)=='legacy-reference-retry','FMR retry route')
    call require(obs%solver_diagnostics%nonlinear_iterations==direct_result%diagnostics%nonlinear_iterations, &
         'FMR/direct nonlinear count identity')
    call require(obs%solver_diagnostics%backtracking_attempts==direct_result%diagnostics%backtracking_attempts, &
         'FMR/direct backtracking identity')
    call require(committed%current_revision()==rev_before,'FMR failure no commit revision')
    call committed%current_time(time_after,time_ok)
    call require(time_ok.and.same_bits(time_after,time_before),'FMR failure no time advance')

    write(*,'(*(g0))') 'F_ROM0R_R3D1_CLASS|CASE=',trim(case_id),'|CLASS=',trim(class_name), &
         '|BAL_FLAGS=',bal_count,'|HEAD_FLAGS=',head_count,'|RMAX=',rmax,'|RSUM=',rsum,'|IMAX=',imax, &
         '|CP_TOL=',parameters%compartment_balance_tolerance,'|TOT_TOL=',parameters%total_balance_tolerance, &
         '|NL=',direct_result%diagnostics%nonlinear_iterations, &
         '|BACKTRACK=',direct_result%diagnostics%backtracking_attempts, &
         '|FMR_BACKTRACK=',obs%solver_diagnostics%backtracking_attempts
  end subroutine direct_diagnostic

  subroutine execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass_residual,bottom_exchange, &
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

    mass_residual=huge(0.0_real64); bottom_exchange=0.0_real64; terminal_bottom_flux=0.0_real64
    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    solver_status=observation%solver_status
    solver_route=trim(observation%solver_diagnostics%route)
    nonlinear_iterations=result%nonlinear_iterations
    internal_retries=result%internal_retries
    backtracking=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate.and. &
       observation%solver_status==SW_SOLVE_CONVERGED.and.result%bottom_interface_exchange_available
    if(.not.ok) then
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass_residual=result%mass%residual
    bottom_exchange=result%bottom_outward_exchange_native
    terminal_bottom_flux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED
  end subroutine execute_sample

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    equal=.false.
    select type(a=>left)
    type is(fmr_b110_physical_state_t)
      select type(b=>right)
      type is(fmr_b110_physical_state_t)
        equal=a%active_nodes==b%active_nodes.and.array_bits_equal(a%pressure_head,b%pressure_head).and. &
             array_bits_equal(a%water_content,b%water_content).and.same_bits(a%ponding_depth,b%ponding_depth).and. &
             same_bits(a%groundwater_level,b%groundwater_level)
      end select
    end select
  end function state_bits_equal

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

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=963101_int64;p%active_nodes=numnod
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
    p%compartment_balance_tolerance=hard_mass_gate;p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=hard_mass_gate;p%head_rel_tolerance=hard_mass_gate;p%ponding_tolerance=hard_mass_gate
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
    tmpl%template_id=963101_int64;tmpl%physics_topology_id=963102_int64
    tmpl%vertical_layout_id=963103_int64;tmpl%state_layout_id=963104_int64
    tmpl%solver_interface_id=963105_int64
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
      write(*,'(A,1X,A)') 'F_ROM0R_R3D1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3d1_retry_cause
