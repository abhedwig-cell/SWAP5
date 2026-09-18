program test_f_rom0ta4_restart_replay
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
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_PARAMETER_SET_MISMATCH
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  integer, parameter :: split_step=8
  real(real64), parameter :: epsilon_fraction=0.01_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: parameter_set_identity=930400_int64
  integer(int64), parameter :: column_id=930401_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=12), parameter :: cases(2)=[character(len=12) :: 'TOP_PLUS','TOP_MINUS']

  integer :: imat,icase,case_failures,case_count

  call require(numnod==16,'TA4 geometry frozen at 16 nodes')
  case_failures=0
  case_count=0
  do imat=1,size(materials)
    do icase=1,size(cases)
      case_count=case_count+1
      call run_case(trim(materials(imat)),trim(cases(icase)),case_failures)
    end do
  end do
  call require(case_count==4,'TA4 complete case matrix attempted')
  write(*,'(*(g0))') 'F_ROM0TA4_MATRIX|CASES=',case_count,'|FAILURES=',case_failures
  write(*,'(A)') 'F_ROM0TA4_EXECUTION_COMPLETE=PASS'

contains

  subroutine run_case(material_id,case_id,failures)
    character(len=*),intent(in) :: material_id,case_id
    integer,intent(inout) :: failures

    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(kernel_committed_state_t) :: continuous_states(1), split_states(1), restored_states(1), bad_states(1)
    type(fmr_serialized_reference_backend_t) :: backend_cont, backend_pre, backend_post
    type(fixed_flux_top_boundary_provider_t), target :: top_boundary_cont, top_boundary_pre, top_boundary_post
    type(fmr_committed_restart_bundle_t) :: bundle
    real(real64) :: h0,k0,qeq,qtop
    real(real64) :: ref_h(numnod,perturb_intervals),ref_theta(numnod,perturb_intervals)
    real(real64) :: ref_pond(perturb_intervals),ref_gwl(perturb_intervals)
    real(real64) :: ref_mass(perturb_intervals),ref_top_exchange(perturb_intervals),ref_bottom_exchange(perturb_intervals)
    real(real64) :: ref_time(perturb_intervals)
    integer(int64) :: ref_revision(perturb_intervals)
    integer :: i,restart_status
    logical :: ok,exported,restored,step_ok,identity_ok

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    if(trim(case_id)=='TOP_PLUS') then
      qtop=qeq+epsilon_fraction*k0
    else if(trim(case_id)=='TOP_MINUS') then
      qtop=qeq-epsilon_fraction*k0
    else
      call require(.false.,'TA4 known perturbation case')
    end if
    call initialize_forcing(forcing,qeq,qeq)
    call initialize_identity(columns(1),templates(1))

    write(*,'(*(g0))') 'F_ROM0TA4_CASE_START|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',perturb_dt,'|SPLIT_STEP=',split_step,'|QEQ=',qeq,'|QTOP=',qtop

    call fmr_new_b110_committed_state(continuous_states(1),column_id,initial_state,0.0_real64,ok)
    call require(ok,'TA4 continuous state initialized')
    call backend_cont%initialize(top_boundary_cont)
    call run_seed(backend_cont,continuous_states(1),columns(1),templates(1),parameters,forcing,qeq,step_ok)
    if(.not.step_ok) then
      failures=failures+1
      write(*,'(*(g0))') 'F_ROM0TA4_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|PHASE=CONT_SEED'
      return
    end if
    forcing%top_flux=qtop;forcing%bottom_flux=qeq
    do i=1,perturb_intervals
      call execute_sample(backend_cont,continuous_states(1),columns(1),templates(1),parameters,forcing, &
           perturb_t0(i),perturb_t1(i),step_ok,ref_mass(i),ref_top_exchange(i),ref_bottom_exchange(i))
      if(.not.step_ok) then
        failures=failures+1
        write(*,'(*(g0))') 'F_ROM0TA4_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|PHASE=CONT_PERT|STEP=',i
        return
      end if
      call capture_reference_endpoint(continuous_states(1),ref_h(:,i),ref_theta(:,i),ref_pond(i),ref_gwl(i), &
           ref_revision(i),ref_time(i))
    end do

    call fmr_new_b110_committed_state(split_states(1),column_id,initial_state,0.0_real64,ok)
    call require(ok,'TA4 split state initialized')
    call backend_pre%initialize(top_boundary_pre)
    forcing%top_flux=qeq;forcing%bottom_flux=qeq
    call run_seed(backend_pre,split_states(1),columns(1),templates(1),parameters,forcing,qeq,step_ok)
    if(.not.step_ok) then
      failures=failures+1
      write(*,'(*(g0))') 'F_ROM0TA4_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|PHASE=SPLIT_SEED'
      return
    end if

    forcing%top_flux=qtop;forcing%bottom_flux=qeq
    do i=1,split_step
      call execute_and_compare(backend_pre,split_states(1),columns(1),templates(1),parameters,forcing,i, &
           ref_h(:,i),ref_theta(:,i),ref_pond(i),ref_gwl(i),ref_revision(i),ref_time(i), &
           ref_mass(i),ref_top_exchange(i),ref_bottom_exchange(i),step_ok,identity_ok)
      if(.not.step_ok .or. .not.identity_ok) then
        failures=failures+1
        write(*,'(*(g0))') 'F_ROM0TA4_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|PHASE=PRE_RESTART|STEP=',i,'|STEP_OK=',step_ok,'|IDENTITY_OK=',identity_ok
        return
      end if
    end do

    call fmr_export_committed_restart(columns,templates,split_states,parameter_set_identity,bundle,exported,restart_status)
    call require(exported .and. restart_status==FMR_RESTART_OK,'TA4 restart export')

    call fmr_restore_committed_restart(bundle,parameter_set_identity+1_int64,columns,templates,bad_states,restored,restart_status)
    call require(.not.restored .and. restart_status==FMR_RESTART_PARAMETER_SET_MISMATCH, &
         'TA4 wrong parameter identity rejected')
    call require(.not.bad_states(1)%ready(),'TA4 wrong-identity restore atomic')

    call fmr_restore_committed_restart(bundle,parameter_set_identity,columns,templates,restored_states,restored,restart_status)
    call require(restored .and. restart_status==FMR_RESTART_OK,'TA4 correct restart restore')
    call require(restored_states(1)%current_lineage_id()==split_states(1)%current_lineage_id(),'TA4 restored lineage')
    call require(restored_states(1)%current_revision()==split_states(1)%current_revision(),'TA4 restored revision')
    call require(committed_time_bits_equal(restored_states(1),split_states(1)),'TA4 restored committed time')

    write(*,'(*(g0))') 'F_ROM0TA4_RESTART|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|REV=',restored_states(1)%current_revision(),'|LINEAGE=',restored_states(1)%current_lineage_id(), &
         '|NEGATIVE_PARAMETER_ID_CONTROL=PASS'

    call backend_post%initialize(top_boundary_post)
    do i=split_step+1,perturb_intervals
      call execute_and_compare(backend_post,restored_states(1),columns(1),templates(1),parameters,forcing,i, &
           ref_h(:,i),ref_theta(:,i),ref_pond(i),ref_gwl(i),ref_revision(i),ref_time(i), &
           ref_mass(i),ref_top_exchange(i),ref_bottom_exchange(i),step_ok,identity_ok)
      if(.not.step_ok .or. .not.identity_ok) then
        failures=failures+1
        write(*,'(*(g0))') 'F_ROM0TA4_CASE_FAIL|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
             '|PHASE=POST_RESTART|STEP=',i,'|STEP_OK=',step_ok,'|IDENTITY_OK=',identity_ok
        return
      end if
    end do

    write(*,'(*(g0))') 'F_ROM0TA4_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',perturb_dt,'|FINAL_REV=',restored_states(1)%current_revision()
  end subroutine run_case

  subroutine run_seed(backend,state,column,template,parameters,forcing,qeq,ok)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(inout) :: forcing
    real(real64),intent(in) :: qeq
    logical,intent(out) :: ok
    integer :: i
    real(real64) :: mass,te,be
    forcing%top_flux=qeq;forcing%bottom_flux=qeq
    ok=.true.
    do i=1,seed_intervals
      call execute_sample(backend,state,column,template,parameters,forcing,real(i-1,real64)*seed_dt, &
           real(i,real64)*seed_dt,ok,mass,te,be)
      if(.not.ok) return
    end do
  end subroutine run_seed

  subroutine execute_and_compare(backend,state,column,template,parameters,forcing,step,h_ref,theta_ref,pond_ref,gwl_ref, &
                                 rev_ref,time_ref,mass_ref,top_ref,bottom_ref,step_ok,identity_ok)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    integer,intent(in) :: step
    real(real64),intent(in) :: h_ref(:),theta_ref(:),pond_ref,gwl_ref,time_ref,mass_ref,top_ref,bottom_ref
    integer(int64),intent(in) :: rev_ref
    logical,intent(out) :: step_ok,identity_ok
    real(real64) :: mass,top_exchange,bottom_exchange
    class(transaction_state_t),allocatable :: snapshot
    logical :: got,time_available
    real(real64) :: time_value

    call execute_sample(backend,state,column,template,parameters,forcing,perturb_t0(step),perturb_t1(step), &
         step_ok,mass,top_exchange,bottom_exchange)
    identity_ok=.false.
    if(.not.step_ok) return
    if(state%current_revision()/=rev_ref) return
    call state%current_time(time_value,time_available)
    if(.not.time_available .or. .not.same_bits(time_value,time_ref)) return
    if(.not.same_bits(mass,mass_ref) .or. .not.same_bits(top_exchange,top_ref) .or. &
       .not.same_bits(bottom_exchange,bottom_ref)) return
    call state%snapshot(snapshot,got)
    if(.not.got) return
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      if(.not.array_bits_equal(physical%pressure_head,h_ref)) return
      if(.not.array_bits_equal(physical%water_content,theta_ref)) return
      if(.not.same_bits(physical%ponding_depth,pond_ref)) return
      if(.not.same_bits(physical%groundwater_level,gwl_ref)) return
    class default
      return
    end select
    identity_ok=.true.
    write(*,'(*(g0))') 'F_ROM0TA4_ENDPOINT_IDENTITY|STEP=',step,'|T=',time_value,'|REV=',state%current_revision(), &
         '|MASS_RES=',mass,'|TOP_EXCHANGE=',top_exchange,'|BOTTOM_EXCHANGE=',bottom_exchange,'|PASS=1'
  end subroutine execute_and_compare

  subroutine execute_sample(backend,state,column,template,parameters,forcing,t0,t1,ok,mass_residual,top_exchange,bottom_exchange)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(kernel_committed_state_t),intent(inout) :: state
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(out) :: ok
    real(real64),intent(out) :: mass_residual,top_exchange,bottom_exchange
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    mass_residual=huge(0.0_real64);top_exchange=0.0_real64;bottom_exchange=0.0_real64
    call backend%run_reference_floor_sample(column,template,parameters,state,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    ok=result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK .and. result%sample_valid .and. candidate%ready() .and. &
       result%physical_advances==1 .and. result%internal_retries==0 .and. result%mass%complete .and. &
       abs(result%mass%residual)<=hard_mass_gate
    if(.not.ok) then
      write(*,'(*(g0))') 'F_ROM0TA4_SAMPLE_FAIL|T0=',t0,'|T1=',t1,'|STATUS=',result%status, &
           '|SOLVER_STATUS=',observation%solver_status,'|ROUTE=',trim(observation%solver_diagnostics%route), &
           '|NL=',result%nonlinear_iterations,'|INTERNAL_RETRIES=',result%internal_retries
      if(candidate%ready()) call backend%discard_reference_floor_candidate(candidate,diagnostics)
      return
    end if
    mass_residual=result%mass%residual
    top_exchange=observation%top_flux*(t1-t0)
    call require(result%bottom_interface_exchange_available,'TA4 bottom exchange available')
    bottom_exchange=result%bottom_outward_exchange_native
    call backend%commit_reference_floor_candidate(state,candidate,diagnostics,did_commit,commit_status)
    ok=did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED
  end subroutine execute_sample

  subroutine capture_reference_endpoint(state,h,theta,pond,gwl,revision,time_value)
    type(kernel_committed_state_t),intent(in) :: state
    real(real64),intent(out) :: h(:),theta(:),pond,gwl,time_value
    integer(int64),intent(out) :: revision
    class(transaction_state_t),allocatable :: snapshot
    logical :: got,time_available
    call state%snapshot(snapshot,got)
    call require(got,'TA4 continuous snapshot')
    select type(physical=>snapshot)
    type is(fmr_b110_physical_state_t)
      h=physical%pressure_head;theta=physical%water_content
      pond=physical%ponding_depth;gwl=physical%groundwater_level
    class default
      error stop 'F_ROM0TA4_FAIL unexpected state type'
    end select
    revision=state%current_revision()
    call state%current_time(time_value,time_available)
    call require(time_available,'TA4 continuous committed time')
  end subroutine capture_reference_endpoint

  pure real(real64) function perturb_t0(step) result(t)
    integer,intent(in) :: step
    t=real(seed_intervals,real64)*seed_dt+real(step-1,real64)*perturb_dt
  end function perturb_t0

  pure real(real64) function perturb_t1(step) result(t)
    integer,intent(in) :: step
    t=real(seed_intervals,real64)*seed_dt+real(step,real64)*perturb_dt
  end function perturb_t1

  logical function committed_time_bits_equal(a,b) result(equal)
    type(kernel_committed_state_t),intent(in) :: a,b
    real(real64) :: ta,tb
    logical :: aa,ab
    call a%current_time(ta,aa);call b%current_time(tb,ab)
    equal=aa .and. ab .and. same_bits(ta,tb)
  end function committed_time_bits_equal

  logical function array_bits_equal(a,b) result(equal)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if(.not.equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i))) then
        equal=.false.;return
      end if
    end do
  end function array_bits_equal

  logical function same_bits(a,b) result(equal)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

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
      call require(.false.,'TA4 known material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=930401_int64;p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha;p%cofgen(5,k)=lam;p%cofgen(6,k)=nn
      p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha;p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
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
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'TA4 finite seed')
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
    tmpl%template_id=930401_int64;tmpl%physics_topology_id=930402_int64;tmpl%vertical_layout_id=930403_int64
    tmpl%state_layout_id=930404_int64;tmpl%solver_interface_id=930405_int64
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
      write(*,'(A,1X,A)') 'F_ROM0TA4_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_rom0ta4_restart_replay
