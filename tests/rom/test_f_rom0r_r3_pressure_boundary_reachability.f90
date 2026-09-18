program test_f_rom0r_r3_pressure_boundary_reachability
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
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=960301_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=20), parameter :: cases(2)=[character(len=20) :: 'BOTTOM_HEAD_RISE','BOTTOM_HEAD_FALL']

  integer :: imat,icase,attempted

  call require(numnod==16,'R3 geometry frozen at 16 nodes')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'R3 depth frozen at 160 cm')

  attempted=0
  do imat=1,size(materials)
    do icase=1,size(cases)
      call run_case(trim(materials(imat)),trim(cases(icase)))
      attempted=attempted+1
    end do
  end do

  call require(attempted==4,'R3 full four-case matrix attempted')
  write(*,'(A,I0)') 'F_ROM0R_R3_CASES_ATTEMPTED=',attempted
  write(*,'(A)') 'F_ROM0R_R3_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_case(material_id,case_id)
    character(len=*),intent(in) :: material_id,case_id
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq,hbot,t0,t1
    real(real64) :: mass_residual,bottom_exchange,terminal_bottom_flux
    real(real64) :: cumulative_bottom_exchange,max_abs_mass
    real(real64) :: total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state
    integer :: i,solver_status,nonlinear_iterations,internal_retries,backtracking
    character(len=96) :: solver_route
    logical :: ok

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('BOTTOM_HEAD_RISE')
      hbot=0.75_real64*h0
    case('BOTTOM_HEAD_FALL')
      hbot=1.25_real64*h0
    case default
      call require(.false.,'R3 known case')
      hbot=h0
    end select
    call initialize_identity(column,template)
    call initialize_forcing(forcing,qeq,qeq,h0)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),'R3 committed state initialized')
    call backend%initialize(top_boundary)

    write(*,'(*(g0))') 'F_ROM0R_R3_CASE_START|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|H0=',h0,'|HBOT=',hbot,'|QEQ=',qeq,'|DT=',perturb_dt

    parameters%bottom_mode=2
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq
      forcing%bottom_flux=qeq
      forcing%bottom_head=h0
      call execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass_residual,bottom_exchange, &
           terminal_bottom_flux,solver_status,solver_route,nonlinear_iterations,internal_retries,backtracking)
      if(.not.ok) then
        write(*,'(*(g0))') 'F_ROM0R_R3_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|PHASE=SEED|STEP=',i,'|T0=',t0,'|T1=',t1,'|SOLVER_STATUS=',solver_status, &
             '|ROUTE=',trim(solver_route),'|NL=',nonlinear_iterations,'|INTERNAL_RETRIES=',internal_retries, &
             '|BACKTRACK=',backtracking
        return
      end if
      t0=t1
    end do

    parameters%bottom_mode=5
    forcing%top_flux=qeq
    forcing%bottom_flux=qeq
    forcing%bottom_head=hbot
    cumulative_bottom_exchange=0.0_real64
    max_abs_mass=0.0_real64

    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call execute_sample(backend,column,template,parameters,committed,forcing,t0,t1,ok,mass_residual,bottom_exchange, &
           terminal_bottom_flux,solver_status,solver_route,nonlinear_iterations,internal_retries,backtracking)
      if(.not.ok) then
        write(*,'(*(g0))') 'F_ROM0R_R3_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|PHASE=PERT|STEP=',i,'|T0=',t0,'|T1=',t1,'|SOLVER_STATUS=',solver_status, &
             '|ROUTE=',trim(solver_route),'|NL=',nonlinear_iterations,'|INTERNAL_RETRIES=',internal_retries, &
             '|BACKTRACK=',backtracking
        return
      end if
      cumulative_bottom_exchange=cumulative_bottom_exchange+bottom_exchange
      max_abs_mass=max(max_abs_mass,abs(mass_residual))
      write(*,'(*(g0))') 'F_ROM0R_R3_STEP|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|STEP=',i, &
           '|T=',t1,'|MASS=',mass_residual,'|BOTTOM_EXCHANGE=',bottom_exchange,'|BOTTOM_FLUX=',terminal_bottom_flux, &
           '|NL=',nonlinear_iterations
      t0=t1
    end do

    call state_metrics(committed,total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state,ok)
    call require(ok,'R3 final state metrics')
    write(*,'(*(g0))') 'F_ROM0R_R3_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|FINAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
         '|CUM_BOTTOM_OUTWARD_EXCHANGE=',cumulative_bottom_exchange,'|TERMINAL_BOTTOM_FLUX=',terminal_bottom_flux, &
         '|FINAL_BOTTOM_NODE_HEAD=',bottom_head_state,'|POND=',pond,'|GWL=',gwl,'|MAX_ABS_MASS=',max_abs_mass, &
         '|FINAL_REV=',committed%current_revision(),'|FINAL_T=',t0
  end subroutine run_case

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

    mass_residual=huge(0.0_real64)
    bottom_exchange=0.0_real64
    terminal_bottom_flux=0.0_real64
    solver_status=-999
    nonlinear_iterations=0
    internal_retries=0
    backtracking=0
    solver_route='not-run'

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    solver_status=observation%solver_status
    solver_route=trim(observation%solver_diagnostics%route)
    nonlinear_iterations=result%nonlinear_iterations
    internal_retries=result%internal_retries
    backtracking=result%backtracking_attempts

    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid .and. candidate%ready() .and. &
       result%physical_advances==1 .and. result%internal_retries==0 .and. diagnostics%retries==0 .and. &
       result%mass%complete .and. ieee_is_finite(result%mass%residual) .and. &
       abs(result%mass%residual)<=hard_mass_gate .and. observation%solver_executed .and. &
       observation%solver_status==SW_SOLVE_CONVERGED .and. result%bottom_interface_exchange_available .and. &
       ieee_is_finite(result%bottom_outward_exchange_native) .and. ieee_is_finite(result%terminal_bottom_outward_flux_native)

    if(.not.ok) then
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if

    mass_residual=result%mass%residual
    bottom_exchange=result%bottom_outward_exchange_native
    terminal_bottom_flux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED .and. .not.candidate%ready()
  end subroutine execute_sample

  subroutine state_metrics(committed,total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state,ok)
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(out) :: total_storage,upper_storage,lower_storage,pond,gwl,bottom_head_state
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snapshot
    logical :: got
    integer :: upper_nodes

    ok=.false.
    total_storage=0.0_real64
    upper_storage=0.0_real64
    lower_storage=0.0_real64
    pond=0.0_real64
    gwl=0.0_real64
    bottom_head_state=0.0_real64
    call committed%snapshot(snapshot,got)
    if(.not.got) return
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(physical%active_nodes/=numnod) return
      if(.not.allocated(physical%water_content).or..not.allocated(physical%pressure_head)) return
      upper_nodes=4
      total_storage=sum(physical%water_content(1:numnod)*dz(1:numnod))
      upper_storage=sum(physical%water_content(1:upper_nodes)*dz(1:upper_nodes))
      lower_storage=sum(physical%water_content(upper_nodes+1:numnod)*dz(upper_nodes+1:numnod))
      pond=physical%ponding_depth
      gwl=physical%groundwater_level
      bottom_head_state=physical%pressure_head(numnod)
      ok=ieee_is_finite(total_storage).and.ieee_is_finite(upper_storage).and.ieee_is_finite(lower_storage).and. &
         ieee_is_finite(pond).and.ieee_is_finite(gwl).and.ieee_is_finite(bottom_head_state)
    class default
      ok=.false.
    end select
    if(allocated(snapshot)) deallocate(snapshot)
  end subroutine state_metrics

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
      nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64
      nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'R3 known material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960301_int64
    p%active_nodes=numnod
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
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'R3 finite seed')
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
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960301_int64;tmpl%physics_topology_id=960302_int64
    tmpl%vertical_layout_id=960303_int64;tmpl%state_layout_id=960304_int64
    tmpl%solver_interface_id=960305_int64
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
      write(*,'(A,1X,A)') 'F_ROM0R_R3_STRUCTURAL_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0r_r3_pressure_boundary_reachability
