program test_gc_rootzone_memory_rzm06e03c_expand
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: dt=3435974.0_real64/4294967296.0_real64
  real(real64), parameter :: mass_gate=1.0e-12_real64
  integer, parameter :: closed_steps=10
  integer, parameter :: n_half(7)=[12,14,16,18,20,22,24]
  integer, parameter :: n_quarter(7)=[24,28,32,36,40,44,48]
  integer(int64), parameter :: lineage_base=960705_int64

  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  real(real64) :: h0,k0,qeq
  integer :: j
  character(len=24) :: label

  call require(numnod==16,'E03C geometry node count')
  call require(all(abs(dz-10.0_real64)<=1.0e-14_real64),'E03C geometry dz')
  call require(same_bits(dt,3435974.0_real64/4294967296.0_real64),'E03C dyadic dt')
  call initialize_parameters(parameters)
  call initialize_state(parameters,h0,k0,initial_state)
  qeq=-k0
  call initialize_identity(column,template)

  write(*,'(*(g0))') 'RZM06E03C_CONFIG|N=',numnod,'|DZ_CM=',dz(1),'|DT_DAY=',dt, &
       '|K0=',k0,'|QEQ=',qeq,'|CLOSED_STEPS=',closed_steps

  call run_baseline(parameters,initial_state,column,template,lineage_base,qeq)

  do j=1,size(n_half)
    write(label,'("H_N",I2.2)') n_half(j)
    call run_gentle(trim(label),0.5_real64,n_half(j),parameters,initial_state,column,template, &
         lineage_base+int(j,int64),qeq)
  end do
  do j=1,size(n_quarter)
    write(label,'("Q_N",I2.2)') n_quarter(j)
    call run_gentle(trim(label),0.25_real64,n_quarter(j),parameters,initial_state,column,template, &
         lineage_base+int(size(n_half)+j,int64),qeq)
  end do

  write(*,'(A)') 'GC_RZM06E03C_GENTLE_BOTTOM_FIRST_GENERATION=PASS'

contains

  subroutine run_baseline(p,origin,col,tmpl,lineage,q)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_state_t),intent(in) :: origin
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    integer(int64),intent(in) :: lineage
    real(real64),intent(in) :: q
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    integer :: committed_steps
    logical :: ok,completed

    call fmr_new_b110_committed_state(committed,lineage,origin,0.0_real64,ok)
    call require(ok.and.committed%ready(),'BASE_EQ committed seed')
    call backend%initialize(top)
    committed_steps=0
    call run_segment('BASE_EQ','CONTROL',1,q,q,1.0_real64,p,committed,backend,col,tmpl,committed_steps,completed)
    call require(completed,'BASE_EQ completion')
    call emit_candidate('BASE_EQ',1.0_real64,1,committed_steps,committed)
  end subroutine run_baseline

  subroutine run_gentle(label,fraction,n,p,origin,col,tmpl,lineage,qeq_in)
    character(len=*),intent(in) :: label
    real(real64),intent(in) :: fraction,qeq_in
    integer,intent(in) :: n
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(fmr_b110_physical_state_t),intent(in) :: origin
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    integer(int64),intent(in) :: lineage
    type(kernel_committed_state_t) :: committed
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top
    integer :: committed_steps
    logical :: ok,completed
    real(real64) :: q

    q=fraction*qeq_in
    call fmr_new_b110_committed_state(committed,lineage,origin,0.0_real64,ok)
    call require(ok.and.committed%ready(),trim(label)//' committed seed')
    call backend%initialize(top)
    committed_steps=0

    call run_segment(label,'CLOSED',closed_steps,0.0_real64,0.0_real64,fraction,p,committed,backend, &
         col,tmpl,committed_steps,completed)
    if(.not.completed) return
    call run_segment(label,'BOTTOM',n,0.0_real64,q,fraction,p,committed,backend,col,tmpl,committed_steps,completed)
    if(.not.completed) return
    call run_segment(label,'TOP',n,q,0.0_real64,fraction,p,committed,backend,col,tmpl,committed_steps,completed)
    if(.not.completed) return
    call emit_candidate(label,fraction,n,committed_steps,committed)
  end subroutine run_gentle

  subroutine run_segment(label,phase,nsteps,qtop,qbottom,fraction,p,committed,backend,col,tmpl,committed_steps,completed)
    character(len=*),intent(in) :: label,phase
    integer,intent(in) :: nsteps
    real(real64),intent(in) :: qtop,qbottom,fraction
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: col
    type(fmr_template_t),intent(in) :: tmpl
    integer,intent(inout) :: committed_steps
    logical,intent(out) :: completed

    type(fmr_b110_physical_forcing_t) :: forcing
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diag
    class(transaction_state_t),allocatable :: before,after
    real(real64) :: t0,t1,tcur,cumulative_bottom
    integer :: phase_step,commit_status
    logical :: available,did_commit

    completed=.false.
    call initialize_forcing(forcing,qtop,qbottom)

    do phase_step=1,nsteps
      call committed%current_time(t0,available)
      call require(available,trim(label)//' current time')
      t1=t0+dt
      call require(same_bits(t1-t0,dt),trim(label)//' binary duration')
      call committed%snapshot(before,available)
      call require(available,trim(label)//' before snapshot')
      call backend%run_reference_floor_sample(col,tmpl,p,committed,forcing,t0,t1,mass_gate,result,candidate,diag)

      if(result%status/=KERNEL_REFERENCE_FLOOR_STATUS_OK .or. .not.result%sample_valid .or. .not.candidate%ready() .or. &
           .not.result%mass%complete .or. abs(result%mass%residual)>mass_gate) then
        call committed%snapshot(after,available)
        call require(available.and.state_bits_equal(before,after),trim(label)//' failed sample origin immutable')
        call require(committed%current_revision()==int(committed_steps,int64),trim(label)//' failed revision immutable')
        cumulative_bottom=0.0_real64
        if(trim(phase)=='BOTTOM') cumulative_bottom=abs(qbottom)*dt*real(phase_step-1,real64)
        write(*,'(*(g0))') 'RZM06E03C_STOP|FAMILY=',trim(label),'|PHASE=',trim(phase), &
             '|RATE_FRACTION=',fraction,'|PHASE_STEP=',phase_step,'|COMMITTED_STEPS=',committed_steps, &
             '|CUM_BOTTOM_CM=',cumulative_bottom,'|STATUS=',result%status,'|SAMPLE_VALID=',result%sample_valid, &
             '|CANDIDATE_READY=',candidate%ready(),'|MASS_COMPLETE=',result%mass%complete, &
             '|SOLVER_REJECTIONS=',diag%solver_rejections,'|MASS_REJECTIONS=',diag%mass_rejections
        return
      end if

      call require(result%physical_advances==1,trim(label)//' one physical advance')
      call require(result%internal_retries==0,trim(label)//' zero internal retries')
      call require(diag%retries==0,trim(label)//' zero transaction retries')
      call require(same_bits(result%accepted_dt,dt),trim(label)//' accepted dt')
      call backend%commit_reference_floor_candidate(committed,candidate,diag,did_commit,commit_status)
      call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,trim(label)//' commit')
      committed_steps=committed_steps+1
      call require(committed%current_revision()==int(committed_steps,int64),trim(label)//' revision progression')
      call committed%current_time(tcur,available)
      call require(available.and.same_bits(tcur,t1),trim(label)//' time progression')
    end do
    completed=.true.
  end subroutine run_segment

  subroutine emit_candidate(label,fraction,n,steps,committed)
    character(len=*),intent(in) :: label
    real(real64),intent(in) :: fraction
    integer,intent(in) :: n,steps
    type(kernel_committed_state_t),intent(in) :: committed
    class(transaction_state_t),allocatable :: snapshot
    logical :: available
    real(real64) :: tcur
    integer :: i

    call committed%snapshot(snapshot,available)
    call require(available.and.allocated(snapshot),trim(label)//' final snapshot')
    call committed%current_time(tcur,available)
    call require(available,trim(label)//' final time')
    select type(s=>snapshot)
    class is(fmr_b110_physical_state_t)
      call require(s%active_nodes==numnod,trim(label)//' active nodes')
      write(*,'(*(g0))') 'RZM06E03C_CANDIDATE|FAMILY=',trim(label),'|RATE_FRACTION=',fraction, &
           '|N=',n,'|STEPS=',steps,'|T=',tcur
      do i=1,numnod
        write(*,'(*(g0))') 'RZM06E03C_NODE|FAMILY=',trim(label),'|NODE=',i, &
             '|H=',s%pressure_head(i),'|THETA=',s%water_content(i)
      end do
    class default
      call require(.false.,trim(label)//' final state type')
    end select
  end subroutine emit_candidate

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
    nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=960705_int64;p%active_nodes=numnod
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
    p%compartment_balance_tolerance=mass_gate;p%total_balance_tolerance=mass_gate
    p%head_abs_tolerance=mass_gate;p%head_rel_tolerance=mass_gate;p%ponding_tolerance=mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%black_evaporation_active=.false.;p%boesten_evaporation_active=.false.
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
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'E03C finite B01 seed')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qtop,qbottom)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qtop,qbottom
    f%top_flux=qtop;f%top_head=0.0_real64
    f%bottom_flux=qbottom;f%bottom_head=0.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=960705_int64;tmpl%physics_topology_id=960706_int64
    tmpl%vertical_layout_id=960707_int64;tmpl%state_layout_id=960708_int64
    tmpl%solver_interface_id=960709_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=lineage_base;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  logical function state_bits_equal(left,right) result(equal)
    class(transaction_state_t),allocatable,intent(in) :: left,right
    integer :: i
    equal=.false.
    if(.not.allocated(left).or..not.allocated(right))return
    select type(a=>left)
    class is(fmr_b110_physical_state_t)
      select type(b=>right)
      class is(fmr_b110_physical_state_t)
        if(a%active_nodes/=b%active_nodes)return
        do i=1,a%active_nodes
          if(.not.same_bits(a%pressure_head(i),b%pressure_head(i)))return
          if(.not.same_bits(a%water_content(i),b%water_content(i)))return
        end do
        if(.not.same_bits(a%ponding_depth,b%ponding_depth))return
        if(.not.same_bits(a%groundwater_level,b%groundwater_level))return
        equal=.true.
      end select
    end select
  end function state_bits_equal

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    integer(int64)::ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib);equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'GC_RZM06E03C_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_gc_rootzone_memory_rzm06e03c_expand
