program test_crop_root_transaction
 use iso_fortran_env,only:real64,int64
 use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_EXTERNAL_FULL_HALF
 use mod_canonical_contracts,only:canonical_numerical_config_t
 use mod_kernel_transactions,only:kernel_committed_state_t
 use MOD_grid,only:numnod,z,dz,disnod
 use solute_column_context,only:initialize_column_context
 use mod_fmr_runtime_core
 use mod_fmr_serialized_reference_backend
 use mod_fixed_flux_top_boundary_provider
 use mod_b110_default_mvg_provider
 use mod_fmr_root_uptake_process_binding
 use mod_root_water_uptake_process
 use mod_b111_reactive_solute_substep
 use mod_fmr_b111_matrix_solute_route
 use mod_fmr_b111_matrix_joint_application
 use mod_fmr_b111_pond_joint_application
 use mod_b111_persistent_pond
 use mod_matrix_joint_restart_file
 implicit none
 type(fmr_b110_physical_parameters_t),target::p
 type(fmr_b110_physical_state_t)::initial
 type(fmr_b110_physical_forcing_t)::forcing
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t)::provider
 type(fmr_logical_column_t)::column
 type(fmr_template_t)::template
 type(canonical_numerical_config_t)::config
 type(fmr_serialized_reference_backend_t)::backend,fresh
 type(fixed_flux_top_boundary_provider_t),target::top
 type(kernel_committed_state_t)::water,base,other
 type(matrix_solute_state_t)::chemical,original,other_chemical
 type(b111_reactive_solute_substep_forcing_t)::chemistry
 type(matrix_joint_result_t)::result
 type(pond_step_t)::supply,invalid
 type(root_water_uptake_parameters_t)::root_parameters
 type(fmr_root_uptake_crop_input_t)::crop
 type(root_water_uptake_flux_result_t)::fluxes,again
 type(root_water_uptake_diagnostics_t)::diagnostics
 type(fmr_root_uptake_binding_diagnostics_t)::binding
 real(real64),allocatable::k(:),c(:),dk(:)
 logical::ok
 integer::s
 call initialize_column_context([1d0,2d0])
 p%parameter_set_id=670001_int64;p%active_nodes=numnod
 p%z=z;p%dz=dz;p%node_distance=disnod(:numnod)
 allocate(p%cofgen(24,numnod));p%cofgen=0d0
 p%cofgen(1,:)=.032d0;p%cofgen(2,:)=.423d0;p%cofgen(3,:)=.00475d0
 p%cofgen(4,:)=.0135d0;p%cofgen(5,:)=.365d0;p%cofgen(6,:)=1.455d0
 p%cofgen(7,:)=1d0-1d0/1.455d0;p%cofgen(8,:)=.0135d0;p%cofgen(10,:)=.00475d0
 p%cofgen(11,:)=.999d0;p%cofgen(12,:)=.99d0*.00475d0;p%cofgen(22,:)=-1d6;p%cofgen(23,:)=1d-12
 p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%max_iterations=8;p%max_backtracking=4;p%root_extraction_active=.true.
 initial%active_nodes=numnod;initial%pressure_head=[-75d0,-75d0]
 allocate(initial%water_content(numnod),k(numnod),c(numnod),dk(numnod))
 call initialize_b110_default_mvg_parameters(hp,p%cofgen)
 call bind_b110_default_mvg_provider(provider,hp,.001d0)
 call provider%evaluate(initial%pressure_head,initial%water_content,k,c,dk)
 initial%ponding_depth=0d0;initial%groundwater_level=-3d0
 forcing%top_flux=0d0;forcing%top_head=-75d0;forcing%bottom_flux=0d0
 allocate(forcing%drainage_flux_by_level(1,numnod));forcing%drainage_flux_by_level=0d0
 forcing%root_extraction_sink=[0d0,0d0];forcing%subsurface_irrigation_source=[0d0,0d0]
 allocate(forcing%pond_input);forcing%pond_input%ponding_max_cm=1d6
 chemistry%dz_cm=dz;chemistry%theta=initial%water_content
 chemistry%bulk_density=[1.3d0,1.3d0];chemistry%kf=[.2d0,.2d0];chemistry%frexp=.5d0
 chemistry%temperature_c=[0d0,0d0];chemistry%gampar=[0d0,0d0];chemistry%rtheta=[.3d0,.3d0]
 chemistry%bexp=[1d0,1d0];chemistry%decpot=[0d0,0d0];chemistry%fdepth=[1d0,1d0]
 chemistry%face_distance_cm=disnod(2:numnod)
 chemistry%face_left_weight=.5d0*dz(2:numnod)/chemistry%face_distance_cm
 chemistry%face_right_weight=.5d0*dz(:numnod-1)/chemistry%face_distance_cm
 chemistry%theta_sat_left=[.423d0];chemistry%dispersivity_cm=[.2d0]
 chemistry%molecular_diffusion_cm2_day=.05d0;chemistry%tscf=.5d0
 column%column_id=660101_int64;column%template_id=660201_int64
 column%parameter_ref=1;column%state_handle=1;column%forcing_handle=1;column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 template%template_id=column%template_id;template%physics_topology_id=660210_int64
 template%vertical_layout_id=660220_int64;template%state_layout_id=660230_int64;template%solver_interface_id=660240_int64
 template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
 config%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF;config%transaction%temporal_tolerance=1d-4
 config%transaction%mass_tolerance=1d-10;config%transaction%max_retries=30;config%max_committed_substeps=100000
 call backend%initialize(top);call fresh%initialize(top)
 call fmr_new_b110_committed_state(water,column%column_id,initial,0d0,ok);call check(ok,'initialize water')
 call initialize_matrix_solute(chemistry,9001_int64,0d0,initial%water_content,[.2d0,.4d0],chemical,s)
 call check(s==MATRIX_OK,'initialize solute')
 base=water;original=chemical;other=water;other_chemical=chemical
 root_parameters=root_water_uptake_parameters_t(numnod,-1000d0,-500d0,-16000d0,.1d0,.5d0)
 crop%crop_emerged=.true.;crop%rooted_nodes=2;crop%potential_transpiration=.01d0
 crop%cumulative_root_fraction=[0d0,.5d0,1d0]
 call fmr_evaluate_committed_root_uptake(water,root_parameters,crop,fluxes,diagnostics,binding)
 call check(binding%status==FMR_ROOT_UPTAKE_BINDING_OK,'root evaluation')
 call compare_water(water,base)
 forcing%root_extraction_sink=fluxes%root_extraction_sink
 supply=pond_step_t();supply%t0=0d0;supply%t1=.001d0
 invalid=supply;invalid%rain_c=-1d0
 call run_pond_joint_interval(backend,column,template,p,water,forcing,config,chemical,invalid,0d0,.001d0,result)
 call check(result%status==JOINT_CHEMICAL_REJECTED.and.result%water%completed,'chemical rejects completed root/water trial')
 call compare_water(water,base)
 call write_matrix_joint_restart_file('rejected.bin',column,template,p%parameter_set_id,water,chemical,s,allow_surface_mass=.true.)
 call check(s==JOINT_OK,'rejected snapshot')
 call write_matrix_joint_restart_file('original.bin',column,template,p%parameter_set_id,base,original,s,allow_surface_mass=.true.)
 call check(s==JOINT_OK,'original snapshot')
 call fmr_evaluate_committed_root_uptake(water,root_parameters,crop,again,diagnostics,binding)
 call check(binding%status==0.and.all(again%root_extraction_sink==fluxes%root_extraction_sink),'retry root identity')
 call run_pond_joint_interval(backend,column,template,p,water,forcing,config,chemical,supply,0d0,.001d0,result)
 call check(result%status==JOINT_OK,'retry accepts')
 call check(abs(result%water%mass%residual)<1d-10.and.abs(result%chemical%residual)<1d-10,'retry balances')
 call write_matrix_joint_restart_file('retry.bin',column,template,p%parameter_set_id,water,chemical,s,allow_surface_mass=.true.)
 call check(s==JOINT_OK,'retry snapshot')
 call run_pond_joint_interval(fresh,column,template,p,other,forcing,config,other_chemical,supply,0d0,.001d0,result)
 call check(result%status==JOINT_OK,'fresh accepts')
 call write_matrix_joint_restart_file('fresh.bin',column,template,p%parameter_set_id,other,other_chemical,s,allow_surface_mass=.true.)
 call check(s==JOINT_OK,'fresh snapshot')
 print '(A)','CROP_ROOT_COMMITTED_NONMUTATION_CHEMICAL_REJECT_RETRY_PASS'
contains
 subroutine check(condition,message)
  logical,intent(in)::condition
  character(*),intent(in)::message
  if(.not.condition)then
   print *,message;error stop 1
  end if
 end subroutine
 subroutine compare_water(a,b)
  type(kernel_committed_state_t),intent(in)::a,b
  class(transaction_state_t),allocatable::x,y
  real(real64)::ta,tb
  logical::ok
  call a%current_time(ta,ok);call check(ok,'first clock')
  call b%current_time(tb,ok);call check(ok,'second clock')
  call check(ta==tb.and.a%current_revision()==b%current_revision(),'water identity')
  call a%snapshot(x,ok);call check(ok,'first state')
  call b%snapshot(y,ok);call check(ok,'second state')
  select type(x)
  type is(fmr_b110_physical_state_t)
   select type(y)
   type is(fmr_b110_physical_state_t)
    call check(all(x%pressure_head==y%pressure_head).and.all(x%water_content==y%water_content).and. &
      x%ponding_depth==y%ponding_depth,'root binding or rejection mutated water')
   class default
    error stop 1
   end select
  class default
   error stop 1
  end select
 end subroutine
end program
