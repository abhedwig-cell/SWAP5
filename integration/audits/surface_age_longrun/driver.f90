program surface_age_longrun
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
  integer::level,cut,nsteps,i,first,cycle,substeps
  integer::temporal_rejections,solver_rejections,mass_rejections
  real(real64)::actual_min_dt,actual_max_dt
  real(real64)::dt,begin_pond,begin_soil,previous_depth,min_depth,max_depth
  real(real64)::total_input,total_production,total_other,total_output,total_surface_output
  real(real64)::max_combined,max_water,elapsed,accwater,scale_sum,change
  real(real64)::waterdepths(6),intervaldepths(6),initial_depth
  character(32)::arg
  character(512)::snapshot_name
  call get_command_argument(1,mode)
  call get_command_argument(2,arg);read(arg,*)level
  call get_command_argument(3,restart_path)
  call get_command_argument(4,endpoint_path)
  call get_command_argument(5,arg);read(arg,*)cut
  call require(any(level==[1,2,4,8,16]),'defined temporal partitions')
  nsteps=2000*level;dt=2d0/nsteps
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
  cfg%numerical%retain_accepted_step_proposal=.true.
  cfg%numerical%transaction%max_retries=30;cfg%numerical%max_committed_substeps=10000
  column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
  column%parameter_ref=1_int64;column%state_handle=1_int64;column%forcing_handle=1_int64
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  ages%runon_age_day=7d0;ages%irrigation_age_day=2d0
  call parameters(p)
  call backend%initialize(top)
  if(trim(mode)=='resume')then
   call read_age_snapshot_disk(trim(restart_path),column,cfg%tiles(1)%template,670001_int64,9001_int64, &
       8801_int64,p,water,soil,surface,status)
   call require(status==0,'fresh process long restart')
   first=cut+1
  else
   call fmr_new_b110_committed_state(water,column%column_id,cfg%tiles(1)%initial_state,T0,ok)
   call require(ok,'real Reference water initialization')
   call initialize_age(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
       [(1d0+1d0*j,j=1,numnod)],soil,status)
   call require(status==AGE_OK,'soil age initialization')
   call initialize_surface_age_owner(8801_int64,T0,.5d0,3d0,surface,status)
   call require(status==AGE_OWNER_OK,'surface age initialization')
   first=1
  end if
  call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok)
  initial_depth=depth;begin_pond=stock;min_depth=depth;max_depth=depth
  call soil%snapshot(t,theta,c,revision);begin_soil=sum(c%age_amount)
  total_input=0d0;total_production=0d0;total_other=0d0;total_output=0d0;total_surface_output=0d0
  max_combined=0d0;max_water=0d0;waterdepths=0d0;accwater=0d0;scale_sum=0d0;substeps=0
  actual_min_dt=huge(1d0);actual_max_dt=0d0
  temporal_rejections=0;solver_rejections=0;mass_rejections=0
  do i=first,nsteps
   ! Four identical half-day cycles: 0.1 d wet followed by 0.4 d drying.
   cycle=mod(i-1,500*level)
   associate(g=>cfg%tiles(1)%base_forcing%pond_input)
    if(cycle<100*level)then
     g%rain_rate_cm_day=4d0;g%irrigation_rate_cm_day=1d0;g%runon_rate_cm_day=2d0
     g%potential_pond_evaporation_cm_day=.05d0
    else
     g%rain_rate_cm_day=0d0;g%irrigation_rate_cm_day=0d0;g%runon_rate_cm_day=0d0
     g%potential_pond_evaporation_cm_day=.2d0
    end if
   end associate
   previous_depth=depth;initial_stock=stock
   call soil%snapshot(t,theta,c,revision);initial_soil=sum(c%age_amount)
   w0=water;s0=soil;a0=surface
   call step((i-1)*dt,i*dt,ages)
   if(result%status/=JOINT_OK)then
    print *,'LONG_REJECT',i,result%status,result%chemical%status,result%chemical%process_status, &
      result%water%status,result%diagnostics%temporal_rejections,result%diagnostics%mass_rejections
    call compare_all(w0,s0,a0)
   end if
   call require(result%status==JOINT_OK,'accepted coupled long interval')
   obs=backend%observation();intervaldepths=0d0;expected_production=0d0
   do j=1,size(obs%accepted_water_flux_substeps)
    associate(q=>obs%accepted_water_flux_substeps(j))
     elapsed=q%t1-q%t0
     actual_min_dt=min(actual_min_dt,elapsed);actual_max_dt=max(actual_max_dt,elapsed)
     intervaldepths=intervaldepths+[q%converged_rain_rate_cm_day*elapsed, &
      q%converged_irrigation_rate_cm_day*elapsed,q%converged_runon_rate_cm_day*elapsed, &
      -q%top_flux*elapsed,q%converged_runoff_depth_cm,q%converged_pond_evaporation_cm_day*elapsed]
     expected_production=expected_production+.5d0*(q%pond_start_cm+q%pond_end_cm)*elapsed
    end associate
   end do
   substeps=substeps+size(obs%accepted_water_flux_substeps)
   temporal_rejections=temporal_rejections+result%diagnostics%temporal_rejections
   solver_rejections=solver_rejections+result%diagnostics%solver_rejections
   mass_rejections=mass_rejections+result%diagnostics%mass_rejections
   call snapshot_surface_age_owner(surface,t,depth,stock,revision,ok)
   call require(ok.and.abs(t-i*dt)<=1d-14,'accepted surface clock')
   call require(depth>0d0,'strictly positive pond in bounded wet-dry profile')
   if(cycle>=100*level)call require(depth<previous_depth,'actual drying phase')
   call soil%snapshot(t,theta,c,revision);final_soil=sum(c%age_amount)
   scale=max(1d0,initial_stock+initial_soil,stock+final_soil)
   scale_sum=scale_sum+scale
   water_residual=depth-previous_depth-sum(intervaldepths(1:3))+sum(intervaldepths(4:6))
   call require(abs(water_residual)<=1d-10*max(1d0,previous_depth,sum(intervaldepths)), 'pond interval water closure')
   call require(abs(result%water%mass%residual)<=1d-10,'whole-column interval water closure')
   call require(abs(result%chemical%surface_production-expected_production)<=8192*epsilon(1d0)*scale, &
       'surface exposure from real accepted trace')
   call require(abs(result%chemical%surface_input-dot_product(intervaldepths(1:3),[0d0,2d0,7d0])) &
       <=8192*epsilon(1d0)*scale,'incoming age units')
   combined=stock-initial_stock-result%chemical%surface_input-result%chemical%surface_production+ &
       result%chemical%infiltrated_age+result%chemical%surface_runoff
   call require(abs(combined)<=8192*epsilon(1d0)*scale,'individual surface age closure')
   combined=final_soil-initial_soil-result%chemical%external_in-result%chemical%production+ &
       result%chemical%external_out
   call require(abs(combined)<=8192*epsilon(1d0)*scale,'individual soil age closure')
   total_input=total_input+result%chemical%surface_input
   total_production=total_production+result%chemical%surface_production+result%chemical%production
   total_other=total_other+result%chemical%external_in-result%chemical%infiltrated_age
   total_output=total_output+result%chemical%external_out
   total_surface_output=total_surface_output+result%chemical%surface_runoff
   combined=stock+final_soil-begin_pond-begin_soil-total_input-total_production-total_other+ &
       total_output+total_surface_output
   call require(abs(combined)<=8192*epsilon(1d0)*scale_sum,'cumulative combined age closure')
   max_combined=max(max_combined,abs(combined));max_water=max(max_water,abs(water_residual), &
       abs(result%water%mass%residual));accwater=accwater+water_residual
   waterdepths=waterdepths+intervaldepths;min_depth=min(min_depth,depth);max_depth=max(max_depth,depth)
   if(i==first.or.mod(i,50*level)==0)print '(A,I6,9ES24.15)','WINDOW ',i,t,depth,stock,final_soil,combined,water_residual, &
       result%water%mass%residual,result%chemical%infiltrated_age,result%chemical%surface_runoff
   flush(6)
   if(trim(mode)=='write'.and.(i==cut.or.(cut==-1.and.any(i==level*[1550,1600,1850,1500]))))then
    snapshot_name=restart_path
    if(cut==-1)then
     write(arg,'(I0)')i
     snapshot_name=trim(restart_path)//'.cut'//trim(arg)
    end if
    call write_age_snapshot_disk(trim(snapshot_name),column,cfg%tiles(1)%template,670001_int64,8801_int64, &
       water,soil,surface,status)
    call require(status==0,'long snapshot publication')
   end if
  end do
  water_residual=depth-initial_depth-sum(waterdepths(1:3))+sum(waterdepths(4:6))
  call require(abs(water_residual)<=1d-10*max(1d0,sum(waterdepths)), 'cumulative pond water closure')
  if(trim(mode)/='resume')call require(minval(waterdepths)>0d0,'all six water exchanges realized')
  print '(A,I9)','EXECUTED_WINDOWS ',nsteps-first+1
  print '(A,6ES24.15)','TOTAL_WATER_CM ',waterdepths
  print '(A,8ES24.15)','TOTAL_AGE_CM_DAY ',begin_pond+begin_soil,total_input,total_production, &
      total_other,total_output,total_surface_output,stock+final_soil,combined
  print '(A,6ES24.15,I9)','SUMMARY ',t,min_depth,max_depth,stock,final_soil,max_combined,substeps
  print '(A,2ES24.15,3I10)','ACTUAL_STEPS ',actual_min_dt,actual_max_dt, &
       temporal_rejections,solver_rejections,mass_rejections
  print '(A,3ES24.15)','MAX_CLOSURE ',max_combined,max_water,water_residual
  call endpoint(trim(endpoint_path))
  print '(A)','SURFACE_AGE_TWO_DAY_REFERENCE=PASS'
contains
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
