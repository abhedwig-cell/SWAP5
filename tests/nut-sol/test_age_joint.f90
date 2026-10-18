program test_age_joint
  use iso_fortran_env,only:real64,int64
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend
  use mod_fmr_production_application_bootstrap
  use mod_kernel_transactions
  use mod_fixed_flux_top_boundary_provider
  use mod_b110_default_mvg_provider
  use MOD_grid,only:numnod,z,dz,disnod
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t
  use mod_fmr_b111_age_route
  use mod_fmr_b111_age_joint_application
  use mod_b111_surface_age_owner
  use mod_b111_surface_age_disk
  use mod_b111_age_triplet_disk
  use mod_age_joint_restart_file
  use historical_age_oracle
  use mod_solute_water_face_flux_reconstruction
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  real(real64),parameter::T0=0.0_real64,T1=1.0e-3_real64,HARD_MASS_GATE=1.0e-10_real64
  type(fmr_production_application_config_t)::cfg
  type(fmr_serialized_reference_backend_t)::backend,second
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::column
  type(kernel_committed_state_t)::water,other_water,initial_water,bad_water
  type(age_state_t)::solute,other_solute,initial_solute,bad_solute,rejected_solute
  type(age_joint_restart_t)::payload
  type(age_joint_result_t)::result,result2
  type(b111_age_tracer_substep_forcing_t)::p,pbad
  real(real64)::k,mass0,net_input
  integer::status,u
  logical::ok
  character(512)::mode,restart_path,endpoint_path
  call get_command_argument(1,mode);call get_command_argument(2,restart_path);call get_command_argument(3,endpoint_path)
  call initialize_application_config(cfg,-75.0_real64,k)
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  cfg%tiles(1)%base_forcing%top_flux=0.0_real64
  cfg%tiles(1)%base_forcing%bottom_flux=-0.1_real64
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=1.0e-4_real64
  cfg%tiles(1)%base_forcing%root_extraction_sink=1.0e-4_real64
  cfg%tiles(1)%parameters%root_extraction_active=.true.
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=1.0e-6_real64
  cfg%numerical%transaction%temporal_tolerance=0.0_real64
  cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=10000
  column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
  column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call parameters(p)
  call backend%initialize(top);call second%initialize(top)
  if(trim(mode)=='reject')then
    call read_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status)
    call require(status/=JOINT_OK,'invalid disk payload rejected')
    call require(.not.water%ready().and..not.solute%ready(),'disk rejection leaves both empty targets untouched')
    print '(A)','AGE_INVALID_DISK=PASS'
    stop
  end if
  if(trim(mode)=='resume')then
    call read_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status)
    call require(status==JOINT_OK,'fresh-process disk reconstruction')
    cfg%tiles(1)%base_forcing%bottom_flux=0.1_real64
    cfg%tiles(1)%base_forcing%drainage_flux_by_level=-1.0e-4_real64
    call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
         cfg%tiles(1)%base_forcing,cfg%numerical,solute,T1,2*T1,result)
    call require(result%status==JOINT_OK,'fresh-process physical joint continuation')
    call write_endpoint(trim(endpoint_path),water,solute)
    print '(A)','AGE_FRESH_PROCESS=PASS'
    stop
  end if
  call base_codec_contract()
  call initialize_owners(water,solute,p)
  initial_water=water;initial_solute=solute
  ! Chemical rejection after a successful hydraulic candidate rolls both back.
  pbad=p;pbad%dispersivity_cm=1.0e4_real64;pbad%molecular_diffusion_cm2_day=1.0e6_real64
  call initialize_age(pbad,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
       [(1.0_real64+1.0_real64*u,u=1,numnod)],bad_solute,status)
  bad_water=water
  rejected_solute=bad_solute
  call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,T0,T1,result)
  if(result%status/=JOINT_CHEMICAL_REJECTED)print *,'overdraw diagnostics',result%status,result%chemical%status,result%chemical%process_status
  call require(result%status==JOINT_CHEMICAL_REJECTED,'chemical overdraw rejects successful water trial')
  call require(bad_water%current_revision()==water%current_revision(),'no water commit on chemical rejection')
  call compare_water(water,bad_water)
  call compare_chemical(rejected_solute,bad_solute)
  call require(age_joint_states_match(bad_water,bad_solute),'failed joint attempt preserves clocks')
  call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,T0,1.0e-9_real64,result)
  call require(result%status==JOINT_OK,'smaller joint retry succeeds')
  ! Hydraulic failure does not execute or mutate chemistry.
  block
    type(fmr_b110_physical_forcing_t)::invalid
    invalid=cfg%tiles(1)%base_forcing
    invalid%root_extraction_sink=-1.0_real64
    call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
         invalid,cfg%numerical,solute,T0,T1,result)
    call require(result%status/=JOINT_OK,'invalid hydraulic input rejects joint attempt')
    call compare_water(water,initial_water);call compare_chemical(solute,initial_solute)
  end block
  call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,solute,T0,T1,result)
  if(result%status/=0)print *,'joint diagnostics',result%status,result%chemical%status,result%water%status
  call require(result%status==JOINT_OK,'normal joint physical route')
  call verify_actual_trace(initial_solute,solute)
  mass0=result%chemical%amount_before
  net_input=result%chemical%external_in+result%chemical%production-result%chemical%external_out
  call require(abs(result%chemical%residual)<1.0e-11_real64,'first joint chemical balance')
  call require(age_joint_states_match(water,solute),'joint accepted carrier clock and state')
  call export_age_joint_restart(column,cfg%tiles(1)%template,670001_int64,water,solute,payload,status)
  call require(status==JOINT_OK,'joint opaque restart export')
  call restore_age_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9002_int64, &
       other_water,other_solute,status)
  call require(status/=0.and..not.other_water%ready().and..not.other_solute%ready(),'wrong chemical identity restores neither')
  call restore_age_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9001_int64, &
       other_water,other_solute,status)
  call require(status==0,'joint opaque restart restore')
  call compare_water(water,other_water);call compare_chemical(solute,other_solute)
  call write_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,water,solute,status)
  call require(status==JOINT_OK,'production joint disk writer')
  ! Candidate composite-reader fixture on actual accepted Reference water and
  ! actual age state. Dry surface is a bounded test, NOT positive-pond admission.
  block
    type(surface_age_owner_t)::original_surface,restored_surface
    type(kernel_committed_state_t)::restored_water
    type(age_state_t)::restored_soil
    integer::code
    call initialize_surface_age_owner(8801_int64,T1,0.0_real64,0.0_real64,original_surface,code)
    call require(code==AGE_OWNER_OK,'surface age zero pond initialize')
    call write_surface_age_disk(trim(restart_path)//'.surface',8801_int64,original_surface,code)
    call require(code==AGE_DISK_OK,'surface age sidecar written')
    call restore_age_triplet_disk(trim(restart_path),trim(restart_path)//'.surface',column, &
         cfg%tiles(1)%template,670001_int64,9001_int64,8802_int64,p, &
         restored_water,restored_soil,restored_surface,code)
    call require(code/=TRIPLET_DISK_OK,'wrong surface identity rejects all')
    call require(.not.restored_water%ready().and..not.restored_soil%ready(), &
         'failed composite read leaves both old owners empty')
    call restore_age_triplet_disk(trim(restart_path),trim(restart_path)//'.surface',column, &
         cfg%tiles(1)%template,670001_int64,9001_int64,8801_int64,p, &
         restored_water,restored_soil,restored_surface,code)
    call require(code==TRIPLET_DISK_OK,'composite disk restore succeeds')
    call require(age_joint_states_match(restored_water,restored_soil,restored_surface), &
         'composite restored owners synchronized')
    call compare_water(water,restored_water)
    call compare_chemical(solute,restored_soil)
    print '(A)','MC_SOL01_REAL_REFERENCE_ZERO_POND_TRIPLET_RESTORE=PASS'
  end block
  block
    type(kernel_committed_state_t)::empty_water
    type(age_state_t)::empty_solute
    pbad=p;pbad%dispersivity_cm=p%dispersivity_cm*2.0_real64
    call read_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
         empty_water,empty_solute,status)
    call require(status/=0.and..not.empty_water%ready().and..not.empty_solute%ready(),'same-id altered parameters rejected')
    pbad=p;pbad%drain_age_day=p%drain_age_day+1d0
    call read_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
         empty_water,empty_solute,status)
    call require(status/=0.and..not.empty_water%ready().and..not.empty_solute%ready(),'same-id altered boundary age rejected')
    call read_age_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670002_int64,9001_int64,p, &
         empty_water,empty_solute,status)
    call require(status/=0,'wrong hydraulic identity rejected')
  end block
  cfg%tiles(1)%base_forcing%bottom_flux=0.1_real64
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=-1.0e-4_real64
  initial_solute=solute
  call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,solute,T1,2*T1,result)
  call run_age_joint_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,other_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,other_solute,T1,2*T1,result2)
  call require(result%status==0.and.result2%status==0,'both original and restarted water/chemistry execute')
  call require(result%chemical%external_in>0d0,'actual bottom and lateral age inflow active')
  call verify_actual_trace(initial_solute,solute)
  net_input=net_input+result%chemical%external_in+result%chemical%production-result%chemical%external_out
  call require(abs(result%chemical%amount_after-mass0-net_input)<1.0e-11_real64,'multi-window joint chemical balance')
  call require(abs(result%chemical%residual)<1.0e-11_real64.and. &
       abs(result2%chemical%residual)<1.0e-11_real64,'continued and restarted balance')
  call compare_water(water,other_water);call compare_chemical(solute,other_solute)
  call write_endpoint(trim(endpoint_path),water,solute)
  print '(A)','AGE_JOINT_ATOMIC_RETRY_RESTART_BALANCE=PASS'
contains
  subroutine base_codec_contract()
    type(kernel_committed_state_t)::w,x
    type(age_state_t)::s,y
    type(fmr_template_t)::t
    class(transaction_state_t),allocatable::q
    logical::ok
    integer::code,j
    t=cfg%tiles(1)%template;t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    call fmr_new_b110_committed_state(w,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
    call require(ok,'base state codec initialization')
    call initialize_age(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
         [(1.0_real64+1.0_real64*j,j=1,numnod)],s,code)
    call write_age_joint_restart_file(trim(restart_path)//'.base',column,t,670001_int64,w,s,code)
    call require(code==0,'base-family disk export')
    call read_age_joint_restart_file(trim(restart_path)//'.base',column,t,670001_int64,9001_int64,p,x,y,code)
    call require(code==0,'base-family disk restore')
    call compare_chemical(s,y)
    call x%snapshot(q,ok)
    select type(q)
    type is(fmr_b110_physical_state_t)
      call require(all(abs(q%water_content-cfg%tiles(1)%initial_state%water_content)<=0.0_real64),'base disk physical identity')
    class default
      error stop 'base codec physical family'
    end select
    print '(A)','MATRIX_BASE_DISK_CONTRACT=PASS'
  end subroutine
  subroutine initialize_owners(w,s,p)
    type(kernel_committed_state_t),intent(out)::w
    type(age_state_t),intent(out)::s
    type(b111_age_tracer_substep_forcing_t),intent(in)::p
    logical::ok
    integer::code,j
    call fmr_new_b110_temporal_indicator_committed_state(w,column%column_id,cfg%tiles(1)%initial_state,T0,ok, &
         spread(0.0_real64,1,numnod))
    call require(ok,'initial water owner')
    call initialize_age(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
         [(1.0_real64+1.0_real64*j,j=1,numnod)],s,code)
    call require(code==0,'initial chemical owner')
  end subroutine
  subroutine write_endpoint(path,w,s)
    character(*),intent(in)::path
    type(kernel_committed_state_t),intent(in)::w
    type(age_state_t),intent(in)::s
    class(transaction_state_t),allocatable::q
    type(solute_compartment_state_t)::c
    real(real64),allocatable::theta(:),history(:)
    real(real64)::t
    integer(int64)::rev
    integer::unit
    logical::ok
    call w%snapshot(q,ok);call require(ok,'endpoint water snapshot')
    call s%snapshot(t,theta,c,rev)
    open(newunit=unit,file=path,access='stream',form='unformatted',status='replace')
    select type(q)
    type is(fmr_b110_temporal_indicator_state_t)
      call q%temporal_history_snapshot(history,ok);call require(ok,'endpoint temporal history available')
      write(unit)w%current_lineage_id(),w%current_revision(),q%pressure_head,q%water_content, &
           q%ponding_depth,q%groundwater_level,history
    class default
      error stop 'wrong endpoint family'
    end select
    write(unit)t,rev,theta,c%age_amount
    close(unit)
  end subroutine
  subroutine compare_water(a,b)
    type(kernel_committed_state_t),intent(in)::a,b
    class(transaction_state_t),allocatable::x,y
    real(real64),allocatable::hx(:),hy(:)
    real(real64)::t1,t2
    logical::ok
    call a%current_time(t1,ok);call require(ok,'water clock1')
    call b%current_time(t2,ok);call require(ok,'water clock2')
    call require(abs(t1-t2)<=0.0_real64.and.a%current_revision()==b%current_revision(),'water provenance identity')
    call a%snapshot(x,ok);call b%snapshot(y,ok)
    select type(x)
    type is(fmr_b110_temporal_indicator_state_t)
      select type(y)
      type is(fmr_b110_temporal_indicator_state_t)
        call require(all(abs(x%pressure_head-y%pressure_head)<=0.0_real64),'water head identity')
        call require(all(abs(x%water_content-y%water_content)<=0.0_real64),'water storage identity')
        call x%temporal_history_snapshot(hx,ok);call y%temporal_history_snapshot(hy,ok)
        call require(all(abs(hx-hy)<=0.0_real64),'water history identity')
      class default
        error stop 'water family2'
      end select
    class default
      error stop 'water family1'
    end select
  end subroutine
  subroutine compare_chemical(a,b)
    type(age_state_t),intent(in)::a,b
    type(solute_compartment_state_t)::s1,s2
    real(real64),allocatable::w1(:),w2(:)
    real(real64)::t1,t2
    integer(int64)::r1,r2
    call a%snapshot(t1,w1,s1,r1);call b%snapshot(t2,w2,s2,r2)
    call require(abs(t1-t2)<=0.0_real64.and.r1==r2,'chemical provenance identity')
    call require(all(abs(w1-w2)<=0.0_real64),'chemical carrier identity')
    call require(all(abs(s1%age_amount-s2%age_amount)<=0.0_real64),'age amount identity')
  end subroutine
  subroutine parameters(f)
    type(b111_age_tracer_substep_forcing_t),intent(out)::f
    f%dz_cm=dz;f%theta=cfg%tiles(1)%initial_state%water_content
    f%face_distance_cm=disnod(2:numnod)
    f%face_left_weight=0.5_real64*dz(2:numnod)/f%face_distance_cm
    f%face_right_weight=0.5_real64*dz(1:numnod-1)/f%face_distance_cm
    f%theta_sat_left=cfg%tiles(1)%parameters%cofgen(2,1:numnod-1)
    f%dispersivity_cm=spread(0.2_real64,1,numnod-1)
    f%molecular_diffusion_cm2_day=0.05_real64;f%drain_age_day=42d0
  end subroutine
  subroutine verify_actual_trace(initial,accepted)
    type(age_state_t),intent(in)::initial,accepted
    type(fmr_serialized_physical_observation_t)::obs
    type(fmr_water_flux_substep_trace_t),allocatable::traces(:),bad(:)
    type(age_state_t)::trial
    type(age_receipt_t)::receipt
    type(solute_compartment_state_t)::stores,finalstores
    type(b111_age_tracer_substep_forcing_t)::f
    real(real64),allocatable::water(:),faces(:),age(:),density(:)
    real(real64)::time,closure,production,root,drain,bottom
    integer(int64)::revision
    integer::i,j,code
    obs=backend%observation();traces=obs%accepted_water_flux_substeps
    call require(size(traces)>0,'actual internally accepted trajectory available')
    call require(sum(traces(1)%root_sink)>0d0,'accepted root water extraction active')
    call initial%snapshot(time,water,stores,revision)
    density=stores%age_amount/p%dz_cm;age=density/water
    do i=1,size(traces)
      associate(t=>traces(i))
        f=p;f%theta_previous=t%water_start;f%theta=t%water_end;f%dt_day=t%t1-t%t0
        f%root_sink_cm_day=t%root_sink;f%qdra_cm_day=t%drainage_sink_by_level
        call reconstruct_interval_water_face_flux(p%dz_cm,t%water_start,t%water_end,t%net_node_source, &
           -t%top_flux,-t%bottom_flux,f%dt_day,1d-10/f%dt_day,faces,closure,code)
        call require(code==0,'every actual vertical interface closes')
        f%q_face_up_cm_day=-faces
        call literal_age_step(f,age,density,production,root,drain,bottom)
      end associate
    end do
    call accepted%snapshot(time,water,finalstores,revision)
    call require(maxval(abs(finalstores%age_amount-density*p%dz_cm))<1d-11,'actual accepted trace independent literal endpoint')
    do j=1,15
      bad=traces
      select case(j)
      case(1);bad(1)%t0=bad(1)%t0+1d-4
      case(2);bad(1)%root_sink(1)=-1d0
      case(3);bad(1)%water_start(1)=bad(1)%water_start(1)+1d-4
      case(4);bad(1)%water_end(1)=bad(1)%water_end(1)+.1d0
      case(5);bad(1)%net_node_source(1)=bad(1)%net_node_source(1)+1d-4
      case(6);bad(1)%top_flux=.1d0
      case(7);bad(1)%subsurface_source=spread(.1d0,1,numnod)
      case(8);bad(1)%macropore_matrix_exchange=spread(.1d0,1,numnod)
      case(9);bad(size(bad))%t0=bad(size(bad))%t0+1d-4
      case(10);bad(1)%bottom_flux=bad(1)%bottom_flux+1d0
      case(11);bad(1)%t1=bad(1)%t0+1d-310
      case(12)
        bad(1)%root_sink=huge(0d0)
        bad(1)%drainage_sink_by_level=huge(0d0)
      case(13);bad(1)%drainage_sink_by_level=1d300
      case(14);bad(1)%net_node_source=1d300
      case(15);bad(1)%bottom_flux=1d300
      end select
      trial=initial
      call consume_accepted_age_trace(trial,bad,receipt)
      if(receipt%status==AGE_OK)print *,'unexpected carrier acceptance',j
      call require(receipt%status/=AGE_OK,'malformed accepted carrier rejects')
      call compare_chemical(initial,trial)
    end do
    trial=initial
    call consume_accepted_age_trace(trial,traces,receipt)
    call require(receipt%status==AGE_OK,'fresh trace succeeds after rejected inputs')
    call compare_chemical(trial,accepted)
    call consume_accepted_age_trace(trial,traces,receipt)
    call require(receipt%status/=AGE_OK,'consumed clock rejects replay')
    call compare_chemical(trial,accepted)
    print '(A)','AGE_ACTUAL_LITERAL_FIFTEEN_CARRIER_NEGATIVES_REPLAY=PASS'
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print '(A)','FAIL '//label;error stop 1
    end if
  end subroutine
  include 'matrix_fixture.inc'
end program
