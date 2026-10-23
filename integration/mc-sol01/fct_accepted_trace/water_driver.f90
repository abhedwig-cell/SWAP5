program accepted_water_export
 use iso_fortran_env,only:real64,int64
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_kernel_transactions
 use mod_fixed_flux_top_boundary_provider
 use mod_b110_default_mvg_provider
 use mod_transaction_reference,only:TX_TEMPORAL_MODEL_CERTIFICATE
 use mod_solute_water_face_flux_reconstruction
 use MOD_grid,only:numnod,z,dz,disnod
 use solute_column_context,only:initialize_column_context
 implicit none
 ! Local input holder only. All physical state, forcing, parameters, solver and
 ! transaction types below are the real production interfaces.
 type tile_input_t
  integer(int64)::tile_id,ledger_id
  type(fmr_template_t)::template
  type(fmr_b110_physical_parameters_t)::parameters
  type(fmr_b110_physical_state_t)::initial_state
  type(fmr_b110_physical_forcing_t)::base_forcing
 end type
 type input_t
  real(real64)::initial_time
  type(canonical_numerical_config_t)::numerical
  type(tile_input_t),allocatable::tiles(:)
 end type
 type(input_t)::cfg
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(fmr_logical_column_t)::column
 type(kernel_committed_state_t)::water
 type(kernel_checkpoint_t)::cp
 type(kernel_candidate_state_t)::candidate
 type(kernel_result_t)::result
 type(kernel_diagnostics_t)::diag
 type(fmr_serialized_physical_observation_t)::obs
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::provider
 real(real64),allocatable::heads(:),theta(:),conduct(:),capacity(:),derivative(:),faces(:)
 real(real64)::factor,k0,closure,maxclosure,maxchange
 integer::i,j,code,u,count,nodes
 logical::ok,committed
 character(512)::arg,path
 call get_command_argument(1,arg);read(arg,*)nodes
 call get_command_argument(2,arg);read(arg,*)factor
 call get_command_argument(3,path)
 call initialize_column_context(spread(40d0/nodes,1,nodes))
 allocate(cfg%tiles(1));cfg%initial_time=0d0
 cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
 cfg%numerical%model_temporal_indicator_budget_available=.true.
 cfg%numerical%model_temporal_indicator_budget=1d-3
 cfg%numerical%transaction%temporal_tolerance=0d0
 cfg%numerical%transaction%mass_tolerance=1d-10
 cfg%numerical%transaction%retry_scale=.5d0;cfg%numerical%transaction%max_retries=30
 cfg%numerical%max_committed_substeps=100000;cfg%numerical%progress_tolerance=0d0
 associate(tile=>cfg%tiles(1))
  tile%tile_id=660101_int64;tile%ledger_id=760101_int64
  tile%template%template_id=660201_int64;tile%template%physics_topology_id=660210_int64
  tile%template%vertical_layout_id=660220_int64;tile%template%state_layout_id=660230_int64
  tile%template%solver_interface_id=660240_int64;tile%template%optional_state_layout_id=0_int64
  tile%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  tile%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  associate(p=>tile%parameters)
   p%parameter_set_id=670001_int64;p%active_nodes=numnod
   p%z=z;p%dz=dz;p%node_distance=disnod(:numnod)
   allocate(p%cofgen(24,numnod));p%cofgen=0d0
   p%cofgen(1,:)=.032d0;p%cofgen(2,:)=.423d0;p%cofgen(3,:)=4.75d0
   p%cofgen(4,:)=.0135d0;p%cofgen(5,:)=.365d0;p%cofgen(6,:)=1.455d0
   p%cofgen(7,:)=1d0-1d0/1.455d0;p%cofgen(8,:)=.0135d0
   p%cofgen(10,:)=4.75d0;p%cofgen(11,:)=.999d0;p%cofgen(12,:)=.99d0*4.75d0
   p%cofgen(22,:)=-1d6;p%cofgen(23,:)=1d-12
   p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
   p%max_iterations=8;p%max_backtracking=4
   call initialize_b110_default_mvg_parameters(hp,p%cofgen)
  end associate
  call bind_b110_default_mvg_provider(provider,hp,.1d0)
  allocate(heads(numnod),theta(numnod),conduct(numnod),capacity(numnod),derivative(numnod));heads=-75d0
  call provider%evaluate(heads,theta,conduct,capacity,derivative);k0=conduct(1)
  tile%initial_state%active_nodes=numnod
  tile%initial_state%pressure_head=heads;tile%initial_state%water_content=theta
  tile%initial_state%ponding_depth=0d0;tile%initial_state%groundwater_level=-100d0
  tile%base_forcing%top_flux=-factor*k0;tile%base_forcing%top_head=-75d0
  tile%base_forcing%bottom_flux=-k0;tile%base_forcing%bottom_head=-100d0
  allocate(tile%base_forcing%drainage_flux_by_level(1,numnod));tile%base_forcing%drainage_flux_by_level=0d0
  tile%base_forcing%subsurface_irrigation_source=0d0*theta;tile%base_forcing%root_extraction_sink=0d0*theta
 end associate
 column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
 column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 call backend%initialize(top)
 call fmr_new_b110_temporal_indicator_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,0d0,ok,0d0*theta)
 if(.not.ok)error stop 'initial water'
 open(newunit=u,file=trim(path),status='new',action='write');write(u,*)numnod
 count=0;maxclosure=0d0;maxchange=0d0
 do i=1,20
  call water%capture_checkpoint(cp,ok);if(.not.ok)error stop 'checkpoint'
  call backend%run_trial(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,cfg%numerical,(i-1)*.1d0,i*.1d0,cp,result,candidate,diag,trace_accepted_water_flux_substeps=.true.)
  if(.not.result%completed.or..not.candidate%ready())then
   print *,'WATER_FAILED',i,result%status;error stop 'water trial'
  end if
  obs=backend%observation()
  if(.not.obs%accepted_water_flux_trace_available)error stop 'trace'
  call backend%commit_trial_candidate(water,candidate,diag,committed,code)
  if(.not.committed)error stop 'water commit'
  do j=1,size(obs%accepted_water_flux_substeps)
   associate(s=>obs%accepted_water_flux_substeps(j))
    if(any(s%net_node_source/=0d0).or.any(s%root_sink/=0d0).or.any(s%drainage_sink_by_level/=0d0))error stop 'active sink'
    call reconstruct_interval_water_face_flux(dz,s%water_start,s%water_end,s%net_node_source, &
     -s%top_flux,-s%bottom_flux,s%t1-s%t0,1d-10/(s%t1-s%t0),faces,closure,code)
    if(code/=WATER_FACE_FLUX_OK.or.any(faces<0d0))error stop 'carrier domain'
    count=count+1;maxclosure=max(maxclosure,abs(closure*(s%t1-s%t0)))
    maxchange=max(maxchange,maxval(abs(s%water_end-s%water_start)))
    write(u,'(*(ES25.16E3,1X))')s%t0,s%t1,-s%top_flux,-s%bottom_flux,s%water_start,s%water_end,faces
   end associate
  end do
 end do
 close(u)
 if(maxchange<=1d-12)error stop 'no changing water'
 print '(A,1X,2(I0,1X),4(ES25.16E3,1X))','ACCEPTED_TRACE',numnod,count,factor,k0,maxclosure,maxchange
end program
