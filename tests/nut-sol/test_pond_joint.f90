program test_pond_joint
  use iso_fortran_env,only:real64,int64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_fmr_runtime_core
  use mod_canonical_contracts,only:canonical_numerical_config_t
  use mod_fmr_serialized_reference_backend
  use mod_fmr_production_application_bootstrap
  use mod_kernel_transactions
  use mod_fixed_flux_top_boundary_provider
  use mod_b110_default_mvg_provider
  use MOD_grid,only:numnod,z,dz,disnod
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE,TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t,B111_REACTIVE_NEGATIVE
  use mod_fmr_b111_matrix_solute_route
  use mod_fmr_b111_matrix_joint_application
  use mod_fmr_b111_pond_joint_application
  use mod_b111_persistent_pond
  use mod_fmr_b111_pond_solute_route
  use b111_literal_oracle
  use mod_solute_water_face_flux_reconstruction
  use mod_matrix_joint_restart_file
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  real(real64),parameter::T0=0d0,T1=1d-3,HARD_MASS_GATE=1d-10
  type(fmr_production_application_config_t)::cfg
  type(fmr_serialized_reference_backend_t)::backend,second
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::column
  type(kernel_committed_state_t)::water,other_water,initial_water,bad_water
  type(matrix_solute_state_t)::solute,other_solute,initial_solute,bad_solute
  type(matrix_joint_result_t)::result,result2
  type(pond_step_t)::supply,small_supply
  type(b111_reactive_solute_substep_forcing_t)::p,pbad
  type(mobile_salt_state_t)::current_mobile
  type(solute_compartment_state_t)::current_companion
  real(real64),allocatable::current_theta(:)
  real(real64)::k,clock,mass
  integer(int64)::revision
  integer::status
  logical::ok
  character(512)::mode,restart_path,endpoint_path,variant
  call get_command_argument(1,mode);call get_command_argument(2,restart_path);call get_command_argument(3,endpoint_path)
  call get_command_argument(4,variant)
  call initialize_application_config(cfg,-75d0,k)
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  cfg%tiles(1)%initial_state%ponding_depth=0.5d0
  cfg%tiles(1)%base_forcing%top_flux=-0.5d0
  cfg%tiles(1)%parameters%root_extraction_active=.true.
  cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
  cfg%tiles(1)%base_forcing%bottom_flux=-0.1d0
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=1d-4
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0d0
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=1d-6
  cfg%numerical%transaction%temporal_tolerance=0d0
  cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=10000
  column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
  column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  if(trim(variant)=='dry')then
    cfg%tiles(1)%initial_state%ponding_depth=0d0
    cfg%tiles(1)%base_forcing%top_flux=0d0
  end if
  call parameters(p)
  call backend%initialize(top);call second%initialize(top)
  supply=pond_step_t(T0,T1,0.5d0,0.5d0,-0.5d0,0.25d0,0.125d0,0.25d0,0.375d0,0.125d0)
  supply%depth_begin=cfg%tiles(1)%initial_state%ponding_depth;supply%depth_end=supply%depth_begin
  if(trim(variant)=='dry')then
    supply%qtop=0d0;supply%rain_rate=0d0;supply%irrigation_rate=0d0
  end if
  if(trim(mode)=='write'.and.trim(variant)/='dry')call verify_gross_dynamic()
  if(trim(mode)=='reject')then
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status,allow_surface_mass=.true.)
    call require(status/=JOINT_OK,'invalid pond restart rejected')
    call require(.not.water%ready().and..not.solute%ready(),'atomic decoder rejection')
    print '(A)','POND_JOINT_INVALID_FILE=PASS'
    stop
  end if
  if(trim(mode)=='resume')then
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
         water,solute,status,allow_surface_mass=.true.)
    call require(status==JOINT_OK,'fresh process pond reconstruction')
  else
    call initialize_owners(water,solute,p)
    initial_water=water;initial_solute=solute
    pbad=p;pbad%decpot=1d6
    call initialize_owners(bad_water,bad_solute,pbad)
    ! A chemical runon cannot be injected into a fixed-flux hydraulic trial.
    ! Both owners must remain unchanged until a dynamic gross receipt exists.
    block
      type(pond_step_t)::unmatched
      unmatched=supply;unmatched%runon_rate=0.25d0;unmatched%runon_c=3d0
      call run_pond_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
        cfg%tiles(1)%base_forcing,cfg%numerical,solute,unmatched,T0,T1,result)
      call require(result%status==JOINT_INVALID,'no unverified chemical runon')
      call compare_water(water,initial_water)
      call compare_chemical(solute,initial_solute)
    end block
    small_supply=supply;small_supply%t1=1d-9
    call run_pond_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
      cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,supply,T0,T1,result)
    call require(result%status==JOINT_CHEMICAL_REJECTED.and.result%water%completed,'chemical rejects completed water')
    call compare_water(initial_water,bad_water);call compare_chemical(initial_solute,bad_solute)
    call run_pond_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,bad_water, &
      cfg%tiles(1)%base_forcing,cfg%numerical,bad_solute,small_supply,T0,1d-9,result)
    call require(result%status==JOINT_OK,'smaller retry')
    call run_pond_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
      cfg%tiles(1)%base_forcing,cfg%numerical,solute,supply,T0,T1,result)
    if(result%status/=JOINT_OK)print *,result%status,result%chemical%status,result%chemical%completed_substeps
    call require(result%status==JOINT_OK,'real Richards persistent pond')
    call require(abs(result%water%mass%residual)<=HARD_MASS_GATE.and.abs(result%chemical%residual)<1d-11,'whole balances')
    call solute%snapshot(clock,current_theta,current_mobile,current_companion,revision)
    mass=current_companion%pond_mass
    call require(mass>0d0.and.mass/=0.25d0,'persistent actual surface mass in matrix owner')
    call verify_actual_trace(initial_solute,solute)
    call write_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,water,solute,status,allow_surface_mass=.true.)
    call require(status==JOINT_OK,'native pond writer')
    call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p, &
      other_water,other_solute,status,allow_surface_mass=.true.)
    call require(status==JOINT_OK,'native pond reader')
    call compare_water(water,other_water);call compare_chemical(solute,other_solute);call compare_chemical(solute,other_solute)
    ! No old reader may silently drop a new pond payload.
    block
      type(kernel_committed_state_t)::w
      type(matrix_solute_state_t)::s
      call read_matrix_joint_restart_file(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64,p,w,s,status)
      call require(status/=JOINT_OK.and..not.w%ready().and..not.s%ready(),'matrix-only reader cannot discard pond')
    end block
  end if
  supply%t0=T1;supply%t1=2*T1
  supply%rain_rate=0.25d0;supply%irrigation_rate=0.25d0
  cfg%tiles(1)%base_forcing%top_flux=-0.5d0
  cfg%tiles(1)%base_forcing%bottom_flux=0.1d0
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=-1d-4
  initial_solute=solute
  call run_pond_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    cfg%tiles(1)%base_forcing,cfg%numerical,solute,supply,T1,2*T1,result)
  call require(result%status==JOINT_OK,'continued actual pond')
  call verify_actual_trace(initial_solute,solute)
  if(trim(mode)/='resume')then
    call run_pond_joint_interval(second,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,other_water, &
      cfg%tiles(1)%base_forcing,cfg%numerical,other_solute,supply,T1,2*T1,result2)
    call require(result2%status==JOINT_OK,'restarted pond continues')
    call compare_water(water,other_water);call compare_chemical(solute,other_solute);call compare_chemical(solute,other_solute)
  end if
  call write_endpoint(trim(endpoint_path),water,solute)
  print '(A)','POND_JOINT_ACTUAL_BALANCE_RESTART=PASS'
contains
  subroutine verify_gross_dynamic()
    type(fmr_b110_physical_forcing_t)::gross
    type(fmr_b110_physical_parameters_t),target::gross_parameters
    type(canonical_numerical_config_t)::nc
    type(fmr_template_t)::plain
    type(kernel_committed_state_t)::w
    type(matrix_solute_state_t)::chem
    type(matrix_joint_result_t)::outcome
    type(pond_step_t)::chem_supply
    type(fmr_serialized_physical_observation_t)::observation
    logical::created
    integer::code,kstep
    logical::seen_runon,seen_runoff
    plain=cfg%tiles(1)%template
    plain%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    nc=cfg%numerical
    nc%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    nc%transaction%temporal_tolerance=1d-6
    gross_parameters=cfg%tiles(1)%parameters
    ! Use the qualified dynamic pond low-conductivity domain, not the
    ! fixed-flux high-conductivity fixture's unrelated wetting-front stress.
    gross_parameters%cofgen(3,:)=gross_parameters%cofgen(3,:)*1d-3
    gross_parameters%cofgen(10,:)=gross_parameters%cofgen(10,:)*1d-3
    gross_parameters%cofgen(12,:)=gross_parameters%cofgen(12,:)*1d-3
    gross=cfg%tiles(1)%base_forcing
    gross%top_flux=0d0
    allocate(gross%pond_input)
    gross%pond_input%rain_rate_cm_day=0.25d0
    gross%pond_input%irrigation_rate_cm_day=0.25d0
    gross%pond_input%runon_rate_cm_day=0.5d0
    gross%pond_input%ponding_max_cm=0.50001d0
    gross%pond_input%runoff_resistance_day=0.001d0
    chem_supply=supply
    chem_supply%runon_rate=0.5d0
    chem_supply%runon_c=3d0
    call fmr_new_b110_committed_state(w,column%column_id,cfg%tiles(1)%initial_state,T0,created)
    call require(created,'gross hydraulic owner initialization')
    call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
      [(0.1_real64+0.1_real64*code,code=1,numnod)],chem,code)
    call require(code==MATRIX_OK,'gross chemical initialization')
    block
      type(mobile_salt_state_t)::m
      type(solute_compartment_state_t)::c
      real(real64),allocatable::theta(:)
      real(real64)::tc
      integer(int64)::rv
      call chem%snapshot(tc,theta,m,c,rv)
      call reconstruct_matrix_solute_trusted(p,9001_int64,rv,tc,theta,m%concentration_mg_cm3, &
        m%mass_mg_cm2,c%sorbed_matrix_mass,chem,code,surface_mass=0.25d0)
      call require(code==MATRIX_OK,'gross pond surface mass')
    end block
    call run_pond_joint_interval(backend,column,plain,gross_parameters,w,gross,nc,chem, &
      chem_supply,T0,T1,outcome)
    if(outcome%status/=JOINT_OK)print *,'GROSS_JOINT_STATUS',outcome%status, &
      outcome%water%status,outcome%chemical%status
    call require(outcome%status==JOINT_OK,'positive runon Reference joint')
    observation=backend%observation()
    call require(observation%accepted_water_flux_trace_available,'gross accepted trace')
    seen_runon=.false.;seen_runoff=.false.
    do kstep=1,size(observation%accepted_water_flux_substeps)
      seen_runon=seen_runon.or. &
        observation%accepted_water_flux_substeps(kstep)%converged_runon_rate_cm_day>0d0
      seen_runoff=seen_runoff.or. &
        observation%accepted_water_flux_substeps(kstep)%converged_runoff_depth_cm>0d0
    end do
    call require(seen_runon,'positive gross runon carried from Reference')
    call require(seen_runoff,'positive runoff carried from Reference')
    call require(abs(outcome%chemical%residual)<1d-11,'gross joint chemical closure')
    call require(abs(outcome%water%mass%residual)<HARD_MASS_GATE,'gross joint water closure')
    print '(A)','MC_SOL01_GROSS_POSITIVE_RUNON_RUNOFF_JOINT=PASS'
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
    block
      type(mobile_salt_state_t)::m
      type(solute_compartment_state_t)::c
      real(real64),allocatable::theta(:)
      real(real64)::clock
      integer(int64)::revision
      call s%snapshot(clock,theta,m,c,revision)
      call reconstruct_matrix_solute_trusted(p,9001_int64,revision,clock,theta,m%concentration_mg_cm3, &
        m%mass_mg_cm2,c%sorbed_matrix_mass,s,code,surface_mass=0.25d0)
      call require(code==MATRIX_OK,'accepted1256 persistent surface owner')
    end block

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
    write(unit)t,rev,theta,m%concentration_mg_cm3,m%mass_mg_cm2,c%sorbed_matrix_mass,c%pond_mass
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
    call require(s1%pond_mass==s2%pond_mass,'persistent matrix surface mass identity')
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
    type(pond_step_t)::broken
    real(real64)::surface_mass,pt,pd,pm
    integer(int64)::pr
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
    surface_mass=c%pond_mass
    pm=surface_mass
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
        f%pond_end_cm=t%pond_end_cm
        surface_mass=surface_mass+supply%dry_deposition_rate*f%dt_day
        call literal_step(f,expected,mass,surface_mass,dec,ein,eout)
        ein=ein+supply%dry_deposition_rate*f%dt_day
        surface_input=surface_input+ein;totalout=totalout+eout
      end associate
    end do
    call accepted%snapshot(clock,w,finalm,finalc,rev)
    call require(maxval(abs(finalm%concentration_mg_cm3-expected))<1d-11,'literal surface and vertical concentration')
    call require(maxval(abs(finalm%mass_mg_cm2+finalc%sorbed_matrix_mass-mass))<1d-11,'literal compartment mass')
    k=finalc%pond_mass
    call require(abs(k-surface_mass)<1d-11,'literal persistent pond')
    call require(abs(sum(mass)+surface_mass-sum(m%mass_mg_cm2)-c%solute_total()-surface_input+totalout)<1d-11, &
      'literal combined balance')
    call require(all(finalm%mass_mg_cm2>=0d0).and.all(finalc%sorbed_matrix_mass>=0d0),'nonnegative accepted stores')
    do j=1,21
      bad=steps;broken=supply;trial=initial
      i=size(bad)
      select case(j)
      case(1)
        bad(i)%top_flux=-0.75d0
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
      case(15)
        bad(i)%pond_storage_available=.false.
      case(16)
        bad(i)%pond_end_cm=bad(i)%pond_end_cm+1d-5
      case(17)
        bad(i)%pond_start_cm=ieee_value(0d0,ieee_quiet_nan)
      case(18)
        broken%t0=ieee_value(0d0,ieee_quiet_nan)
      case(19)
        broken%t1=ieee_value(0d0,ieee_quiet_nan)
      case(20)
        broken%dry_deposition_rate=ieee_value(0d0,ieee_quiet_nan)
      case(21)
        broken%dry_deposition_rate=huge(0d0)
      end select
      call consume_accepted_pond_trace(trial,bad,broken,r)
      call require(r%status/=MATRIX_OK,'last-carrier or supply rejection')
      if(j<=10)call require(r%completed_substeps==size(steps)-1,'valid prefix executed before rejection')
      call compare_chemical(initial,trial)
    end do
    trial=accepted
    call consume_accepted_pond_trace(trial,steps,supply,r)
    call require(r%status/=MATRIX_OK,'clock replay rejected')
    call compare_chemical(accepted,trial)
    print '(A)','POND_ACTUAL_LITERAL_TWENTYONE_NEGATIVES_REPLAY=PASS'
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
