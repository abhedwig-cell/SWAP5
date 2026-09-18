program test_f_rom0t1_temporal_reference_floor
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
  real(real64), parameter :: dt_values(2)=[0.0016_real64,0.0008_real64]
  real(real64), parameter :: horizon=0.0512_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=966101_int64
  character(len=24), parameter :: case_ids(4)=[character(len=24) :: 'B01_E1_NOMINAL_FLUX','B01_E2_DRYING_FLUX', &
       'B14_E1_NOMINAL_FLUX','B14_E2_DRYING_FLUX']
  character(len=8), parameter :: material_ids(4)=[character(len=8) :: 'B01','B01','B14','B14']
  real(real64), parameter :: qtop_factor(4)=[0.01_real64,-0.005_real64,0.01_real64,-0.005_real64]
  real(real64), parameter :: qbot_factor(4)=[-0.004_real64,-0.019_real64,-0.004_real64,-0.019_real64]
  integer :: icase,idt

  call require(numnod==16,'T1 geometry node count is 16')
  call require(abs(sum(dz(1:numnod))-160.0_real64)<=1.0e-12_real64,'geometry depth 160 cm')
  call require(maxval(abs(dz(1:numnod)-10.0_real64))<=1.0e-12_real64,'T1 dz 10 cm')

  do icase=1,4
    do idt=1,2
      call run_case(trim(case_ids(icase)),trim(material_ids(icase)),qtop_factor(icase),qbot_factor(icase),dt_values(idt))
    end do
  end do

  write(*,'(A,I0)') 'F_ROM0T1_GEOMETRY_NODES=',numnod
  write(*,'(A)') 'F_ROM0T1_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_case(case_id,material_id,top_factor,bottom_factor,step_dt)
    character(len=*),intent(in) :: case_id,material_id
    real(real64),intent(in) :: top_factor,bottom_factor,step_dt
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(kernel_committed_state_t) :: committed
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qtop,qbot,t0,t1
    real(real64) :: mass,bex,bflux,total_storage,upper_storage,lower_storage
    real(real64) :: cumulative_bottom,cumulative_top,max_mass
    integer :: i,nsteps,status,nl,ir,back,nl_min,nl_max,back_min,back_max
    character(len=96) :: route
    logical :: ok

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,step_dt,h0,k0,initial_state)
    qtop=top_factor*k0
    qbot=bottom_factor*k0
    call initialize_forcing(forcing,qtop,qbot,h0)
    call initialize_identity(column,template)
    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),'initial committed state')

    parameters%bottom_mode=2
    parameters%compartment_balance_tolerance=1.0e-12_real64
    parameters%head_abs_tolerance=1.0e-12_real64
    parameters%head_rel_tolerance=1.0e-12_real64
    parameters%ponding_tolerance=1.0e-12_real64
    parameters%max_iterations=16
    parameters%max_backtracking=8
    parameters%swkimpl=0
    parameters%swkmean=1

    nsteps=nint(horizon/step_dt)
    call require(nsteps>0.and.abs(real(nsteps,real64)*step_dt-horizon)<=1.0e-15_real64,'exact common horizon')
    cumulative_bottom=0.0_real64
    cumulative_top=0.0_real64
    max_mass=0.0_real64
    nl_min=huge(0);nl_max=0;back_min=huge(0);back_max=0
    t0=0.0_real64

    write(*,'(*(g0))') 'F_ROM0T1_CASE_START|GEOM_N=',numnod,'|CASE=',trim(case_id),'|MATERIAL=',trim(material_id), &
         '|H0=',h0,'|K0=',k0,'|QTOP=',qtop,'|QBOT=',qbot,'|DT=',step_dt,'|STEPS=',nsteps

    do i=1,nsteps
      t1=real(i,real64)*step_dt
      call sample_fresh(column,template,parameters,committed,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
      if(.not.ok) then
        write(*,'(*(g0))') 'F_ROM0T1_CASE_FAIL|GEOM_N=',numnod,'|CASE=',trim(case_id),'|DT=',step_dt,'|STEP=',i, &
             '|T0=',t0,'|T1=',t1, &
             '|STATUS=',status,'|ROUTE=',trim(route),'|NL=',nl,'|IR=',ir,'|BACK=',back
        return
      end if

      cumulative_bottom=cumulative_bottom+bex
      cumulative_top=cumulative_top+qtop*(t1-t0)
      max_mass=max(max_mass,abs(mass))
      nl_min=min(nl_min,nl);nl_max=max(nl_max,nl)
      back_min=min(back_min,back);back_max=max(back_max,back)

      call verify_commit_progress(committed,i,t1)
      call state_metrics(committed,total_storage,upper_storage,lower_storage,ok)
      call require(ok,'state metrics')
      write(*,'(*(g0))') 'F_ROM0T1_STEP|GEOM_N=',numnod,'|CASE=',trim(case_id),'|DT=',step_dt,'|STEP=',i,'|T=',t1, &
           '|MASS=',mass, &
           '|TOTAL_STORAGE=',total_storage,'|UPPER_STORAGE=',upper_storage,'|LOWER_STORAGE=',lower_storage, &
           '|CUM_TOP=',cumulative_top,'|CUM_BOTTOM=',cumulative_bottom,'|BOTTOM_FLUX=',bflux,'|NL=',nl,'|BACK=',back
      call emit_nodes(committed,case_id,step_dt,i,t1)
      t0=t1
    end do

    call require(committed%current_revision()==int(nsteps,int64),'exact final revision')
    call require(abs(t0-horizon)<=1.0e-15_real64,'exact final horizon')
    write(*,'(*(g0))') 'F_ROM0T1_CASE_PASS|GEOM_N=',numnod,'|CASE=',trim(case_id),'|DT=',step_dt,'|STEPS=',nsteps, &
         '|FINAL_REV=',committed%current_revision(),'|FINAL_T=',t0,'|MAX_ABS_MASS=',max_mass, &
         '|NL_MIN=',nl_min,'|NL_MAX=',nl_max, &
         '|BACK_MIN=',back_min,'|BACK_MAX=',back_max,'|FINAL_CUM_TOP=',cumulative_top, &
         '|FINAL_CUM_BOTTOM=',cumulative_bottom
  end subroutine run_case

  subroutine sample_fresh(column,template,p,state,forcing,t0,t1,ok,mass,bex,bflux,status,route,nl,ir,back)
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass,bex,bflux
    integer,intent(out) :: status,nl,ir,back
    character(len=*),intent(out) :: route
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass=huge(0.0_real64);bex=0.0_real64;bflux=0.0_real64
    call backend%initialize(top)
    call backend%run_reference_floor_sample(column,template,p,state,forcing,t0,t1,hard_mass_gate,result,candidate,diagnostics)
    observation=backend%observation()
    status=observation%solver_status;route=trim(observation%solver_diagnostics%route)
    nl=result%nonlinear_iterations;ir=result%internal_retries;back=result%backtracking_attempts
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid.and.candidate%ready().and. &
       result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0.and. &
       result%mass%complete.and.ieee_is_finite(result%mass%residual).and.abs(result%mass%residual)<=hard_mass_gate.and. &
       observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED.and. &
       result%bottom_interface_exchange_available.and.ieee_is_finite(result%bottom_outward_exchange_native).and. &
       ieee_is_finite(result%terminal_bottom_outward_flux_native)
    if(.not.ok) then
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass=result%mass%residual;bex=result%bottom_outward_exchange_native;bflux=result%terminal_bottom_outward_flux_native
    call backend%commit_reference_floor_candidate(state,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED.and..not.candidate%ready()
  end subroutine sample_fresh

  subroutine verify_commit_progress(state,step,expected_time)
    type(kernel_committed_state_t),intent(in) :: state
    integer,intent(in) :: step
    real(real64),intent(in) :: expected_time
    real(real64) :: committed_time
    logical :: time_ok
    integer(int64) :: a,b
    call require(state%current_revision()==int(step,int64),'committed revision progression')
    call state%current_time(committed_time,time_ok)
    call require(time_ok,'committed time available')
    a=transfer(committed_time,a);b=transfer(expected_time,b)
    call require(a==b,'committed time bit identity')
  end subroutine verify_commit_progress

  subroutine state_metrics(state,total,upper,lower,ok)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: total,upper,lower
    logical,intent(out) :: ok
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: nupper
    total=0.0_real64;upper=0.0_real64;lower=0.0_real64;ok=.false.
    call state%snapshot(snap,got);if(.not.got)return
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      nupper=numnod/4
      total=sum(physical%water_content(1:numnod)*dz(1:numnod))
      upper=sum(physical%water_content(1:nupper)*dz(1:nupper))
      lower=sum(physical%water_content(nupper+1:numnod)*dz(nupper+1:numnod))
      ok=ieee_is_finite(total).and.ieee_is_finite(upper).and.ieee_is_finite(lower)
    class default
      ok=.false.
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine state_metrics

  subroutine emit_nodes(state,case_id,step_dt,step,time)
    type(kernel_committed_state_t),intent(in) :: state
    character(len=*),intent(in) :: case_id
    real(real64),intent(in) :: step_dt
    integer,intent(in) :: step
    real(real64),intent(in) :: time
    class(transaction_state_t),allocatable :: snap
    logical :: got
    integer :: i
    call state%snapshot(snap,got);call require(got,'node snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      do i=1,numnod
        write(*,'(*(g0))') 'F_ROM0T1_NODE|GEOM_N=',numnod,'|CASE=',trim(case_id),'|DT=',step_dt,'|STEP=',step,'|T=',time, &
             '|NODE=',i,'|Z=',z(i),'|DZ=',dz(i),'|H=',physical%pressure_head(i),'|THETA=',physical%water_content(i)
      end do
    class default
      call require(.false.,'B110 node snapshot')
    end select
    if(allocated(snap))deallocate(snap)
  end subroutine emit_nodes

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
      call require(.false.,'known ROM0V1 material');tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=965101_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha;p%cofgen(5,k)=lam;p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha;p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
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

  subroutine initialize_state(p,step_dt,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(in) :: step_dt
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,step_dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'finite initial state')
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
    tmpl%template_id=966101_int64;tmpl%physics_topology_id=966201_int64
    tmpl%vertical_layout_id=966301_int64;tmpl%state_layout_id=966401_int64
    tmpl%solver_interface_id=966501_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition)then
      write(*,'(A,1X,A)') 'F_ROM0T1_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0t1_temporal_reference_floor
