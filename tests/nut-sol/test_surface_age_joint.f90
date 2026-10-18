program test_surface_age_joint
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
  use mod_b111_age_snapshot_disk
  use mod_b111_surface_age_trace_bridge,only:surface_age_source_ages_t
  use mod_canonical_contracts,only:canonical_numerical_config_t
  use mod_transaction_reference,only:TX_TEMPORAL_EXTERNAL_FULL_HALF
  use historical_age_oracle
  use mod_solute_water_face_flux_reconstruction
  use mod_solute_compartment_state,only:solute_compartment_state_t
  implicit none
  real(real64),parameter::T0=0d0,T1=1d-3,HARD_MASS_GATE=1d-10
  type(fmr_production_application_config_t)::cfg
  type(fmr_serialized_reference_backend_t)::backend
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::column
  type(kernel_committed_state_t)::water,w0
  type(age_state_t)::soil,s0
  type(surface_age_owner_t)::surface,a0
  type(age_joint_result_t)::result
  type(b111_age_tracer_substep_forcing_t)::p
  type(surface_age_source_ages_t)::ages,bad_ages
  type(canonical_numerical_config_t)::bad_config
  type(fmr_serialized_physical_observation_t)::obs
  real(real64)::k,t,depth,stock,initial_stock,initial_soil,final_soil,combined,scale,water_residual
  real(real64)::rain,irrigation,runon,infiltration,runoff,evaporation,expected_production
  real(real64),allocatable::theta(:)
  type(solute_compartment_state_t)::c
  integer(int64)::revision
  integer::status,j,u
  logical::ok
  character(512)::mode,restart_path,endpoint_path
  call get_command_argument(1,mode);call get_command_argument(2,restart_path);call get_command_argument(3,endpoint_path)
  call initialize_application_config(cfg,-75d0,k)
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  cfg%tiles(1)%initial_state%ponding_depth=0.5d0
  cfg%tiles(1)%parameters%cofgen(3,:)=cfg%tiles(1)%parameters%cofgen(3,:)*1d-3
  cfg%tiles(1)%parameters%cofgen(10,:)=cfg%tiles(1)%parameters%cofgen(10,:)*1d-3
  cfg%tiles(1)%parameters%cofgen(12,:)=cfg%tiles(1)%parameters%cofgen(12,:)*1d-3
  cfg%tiles(1)%base_forcing%top_flux=0d0
  cfg%tiles(1)%base_forcing%bottom_flux=-0.1d0
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=1d-4
  cfg%tiles(1)%base_forcing%root_extraction_sink=1d-4
  cfg%tiles(1)%parameters%root_extraction_active=.true.
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0d0
  allocate(cfg%tiles(1)%base_forcing%pond_input)
  associate(g=>cfg%tiles(1)%base_forcing%pond_input)
   g%rain_rate_cm_day=.25d0;g%irrigation_rate_cm_day=.25d0;g%runon_rate_cm_day=.5d0
   g%potential_pond_evaporation_cm_day=.05d0
   g%ponding_max_cm=.50001d0;g%runoff_resistance_day=.001d0
  end associate
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
  cfg%numerical%transaction%temporal_tolerance=1d-6
  cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=10000
  column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
  column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  ages%runon_age_day=7d0;ages%irrigation_age_day=2d0
  call parameters(p)
  call backend%initialize(top)
  if(trim(mode)=='resume'.or.trim(mode)=='reject')then
   call read_age_snapshot_disk(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
       8801_int64,p,water,soil,surface,status)
   if(trim(mode)=='reject')then
    call require(status/=0,'invalid snapshot rejected')
    call require(.not.water%ready().and..not.soil%ready(),'no partial disk restore')
    call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok)
    call require(.not.ok,'no partial surface restore')
    print '(A)','SURFACE_AGE_INVALID_SNAPSHOT=PASS'
    stop
   end if
   call require(status==0,'fresh process triplet restore')
  else
   call fmr_new_b110_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
   call require(ok,'actual Reference initial water')
   call initialize_age(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
       [(1d0+1d0*j,j=1,numnod)],soil,status)
   call require(status==AGE_OK,'initial soil age')
   call initialize_surface_age_owner(8801_int64,T0,.5d0,3d0,surface,status)
   call require(status==AGE_OWNER_OK,'nonzero pond age')
   w0=water;s0=soil;a0=surface
   ! Valid water trial followed by rejected age source must publish no owner.
   bad_ages=ages;bad_ages%runon_age_day=-1d0
   call step(T0,T1,bad_ages)
   call require(result%status==JOINT_CHEMICAL_REJECTED,'chemical rejection after hydraulic success')
   call compare_all(w0,s0,a0)
   ! A real numerical rejection, then a smaller valid retry.
   bad_config=cfg%numerical
   cfg%numerical%transaction%max_retries=0
   cfg%numerical%transaction%temporal_tolerance=1d-30
   call step(T0,1d0,ages)
   call require(result%status==JOINT_WATER_REJECTED,'numerical failure of long attempt')
   call compare_all(w0,s0,a0)
   call require(result%diagnostics%temporal_rejections+result%diagnostics%solver_rejections+ &
       result%diagnostics%mass_rejections>0,'actual numerical rejection diagnostic')
   print '(A,3I8)','REJECTED_NUMERICAL_TRIAL ',result%diagnostics%temporal_rejections, &
       result%diagnostics%solver_rejections,result%diagnostics%mass_rejections
   cfg%numerical=bad_config
   call refinement()
   call soil%snapshot(t,theta,c,revision);initial_soil=sum(c%age_amount)
   initial_stock=1.5d0
   call step(T0,T1,ages)
   if(result%status/=JOINT_OK)print *,'SURFACE_JOINT_DIAGNOSTIC',result%status,result%chemical%status, &
       result%chemical%process_status,result%water%status
   call require(result%status==JOINT_OK,'positive pond real coupled step')
   obs=backend%observation()
   rain=0d0;irrigation=0d0;runon=0d0;infiltration=0d0;runoff=0d0;evaporation=0d0;expected_production=0d0
   do j=1,size(obs%accepted_water_flux_substeps)
    associate(q=>obs%accepted_water_flux_substeps(j))
     rain=rain+q%converged_rain_rate_cm_day*(q%t1-q%t0)
     irrigation=irrigation+q%converged_irrigation_rate_cm_day*(q%t1-q%t0)
     runon=runon+q%converged_runon_rate_cm_day*(q%t1-q%t0)
     infiltration=infiltration-q%top_flux*(q%t1-q%t0)
     runoff=runoff+q%converged_runoff_depth_cm
     evaporation=evaporation+q%converged_pond_evaporation_cm_day*(q%t1-q%t0)
     expected_production=expected_production+.5d0*(q%pond_start_cm+q%pond_end_cm)*(q%t1-q%t0)
    end associate
   end do
   call require(min(rain,irrigation,runon,infiltration,runoff,evaporation)>0d0,'all six real fluxes positive')
   call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok)
   call soil%snapshot(t,theta,c,revision);final_soil=sum(c%age_amount)
   scale=max(1d0,stock,final_soil)
   water_residual=depth-.5d0-rain-irrigation-runon+infiltration+runoff+evaporation
   call require(abs(water_residual)<1d-10,'pond water balance cm')
   call require(abs(result%water%mass%residual)<1d-10,'joint hydraulic water balance cm')
   call require(abs(stock-initial_stock-result%chemical%surface_input-result%chemical%surface_production+ &
       result%chemical%infiltrated_age+result%chemical%surface_runoff)<1d-11*scale,'surface age closure cm day')
   call require(abs(result%chemical%surface_production-expected_production)<1d-13,'accepted midpoint production')
   call require(abs(result%chemical%surface_input-(2d0*irrigation+7d0*runon))<1d-13,'external age units')
   combined=stock+final_soil-initial_stock-initial_soil-result%chemical%surface_input- &
       result%chemical%surface_production-result%chemical%production- &
       (result%chemical%external_in-result%chemical%infiltrated_age)+ &
       result%chemical%external_out+result%chemical%surface_runoff
   call require(abs(result%chemical%residual)<1d-11*scale,'soil age balance cm day')
   call require(abs(combined)<1d-11*scale,'combined age balance internal transfer cancels')
   print '(A,6ES24.15)','ACCEPTED_WATER_DEPTHS_CM ',rain,irrigation,runon,infiltration,runoff,evaporation
   print '(A,3ES24.15)','AGE_RESIDUALS_CM_DAY ',result%chemical%residual,combined,water_residual
   call write_age_snapshot_disk(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,8801_int64, &
       water,soil,surface,status)
   call require(status==0,'single published restart envelope')
   w0=water;s0=soil;a0=surface
   call read_age_snapshot_disk(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
       8801_int64,p,water,soil,surface,status)
   call require(status/=0,'initialized triplet cannot be overwritten')
   call compare_all(w0,s0,a0)
   ! Existing destination stays unchanged if a pending writer cannot acquire lock.
   open(newunit=u,file=trim(restart_path)//'.pending',status='new');close(u)
   call write_age_snapshot_disk(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,8801_int64, &
       water,soil,surface,status)
   call require(status/=0,'interrupted pending writer fails closed')
   open(newunit=u,file=trim(restart_path)//'.pending',status='old');close(u,status='delete')
  end if
  call step(T1,2*T1,ages)
  call require(result%status==JOINT_OK,'continued real coupled interval')
  call endpoint(trim(endpoint_path))
  print '(A)','SURFACE_AGE_REAL_REFERENCE_TRIPLET=PASS'
contains
  subroutine refinement()
   real(real64)::pond(3),soil_amount(3),dt,clock
   integer::level,i,nn
   do level=1,3
    water=w0;soil=s0;surface=a0
    nn=2**(level-1);dt=T1/nn
    do i=1,nn
     clock=(i-1)*dt
     call step(clock,i*dt,ages)
     call require(result%status==JOINT_OK,'actual Reference partition refinement')
    end do
    call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok);pond(level)=stock
    call soil%snapshot(t,theta,c,revision);soil_amount(level)=sum(c%age_amount)
   end do
   ! Interval partitioning changes the adaptive hydraulic meshes. It is a
   ! sensitivity check, not a fixed-mesh monotonic-convergence test.
   call require(maxval(abs(pond-pond(3)))<1d-6*max(1d0,pond(3)),'pond partition sensitivity')
   call require(maxval(abs(soil_amount-soil_amount(3)))<1d-6*max(1d0,soil_amount(3)),'soil partition sensitivity')
   print '(A,3ES24.15)','ACTUAL_REFINEMENT_POND_CM_DAY ',pond
   print '(A,3ES24.15)','ACTUAL_REFINEMENT_SOIL_CM_DAY ',soil_amount
   water=w0;soil=s0;surface=a0
  end subroutine
  subroutine step(t0,t1,a)
   real(real64),intent(in)::t0,t1
   type(surface_age_source_ages_t),intent(in)::a
   call run_age_joint_interval(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
       cfg%tiles(1)%base_forcing,cfg%numerical,soil,t0,t1,result,surface,a)
  end subroutine
  subroutine compare_all(w,s,a)
   type(kernel_committed_state_t),intent(in)::w
   type(age_state_t),intent(in)::s
   type(surface_age_owner_t),intent(in)::a
   class(transaction_state_t),allocatable::x,y
   type(solute_compartment_state_t)::sc,tc
   real(real64),allocatable::sw(:),tw(:)
   real(real64)::st,tt,sd,td,ss,ts
   integer(int64)::sr,tr
   logical::available
   call require(w%current_revision()==water%current_revision(),'hydraulic revision rollback')
   call w%snapshot(x,available);call water%snapshot(y,available)
   select type(x)
   type is(fmr_b110_physical_state_t)
    select type(y)
    type is(fmr_b110_physical_state_t)
     call require(all(abs(x%pressure_head-y%pressure_head)<=0d0),'hydraulic heads rollback')
     call require(all(abs(x%water_content-y%water_content)<=0d0),'water content rollback')
     call require(abs(x%ponding_depth-y%ponding_depth)<=0d0,'pond water rollback')
    end select
   end select
   call s%snapshot(st,sw,sc,sr);call soil%snapshot(tt,tw,tc,tr)
   call require(sr==tr.and.abs(st-tt)<=0d0,'soil clock revision rollback')
   call require(all(abs(sc%age_amount-tc%age_amount)<=0d0),'soil amount rollback')
   call snapshot_surface_age_owner(a,st,sd,ss,sr,available)
   call snapshot_surface_age_owner(surface,tt,td,ts,tr,available)
   call require(sr==tr.and.maxval(abs([st-tt,sd-td,ss-ts]))<=0d0,'surface rollback')
  end subroutine
  subroutine endpoint(path)
   character(*),intent(in)::path
   class(transaction_state_t),allocatable::q
   call water%snapshot(q,ok)
   open(newunit=u,file=path,access='stream',form='unformatted',status='replace')
   select type(q)
   type is(fmr_b110_physical_state_t)
    write(u)water%current_lineage_id(),water%current_revision(),q%pressure_head,q%water_content, &
       q%ponding_depth,q%groundwater_level
   end select
   call soil%snapshot(t,theta,c,revision)
   write(u)t,revision,theta,c%age_amount
   call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok)
   write(u)t,depth,stock,revision
   close(u)
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
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print '(A)','FAIL '//label;error stop 1
    end if
  end subroutine
  include 'matrix_fixture.inc'
end program
