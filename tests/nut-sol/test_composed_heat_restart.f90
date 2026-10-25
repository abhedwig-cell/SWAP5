program test_composed_heat_restart
 use iso_fortran_env,only:real64,int64
 use mod_fmr_serialized_reference_backend
 use mod_fmr_runtime_core
 use mod_kernel_transactions
 use mod_transaction_reference,only:transaction_state_t
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
 type(kernel_committed_state_t)::w
 type(matrix_solute_state_t)::c
 type(b111_reactive_solute_substep_forcing_t)::f
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::hyd
 type(boesten_evaporation_state_t)::pair
 class(transaction_state_t),allocatable::physical
 real(real64)::k(4),cap(4),dk(4)
 integer::code
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
 if(trim(mode)=='create')then
  pair%spev=2d0;pair%saev=.5d0
  call fmr_new_b110_boesten_evaporation_committed_state(w,column%column_id,s,pair,0d0,ok,p);call require(ok,'certified pair and heat')
  call initialize_matrix_solute(f,9001_int64,0d0,s%water_content,[.2d0,.3d0,.4d0,.5d0],c,code);call require(code==0,'chemistry')
 else
  if(trim(mode)=='reject-parameter')p%boesten_evaporation%cofred=.8d0
  call read_pond_thermal_restart(trim(path),column,t,670001_int64,9001_int64,p,f,w,c,code)
  if(index(trim(mode),'reject')==1)then
   call require(code/=0.and..not.w%ready().and..not.c%ready(),'atomic invalid restart')
   print '(A)','COMPOSED_RESTART_REJECTION_PASS';stop
  end if
  call require(code==0,'read exact generation')
 end if
 call w%snapshot(physical,ok);call require(ok,'snapshot')
 select type(q=>physical)
 type is(fmr_b110_boesten_evaporation_state_t)
  call require(q%boesten_evaporation%spev==2d0.and.q%boesten_evaporation%saev==.5d0,'exact pair')
  call require(allocated(q%soil_temperature),'retained heat')
 class default
  error stop 'lost Boesten owner'
 end select
 if(trim(mode)=='create')target=path
 call write_pond_thermal_restart(trim(target),column,t,670001_int64,p,w,c,code);call require(code==0,'write complete generation')
 print '(A)','COMPOSED_RESTART_PAIR_AND_HEAT_PASS'
contains
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print '(A)',label;error stop 1;end if
 end subroutine
end program
