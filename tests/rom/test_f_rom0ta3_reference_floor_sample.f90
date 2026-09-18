program test_f_rom0ta3_reference_floor_sample
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
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: horizon=0.0128_real64
  real(real64), parameter :: epsilon_fraction=0.01_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  real(real64), parameter :: dt_values(3)=[0.0016_real64,0.0008_real64,0.0004_real64]
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=12), parameter :: cases(2)=[character(len=12) :: 'TOP_PLUS','TOP_MINUS']
  integer(int64), parameter :: column_id=930301_int64

  integer :: imat,icase,idt,science_failures,trajectory_count

  call require(numnod==16,'TA3 geometry frozen at 16 nodes')
  science_failures=0
  trajectory_count=0

  do imat=1,size(materials)
    do icase=1,size(cases)
      do idt=1,size(dt_values)
        trajectory_count=trajectory_count+1
        call run_trajectory(trim(materials(imat)),trim(cases(icase)),dt_values(idt),science_failures)
      end do
    end do
  end do

  call require(trajectory_count==12,'complete preregistered trajectory matrix attempted')
  write(*,'(*(g0))') 'F_ROM0TA3_MATRIX|TRAJECTORIES=',trajectory_count,'|SCIENTIFIC_FAILURES=',science_failures
  write(*,'(A)') 'F_ROM0TA3_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_trajectory(material_id,case_id,perturb_dt,failures)
    character(len=*),intent(in) :: material_id,case_id
    real(real64),intent(in) :: perturb_dt
    integer,intent(inout) :: failures

    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t), target :: top_boundary
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: h0,k0,qeq,qtop,t0,t1
    real(real64) :: cumulative_top_exchange,cumulative_bottom_exchange
    integer :: i,npert
    logical :: ok,snapshot_ok,step_ok

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('TOP_PLUS')
      qtop=qeq+epsilon_fraction*k0
    case('TOP_MINUS')
      qtop=qeq-epsilon_fraction*k0
    case default
      call require(.false.,'known TA3 perturbation case')
    end select

    npert=nint(horizon/perturb_dt)
    call require(abs(real(npert,real64)*perturb_dt-horizon)<=1.0e-15_real64,'TA3 exact common horizon')
    call initialize_forcing(forcing,qeq,qeq)
    call initialize_identity(column,template)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok,'TA3 committed trajectory initialized')
    call backend%initialize(top_boundary)

    write(*,'(*(g0))') 'F_ROM0TA3_TRAJECTORY_START|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',perturb_dt,'|NPERT=',npert,'|H0=',h0,'|K0=',k0,'|QEQ=',qeq,'|QTOP=',qtop

    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq
      forcing%bottom_flux=qeq
      call sample_and_commit(material_id,case_id,'SEED',i,t0,t1,parameters,forcing,column,template,backend,committed,step_ok, &
           cumulative_top_exchange,cumulative_bottom_exchange,reset_exchange=(i==1))
      if(.not.step_ok) then
        failures=failures+1
        write(*,'(*(g0))') 'F_ROM0TA3_TRAJECTORY_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|DT=',perturb_dt,'|PHASE=SEED|STEP=',i
        return
      end if
      t0=t1
    end do

    cumulative_top_exchange=0.0_real64
    cumulative_bottom_exchange=0.0_real64
    forcing%top_flux=qtop
    forcing%bottom_flux=qeq
    do i=1,npert
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_and_commit(material_id,case_id,'PERT',i,t0,t1,parameters,forcing,column,template,backend,committed,step_ok, &
           cumulative_top_exchange,cumulative_bottom_exchange)
      if(.not.step_ok) then
        failures=failures+1
        write(*,'(*(g0))') 'F_ROM0TA3_TRAJECTORY_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|DT=',perturb_dt,'|PHASE=PERT|STEP=',i
        return
      end if
      t0=t1
    end do

    call committed%snapshot(snapshot,snapshot_ok)
    call require(snapshot_ok,'TA3 final committed snapshot')
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      call emit_state_summary('FINAL',material_id,case_id,perturb_dt,npert,horizon,physical,parameters, &
           cumulative_top_exchange,cumulative_bottom_exchange,committed%current_revision())
    class default
      error stop 'F_ROM0TA3_FAIL unexpected final state type'
    end select
    if(allocated(snapshot)) deallocate(snapshot)

    write(*,'(*(g0))') 'F_ROM0TA3_TRAJECTORY_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',perturb_dt,'|FINAL_REV=',committed%current_revision(),'|FINAL_T=',t0
  end subroutine run_trajectory

  subroutine sample_and_commit(material_id,case_id,phase,local_step,a,b,parameters,forcing,column,template,backend,committed,step_ok, &
                               cumulative_top_exchange,cumulative_bottom_exchange,reset_exchange)
    character(len=*),intent(in) :: material_id,case_id,phase
    integer,intent(in) :: local_step
    real(real64),intent(in) :: a,b
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(kernel_committed_state_t),intent(inout) :: committed
    logical,intent(out) :: step_ok
    real(real64),intent(inout) :: cumulative_top_exchange,cumulative_bottom_exchange
    logical,intent(in),optional :: reset_exchange

    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    class(transaction_state_t),allocatable :: candidate_snapshot
    logical :: candidate_ok,did_commit
    integer :: commit_status
    real(real64) :: dt,top_exchange

    if(present(reset_exchange)) then
      if(reset_exchange) then
        cumulative_top_exchange=0.0_real64
        cumulative_bottom_exchange=0.0_real64
      end if
    end if
    dt=b-a
    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,a,b,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()

    step_ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid .and. candidate%ready() .and. &
         result%physical_advances==1 .and. result%internal_retries==0 .and. diagnostics%retries==0 .and. &
         diagnostics%trial_rollbacks==0
    if(.not.step_ok) then
      write(*,'(*(g0))') 'F_ROM0TA3_SAMPLE_REJECT|PHASE=',trim(phase),'|STEP=',local_step,'|T0=',a,'|T1=',b, &
           '|STATUS=',result%status,'|SAMPLE_VALID=',result%sample_valid,'|PHYSICAL_ADVANCES=',result%physical_advances, &
           '|MASS_COMPLETE=',result%mass%complete,'|MASS_RES=',result%mass%residual, &
           '|SOLVER_STATUS=',observation%solver_status,'|SOLVER_ROUTE=',trim(observation%solver_diagnostics%route), &
           '|NL=',result%nonlinear_iterations,'|INTERNAL_RETRIES=',result%internal_retries, &
           '|BACKTRACK=',result%backtracking_attempts
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if

    call require(result%physical_advances==1,'TA3 exactly one physical advance')
    call require(abs(result%accepted_dt-dt)<=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(dt)), &
         'TA3 exact requested dt')
    call require(result%mass%complete,'TA3 complete sample mass')
    call require(abs(result%mass%residual)<=hard_mass_gate,'TA3 hard mass gate')
    call require(observation%solver_executed,'TA3 Reference solver executed')
    call require(observation%solver_status==0,'TA3 Reference solver converged')
    call require(abs(observation%top_flux-forcing%top_flux)<= &
         64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(forcing%top_flux)),'TA3 top flux identity')
    call require(abs(observation%bottom_flux-forcing%bottom_flux)<= &
         64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(forcing%bottom_flux)),'TA3 bottom flux identity')

    call candidate%snapshot(candidate_snapshot,candidate_ok)
    call require(candidate_ok,'TA3 candidate snapshot available')
    top_exchange=observation%top_flux*dt
    if(trim(phase)=='PERT') then
      cumulative_top_exchange=cumulative_top_exchange+top_exchange
      call require(result%bottom_interface_exchange_available,'TA3 bottom exchange available')
      cumulative_bottom_exchange=cumulative_bottom_exchange+result%bottom_outward_exchange_native
    end if

    select type(physical=>candidate_snapshot)
    type is(fmr_b110_physical_state_t)
      call require(all(ieee_is_finite(physical%pressure_head)),'TA3 finite candidate heads')
      call require(all(ieee_is_finite(physical%water_content)),'TA3 finite candidate theta')
      if(trim(phase)=='PERT') then
        call emit_state_summary('POINT',material_id,case_id,dt,local_step,b-real(seed_intervals,real64)*seed_dt,physical,parameters, &
             cumulative_top_exchange,cumulative_bottom_exchange,committed%current_revision()+1_int64)
        call emit_node_state(material_id,case_id,local_step,b-real(seed_intervals,real64)*seed_dt,dt,physical)
      end if
    class default
      error stop 'F_ROM0TA3_FAIL unexpected candidate state type'
    end select
    if(allocated(candidate_snapshot)) deallocate(candidate_snapshot)

    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'TA3 dedicated sample commit')
    call require(.not.candidate%ready(),'TA3 committed candidate consumed')

    write(*,'(*(g0))') 'F_ROM0TA3_SAMPLE_ACCEPT|PHASE=',trim(phase),'|STEP=',local_step,'|T0=',a,'|T1=',b, &
         '|DT=',dt,'|PHYSICAL_ADVANCES=',result%physical_advances,'|MASS_RES=',result%mass%residual, &
         '|NL=',result%nonlinear_iterations,'|INTERNAL_RETRIES=',result%internal_retries, &
         '|BACKTRACK=',result%backtracking_attempts,'|LINEAR=',result%linear_solves, &
         '|REV=',committed%current_revision()
  end subroutine sample_and_commit

  subroutine emit_state_summary(kind,material_id,case_id,dt,step,trel,physical,parameters,top_exchange,bottom_exchange,revision)
    character(len=*),intent(in) :: kind,material_id,case_id
    real(real64),intent(in) :: dt,trel,top_exchange,bottom_exchange
    integer,intent(in) :: step
    type(fmr_b110_physical_state_t),intent(in) :: physical
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    integer(int64),intent(in) :: revision
    real(real64) :: total,upper,lower

    call require(physical%active_nodes==16,'TA3 state node count')
    total=sum(parameters%dz*physical%water_content)+physical%ponding_depth
    upper=sum(parameters%dz(1:4)*physical%water_content(1:4))
    lower=sum(parameters%dz(5:16)*physical%water_content(5:16))
    write(*,'(*(g0))') 'F_ROM0TA3_',trim(kind),'|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',dt,'|STEP=',step,'|TREL=',trel,'|REV=',revision,'|TOTAL=',total,'|UPPER=',upper,'|LOWER=',lower, &
         '|TOP_EXCHANGE=',top_exchange,'|BOTTOM_OUTWARD_EXCHANGE=',bottom_exchange
  end subroutine emit_state_summary

  subroutine emit_node_state(material_id,case_id,step,trel,dt,physical)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(in) :: step
    real(real64),intent(in) :: trel,dt
    type(fmr_b110_physical_state_t),intent(in) :: physical
    integer :: k
    do k=1,physical%active_nodes
      write(*,'(*(g0))') 'F_ROM0TA3_NODE|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
           '|DT=',dt,'|STEP=',step,'|TREL=',trel,'|NODE=',k,'|H=',physical%pressure_head(k),'|THETA=',physical%water_content(k)
    end do
  end subroutine emit_node_state

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64
      nn=1.734737_real64; ks=31.225016_real64; lam=0.98087_real64
    case('B14')
      tr=0.01_real64; ts=0.416774_real64; alpha=0.00541_real64
      nn=1.301528_real64; ks=0.895023_real64; lam=-0.334926_real64
    case default
      call require(.false.,'known TA3 material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=930301_int64
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
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'TA3 finite constitutive seed')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qt,qb)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qt,qb
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qb;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64;f%subsurface_irrigation_source=0.0_real64;f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=930301_int64;tmpl%physics_topology_id=930302_int64;tmpl%vertical_layout_id=930303_int64
    tmpl%state_layout_id=930304_int64;tmpl%solver_interface_id=930305_int64
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
      write(*,'(A,1X,A)') 'F_ROM0TA3_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_rom0ta3_reference_floor_sample
