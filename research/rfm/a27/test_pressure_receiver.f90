program test_a27_pressure_receiver
 use,intrinsic::iso_fortran_env,only:int64,real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_solve_request_t,soil_water_solve_result_t,SW_SOLVE_CONVERGED
 use mod_reference_richards_legacy_binding,only:reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
 use mod_reference_richards_state_binding,only:FSI_TOP_MODE_EXPLICIT_FLUX
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,b110_default_mvg_provider_t,initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
 use mod_b110_source_sink_provider,only:b110_source_sink_provider_t,bind_b110_source_sink_provider
 use mod_fixed_flux_top_boundary_provider,only:fixed_flux_top_boundary_provider_t
 use mod_ppa_wu05a6_saturated_exchange_rate
 implicit none
 real(real64),parameter::tol=1e-8_real64,afrac=.05_real64,bottom_depth=100._real64,cdarcy0=5e-4_real64
 real(real64)::dt,receiver,receiver_candidate,external_net,initial_total,matrix_storage,total_storage,cum_bottom
 real(real64)::signed_rate,ledger,maxledger,water_table,water_level,frac,pre_receiver
 real(real64)::final_receiver(3),final_matrix(3),cofgen_row(24)
 integer::ref,step,ns,i,k,node,positive_steps,reverse_steps,contact_changes,contact_index,old_contact
 integer::pulse_fill,pulse_drain,pulse_rewet
 logical::ok,replay_done
 type(saturated_exchange_request_t)::sq
 type(saturated_exchange_result_t)::sx
 type(soil_water_parameter_set_t),target::params
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_default_mvg_provider_t),target::hyd
 type(b110_source_sink_provider_t),target::base
 type(fixed_flux_top_boundary_provider_t),target::top
 type(reference_richards_legacy_solver_t)::solver
 type(reference_richards_legacy_workspace_t)::w0,w1
 type(soil_water_solve_request_t)::q
 type(soil_water_solve_result_t)::r0,r1
 real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
 real(real64),allocatable::cofgen(:,:),h0(:),t0(:),accepted_h(:),accepted_t(:)
 real(real64)::cond(numnod),cap(numnod),dkdh(numnod)

 allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod),cofgen(24,numnod))
 allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod),h0(numnod),t0(numnod),accepted_h(numnod),accepted_t(numnod))
 params%parameter_set_id=527_int64;params%active_nodes=numnod;params%z=z;params%dz=dz;params%node_distance=disnod(1:numnod)

 cofgen_row=0._real64
 cofgen_row(1)=.02_real64;cofgen_row(2)=.42749391_real64;cofgen_row(3)=31.22501566_real64
 cofgen_row(4)=.02165898_real64;cofgen_row(5)=.98087016_real64;cofgen_row(6)=1.73473668_real64
 cofgen_row(7)=1._real64-1._real64/cofgen_row(6);cofgen_row(8)=cofgen_row(4)
 cofgen_row(10)=cofgen_row(3);cofgen_row(11)=.999_real64;cofgen_row(12)=.99_real64*cofgen_row(3)
 cofgen_row(22)=-1e6_real64;cofgen_row(23)=1e-12_real64
 do i=1,numnod;cofgen(:,i)=cofgen_row;enddo

 print '(a)','dt_day,final_receiver_cm,final_matrix_storage_cm,cum_bottom_cm,max_total_ledger_cm,positive_steps,reverse_steps,contact_changes'
 do ref=0,2
  dt=.01_real64/(2._real64**ref);ns=nint(.30_real64/dt)
  call initialize_b110_default_mvg_parameters(hp,cofgen);call bind_b110_default_mvg_provider(hyd,hp,dt)
  water_table=-50._real64;h0=water_table-z;call hyd%evaluate(h0,t0,cond,cap,dkdh)
  qdra=0._real64;qssdi=0._real64;qrot=0._real64;call bind_b110_source_sink_provider(base,qdra,qssdi,qrot)
  q%parameters=>params;q%base_state%active_nodes=numnod
  if(allocated(q%base_state%pressure_head))deallocate(q%base_state%pressure_head,q%base_state%water_content)
  allocate(q%base_state%pressure_head(numnod),q%base_state%water_content(numnod))
  q%base_state%pressure_head=h0;q%base_state%water_content=t0;q%base_state%ponding_depth=0._real64;q%base_state%groundwater_level=water_table
  q%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX;q%boundary%bottom_mode=5;q%boundary%top_flux=0._real64;q%boundary%bottom_head=water_table+100._real64
  q%physical%macropore_active=.false.;q%numerical%max_iterations=64;q%numerical%max_backtracking=24
  q%numerical%conductivity_implicit_mode=0;q%numerical%conductivity_mean_method=1;q%numerical%min_step_duration=1e-12_real64
  q%numerical%compartment_balance_tolerance=tol;q%numerical%total_balance_tolerance=tol;q%numerical%head_abs_tolerance=tol
  q%numerical%head_rel_tolerance=tol;q%numerical%ponding_tolerance=tol;q%evaluation%constitutive=>hyd;q%evaluation%top_boundary=>top
  q%evaluation%source_sink=>base;q%step_duration=dt

  sq%num_domains=1;sq%num_nodes=numnod;sq%matrix_partial_top_active=.false.;sq%flow_reduction=1._real64
  sq%shape_factor=.1_real64;sq%step_duration=dt;sq%bottom_domain=[numnod];sq%z=z;sq%dz=dz
  sq%ksat_horizontal=[(cofgen_row(3),k=1,numnod)];sq%diameter=[(20._real64,k=1,numnod)]
  allocate(sq%domain_fraction(1,numnod),sq%cdarcy(1,numnod));sq%domain_fraction=1._real64;sq%cdarcy=cdarcy0

  receiver=.30_real64;external_net=0._real64;cum_bottom=0._real64
  initial_total=sum(t0*dz)+receiver;maxledger=0._real64
  positive_steps=0;reverse_steps=0;contact_changes=0;old_contact=-1;replay_done=.false.
  pulse_fill=nint(.05_real64/dt)+1;pulse_drain=nint(.15_real64/dt)+1;pulse_rewet=nint(.20_real64/dt)+1

  do step=1,ns
   if(step==pulse_fill)then;external_net=external_net+(4._real64-receiver);receiver=4._real64;endif
   if(step==pulse_drain)then;external_net=external_net+(.10_real64-receiver);receiver=.10_real64;endif
   if(step==pulse_rewet)then;external_net=external_net+(3._real64-receiver);receiver=3._real64;endif

   water_level=bottom_depth-receiver/afrac
   contact_index=numnod
   do i=1,numnod
    if(-z(i)>=water_level)then;contact_index=i;exit;endif
   enddo
   if(old_contact>=0.and.contact_index/=old_contact)contact_changes=contact_changes+1
   old_contact=contact_index
   frac=max(0._real64,min(1._real64,((-z(contact_index)+.5_real64*dz(contact_index))-water_level)/dz(contact_index)))
   sq%top_macro_saturated_node=[contact_index];sq%macro_saturated_fraction=[frac];sq%macro_reference_level=[-water_level]
   sq%matrix_head=q%base_state%pressure_head
   sq%matrix_top_saturated_node=numnod;sq%matrix_bottom_saturated_node=0
   do i=1,numnod
    if(sq%matrix_head(i)>=0._real64)then
     sq%matrix_top_saturated_node=min(sq%matrix_top_saturated_node,i);sq%matrix_bottom_saturated_node=i
    endif
   enddo
   call evaluate_saturated_exchange(sq,sx);if(.not.sx%valid)error stop 'pressure receiver exchange invalid'
   qdra=0._real64;qssdi=0._real64
   do i=1,numnod
    if(sx%qexc_to_matrix_rate_cm_per_day(1,i)>=0._real64)then
     qssdi(i)=sx%qexc_to_matrix_rate_cm_per_day(1,i)
    else
     qdra(1,i)=-sx%qexc_to_matrix_rate_cm_per_day(1,i)
    endif
   enddo
   signed_rate=sum(sx%qexc_to_matrix_rate_cm_per_day(1,:))
   if(abs(signed_rate-(sum(qssdi)-sum(qdra)))>1e-12_real64)error stop 'signed rate ownership mismatch'
   if(signed_rate>1e-14_real64)positive_steps=positive_steps+1
   if(signed_rate<(-1e-14_real64))reverse_steps=reverse_steps+1
   pre_receiver=receiver;receiver_candidate=receiver-signed_rate*dt
   if(receiver_candidate<0._real64.or.receiver_candidate>afrac*bottom_depth)error stop 'receiver storage bounds'
   if(abs((receiver_candidate-pre_receiver)+signed_rate*dt)>1e-12_real64)error stop 'opposite receiver receipt mismatch'

   accepted_h=q%base_state%pressure_head;accepted_t=q%base_state%water_content
   call solver%solve(q,w0,r0);if(r0%status/=SW_SOLVE_CONVERGED)error stop 'Reference trial failed'
   if(.not.r0%integrated_mass_balance_residual_available.or.abs(r0%integrated_mass_balance_residual_cm)>tol)error stop 'Reference mass gate'
   if(maxval(abs(q%base_state%pressure_head-accepted_h))>0._real64.or.maxval(abs(q%base_state%water_content-accepted_t))>0._real64)error stop 'accepted state mutated by trial'
   if(.not.replay_done.and.abs(signed_rate)>1e-14_real64)then
    call solver%solve(q,w1,r1);if(r1%status/=SW_SOLVE_CONVERGED)error stop 'replay failed'
    if(maxval(abs(r1%candidate_state%pressure_head-r0%candidate_state%pressure_head))>1e-12_real64)error stop 'replay pressure mismatch'
    if(maxval(abs(r1%candidate_state%water_content-r0%candidate_state%water_content))>1e-12_real64)error stop 'replay theta mismatch'
    replay_done=.true.
   endif

   q%base_state=r0%candidate_state;receiver=receiver_candidate;cum_bottom=cum_bottom+r0%bottom_flux*dt
   matrix_storage=sum(q%base_state%water_content*dz);total_storage=matrix_storage+receiver
   ledger=total_storage-initial_total-cum_bottom-external_net;maxledger=max(maxledger,abs(ledger))
   if(abs(ledger)>1e-7_real64)error stop 'combined matrix receiver ledger'
  enddo
  if(positive_steps<=0.or.reverse_steps<=0)error stop 'both signed directions not exercised'
  if(contact_changes<3)error stop 'moving contact gate'
  if(.not.replay_done)error stop 'replay gate not exercised'
  final_receiver(ref+1)=receiver;final_matrix(ref+1)=sum(q%base_state%water_content*dz)
  print '(5(es24.16,","),3(i0,","))',dt,final_receiver(ref+1),final_matrix(ref+1),cum_bottom,maxledger,positive_steps,reverse_steps,contact_changes
  deallocate(sq%domain_fraction,sq%cdarcy)
 enddo
 if(abs(final_receiver(3)-final_receiver(2))>1e-3_real64)error stop 'receiver refinement gate'
 if(abs(final_matrix(3)-final_matrix(2))>5e-3_real64)error stop 'matrix refinement gate'
 print '(a)','A27_PRESSURE_RECEIVER_SEAM=PASS'
end program
