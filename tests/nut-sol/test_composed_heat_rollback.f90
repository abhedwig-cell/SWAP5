program test_composed_heat_rollback
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_fixed_flux_top_boundary_provider
 use mod_b111_persistent_pond,only:pond_step_t
 use mod_fmr_b111_pond_thermal_application
 use mod_matrix_joint_restart_file,only:write_matrix_joint_restart_file
 use mod_fmr_b111_matrix_joint_application,only:matrix_joint_result_t,JOINT_CHEMICAL_REJECTED,JOINT_OK
 use iso_fortran_env,only:real64,int64
 use mod_fmr_serialized_reference_backend
 use mod_fmr_runtime_core
 use mod_kernel_transactions
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
 use mod_b111_reactive_solute_substep
 use mod_fmr_b111_matrix_solute_route
 use mod_pond_thermal_restart_file
 use mod_soil_temperature_contract
 use mod_restricted_soil_temperature,only:initialize_soil_temperature_parameters
 use mod_restricted_surface_evaporation,only:boesten_evaporation_state_t
 use mod_b110_default_mvg_provider
 use MOD_grid,only:numnod,z,dz,disnod
 use solute_column_context,only:initialize_column_context
 implicit none
 type(fmr_b110_physical_parameters_t)::p
 type(fmr_b110_physical_state_t)::s
 type(fmr_template_t)::t
 type(fmr_logical_column_t)::column
 type(fmr_b110_physical_forcing_t)::forcing
 type(canonical_numerical_config_t)::numerical
 type(fmr_serialized_reference_backend_t)::backend
 type(fixed_flux_top_boundary_provider_t),target::top
 type(pond_step_t)::supply
 type(matrix_joint_result_t)::result
 type(kernel_committed_state_t)::w
 type(matrix_solute_state_t)::c
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(boesten_evaporation_state_t)::pair
 class(transaction_state_t),allocatable::physical
 real(real64)::k(4),cap(4),dk(4)
 integer::code,u
 logical::ok
 character(512)::mode,path,target
 call get_command_argument(1,mode);call get_command_argument(2,path);call get_command_argument(3,target)
 call initialize_column_context([.5d0,.5d0,1d0,1d0])
 p%parameter_set_id=670001_int64;p%active_nodes=4;p%z=z;p%dz=dz;p%node_distance=disnod(:4)
 allocate(p%cofgen(24,4));p%cofgen=0d0;p%cofgen(1,:)=.032d0;p%cofgen(2,:)=.423d0;p%cofgen(3,:)=.00475d0
 p%cofgen(4,:)=.0135d0;p%cofgen(5,:)=.365d0;p%cofgen(6,:)=1.455d0;p%cofgen(7,:)=1d0-1d0/1.455d0
 p%cofgen(8,:)=.0135d0;p%cofgen(10,:)=-999d0;p%cofgen(22,:)=-1d6;p%cofgen(23,:)=1d-12
 p%soil_temperature_active=.true.;p%boesten_evaporation_active=.true.
 allocate(p%soil_temperature,p%boesten_evaporation,s%soil_temperature);p%boesten_evaporation%cofred=.79d0
 call initialize_soil_temperature_parameters(dz,disnod(:4),p%cofgen(2,:),spread(.3d0,1,4),spread(.2d0,1,4), &
  spread(.04d0,1,4),p%soil_temperature,code);call require(code==0,'heat parameters')
 call initialize_soil_temperature_state([5d0,10d0,20d0,30d0],s%soil_temperature,code);call require(code==0,'heat state')
 s%active_nodes=4;s%pressure_head=spread(-75d0,1,4);allocate(s%water_content(4));s%ponding_depth=.1d0;s%groundwater_level=-2d0
 call initialize_b110_default_mvg_parameters(hp,p%cofgen);call bind_b110_default_mvg_provider(hyd,hp,.001d0)
 call hyd%evaluate(s%pressure_head,s%water_content,k,cap,dk)
 f%dz_cm=dz;f%theta=s%water_content;f%bulk_density=spread(1.3d0,1,4);f%kf=spread(.2d0,1,4)
 f%frexp=1d0;f%temperature_active=.true.;f%temperature_c=spread(20d0,1,4)
 f%gampar=spread(.05d0,1,4);f%rtheta=spread(.3d0,1,4);f%bexp=spread(1d0,1,4)
 f%decpot=spread(.02d0,1,4);f%fdepth=spread(1d0,1,4);f%face_distance_cm=disnod(2:4)
 f%face_left_weight=.5d0*dz(2:4)/f%face_distance_cm;f%face_right_weight=.5d0*dz(1:3)/f%face_distance_cm
 f%theta_sat_left=p%cofgen(2,1:3);f%dispersivity_cm=spread(.2d0,1,3);f%molecular_diffusion_cm2_day=.05d0;f%tscf=.5d0
 t%template_id=660200_int64;t%vertical_layout_id=660220_int64
 t%state_layout_id=660230_int64;t%solver_interface_id=660240_int64;t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION
 column%column_id=71;column%template_id=t%template_id;column%parameter_ref=1;column%state_handle=1
 column%forcing_handle=1;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 pair%spev=2d0;pair%saev=.5d0
 p%bottom_mode=2;p%swkimpl=0;p%swkmean=1
 t%physics_topology_id=660210_int64
 call fmr_new_b110_boesten_evaporation_committed_state(w,column%column_id,s,pair,0d0,ok,p)
 call require(ok,'certified rollback owner')
 f%decpot=spread(1d6,1,4)
 call initialize_matrix_solute(f,9001_int64,0d0,s%water_content,[.2d0,.3d0,.4d0,.5d0],c,code)
 call require(code==0,'valid overdraw configuration')
 allocate(forcing%boesten_evaporation,forcing%soil_temperature,forcing%drainage_flux_by_level(1,4))
 forcing%drainage_flux_by_level=0d0;forcing%root_extraction_sink=spread(0d0,1,4)
 forcing%subsurface_irrigation_source=spread(0d0,1,4);forcing%bottom_flux=-.0001d0
 forcing%boesten_evaporation%potential_bare_soil_evaporation_cm_per_day=.1d0
 forcing%boesten_evaporation%potential_pond_evaporation_cm_per_day=.1d0
 forcing%boesten_evaporation%ponding_max_cm=1d0
 forcing%soil_temperature%prescribed_surface_temperature_c=30d0
 numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
 numerical%transaction%temporal_tolerance=.01d0;numerical%transaction%mass_tolerance=1d-10
 numerical%transaction%max_retries=30;numerical%max_committed_substeps=10000
 call backend%initialize(top)
 call write_pond_thermal_restart(trim(target)//'.before',column,t,670001_int64,p,w,c,code)
 call require(code==0,'before rejected composition')
 call read_pond_thermal_restart(trim(target)//'.before',column,t,670001_int64,9001_int64,p,f,w,c,code)
 call require(code/=0.and.w%ready().and.c%ready(),'initialized destinations reject without mutation')
 call write_pond_thermal_restart(trim(target)//'.initialized',column,t,670001_int64,p,w,c,code)
 call require(code==0,'initialized destinations remain serializable')
 open(newunit=u,file=trim(target)//'.legacy_target',status='new',action='write')
 write(u,'(A)')'PRESERVED';close(u)
 call write_matrix_joint_restart_file(trim(target)//'.legacy_target',column,t,670001_int64,w,c,code,allow_surface_mass=.true.)
 call require(code/=0,'nonthermal writer must not drop heat from Boesten owner')
 supply%t0=0d0;supply%t1=.001d0
 call run_pond_thermal_interval(backend,column,t,p,w,forcing,numerical,c,supply,0d0,.001d0,result)
 if(result%status/=JOINT_CHEMICAL_REJECTED)print *,'ROLLBACK_DIAGNOSTIC',result%status,result%water%status,result%chemical%status
 call require(result%status==JOINT_CHEMICAL_REJECTED,'reject chemistry after real staged water heat and Boesten')
 call write_pond_thermal_restart(trim(target)//'.after',column,t,670001_int64,p,w,c,code)
 call require(code==0,'after rejected composition')
 supply%t1=1d-9
 call run_pond_thermal_interval(backend,column,t,p,w,forcing,numerical,c,supply,0d0,1d-9,result)
 call require(result%status==JOINT_OK,'smaller physical retry')
 call write_pond_thermal_restart(trim(target)//'.retry',column,t,670001_int64,p,w,c,code)
 call require(code==0,'accepted retry generation')
 print '(A)','COMPOSED_WATER_HEAT_BOESTEN_CHEMICAL_ROLLBACK_RETRY_PASS'

contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print '(A)',label;error stop 1;end if
 end subroutine
end program
