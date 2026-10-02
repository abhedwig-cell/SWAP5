module mod_a27_counting_mvg
 use,intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:constitutive_hydraulics_provider_t
 use mod_b110_default_mvg_provider,only:b110_default_mvg_provider_t
 implicit none
 integer::eval_calls=0,demand_calls=0,point_calls=0
 type,extends(constitutive_hydraulics_provider_t)::counting_mvg_t
   type(b110_default_mvg_provider_t),pointer::inner=>null()
 contains
   procedure::evaluate=>ceval
   procedure::evaluate_demand=>cdemand
   procedure::supports_point_conductivity=>csupports
   procedure::evaluate_point_conductivity=>cpoint
 end type
contains
 subroutine reset_counts();eval_calls=0;demand_calls=0;point_calls=0;end subroutine
 subroutine ceval(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
   class(counting_mvg_t),intent(in)::self
   real(real64),intent(in)::pressure_head(:)
   real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
   eval_calls=eval_calls+1
   call self%inner%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
 end subroutine
 subroutine cdemand(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
   class(counting_mvg_t),intent(in)::self
   real(real64),intent(in)::pressure_head(:);integer,intent(in)::demand_mask
   real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
   demand_calls=demand_calls+1
   call self%inner%evaluate_demand(pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
 end subroutine
 logical function csupports(self)
   class(counting_mvg_t),intent(in)::self
   csupports=self%inner%supports_point_conductivity()
 end function
 subroutine cpoint(self,node_index,pressure_head,water_content,conductivity,available)
   class(counting_mvg_t),intent(in)::self
   integer,intent(in)::node_index
   real(real64),intent(in)::pressure_head,water_content
   real(real64),intent(out)::conductivity
   logical,intent(out)::available
   point_calls=point_calls+1
   call self%inner%evaluate_point_conductivity(node_index,pressure_head,water_content,conductivity,available)
 end subroutine
end module

program test_a27_profile01
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz
 use mod_a27_counting_mvg
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
      initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_physical_state,only:rfm_physical_state_t
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 use mod_rfm_surface_forcing,only:rfm_surface_forcing_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 use mod_fmr_rfm_activation_binding,only:fmr_rfm_hydraulic_activation_result_t,evaluate_fmr_rfm_activation_from_view
 use mod_rfm_wall_hydraulic_history_binding,only:rfm_wall_hydraulic_binding_result_t,bind_rfm_wall_hydraulics_from_accepted
 use mod_rfm_live_trial_preparer,only:rfm_live_trial_prepare_result_t,prepare_rfm_live_trial
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX
 implicit none
 integer,parameter::NREP=2000,NBATCH=5
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::inner
 type(counting_mvg_t)::counted
 type(process_hydraulic_view_t)::view
 type(rfm_physical_state_t)::empty,cached
 type(rfm_runtime_configuration_t)::cfg
 type(rfm_surface_forcing_t)::wet,dry
 type(soil_water_top_boundary_result_t)::wet_top,dry_top
 type(fmr_rfm_hydraulic_activation_result_t)::activation
 type(rfm_wall_hydraulic_binding_result_t)::wall
 type(rfm_live_trial_prepare_result_t)::live
 real(real64)::cofgen(24,numnod),h(numnod),theta(numnod),k(numnod),cap(numnod),dkdh(numnod)
 real(real64)::sref,endpoint_input(1),depth(numnod),seconds,checksum
 integer(int64)::c0,c1,rate
 integer::i,batch
 logical::ok

 call init_cofgen(cofgen)
 call initialize_b110_default_mvg_parameters(hp,cofgen)
 call bind_b110_default_mvg_provider(inner,hp,.01_real64)
 counted%inner=>inner
 h=-150._real64-z
 call inner%evaluate(h,theta,k,cap,dkdh)
 view%active_nodes=numnod;allocate(view%pressure_head(numnod),view%water_content(numnod))
 view%pressure_head=h;view%water_content=theta;view%ponding_depth=0._real64;view%groundwater_level=-150._real64
 depth=abs(z)
 call empty%initialize(1,ok);if(.not.ok)error stop 'empty init'
 call cached%initialize(1,ok);if(.not.ok)error stop 'cached init'
 call evaluate_rfm_node_sorptivity(view,inner,6,64,sref,ok);if(.not.ok)error stop 'seed sorp'
 cached%endpoint_water_cm=.02_real64;cached%wall_age_day=.03_real64;cached%wall_sorptivity_cm_sqrt_day=sref;cached%tau_surface_day=.04_real64
 call init_cfg(cfg)
 call init_surface(wet,.true.,8._real64);call init_surface(dry,.false.,0._real64)
 call init_top(wet_top,8._real64);call init_top(dry_top,0._real64)
 endpoint_input=.01_real64

 call count_components()
 call time_components()
 print '(a)','A27_PROFILE01_EXECUTED=PASS'
contains
 subroutine count_components()
   call reset_counts();call evaluate_rfm_node_sorptivity(view,counted,6,64,sref,ok);call require(ok,'node sorp')
   call emit_count('NODE_SORPTIVITY')
   call reset_counts();call evaluate_fmr_rfm_activation_from_view(view,counted,64,.65_real64,8._real64,.025_real64,activation,ok)
   call require(ok,'surface wet');call emit_count('SURFACE_WET')
   call reset_counts();call bind_rfm_wall_hydraulics_from_accepted(empty,endpoint_input,[6],10,view,counted,64,wall)
   call require(wall%valid,'wall fresh');call emit_count('WALL_FRESH')
   call reset_counts();call bind_rfm_wall_hydraulics_from_accepted(cached,endpoint_input,[6],10,view,counted,64,wall)
   call require(wall%valid,'wall cached');call emit_count('WALL_CACHED')
   call reset_counts();call prepare_rfm_live_trial(empty,cfg,wet,view,counted,wet_top,depth,dz,.01_real64,1e-8_real64,live)
   call require(live%valid,'full wet empty');call emit_count('FULL_WET_EMPTY')
   call reset_counts();call prepare_rfm_live_trial(cached,cfg,wet,view,counted,wet_top,depth,dz,.01_real64,1e-8_real64,live)
   call require(live%valid,'full wet cached');call emit_count('FULL_WET_CACHED')
   call reset_counts();call prepare_rfm_live_trial(cached,cfg,dry,view,counted,dry_top,depth,dz,.01_real64,1e-8_real64,live)
   call require(live%valid,'full dry cached');call emit_count('FULL_DRY_CACHED')
 end subroutine
 subroutine time_components()
   do batch=1,NBATCH
     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call evaluate_rfm_node_sorptivity(view,inner,6,64,sref,ok);if(.not.ok)error stop 'time node'
       checksum=checksum+sref
     enddo
     call system_clock(c1);call emit_time('NODE_SORPTIVITY',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call evaluate_fmr_rfm_activation_from_view(view,inner,64,.65_real64,8._real64,.025_real64,activation,ok)
       if(.not.ok)error stop 'time surface';checksum=checksum+activation%activation%preferential_rate_cm_per_day
     enddo
     call system_clock(c1);call emit_time('SURFACE_WET',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call bind_rfm_wall_hydraulics_from_accepted(empty,endpoint_input,[6],10,view,inner,64,wall)
       if(.not.wall%valid)error stop 'time wall fresh';checksum=checksum+wall%endpoint_sorptivity_cm_sqrt_day(1)+wall%mb_sorptivity_cm_sqrt_day
     enddo
     call system_clock(c1);call emit_time('WALL_FRESH',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call bind_rfm_wall_hydraulics_from_accepted(cached,endpoint_input,[6],10,view,inner,64,wall)
       if(.not.wall%valid)error stop 'time wall cached';checksum=checksum+wall%mb_sorptivity_cm_sqrt_day
     enddo
     call system_clock(c1);call emit_time('WALL_CACHED',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call prepare_rfm_live_trial(empty,cfg,wet,view,inner,wet_top,depth,dz,.01_real64,1e-8_real64,live)
       if(.not.live%valid)error stop 'time full wet empty';checksum=checksum+live%candidate%deep_receipt_cm+sum(live%candidate%matrix_source_rate_per_day)
     enddo
     call system_clock(c1);call emit_time('FULL_WET_EMPTY',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call prepare_rfm_live_trial(cached,cfg,wet,view,inner,wet_top,depth,dz,.01_real64,1e-8_real64,live)
       if(.not.live%valid)error stop 'time full wet cached';checksum=checksum+live%candidate%deep_receipt_cm+sum(live%candidate%matrix_source_rate_per_day)
     enddo
     call system_clock(c1);call emit_time('FULL_WET_CACHED',batch,c0,c1,rate,checksum)

     checksum=0._real64;call system_clock(c0,rate)
     do i=1,NREP
       call prepare_rfm_live_trial(cached,cfg,dry,view,inner,dry_top,depth,dz,.01_real64,1e-8_real64,live)
       if(.not.live%valid)error stop 'time full dry cached';checksum=checksum+sum(live%candidate%matrix_source_rate_per_day)
     enddo
     call system_clock(c1);call emit_time('FULL_DRY_CACHED',batch,c0,c1,rate,checksum)
   enddo
 end subroutine
 subroutine emit_count(name)
   character(len=*),intent(in)::name
   write(*,'(*(g0,:,","))') 'COUNT',trim(name),eval_calls,demand_calls,point_calls
 end subroutine
 subroutine emit_time(name,b,cstart,cend,crate,sumv)
   character(len=*),intent(in)::name;integer,intent(in)::b;integer(int64),intent(in)::cstart,cend,crate;real(real64),intent(in)::sumv
   seconds=real(cend-cstart,real64)/real(crate,real64)
   write(*,'(*(g0,:,","))') 'TIME',trim(name),b,NREP,seconds,sumv
 end subroutine
 subroutine init_cfg(x)
   type(rfm_runtime_configuration_t),intent(out)::x
   x%enabled=.true.;x%sigma_b=.65_real64;x%f_mb=.25_real64;x%connectivity_p=1._real64
   x%z_ah_cm=20._real64;x%z_ic_cm=60._real64;x%chi_wall=1._real64;x%exchange_length_cm=20._real64;x%mb_contact_length_cm=80._real64
   x%sorptivity_panels=64;x%mb_wall_node_index=10
   x%endpoint_depth_cm=[60._real64];x%endpoint_contact_thickness_cm=[20._real64];x%endpoint_area_fraction=[.0375_real64];x%endpoint_node_index=[6]
 end subroutine
 subroutine init_surface(x,event,rain)
   type(rfm_surface_forcing_t),intent(out)::x;logical,intent(in)::event;real(real64),intent(in)::rain
   x=rfm_surface_forcing_t();x%supplied=.true.;x%event_active=event;x%precipitation_rate_cm_per_day=rain;x%runoff_exponent=1._real64
 end subroutine
 subroutine init_top(x,supply)
   type(soil_water_top_boundary_result_t),intent(out)::x;real(real64),intent(in)::supply
   x=soil_water_top_boundary_result_t();x%status=SW_TOP_BOUNDARY_AVAILABLE;x%regime=SW_TOP_BOUNDARY_REGIME_FLUX
   x%carries_surface_mass_terms=.true.;x%runoff_resolved=.true.;x%candidate_ponding_depth=0._real64;x%runoff_depth=0._real64
   x%net_potential_surface_flux=supply
 end subroutine
 subroutine init_cofgen(x)
   real(real64),intent(out)::x(:,:);integer::j
   x=0._real64
   do j=1,size(x,2)
    x(1,j)=.02_real64;x(2,j)=.42749391_real64;x(3,j)=31.22501566_real64;x(4,j)=.02165898_real64
    x(5,j)=.98087016_real64;x(6,j)=1.73473668_real64;x(7,j)=1._real64-1._real64/x(6,j);x(8,j)=x(4,j)
    x(10,j)=x(3,j);x(11,j)=.999_real64;x(12,j)=.99_real64*x(3,j);x(22,j)=-1e6_real64;x(23,j)=1e-12_real64
   enddo
 end subroutine
 subroutine require(q,label)
   logical,intent(in)::q;character(len=*),intent(in)::label
   if(.not.q)then;write(*,'(a,1x,a)')'A27_PROFILE01_FAIL',trim(label);error stop 1;endif
 end subroutine
end program
