program test_matrix_thermal
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fmr_production_application_bootstrap
 use mod_kernel_transactions
 use mod_fixed_flux_top_boundary_provider
 use mod_b110_default_mvg_provider
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_fmr_b111_matrix_solute_route
 use mod_fmr_b111_matrix_joint_application,only:matrix_joint_result_t,JOINT_OK,JOINT_CHEMICAL_REJECTED
 use mod_fmr_b111_matrix_thermal_application
 use mod_matrix_thermal_restart_file
 use mod_soil_temperature_contract
 use mod_restricted_soil_temperature,only:initialize_soil_temperature_parameters
 use mod_solute_mobile_salt_state,only:mobile_salt_state_t
 use mod_solute_compartment_state,only:solute_compartment_state_t
 use b111_literal_oracle,only:literal_step
 implicit none
 type(fmr_production_application_config_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water,initial,badwater
 type(matrix_solute_state_t)::chemical,initial_c,badchemical
 type(b111_reactive_solute_substep_forcing_t)::p,pbad
 type(matrix_joint_result_t)::r
 real(real64)::k,dt,t0,t1,decay_total,max_residual
 integer::status,j,windows,first,last,accepted
 character(512)::mode,path,endpoint,arg
 call get_command_argument(1,mode);call get_command_argument(2,path);call get_command_argument(3,endpoint)
 call get_command_argument(4,arg);read(arg,*)windows
 call initialize_application_config(cfg,-75d0,k)
 cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
 cfg%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE
 cfg%tiles(1)%parameters%soil_temperature_active=.true.
 allocate(cfg%tiles(1)%parameters%soil_temperature,cfg%tiles(1)%initial_state%soil_temperature, &
  cfg%tiles(1)%base_forcing%soil_temperature)
 call initialize_soil_temperature_parameters(dz,disnod(1:numnod),cfg%tiles(1)%parameters%cofgen(2,:), &
  spread(.3d0,1,numnod),spread(.2d0,1,numnod),spread(.04d0,1,numnod),cfg%tiles(1)%parameters%soil_temperature,status)
 call require(status==0,'heat parameters')
 call initialize_soil_temperature_state([5d0,10d0,20d0,35d0],cfg%tiles(1)%initial_state%soil_temperature,status)
 call require(status==0,'nonuniform thermal owner')
 cfg%tiles(1)%base_forcing%top_flux=0d0;cfg%tiles(1)%base_forcing%bottom_flux=-.1d0
 cfg%tiles(1)%base_forcing%drainage_flux_by_level=1d-4;cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0d0
 cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 cfg%numerical%model_temporal_indicator_budget_available=.true.;cfg%numerical%model_temporal_indicator_budget=1d-6
 cfg%numerical%transaction%temporal_tolerance=0d0
 cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=10000
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%parameter_ref=1;column%state_handle=1;column%forcing_handle=1;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call parameters(p)
 call backend%initialize(top)
 if(trim(mode)=='reject')then
  call read_matrix_thermal_restart(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   cfg%tiles(1)%parameters,p,water,chemical,status)
  call require(status/=0.and..not.water%ready().and..not.chemical%ready(),'invalid generation atomic reject')
  print '(A)','THERMAL_INVALID_RESTART=PASS';stop
 end if
 if(trim(mode)=='resume')then
  call read_matrix_thermal_restart(trim(path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
   cfg%tiles(1)%parameters,p,water,chemical,status)
  call require(status==0,'fresh-process complete thermal reconstruction')
  first=windows/2+1
 else
  call initialize_owners(water,chemical,p)
  first=1
 end if
 last=windows
 if(trim(mode)=='split')last=windows/2
 decay_total=0d0;max_residual=0d0;accepted=0
 if(trim(mode)=='controls')then
  initial=water;initial_c=chemical
  cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=30d0
  pbad=p;pbad%decpot=1d7
  call initialize_matrix_solute(pbad,9001_int64,0d0,cfg%tiles(1)%initial_state%water_content, &
   [.2d0,.3d0,.4d0,.5d0],badchemical,status)
  call require(status==0,'overdraw parameters valid')
  badwater=water
  call write_matrix_thermal_restart(trim(endpoint)//'.before',column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,badwater,badchemical,status);call require(status==0,'before rejected joint generation')
  call run_matrix_thermal_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,badwater, &
   cfg%tiles(1)%base_forcing,cfg%numerical,badchemical,0d0,.001d0,r)
  call require(r%status==JOINT_CHEMICAL_REJECTED,'chemical failure rejects staged heat and water')
  call write_matrix_thermal_restart(trim(endpoint)//'.after',column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,badwater,badchemical,status);call require(status==0,'unchanged rejected joint generation')
  call run_matrix_thermal_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,badwater, &
   cfg%tiles(1)%base_forcing,cfg%numerical,badchemical,0d0,1d-9,r)
  call require(r%status==0,'smaller physical retry')
  block
   type(fmr_b110_physical_forcing_t)::invalid
   invalid=cfg%tiles(1)%base_forcing;invalid%root_extraction_sink=-1d0
   call run_matrix_thermal_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
    invalid,cfg%numerical,chemical,0d0,.001d0,r)
   call require(r%status/=0,'invalid water rejected')
   call write_matrix_thermal_restart(trim(endpoint)//'.hydraulic',column,cfg%tiles(1)%template,670001_int64, &
    cfg%tiles(1)%parameters,water,chemical,status);call require(status==0,'hydraulic rejection serializable')
   call write_matrix_thermal_restart(trim(endpoint)//'.initial',column,cfg%tiles(1)%template,670001_int64, &
    cfg%tiles(1)%parameters,initial,initial_c,status);call require(status==0,'initial serializable')
  end block
  ! Source SWHEA=0 branch: actual heat may evolve, decay remains zero.
  pbad=p;pbad%temperature_active=.false.
  call initialize_owners(badwater,badchemical,pbad)
  call checked_interval(badwater,badchemical,0d0,.001d0,pbad)
  call require(r%chemical%decay_out==0d0,'historical heat-off zero factor')
  print '(A)','THERMAL_REJECTION_RETRY_HEAT_OFF=PASS';stop
 end if
 do j=first,last
  t0=.002d0*real(j-1,real64)/real(windows,real64);t1=.002d0*real(j,real64)/real(windows,real64)
  cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=5d0
  if(j>windows/2)cfg%tiles(1)%base_forcing%soil_temperature%prescribed_surface_temperature_c=30d0
  call checked_interval(water,chemical,t0,t1,p)
  decay_total=decay_total+r%chemical%decay_out;max_residual=max(max_residual,abs(r%chemical%residual))
  accepted=accepted+r%chemical%completed_substeps
 end do
 if(trim(mode)=='split')then
  call write_matrix_thermal_restart(trim(path),column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,water,chemical,status)
 else
  call write_matrix_thermal_restart(trim(endpoint),column,cfg%tiles(1)%template,670001_int64, &
   cfg%tiles(1)%parameters,water,chemical,status)
 end if
 call require(status==0,'publish complete thermal generation')
 print '(A,I0)','ACCEPTED=',accepted
 print '(A,ES25.17)','DECAY=',decay_total
 print '(A,ES25.17)','MAX_SOLUTE_RESIDUAL=',max_residual
 print '(A)','THERMAL_PHYSICAL_LITERAL_RESTART=PASS'
contains
 subroutine initialize_owners(w,c,f)
  type(kernel_committed_state_t),intent(out)::w
  type(matrix_solute_state_t),intent(out)::c
  type(b111_reactive_solute_substep_forcing_t),intent(in)::f
  type(kernel_committed_state_t)::tmp
  class(transaction_state_t),allocatable::physical
  logical::ok
  call fmr_new_b110_temporal_indicator_committed_state(tmp,column%column_id,cfg%tiles(1)%initial_state,0d0,ok, &
   spread(0d0,1,numnod));call require(ok,'initial temporal carrier')
  call tmp%snapshot(physical,ok);call require(ok,'initial detached carrier')
  call w%initialize(column%column_id,physical,ok,0d0,cfg%tiles(1)%parameters);call require(ok,'initial certified heat water')
  call initialize_matrix_solute(f,9001_int64,0d0,cfg%tiles(1)%initial_state%water_content, &
   [.2d0,.3d0,.4d0,.5d0],c,status);call require(status==0,'initial chemical owner')
  call require(matrix_thermal_states_match(w,c),'initial joint match')
 end subroutine
 subroutine checked_interval(w,c,a,b,f)
  type(kernel_committed_state_t),intent(inout)::w
  type(matrix_solute_state_t),intent(inout)::c
  real(real64),intent(in)::a,b
  type(b111_reactive_solute_substep_forcing_t),intent(in)::f
  class(transaction_state_t),allocatable::physical
  type(soil_temperature_field_view_t)::heat
  type(fmr_serialized_physical_observation_t)::obs
  type(b111_reactive_solute_substep_forcing_t)::oracle,config_after
  type(mobile_salt_state_t)::m
  type(solute_compartment_state_t)::s
  real(real64),allocatable::theta(:),conc(:),mass(:),water0(:),q(:)
  real(real64)::time,dec,ein,eout,expected_decay,water_residual
  integer(int64)::rev,id
  integer::i,h,code
  logical::ok
  call c%snapshot(time,theta,m,s,rev);conc=m%concentration_mg_cm3;mass=m%mass_mg_cm2+s%sorbed_matrix_mass
  water0=theta
  call run_matrix_thermal_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w, &
   cfg%tiles(1)%base_forcing,cfg%numerical,c,a,b,r)
  if(r%status/=0)print *,'DIAGNOSTIC',r%status,r%water%status,r%chemical%status
  call require(r%status==JOINT_OK,'real coupled interval')
  call w%snapshot(physical,ok);call require(ok,'staged heat published')
  select type(physical)
  class is(fmr_b110_physical_state_t)
   call build_soil_temperature_field_view(physical%soil_temperature,heat,code)
  end select
  call require(code==0,'actual endpoint temperature')
  call require(maxval(abs(heat%temperature_c-f%temperature_c))>1d0,'actual profile differs from configured constant')
  oracle=f;oracle%temperature_c=heat%temperature_c
  obs=backend%observation();expected_decay=0d0;water_residual=0d0
  allocate(q(numnod+1))
  do h=1,size(obs%accepted_water_flux_substeps)
   associate(t=>obs%accepted_water_flux_substeps(h))
    oracle%dt_day=t%t1-t%t0;oracle%theta=t%water_end;oracle%theta_previous=t%water_start
    q(1)=t%top_flux
    do i=1,numnod
     q(i+1)=q(i)+(t%water_end(i)-t%water_start(i))*dz(i)/oracle%dt_day-t%net_node_source(i)
    end do
    water_residual=water_residual+sum(dz*(t%water_end-t%water_start))- &
     oracle%dt_day*(t%bottom_flux-t%top_flux+sum(t%net_node_source))
    oracle%q_face_up_cm_day=q;oracle%root_sink_cm_day=t%root_sink;oracle%qdra_cm_day=t%drainage_sink_by_level
    call literal_step(oracle,conc,mass,dec,ein,eout);expected_decay=expected_decay+dec
   end associate
  end do
  call c%snapshot(time,theta,m,s,rev)
  call require(maxval(abs(m%concentration_mg_cm3-conc))<1d-12,'literal source concentration at dynamic heat')
  call require(maxval(abs(m%mass_mg_cm2+s%sorbed_matrix_mass-mass))<1d-12,'literal source inventory')
  call require(abs(r%chemical%decay_out-expected_decay)<1d-12,'literal temperature moisture depth decay ledger')
  call require(abs(water_residual)<1d-10.and.abs(r%chemical%residual)<1d-11,'independent joint water/solute balance')
  call c%configuration(config_after,id)
  call require(all(matrix_parameter_vector(config_after)==matrix_parameter_vector(f)),'immutable chemical configuration')
 end subroutine
 subroutine parameters(f)
  type(b111_reactive_solute_substep_forcing_t),intent(out)::f
  f%dz_cm=dz;f%theta=cfg%tiles(1)%initial_state%water_content
  f%bulk_density=spread(1.3d0,1,numnod);f%kf=spread(.2d0,1,numnod)
  f%temperature_active=.true.;f%temperature_c=spread(20d0,1,numnod)
  f%gampar=spread(.05d0,1,numnod);f%rtheta=spread(.3d0,1,numnod)
  f%bexp=spread(1d0,1,numnod);f%decpot=spread(.02d0,1,numnod);f%fdepth=spread(1d0,1,numnod)
  f%face_distance_cm=disnod(2:numnod)
  f%face_left_weight=.5d0*dz(2:numnod)/f%face_distance_cm;f%face_right_weight=.5d0*dz(1:numnod-1)/f%face_distance_cm
  f%theta_sat_left=cfg%tiles(1)%parameters%cofgen(2,1:numnod-1)
  f%dispersivity_cm=spread(.2d0,1,numnod-1);f%molecular_diffusion_cm2_day=.05d0;f%tscf=.5d0
  f%cdrain_mg_cm3=.4d0;f%cseep_mg_cm3=.3d0
 end subroutine
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print '(A)','FAIL '//label;error stop 1;end if
 end subroutine
 include 'matrix_fixture.inc'
end program
