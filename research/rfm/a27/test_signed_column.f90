program test_ppa_wu05a27_signed_column
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_EXPLICIT_FLUX
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 use mod_rfm_matrix_source_provider,only:rfm_matrix_source_provider_t,bind_rfm_matrix_source_provider
 use mod_ppa_wu05a6_saturated_exchange_rate
 use mod_rfm_signed_contact_research
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 implicit none
 real(real64),parameter::tol=1e-8_real64
 real(real64)::dt,elapsed,cum_exchange,cum_bottom,initial_storage,ks,water_table,rate,clock0,clock1
 real(real64)::macro_water,macro_initial,into_macro,out_macro,amount(numnod),pos(numnod),neg(numnod),fac
 type(signed_contact_request_t)::contact
 type(signed_contact_result_t)::cr
 type(process_hydraulic_view_t)::view
 real(real64)::stheta(numnod),scond(numnod),scap(numnod),sdk(numnod),ss
 real(real64)::event_seed(numnod),event_age(numnod),trial_seed(numnod),trial_age(numnod)
 logical::wall_wet(numnod),trial_wet(numnod)
 integer::soil,wet,mode,ref,step,ns,iters,backs,k
 integer::budget_hits,new_wall_events,dry_resets
 type(saturated_exchange_request_t)::sq
 type(saturated_exchange_result_t)::sx
 type(soil_water_parameter_set_t),target::params
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::base
 type(rfm_matrix_source_provider_t),target::rfm
 type(fixed_flux_top_boundary_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::w0,w1,w2
 type(soil_water_solve_request_t)::q,q0,q1,q2
 type(soil_water_solve_result_t)::r0,r1,r2
 real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:),source(:)
 real(real64),allocatable::cofgen(:,:),h0(:),t0(:)
 real(real64)::cond(numnod),cap(numnod),dkdh(numnod)
 integer::i,node
 logical::ok
 allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
 params%parameter_set_id=526_int64;params%active_nodes=numnod;params%z=z;params%dz=dz;params%node_distance=disnod(1:numnod)

 print '(a)','soil,wet,reverse_on,dt_day,time_day,exchange_cm,bottom_cm,storage_cm,storage_change_cm,max_abs_head_change_cm,mass_residual_cm,newton,backtracks,cpu_seconds,macro_storage_cm,macro_water_level_cm,budget_hits,new_wall_events,dry_resets,head_top_cm,head_mid_cm,head_bottom_cm,theta_top,theta_mid,theta_bottom'
 allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod),source(numnod),h0(numnod),t0(numnod))
 do soil=1,2
 do wet=0,3
 do mode=0,6
 do ref=0,4
 dt=.002_real64/(2**ref);ns=nint(1._real64/dt)
 ks=1._real64;if(soil==2)ks=5._real64
 water_table=-200._real64;if(wet==1.or.wet==2)water_table=-20._real64
 cofgen=0._real64
 do i=1,numnod
  cofgen(1,i)=0.02_real64;cofgen(2,i)=0.427494_real64;cofgen(3,i)=ks
  cofgen(4,i)=0.021659_real64;cofgen(5,i)=0.98087_real64;cofgen(6,i)=1.734737_real64
  cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i);cofgen(8,i)=cofgen(4,i);cofgen(10,i)=cofgen(3,i)
  cofgen(11,i)=0.999_real64;cofgen(12,i)=0.99_real64*cofgen(3,i);cofgen(22,i)=-1e6_real64;cofgen(23,i)=1e-12_real64
 end do
 call initialize_b110_default_mvg_parameters(hp,cofgen);call bind_b110_default_mvg_provider(hyd,hp,dt)
 h0=water_table-z;call hyd%evaluate(h0,t0,cond,cap,dkdh)
 qdra=0.0_real64;qssdi=0.0_real64;qrot=0.0_real64;source=0.0_real64
 call bind_b110_source_sink_provider(base,qdra,qssdi,qrot)
 node=max(1,numnod/2);source(node)=0.0_real64
 call bind_rfm_matrix_source_provider(rfm,base,source,ok);if(.not.ok)error stop 'bind'
 q%parameters=>params;q%base_state%active_nodes=numnod
 if(allocated(q%base_state%pressure_head))deallocate(q%base_state%pressure_head,q%base_state%water_content)
 allocate(q%base_state%pressure_head(numnod),q%base_state%water_content(numnod));q%base_state%pressure_head=h0;q%base_state%water_content=t0
 q%base_state%ponding_depth=0.0_real64;q%base_state%groundwater_level=water_table
 q%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;q%boundary%bottom_mode=5;q%boundary%top_flux=0.0_real64;q%boundary%bottom_head=water_table+100._real64
 q%physical%macropore_active=.false.;q%numerical%max_iterations=64;q%numerical%max_backtracking=24
 q%numerical%conductivity_implicit_mode=0;q%numerical%conductivity_mean_method=1;q%numerical%min_step_duration=1e-12_real64
 q%numerical%compartment_balance_tolerance=tol;q%numerical%total_balance_tolerance=tol;q%numerical%head_abs_tolerance=tol
 q%numerical%head_rel_tolerance=tol;q%numerical%ponding_tolerance=tol;q%evaluation%constitutive=>hyd;q%evaluation%top_boundary=>top;q%step_duration=dt

 q%evaluation%source_sink=>base
 sq%num_domains=1;sq%num_nodes=numnod;sq%matrix_bottom_saturated_node=numnod
 sq%matrix_partial_top_active=.false.;sq%flow_reduction=1.;sq%shape_factor=.1_real64
 sq%step_duration=dt;sq%bottom_domain=[numnod];sq%top_macro_saturated_node=[numnod]
 sq%macro_saturated_fraction=[0._real64];sq%macro_reference_level=[-100._real64]
 sq%z=z;sq%dz=dz;sq%matrix_head=h0;sq%ksat_horizontal=[(ks*.1_real64,k=1,numnod)]
 sq%diameter=[(20._real64,k=1,numnod)]
 if(allocated(sq%domain_fraction))deallocate(sq%domain_fraction,sq%cdarcy)
 allocate(sq%domain_fraction(1,numnod),sq%cdarcy(1,numnod));sq%domain_fraction=1.;sq%cdarcy=.1_real64*16._real64/(20._real64**2)*(ks*.1_real64)*10._real64
 macro_initial=0.;if(wet==2.or.wet==3)macro_initial=4._real64
 macro_water=macro_initial
 event_seed=0.;event_age=0.;wall_wet=.false.
 budget_hits=0;new_wall_events=0;dry_resets=0
 if(allocated(contact%contact_age))deallocate(contact%contact_age)
 if(allocated(contact%capillary_budget))deallocate(contact%capillary_budget)
 cum_exchange=0.;cum_bottom=0.;iters=0;backs=0.;initial_storage=sum(t0*dz)
 call cpu_time(clock0)
 do step=1,ns
 qdra=0.;qssdi=0.
 if((wet==1.or.wet==2).and.step>ns/2)q%boundary%bottom_head=40._real64
 into_macro=0.;out_macro=0.
 if(mode>0)then
  sq%macro_reference_level=[-100._real64+macro_water/.05_real64]
  sq%matrix_head=q%base_state%pressure_head
  sq%matrix_top_saturated_node=numnod
  sq%matrix_bottom_saturated_node=0
  do k=1,numnod
   if(sq%matrix_head(k)>=0.)then
    sq%matrix_top_saturated_node=min(sq%matrix_top_saturated_node,k)
    sq%matrix_bottom_saturated_node=k
   endif
  enddo
  call evaluate_saturated_exchange(sq,sx)
  if(.not.sx%valid)error stop 'exchange request'
  amount=sx%signed_matrix_to_macro_amount_cm(1,:)
  if(mode==1)amount=max(0._real64,amount)
  pos=max(0._real64,amount);neg=max(0._real64,-amount)
  pos=min(pos,max(0._real64,q%base_state%water_content-.02_real64)*dz)
  if(sum(pos)>0.)pos=pos*min(1._real64,(5._real64-macro_water)/sum(pos))
  if(sum(neg)>0.)neg=neg*min(1._real64,macro_water/sum(neg))
  into_macro=sum(pos);out_macro=sum(neg)
  qdra(1,:)=pos/dt;qssdi=neg/dt
 endif
 if(mode>=3)then
  contact%finite_contact=mode>=4
  contact%dt=dt;contact%storage=macro_water;contact%capacity=5._real64;contact%area=.05_real64
  contact%bottom_depth=100._real64;contact%length=20._real64;contact%chi=1._real64;contact%age=(step-1)*dt
  contact%depth=-z;contact%thickness=dz;contact%matrix_head=q%base_state%pressure_head
  contact%donor_water=max(0._real64,q%base_state%water_content-.02_real64)*dz
  ! Explicit receipt budget permits through-flow in saturated cells.
  contact%receiver_space=[(100._real64,k=1,numnod)]
  call hyd%evaluate(q%base_state%pressure_head,stheta,scond,scap,sdk)
  contact%conductivity=.1_real64*scond
  view%active_nodes=numnod;view%pressure_head=q%base_state%pressure_head;view%water_content=q%base_state%water_content
  view%ponding_depth=0._real64;view%groundwater_level=q%base_state%groundwater_level
  contact%sorptivity=[(0._real64,k=1,numnod)]
  do k=1,numnod
   call evaluate_rfm_node_sorptivity(view,hyd,k,16,ss,ok)
   if(.not.ok)error stop 'contact sorptivity'
   contact%sorptivity(k)=ss
  enddo
  if(mode>=5)then
   trial_seed=event_seed;trial_age=event_age
   trial_wet=macro_water>0._real64.and.(-z+dz/2)>100._real64-macro_water/.05_real64
   do k=1,numnod
    if(.not.trial_wet(k))then
     trial_seed(k)=0.;trial_age(k)=0.
    else if(.not.wall_wet(k))then
     trial_seed(k)=contact%sorptivity(k);trial_age(k)=0.
    endif
   enddo
   contact%sorptivity=trial_seed;contact%contact_age=trial_age
   if(mode==6)contact%capillary_budget=max(0._real64,cofgen(2,:)-q%base_state%water_content)*dz
  endif
  call evaluate_signed_contact(contact,cr)
  if(.not.cr%valid)error stop 'signed contact'
  budget_hits=budget_hits+cr%budget_limited_contacts
  into_macro=sum(cr%matrix_loss);out_macro=sum(cr%matrix_gain)
  qdra(1,:)=cr%matrix_loss/dt;qssdi=cr%matrix_gain/dt
 endif
 call solver%solve(q,w0,r0)
 if(r0%status/=SW_SOLVE_CONVERGED)then
  print *, 'FAIL',soil,wet,mode,ref,step,r0%status
  error stop 'column solve'
 endif
 if(.not.r0%integrated_mass_balance_residual_available.or.abs(r0%integrated_mass_balance_residual_cm)>tol)error stop 'column mass'
 macro_water=macro_water+into_macro-out_macro
 if(mode>=5)then
  new_wall_events=new_wall_events+count(trial_wet.and..not.wall_wet)
  dry_resets=dry_resets+count(wall_wet.and..not.trial_wet)
  event_seed=trial_seed;event_age=trial_age+merge(dt,0._real64,trial_wet);wall_wet=trial_wet
 endif
 if(macro_water< -1e-12_real64.or.macro_water>5._real64+1e-12_real64)error stop 'receiver capacity'
 cum_exchange=cum_exchange+into_macro-out_macro
 cum_bottom=cum_bottom+r0%bottom_flux*dt
 iters=iters+r0%diagnostics%nonlinear_iterations;backs=backs+r0%diagnostics%backtracking_attempts
 q%base_state=r0%candidate_state
 if(abs(sum(q%base_state%water_content*dz)-initial_storage-cum_bottom+macro_water-macro_initial)>1e-7_real64)error stop "whole column ledger"
 if(mod(step,max(1,ns/10))==0)then
  call cpu_time(clock1)
  print '(3(i0,","),8(es24.16,","),2(i0,","),3(es24.16,","),3(i0,","),6(es24.16,:,","))',soil,wet,mode,dt,step*dt,cum_exchange,cum_bottom, &
   sum(q%base_state%water_content*dz),sum(q%base_state%water_content*dz)-initial_storage, &
   maxval(abs(q%base_state%pressure_head-h0)),r0%integrated_mass_balance_residual_cm,iters,backs,clock1-clock0,macro_water,-100._real64+macro_water/.05_real64, &
   budget_hits,new_wall_events,dry_resets,q%base_state%pressure_head(1),q%base_state%pressure_head(node),q%base_state%pressure_head(numnod), &
   q%base_state%water_content(1),q%base_state%water_content(node),q%base_state%water_content(numnod)
 endif
 enddo
 enddo
 enddo
 enddo
 enddo
end program
