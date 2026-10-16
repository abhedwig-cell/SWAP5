program test_surface_joint
  use iso_fortran_env,only:real64,int64
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend
  use mod_fmr_production_application_bootstrap
  use mod_kernel_transactions
  use mod_fixed_flux_top_boundary_provider
  use mod_b110_default_mvg_provider
  use MOD_grid,only:numnod,z,dz,disnod
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t,B111_REACTIVE_NEGATIVE
  use mod_fmr_b111_matrix_solute_route
  use mod_fmr_b111_matrix_joint_application
  use mod_fmr_b111_surface_joint_application
  use mod_b111_surface_supply
  use mod_fmr_b111_surface_solute_route
  use b111_literal_oracle
  use mod_solute_water_face_flux_reconstruction
  use mod_matrix_joint_restart_file
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  real(real64),parameter::T0=0.0_real64,T1=1.0e-3_real64,HARD_MASS_GATE=1.0e-10_real64
  type(fmr_production_application_config_t)::cfg
  type(fmr_serialized_reference_backend_t)::backend,second
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::column
  type(kernel_committed_state_t)::water,other_water,initial_water,bad_water
  type(matrix_solute_state_t)::solute,other_solute,initial_solute,bad_solute,rejected_solute
  type(matrix_joint_restart_t)::payload
  type(matrix_joint_result_t)::result,result2
  type(surface_supply_t)::supply,small_supply
  type(b111_reactive_solute_substep_forcing_t)::p,pbad
  real(real64)::k,mass0,net_input
  integer::status,u
  logical::ok
  character(512)::mode,restart_path,endpoint_path
  character(64)::exponent_argument
  call get_command_argument(1,mode);call get_command_argument(2,restart_path);call get_command_argument(3,endpoint_path)
  call initialize_application_config(cfg,-75.0_real64,k)
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  cfg%tiles(1)%base_forcing%top_flux=-0.5_real64
  supply=surface_supply_t(777_int64,0_int64,T0,T1,0.25d0,0.25d0,0.125d0,0.375d0)
  small_supply=supply;small_supply%t1=1d-9
  cfg%tiles(1)%parameters%root_extraction_active=.true.
  cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
  cfg%tiles(1)%base_forcing%bottom_flux=-0.1_real64
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=1.0e-4_real64
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
  call get_command_argument(4,exponent_argument)
  if(len_trim(exponent_argument)>0)read(exponent_argument,*)p%frexp
  if(abs(p%frexp-1.0_real64)>epsilon(1.0_real64))p%cref_mg_cm3=0.37_real64
  call backend%initialize(top);call second%initialize(top)
  if(trim(mode)=='reject')then
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status)
    call require(status/=JOINT_OK,'invalid disk payload rejected')
    call require(.not.water%ready().and..not.solute%ready(),'disk rejection leaves both empty targets untouched')
    print '(A)','MATRIX_JOINT_INVALID_FILE=PASS'
    stop
  end if
  if(trim(mode)=='resume')then
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status)
    call require(status==JOINT_OK,'fresh-process disk reconstruction')
    supply%t0=T1;supply%t1=2*T1;supply%revision=1
    cfg%tiles(1)%base_forcing%bottom_flux=0.1d0
    cfg%tiles(1)%base_forcing%drainage_flux_by_level=-1d-4
    call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
         cfg%tiles(1)%base_forcing,cfg%numerical,solute,supply,T1,2*T1,result)
    call require(result%status==JOINT_OK,'fresh-process physical joint continuation')
    call write_endpoint(trim(endpoint_path),water,solute)
    print '(A)','SURFACE_JOINT_FRESH_PROCESS=PASS'
    stop
  end if
  call base_codec_contract()
  call initialize_owners(water,solute,p)
  initial_water=water;initial_solute=solute
  ! Chemical rejection after a successful hydraulic candidate rolls both back.
  pbad=p;pbad%decpot=1.0e6_real64
  call initialize_matrix_solute(pbad,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
       [(0.1_real64+0.1_real64*u,u=1,numnod)],bad_solute,status)
  bad_water=water
  rejected_solute=bad_solute
  call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,supply,T0,T1,result)
  call require(result%status==JOINT_CHEMICAL_REJECTED,'chemical overdraw rejects successful water trial')
  call require(result%water%completed.and.result%chemical%process_status==B111_REACTIVE_NEGATIVE, &
    'real reaction overdraw after successful accepted water trial')
  call require(bad_water%current_revision()==water%current_revision(),'no water commit on chemical rejection')
  call compare_water(water,bad_water)
  call compare_chemical(rejected_solute,bad_solute)
  call require(matrix_joint_states_match(bad_water,bad_solute),'failed joint attempt preserves clocks')
  call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,small_supply,T0,1.0e-9_real64,result)
  call require(result%status==JOINT_OK,'smaller joint retry succeeds')
  ! Hydraulic failure does not execute or mutate chemistry.
  block
    type(fmr_b110_physical_forcing_t)::invalid
    invalid=cfg%tiles(1)%base_forcing
    invalid%root_extraction_sink=-1.0_real64
    call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
         invalid,cfg%numerical,solute,supply,T0,T1,result)
    call require(result%status/=JOINT_OK,'invalid hydraulic input rejects joint attempt')
    call compare_water(water,initial_water);call compare_chemical(solute,initial_solute)
  end block
  call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,solute,supply,T0,T1,result)
  if(result%status/=0)print *,'joint diagnostics',result%status,result%chemical%status,result%water%status
  call require(result%status==JOINT_OK,'normal joint physical route')
  call require(abs(result%water%mass%residual)<=HARD_MASS_GATE,'accepted complete water balance')
  call verify_actual_trace(initial_solute,solute)
  call require(result%chemical%external_in>=0.125d0*T1,'surface input is active')
  mass0=result%chemical%mass_before
  net_input=result%chemical%external_in-result%chemical%external_out
  call require(abs(result%chemical%residual)<1.0e-11_real64,'first joint chemical balance')
  call require(matrix_joint_states_match(water,solute),'joint accepted carrier clock and state')
  call export_matrix_joint_restart(column,cfg%tiles(1)%template,670001_int64,water,solute,payload,status)
  call require(status==JOINT_OK,'joint opaque restart export')
  call restore_matrix_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9002_int64, &
       other_water,other_solute,status)
  call require(status/=0.and..not.other_water%ready().and..not.other_solute%ready(),'wrong chemical identity restores neither')
  call restore_matrix_joint_restart(payload,column,cfg%tiles(1)%template,670001_int64,9001_int64, &
       other_water,other_solute,status)
  call require(status==0,'joint opaque restart restore')
  call compare_water(water,other_water);call compare_chemical(solute,other_solute)
  call write_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,water,solute,status)
  call require(status==JOINT_OK,'production joint disk writer')
  block
    type(kernel_committed_state_t)::empty_water
    type(matrix_solute_state_t)::empty_solute
    pbad=p;pbad%decpot=p%decpot*2.0_real64
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
         empty_water,empty_solute,status)
    call require(status/=0.and..not.empty_water%ready().and..not.empty_solute%ready(),'same-id altered parameters rejected')
    pbad=p;pbad%frexp=0.5_real64
    if(abs(p%frexp-0.5_real64)<epsilon(1.0_real64))pbad%frexp=2.0_real64
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
         empty_water,empty_solute,status)
    call require(status/=0.and..not.empty_water%ready().and..not.empty_solute%ready(),'same-id altered exponent rejected')
    pbad=p;pbad%cref_mg_cm3=2.0_real64*p%cref_mg_cm3
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,pbad, &
         empty_water,empty_solute,status)
    call require(status/=0.and..not.empty_water%ready().and..not.empty_solute%ready(),'same-id altered Cref rejected')
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670002_int64,9001_int64,p, &
         empty_water,empty_solute,status)
    call require(status/=0,'wrong hydraulic identity rejected')
  end block
  supply%t0=T1;supply%t1=2*T1;supply%revision=1
  cfg%tiles(1)%base_forcing%bottom_flux=0.1d0
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=-1d-4
  initial_solute=solute
  call run_surface_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,solute,supply,T1,2*T1,result)
  call run_surface_joint_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,other_water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,other_solute,supply,T1,2*T1,result2)
  call require(result%status==0.and.result2%status==0,'both original and restarted water/chemistry execute')
  call verify_actual_trace(initial_solute,solute)
  call require(abs(result%water%mass%residual)<=HARD_MASS_GATE,'continued complete water balance')
  net_input=net_input+result%chemical%external_in-result%chemical%external_out
  call require(abs(result%chemical%mass_after-mass0-net_input)<1.0e-11_real64,'multi-window joint chemical balance')
  call require(abs(result%chemical%residual)<1.0e-11_real64.and. &
       abs(result2%chemical%residual)<1.0e-11_real64,'continued and restarted balance')
  call compare_water(water,other_water);call compare_chemical(solute,other_solute)
  call write_endpoint(trim(endpoint_path),water,solute)
  print '(A)','SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS'
contains
  subroutine base_codec_contract()
    type(kernel_committed_state_t)::w,x
    type(matrix_solute_state_t)::s,y
    type(fmr_template_t)::t
    class(transaction_state_t),allocatable::q
    logical::ok
    integer::code,j
    t=cfg%tiles(1)%template;t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    call fmr_new_b110_committed_state(w,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
    call require(ok,'base state codec initialization')
    call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
         [(0.1_real64+0.1_real64*j,j=1,numnod)],s,code)
    call write_matrix_joint_restart_file(trim(restart_path)//'.base',column,t,670001_int64,w,s,code)
    call require(code==0,'base-family disk export')
    call read_matrix_joint_restart_file(trim(restart_path)//'.base',column,t,670001_int64,9001_int64,p,x,y,code)
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
    type(matrix_solute_state_t),intent(out)::s
    type(b111_reactive_solute_substep_forcing_t),intent(in)::p
    logical::ok
    integer::code,j
    call fmr_new_b110_temporal_indicator_committed_state(w,column%column_id,cfg%tiles(1)%initial_state,T0,ok, &
         spread(0.0_real64,1,numnod))
    call require(ok,'initial water owner')
    call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
         [(0.1_real64+0.1_real64*j,j=1,numnod)],s,code)
    call require(code==0,'initial chemical owner')
  end subroutine
  subroutine write_endpoint(path,w,s)
    character(*),intent(in)::path
    type(kernel_committed_state_t),intent(in)::w
    type(matrix_solute_state_t),intent(in)::s
    class(transaction_state_t),allocatable::q
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::c
    real(real64),allocatable::theta(:),history(:)
    real(real64)::t
    integer(int64)::rev
    integer::unit
    logical::ok
    call w%snapshot(q,ok);call require(ok,'endpoint water snapshot')
    call s%snapshot(t,theta,m,c,rev)
    open(newunit=unit,file=path,access='stream',form='unformatted',status='replace')
    select type(q)
    type is(fmr_b110_temporal_indicator_state_t)
      call q%temporal_history_snapshot(history,ok);call require(ok,'endpoint temporal history available')
      write(unit)w%current_lineage_id(),w%current_revision(),q%pressure_head,q%water_content, &
           q%ponding_depth,q%groundwater_level,history
    class default
      error stop 'wrong endpoint family'
    end select
    write(unit)t,rev,theta,m%concentration_mg_cm3,m%mass_mg_cm2,c%sorbed_matrix_mass
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
    type(matrix_solute_state_t),intent(in)::a,b
    type(mobile_salt_state_t)::m1,m2
    type(solute_compartment_state_t)::s1,s2
    real(real64),allocatable::w1(:),w2(:)
    real(real64)::t1,t2
    integer(int64)::r1,r2
    call a%snapshot(t1,w1,m1,s1,r1);call b%snapshot(t2,w2,m2,s2,r2)
    call require(abs(t1-t2)<=0.0_real64.and.r1==r2,'chemical provenance identity')
    call require(all(abs(w1-w2)<=0.0_real64),'chemical carrier identity')
    call require(all(abs(m1%mass_mg_cm2-m2%mass_mg_cm2)<=0.0_real64),'chemical dissolved identity')
    call require(all(abs(m1%concentration_mg_cm3-m2%concentration_mg_cm3)<=0.0_real64),'chemical concentration identity')
    call require(all(abs(s1%sorbed_matrix_mass-s2%sorbed_matrix_mass)<=0.0_real64),'chemical sorbed identity')
  end subroutine
  subroutine verify_actual_trace(initial,accepted)
    use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
    type(matrix_solute_state_t),intent(in)::initial,accepted
    type(fmr_serialized_physical_observation_t)::obs
    type(fmr_water_flux_substep_trace_t),allocatable::steps(:),bad(:)
    type(matrix_solute_state_t)::trial
    type(matrix_solute_receipt_t)::r
    type(mobile_salt_state_t)::m,finalm
    type(solute_compartment_state_t)::c,finalc
    type(b111_reactive_solute_substep_forcing_t)::f
    type(surface_supply_t)::broken
    real(real64),allocatable::w(:),faces(:),expected(:),mass(:)
    real(real64)::clock,closure,dec,ein,eout,surface_input,totalout
    integer(int64)::rev
    integer::i,j,code
    obs=backend%observation();steps=obs%accepted_water_flux_substeps
    call require(size(steps)>1,'multiple internally accepted physical substeps')
    call require(sum(steps(1)%root_sink)>0d0,'actual root water export active')
    call require(abs(steps(1)%bottom_flux)>0d0.and.sum(abs(steps(1)%drainage_sink_by_level))>0d0, &
      'actual signed bottom and drainage active')
    call initial%snapshot(clock,w,m,c,rev)
    expected=m%concentration_mg_cm3;mass=m%mass_mg_cm2+c%sorbed_matrix_mass
    surface_input=0;totalout=0
    do i=1,size(steps)
      associate(t=>steps(i))
        f=p;f%theta_previous=t%water_start;f%theta=t%water_end;f%dt_day=t%t1-t%t0
        f%root_sink_cm_day=t%root_sink;f%qdra_cm_day=t%drainage_sink_by_level
        f%rain_rate_cm_day=supply%rain_rate;f%rain_c_mg_cm3=supply%rain_c
        f%irrigation_rate_cm_day=supply%irrigation_rate;f%irrigation_c_mg_cm3=supply%irrigation_c
        call reconstruct_interval_water_face_flux(p%dz_cm,t%water_start,t%water_end,t%net_node_source, &
          -t%top_flux,-t%bottom_flux,f%dt_day,1d-10/f%dt_day,faces,closure,code)
        call require(code==0.and.abs(closure)*f%dt_day<=1d-10,'actual interface water closure')
        f%q_face_up_cm_day=-faces
        call literal_step(f,expected,mass,dec,ein,eout)
        surface_input=surface_input+ein;totalout=totalout+eout
      end associate
    end do
    call accepted%snapshot(clock,w,finalm,finalc,rev)
    call require(maxval(abs(finalm%concentration_mg_cm3-expected))<1d-11,'literal surface and vertical concentration')
    call require(maxval(abs(finalm%mass_mg_cm2+finalc%sorbed_matrix_mass-mass))<1d-11,'literal compartment mass')
    call require(abs(sum(mass)-sum(m%mass_mg_cm2)-c%solute_total()-surface_input+totalout)<1d-11,'literal combined balance')
    call require(all(finalm%mass_mg_cm2>=0d0).and.all(finalc%sorbed_matrix_mass>=0d0),'nonnegative accepted stores')
    call require(finalc%pond_mass==0d0,'no dry-surface mass lost on restart')
    do j=1,14
      bad=steps;broken=supply;trial=initial
      i=size(bad)
      select case(j)
      case(1)
        bad(i)%top_flux=0d0
      case(2)
        bad(i)%top_flux=0.5d0
      case(3)
        bad(i)%top_flux=-0.25d0
      case(4)
        bad(i)%water_start(1)=0.9d0
      case(5)
        bad(i)%water_end(1)=0.9d0
      case(6)
        bad(i)%root_sink(1)=huge(0d0)
        bad(i)%drainage_sink_by_level(1,1)=huge(0d0)
      case(7)
        bad(i)%net_node_source(1)=ieee_value(0d0,ieee_quiet_nan)
      case(8)
        bad(i)%subsurface_source(1)=0.1d0
      case(9)
        bad(i)%macropore_matrix_exchange(1)=0.1d0
      case(10)
        bad(i)%t0=bad(i)%t1
      case(11)
        broken%rain_c=-1d0
      case(12)
        broken%rain_rate=huge(0d0);broken%irrigation_rate=huge(0d0)
      case(13)
        broken%t0=broken%t0+1d-9
      case(14)
        broken%t1=broken%t1+1d-9
      end select
      call consume_accepted_surface_trace(trial,bad,broken,r)
      call require(r%status/=MATRIX_OK,'last-carrier or supply rejection')
      if(j<=10)call require(r%completed_substeps==size(steps)-1,'valid prefix executed before rejection')
      call compare_chemical(initial,trial)
    end do
    trial=accepted
    call consume_accepted_surface_trace(trial,steps,supply,r)
    call require(r%status/=MATRIX_OK,'clock replay rejected')
    call compare_chemical(accepted,trial)
    print '(A)','SURFACE_ACTUAL_LITERAL_FOURTEEN_NEGATIVES_REPLAY=PASS'
  end subroutine
  subroutine parameters(f)
    type(b111_reactive_solute_substep_forcing_t),intent(out)::f
    f%dz_cm=dz;f%theta=cfg%tiles(1)%initial_state%water_content
    f%bulk_density=spread(1.3_real64,1,numnod);f%kf=spread(0.2_real64,1,numnod)
    f%temperature_active=.true.;f%temperature_c=spread(20.0_real64,1,numnod)
    f%gampar=spread(0.05_real64,1,numnod);f%rtheta=spread(0.3_real64,1,numnod)
    f%bexp=spread(1.0_real64,1,numnod);f%decpot=spread(0.02_real64,1,numnod)
    f%fdepth=spread(1.0_real64,1,numnod)
    f%face_distance_cm=disnod(2:numnod)
    f%face_left_weight=0.5_real64*dz(2:numnod)/f%face_distance_cm
    f%face_right_weight=0.5_real64*dz(1:numnod-1)/f%face_distance_cm
    f%theta_sat_left=cfg%tiles(1)%parameters%cofgen(2,1:numnod-1)
    f%dispersivity_cm=spread(0.2_real64,1,numnod-1)
    f%molecular_diffusion_cm2_day=0.05_real64;f%tscf=0.5_real64
    f%cdrain_mg_cm3=0.4_real64;f%cseep_mg_cm3=0.3_real64
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
