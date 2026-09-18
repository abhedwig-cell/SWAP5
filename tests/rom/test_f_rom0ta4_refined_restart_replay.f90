program test_f_rom0ta4_refined_restart_replay
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
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: seed_dt=0.0016_real64
  integer, parameter :: seed_intervals=2
  real(real64), parameter :: perturb_dt=0.0008_real64
  integer, parameter :: perturb_intervals=16
  integer, parameter :: restart_split=8
  real(real64), parameter :: epsilon_fraction=0.01_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=940401_int64
  integer(int64), parameter :: parameter_set_identity=940499_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  character(len=12), parameter :: cases(2)=[character(len=12) :: 'TOP_PLUS','TOP_MINUS']

  integer :: imat,icase,case_count

  call require(numnod==16,'TA4 geometry frozen at 16 nodes')
  case_count=0
  do imat=1,size(materials)
    do icase=1,size(cases)
      call qualify_case(trim(materials(imat)),trim(cases(icase)))
      case_count=case_count+1
    end do
  end do

  call require(case_count==4,'TA4 four-case matrix complete')
  write(*,'(A,I0)') 'F_ROM0TA4_CASES=',case_count
  write(*,'(A)') 'F_ROM0TA4_RESTART_REPLAY_GATE=PASS'

contains

  subroutine qualify_case(material_id,case_id)
    character(len=*),intent(in) :: material_id,case_id

    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_serialized_reference_backend_t) :: continuous_backend,split_backend,restarted_backend
    type(fixed_flux_top_boundary_provider_t),target :: continuous_top,split_top,restarted_top
    type(kernel_committed_state_t) :: continuous_states(1),split_states(1),restored_states(1),negative_states(1)
    type(fmr_logical_column_t) :: columns(1)
    type(fmr_template_t) :: templates(1)
    type(fmr_committed_restart_bundle_t) :: bundle
    real(real64) :: h0,k0,qeq,qtop,t0,t1
    real(real64) :: continuous_h(numnod,perturb_intervals)
    real(real64) :: continuous_theta(numnod,perturb_intervals)
    real(real64) :: continuous_pond(perturb_intervals)
    real(real64) :: continuous_gwl(perturb_intervals)
    real(real64) :: continuous_mass(perturb_intervals)
    real(real64) :: continuous_time(perturb_intervals)
    integer(int64) :: continuous_revision(perturb_intervals)
    integer(int64) :: continuous_lineage(perturb_intervals)
    integer :: i,status
    logical :: ok,exported,restored
    real(real64) :: restored_time
    logical :: time_available

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    select case(trim(case_id))
    case('TOP_PLUS')
      qtop=qeq+epsilon_fraction*k0
    case('TOP_MINUS')
      qtop=qeq-epsilon_fraction*k0
    case default
      call require(.false.,'known TA4 case')
    end select
    call initialize_forcing(forcing,qeq,qeq)
    call initialize_identity(columns(1),templates(1))

    ! Continuous authority trajectory.
    call fmr_new_b110_committed_state(continuous_states(1),column_id,initial_state,0.0_real64,ok)
    call require(ok,'continuous initial committed state')
    call continuous_backend%initialize(continuous_top)
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq
      forcing%bottom_flux=qeq
      call sample_commit(continuous_backend,columns(1),templates(1),parameters,continuous_states(1),forcing,t0,t1)
      t0=t1
    end do
    forcing%top_flux=qtop
    forcing%bottom_flux=qeq
    do i=1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_commit_record(continuous_backend,columns(1),templates(1),parameters,continuous_states(1),forcing,t0,t1, &
           merge(i>=restart_split,.true.,.false.),i,continuous_h,continuous_theta,continuous_pond,continuous_gwl, &
           continuous_mass,continuous_time,continuous_revision,continuous_lineage)
      t0=t1
    end do

    ! Fresh split trajectory through the preregistered restart point.
    call fmr_new_b110_committed_state(split_states(1),column_id,initial_state,0.0_real64,ok)
    call require(ok,'split initial committed state')
    call split_backend%initialize(split_top)
    t0=0.0_real64
    do i=1,seed_intervals
      t1=real(i,real64)*seed_dt
      forcing%top_flux=qeq
      forcing%bottom_flux=qeq
      call sample_commit(split_backend,columns(1),templates(1),parameters,split_states(1),forcing,t0,t1)
      t0=t1
    end do
    forcing%top_flux=qtop
    forcing%bottom_flux=qeq
    do i=1,restart_split
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_commit(split_backend,columns(1),templates(1),parameters,split_states(1),forcing,t0,t1)
      t0=t1
    end do

    call require(split_states(1)%current_lineage_id()==continuous_lineage(restart_split),'split lineage identity')
    call require(split_states(1)%current_revision()==continuous_revision(restart_split),'split revision identity')
    call split_states(1)%current_time(restored_time,time_available)
    call require(time_available.and.same_bits(restored_time,continuous_time(restart_split)),'split time bit identity')
    call compare_committed_to_reference(split_states(1),continuous_h(:,restart_split), &
         continuous_theta(:,restart_split),continuous_pond(restart_split), &
         continuous_gwl(restart_split),'split endpoint state identity')

    call fmr_export_committed_restart(columns,templates,split_states,parameter_set_identity,bundle,exported,status)
    call require(exported.and.status==FMR_RESTART_OK,'restart export')

    call fmr_restore_committed_restart(bundle,parameter_set_identity+1_int64,columns,templates,negative_states,restored,status)
    call require(.not.restored.and.status==FMR_RESTART_PARAMETER_SET_MISMATCH,'wrong parameter identity fails closed')
    call require(.not.negative_states(1)%ready(),'wrong parameter target remains uninitialized')
    write(*,'(*(g0))') 'F_ROM0TA4_NEGATIVE_RESTORE|MATERIAL=',trim(material_id),'|CASE=',trim(case_id),'|PASS=1'

    call fmr_restore_committed_restart(bundle,parameter_set_identity,columns,templates,restored_states,restored,status)
    call require(restored.and.status==FMR_RESTART_OK,'valid restart restore')
    call require(restored_states(1)%ready(),'restored committed ready')
    call require(restored_states(1)%current_lineage_id()==split_states(1)%current_lineage_id(),'restored lineage exact')
    call require(restored_states(1)%current_revision()==split_states(1)%current_revision(),'restored revision exact')
    call restored_states(1)%current_time(restored_time,time_available)
    call require(time_available.and.same_bits(restored_time,continuous_time(restart_split)),'restored time bit identity')

    ! Continue from fresh backend only. No solver/workspace state crosses restart.
    call restarted_backend%initialize(restarted_top)
    t0=restored_time
    do i=restart_split+1,perturb_intervals
      t1=real(seed_intervals,real64)*seed_dt+real(i,real64)*perturb_dt
      call sample_commit_compare(restarted_backend,columns(1),templates(1),parameters,restored_states(1),forcing,t0,t1,i, &
           continuous_h(:,i),continuous_theta(:,i),continuous_pond(i),continuous_gwl(i),continuous_mass(i), &
           continuous_time(i),continuous_revision(i),continuous_lineage(i))
      t0=t1
    end do

    write(*,'(*(g0))') 'F_ROM0TA4_CASE_PASS|MATERIAL=',trim(material_id),'|CASE=',trim(case_id), &
         '|DT=',perturb_dt,'|SPLIT=',restart_split,'|FINAL_REV=',restored_states(1)%current_revision()
  end subroutine qualify_case

  subroutine sample_commit(backend,column,template,parameters,committed,forcing,t0,t1)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: did_commit
    integer :: commit_status

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid,'sample valid')
    call require(candidate%ready(),'sample candidate ready')
    call require(result%physical_advances==1,'one physical advance')
    call require(result%internal_retries==0.and.diagnostics%retries==0,'zero internal/transaction retries')
    call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'sample hard mass gate')
    call require(observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED,'Reference solver converged')
    call require(same_bits(result%accepted_dt,t1-t0),'accepted dt bit identity')
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'one sample commit')
    call require(.not.candidate%ready(),'candidate consumed')
  end subroutine sample_commit

  subroutine sample_commit_record(backend,column,template,parameters,committed,forcing,t0,t1,record,step, &
       h_store,theta_store,pond_store,gwl_store,mass_store,time_store,rev_store,lineage_store)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    logical,intent(in) :: record
    integer,intent(in) :: step
    real(real64),intent(inout) :: h_store(:,:),theta_store(:,:),pond_store(:),gwl_store(:),mass_store(:),time_store(:)
    integer(int64),intent(inout) :: rev_store(:),lineage_store(:)
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    class(transaction_state_t),allocatable :: snap
    logical :: did_commit,got,time_ok
    integer :: commit_status
    real(real64) :: tt

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid,'record sample valid')
    call require(result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0,'record one no-retry')
    call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'record mass')
    call require(observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED,'record solver converged')
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'record commit')

    if(record) then
      call committed%snapshot(snap,got)
      call require(got,'record committed snapshot')
      select type(physical=>snap)
      type is(fmr_b110_physical_state_t)
        h_store(:,step)=physical%pressure_head
        theta_store(:,step)=physical%water_content
        pond_store(step)=physical%ponding_depth
        gwl_store(step)=physical%groundwater_level
      class default
        error stop 'F_ROM0TA4_FAIL unexpected record state'
      end select
      mass_store(step)=result%mass%residual
      call committed%current_time(tt,time_ok)
      call require(time_ok,'record committed time')
      time_store(step)=tt
      rev_store(step)=committed%current_revision()
      lineage_store(step)=committed%current_lineage_id()
      if(allocated(snap)) deallocate(snap)
    end if
  end subroutine sample_commit_record

  subroutine sample_commit_compare(backend,column,template,parameters,committed,forcing,t0,t1,step, &
       expected_h,expected_theta,expected_pond,expected_gwl,expected_mass,expected_time,expected_rev,expected_lineage)
    type(fmr_serialized_reference_backend_t),intent(inout) :: backend
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(kernel_committed_state_t),intent(inout) :: committed
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    real(real64),intent(in) :: t0,t1
    integer,intent(in) :: step
    real(real64),intent(in) :: expected_h(:),expected_theta(:),expected_pond,expected_gwl,expected_mass,expected_time
    integer(int64),intent(in) :: expected_rev,expected_lineage
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    class(transaction_state_t),allocatable :: snap
    logical :: did_commit,got,time_ok
    integer :: commit_status
    real(real64) :: tt

    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,t0,t1,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()
    call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid,'replay sample valid')
    call require(result%physical_advances==1.and.result%internal_retries==0.and.diagnostics%retries==0,'replay one no-retry')
    call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'replay hard mass')
    call require(observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED,'replay solver converged')
    call require(same_bits(result%mass%residual,expected_mass),'replay mass residual bit identity')
    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'replay commit')
    call require(committed%current_lineage_id()==expected_lineage,'replay lineage identity')
    call require(committed%current_revision()==expected_rev,'replay revision identity')
    call committed%current_time(tt,time_ok)
    call require(time_ok.and.same_bits(tt,expected_time),'replay committed time bit identity')
    call committed%snapshot(snap,got)
    call require(got,'replay snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      call require(all_same_bits(physical%pressure_head,expected_h),'replay h profile bit identity')
      call require(all_same_bits(physical%water_content,expected_theta),'replay theta profile bit identity')
      call require(same_bits(physical%ponding_depth,expected_pond),'replay ponding bit identity')
      call require(same_bits(physical%groundwater_level,expected_gwl),'replay groundwater level bit identity')
    class default
      error stop 'F_ROM0TA4_FAIL unexpected replay state'
    end select
    if(allocated(snap)) deallocate(snap)
    write(*,'(*(g0))') 'F_ROM0TA4_REPLAY_POINT|STEP=',step,'|T=',tt,'|REV=',expected_rev,'|MASS=',expected_mass
  end subroutine sample_commit_compare

  subroutine compare_committed_to_reference(committed,expected_h,expected_theta,expected_pond,expected_gwl,label)
    type(kernel_committed_state_t),intent(in) :: committed
    real(real64),intent(in) :: expected_h(:),expected_theta(:),expected_pond,expected_gwl
    character(len=*),intent(in) :: label
    class(transaction_state_t),allocatable :: snap
    logical :: got
    call committed%snapshot(snap,got)
    call require(got,trim(label)//' snapshot')
    select type(physical=>snap)
    type is(fmr_b110_physical_state_t)
      call require(all_same_bits(physical%pressure_head,expected_h),trim(label)//' h')
      call require(all_same_bits(physical%water_content,expected_theta),trim(label)//' theta')
      call require(same_bits(physical%ponding_depth,expected_pond),trim(label)//' pond')
      call require(same_bits(physical%groundwater_level,expected_gwl),trim(label)//' gwl')
    class default
      error stop 'F_ROM0TA4_FAIL unexpected compare state'
    end select
    if(allocated(snap)) deallocate(snap)
  end subroutine compare_committed_to_reference

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
      call require(.false.,'known TA4 material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=940401_int64
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
    tmpl%template_id=940401_int64;tmpl%physics_topology_id=940402_int64;tmpl%vertical_layout_id=940403_int64
    tmpl%state_layout_id=940404_int64;tmpl%solver_interface_id=940405_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  pure logical function all_same_bits(a,b)
    real(real64),intent(in) :: a(:),b(:)
    integer :: i
    all_same_bits=size(a)==size(b)
    if(.not.all_same_bits) return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i))) then
        all_same_bits=.false.
        return
      end if
    end do
  end function all_same_bits

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0TA4_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0ta4_refined_restart_replay
