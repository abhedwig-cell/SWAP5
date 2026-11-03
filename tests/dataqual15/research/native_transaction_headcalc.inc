subroutine research_coupled_contact()
 type(reference_richards_state_binding_t)::saved_state
 type(reference_richards_workspace_t)::saved_workspace
 type(a23bu_worker_context_t)::saved_context
 type(a23bu_solver_history_t)::saved_history
 type(native_coupled_model_t)::model
 type(native_coupled_state_t)::origin,restored
 class(transaction_state_t),allocatable::accepted
 type(transaction_result_t)::tx
 real(8)::saved_dt,pond_saved
 real(8),allocatable::saved_exchange(:)
 logical::saved_flags(6)
 character(64)::binding
 character(40)::restart_path
 integer::u,kind,id,n,restart_status
 if(research_logged.or.NN/=112.or.storage_rank/=0.or..not.provider_constitutive_active)return
 call research_action_witness()
 open(newunit=u,file="native-coupled-context.csv",status="replace")
 write(u,*) native_feedback_context%ready,native_feedback_context%t0,native_feedback_context%t1,dt
 close(u)
 if(.not.native_feedback_context%ready)return
 if(abs((native_feedback_context%t1-native_feedback_context%t0)-dt)> &
    8d0*epsilon(dt)*max(1d0,abs(native_feedback_context%t0)))return
 saved_state=state;saved_workspace=fsi_ws;saved_context=ctx;saved_history=hist;saved_dt=dt
 pond_saved=evaluation_context%macropore%candidate_pond_lateral()
 select type(mp=>evaluation_context%macropore)
 type is(ppa_wu05a16_inner_macropore_provider_t)
  research_base_macro=mp
 class default
  return
 end select
 open(newunit=u,file="native-coupled-context.csv",position="append")
 write(u,*) research_base_macro%shrinkage%enabled,research_base_macro%geometry_config%top_node,pond_saved,state%pondm1
 close(u)
 if(research_base_macro%geometry_config%top_node/=1)return
 if(pond_saved/=0d0.or.state%pondm1/=0d0)return
 saved_exchange=provider_macropore_exchange
 saved_flags=[provider_macropore_rate_active,provider_macropore_partition_evaluated, &
  provider_tuple_valid,provider_tuple_from_candidate,provider_runoff_resolved,typed_bottom_invalid]
 call get_command_argument(6,binding)
 n=numnod
 origin%head=state%hm1;origin%theta=state%thetm1;allocate(origin%area_dz(n))
 do id=1,n;origin%area_dz(id)=matrix_fraction(id)*grid_dz(id);end do
 origin%macro=research_base_macro%accepted_macro;origin%time=native_feedback_context%t0
 origin%matrix_temperature=native_feedback_context%matrix_temperature
 allocate(origin%macro_temperature(origin%macro%num_domains,n))
 do id=1,origin%macro%num_domains;origin%macro_temperature(id,:)=origin%matrix_temperature;end do
 open(newunit=u,file='native-coupled-transaction.csv',status='replace');research_log_unit=u
 do kind=0,3
  model=native_coupled_model_t();model%water_trial=>research_native_water_trial
  model%heat_parameters=native_feedback_context%parameters;model%heat_forcing=native_feedback_context%forcing
  model%heat_numerical=native_feedback_context%numerical
  model%rain_temperature=model%heat_forcing%air_temperature_c
  model%groundwater_temperature=origin%matrix_temperature(n)
  model%allow_source_proxies=kind/=0;model%inject_feedback_failure=kind==2
  origin%source_proxy_policy=model%allow_source_proxies
  call origin%clone(accepted)
  if(kind==3)then
   select type(accepted)
   type is(native_coupled_state_t)
    accepted%model_id='WRONG_PHYSICAL_MODEL'
   end select
  end if
  call execute_native_coupled_transaction(model,accepted,native_feedback_context%t0,native_feedback_context%t1,tx)
  write(u,'(a,7(a,i0),7(a,es25.17e3))')'TRANSACTION',',',kind,',',tx%status,',',tx%commits,',',tx%full_trials,',',tx%half_trials, &
    ',',model%water_calls,',',model%donor_refusals,',',tx%full_mass_residual,',',tx%half_mass_residual,',',tx%temporal_error, &
    ',',model%max_joint_residual,',',model%max_feedback,',',model%rain_temperature,',',model%groundwater_temperature
  write(u,'(a,3(a,i0),2(a,es25.17e3))')'WINDOW',',',kind,',',model%provisional_leaves,',',tx%temporal_rejections, &
    ',',model%max_attempted_temporal,',',tx%accepted_mass_residual
  select type(accepted)
  type is(native_coupled_state_t)
   write(u,'(a,2(a,i0),a,es25.17e3)')'REVISION',',',kind,',',accepted%revision,',',accepted%time
   if(tx%status/=TX_STATUS_ACCEPTED)then
    if(any(accepted%head/=origin%head).or.any(accepted%matrix_temperature/=origin%matrix_temperature).or. &
       .not.accepted%macro%same_values(origin%macro).or.accepted%revision/=0.or.accepted%time/=origin%time)error stop 'coupled failed rollback'
   else
    if(kind>1)error stop 'unexpected coupled acceptance'
    write(restart_path,'(a,i0,a)')'native-coupled-accepted-',kind,'.bin'
    call write_native_coupled_restart(trim(restart_path),binding,accepted,restart_status)
    if(restart_status/=0)error stop 'native coupled durable restart'
    restored=origin
    call read_native_coupled_restart(trim(restart_path),binding,restored,restart_status)
    if(restart_status/=0)error stop 'native coupled typed restart read'
    if(restored%revision/=accepted%revision.or.restored%time/=accepted%time.or. &
      any(restored%head/=accepted%head).or.any(restored%theta/=accepted%theta).or. &
      any(restored%matrix_temperature/=accepted%matrix_temperature).or.any(restored%macro_temperature/=accepted%macro_temperature).or. &
      .not.restored%macro%same_values(accepted%macro))error stop 'native coupled restart equality'
    write(u,'(a,a,i0)')'NATIVE_TYPED_DISK_RESTART_EXACT',',',kind
    do id=1,n
     write(u,'(a,a,i0,4(a,es25.17e3))')'ACCEPTED_NODE',',',id,',',accepted%head(id),',',accepted%theta(id), &
       ',',accepted%matrix_temperature(id),',',sum(accepted%macro%water_domain_cp(:,id))
    end do
   end if
  end select
 end do
 state=saved_state;fsi_ws=saved_workspace;ctx=saved_context;hist=saved_history;dt=saved_dt
 provider_macropore_exchange=saved_exchange
 provider_macropore_rate_active=saved_flags(1);provider_macropore_partition_evaluated=saved_flags(2)
 provider_tuple_valid=saved_flags(3);provider_tuple_from_candidate=saved_flags(4)
 provider_runoff_resolved=saved_flags(5);typed_bottom_invalid=saved_flags(6)
 call evaluation_context%macropore%set_candidate_pond_lateral(pond_saved)
 write(u,'(a)')'ORIGINAL_NATIVE_CONTEXT_RESTORED_EXPERIMENTAL_OWNER_SEPARATE'
 close(u)
end subroutine

subroutine research_native_water_trial(physical,t0,t1,face,exchange,external_out,mass_in,mass_out,has_bottom_in,ok)
 type(native_coupled_state_t),intent(inout)::physical
 real(8),intent(in)::t0,t1
 real(8),allocatable,intent(out)::face(:,:),exchange(:,:),external_out(:,:)
 real(8),intent(out)::mass_in,mass_out
 logical,intent(out)::has_bottom_in,ok
 real(8)::x(numnod+1),r(numnod+1),rp(numnod+1),rm(numnod+1),jac(numnod+1,numnod+1)
 real(8)::delta(numnod+1),trial(numnod+1),rt(numnod+1),eps,alpha,norm,top_amount,amount,fraction
 type(macropore_continuation_state_t)::macro_candidate
 logical::valid,linear_ok,converged
 integer::mode,it,col,ls,m,node
 ok=.false.;mass_in=0d0;mass_out=0d0;has_bottom_in=.false.
 dt=t1-t0;state%hm1=physical%head;state%thetm1=physical%theta
 research_macro=research_base_macro;research_macro%accepted_macro=physical%macro
 research_macro%step_duration=dt;research_macro%accepted_matrix_theta=physical%theta
 call derive_macropore_standard_storage_view(research_macro%accepted_macro,research_macro%geometry%top_node, &
    research_macro%z,research_macro%dz,research_macro%accepted_view)
 if(.not.research_macro%accepted_view%valid)return
 do mode=0,1
  research_branch=merge(-1,0,mode==0);m=numnod+merge(0,1,mode==0)
  x(:numnod)=physical%head;x(numnod+1)=2.3d-4;converged=.false.
  if(mode==1)x(26)=-x(27)
  do it=0,24
   call research_coupled_residual(x,r,valid)
   if(.not.valid)exit
   if(maxval(abs(r(:numnod)))<=1d-10.and.(mode==0.or.abs(r(numnod+1))<=1d-11))then
    converged=.true.;exit
   end if
   norm=maxval(abs(r(:m)))
   write(research_log_unit,'(a,2(a,i0),4(a,es25.17e3))')'WATER_ITERATION',',',mode,',',it,',',norm,',',x(26),',',x(27),',',x(numnod+1)
   do col=1,m
    eps=1d-5*max(1d0,abs(x(col)))
    ! Differentiate the ordinary smooth branch without crossing its contact plane.
    if(mode==0.and.(col==26.or.col==27))eps=min(eps,max(1d-12,.25d0*abs(x(26)+x(27))))
    trial=x;trial(col)=x(col)+eps
    call research_coupled_residual(trial,rp,valid);if(.not.valid)exit
    trial=x;trial(col)=x(col)-eps;call research_coupled_residual(trial,rm,valid);if(.not.valid)exit
    jac(:m,col)=(rp(:m)-rm(:m))/(2d0*eps)
   end do
   if(.not.valid)exit
   call research_dense_solve(jac(:m,:m),r(:m),delta(:m),linear_ok);if(.not.linear_ok)exit
   delta(m+1:)=0d0;alpha=1d0
   do ls=0,30
    trial=x-alpha*delta
    if(mode==0.or.(trial(numnod+1)>=0d0.and.trial(numnod+1)<=1d0))then
     call research_coupled_residual(trial,rt,valid)
     if(valid)then
      if(maxval(abs(rt(:m)))<norm)exit
     end if
    end if
    alpha=alpha*.5d0
   end do
   write(research_log_unit,'(a,2(a,i0),3(a,es25.17e3))')'WATER_LINESEARCH',',',mode,',',ls,',',alpha,',',delta(numnod+1),',',trial(numnod+1)
   if(ls>30)exit
   x=trial
  end do
  if(converged)exit
 end do
 write(research_log_unit,'(a,2(a,es25.17e3),3(a,i0),a,l1,a,es25.17e3)')'WATER_TRIAL',',',t0,',',t1,',',mode,',',it,',',m,',',converged,',',maxval(abs(r(:numnod)))
 if(.not.converged)return
 if(mode==0)then
  call research_macro%research_contact_selector(state%h,state%theta,fraction,valid)
  if(.not.valid)return
 else
  fraction=x(numnod+1)
 end if
 call research_macro%research_contact_lifecycle(state%h,state%theta,fraction,research_log_unit,10,macro_candidate,face,exchange,external_out,top_amount,valid)
 if(.not.valid)return
 if(state%pond/=0d0)return
 if(state%ftoph)state%qtop=-state%kmean(1)*fsi_ws%head_gradient(1)
 if(swbotb==1.or.swbotb==5.or.swbotb==9)state%qbot=-state%kmean(numnod+1)*fsi_ws%head_gradient(numnod+1)
 write(research_log_unit,'(a,2(a,es25.17e3))')'WATER_BOUNDARY',',',state%qtop,',',state%qbot
 physical%head=state%h;physical%theta=state%theta;physical%macro=macro_candidate
 mass_in=max(0d0,-state%qtop*dt)+max(0d0,state%qbot*dt)+top_amount
 mass_out=max(0d0,state%qtop*dt)+max(0d0,-state%qbot*dt)+sum(external_out)*dt
 do node=1,numnod
  amount=(fsi_ws%source(node)-fsi_ws%sink(node)-root_sink_term(node))*dt
  mass_in=mass_in+max(0d0,amount);mass_out=mass_out+max(0d0,-amount)
 end do
 has_bottom_in=state%qbot>0d0;ok=.true.
end subroutine

! Isolated full-column nonlinear experiment; never publishes to native state.
subroutine research_action_witness()
   type(reference_richards_state_binding_t)::saved_state
   type(reference_richards_workspace_t)::saved_workspace
   type(a23bu_worker_context_t)::saved_context
   type(a23bu_solver_history_t)::saved_history
   real(8)::x(numnod+1),r(numnod+1),rp(numnod+1),rm(numnod+1),jac(numnod+1,numnod+1)
   real(8)::delta(numnod+1),trial(numnod+1),rt(numnod+1),eps,alpha,norm,pond_saved
   real(8),allocatable::domain(:,:)
   integer::u,kind,it,col,ls,calls
   logical::ok,linear_ok,produced
   if(research_logged.or.NN/=112.or.storage_rank/=0.or..not.provider_constitutive_active)return
   research_logged=.true.
   saved_state=state;saved_workspace=fsi_ws;saved_context=ctx;saved_history=hist
   select type(mp=>evaluation_context%macropore)
   type is(ppa_wu05a16_inner_macropore_provider_t)
      research_macro=mp
   end select
   research_h=state%h;research_theta=state%theta
   research_exchange=provider_macropore_exchange
   pond_saved=evaluation_context%macropore%candidate_pond_lateral()
   open(newunit=u,file='coupled-contact.csv',status='replace')
   do kind=0,4
      research_branch=0
      if(kind==3)research_branch=1
      if(kind==4)research_branch=2
      x(:numnod)=research_h;x(numnod+1)=2.3d-4
      if(kind==1)x(26)=x(26)-1d-3
      if(kind==2)x(26)=x(26)+1d-3
      calls=0;produced=.false.
      do it=0,24
         call research_coupled_residual(x,r,ok);calls=calls+1
         if(.not.ok)exit
         norm=maxval(abs(r))
         if(maxval(abs(r(:numnod)))<=1d-10.and.abs(r(numnod+1))<=1d-11)then
            produced=.true.;exit
         end if
         do col=1,numnod+1
            eps=1d-5*max(1d0,abs(x(col)))
            trial=x;trial(col)=x(col)+eps
            call research_coupled_residual(trial,rp,ok);calls=calls+1
            if(.not.ok)exit
            trial=x;trial(col)=x(col)-eps
            call research_coupled_residual(trial,rm,ok);calls=calls+1
            if(.not.ok)exit
            jac(:,col)=(rp-rm)/(2d0*eps)
         end do
         if(.not.ok)exit
         call research_dense_solve(jac,r,delta,linear_ok)
         if(.not.linear_ok)exit
         alpha=1d0
         do ls=0,30
            trial=x-alpha*delta
            if(trial(numnod+1)>=0d0.and.trial(numnod+1)<=1d0)then
               call research_coupled_residual(trial,rt,ok);calls=calls+1
               if(ok)then
                  if(maxval(abs(rt))<norm)exit
               end if
            end if
            alpha=alpha*.5d0
         end do
         if(ls>30)exit
         x=trial
      end do
      call research_coupled_residual(x,r,ok);calls=calls+1
      write(u,'(a,a,i0,a,l1,2(a,i0),5(a,es25.17e3))')'COUPLED',',',kind,',',produced,',',it,',',calls, &
           ',',x(26),',',x(27),',',x(numnod+1),',',maxval(abs(r(:numnod))),',',r(numnod+1)
      if(produced)then
         select type(mp=>evaluation_context%macropore)
         type is(ppa_wu05a16_inner_macropore_provider_t)
            call mp%research_contact_lifecycle(state%h,state%theta,x(numnod+1),u,kind)
         end select
         do col=1,numnod
            write(u,'(a,2(a,i0),3(a,es25.17e3))')'NODE',',',kind,',',col,',',x(col),',',state%theta(col),',',r(col)
         end do
      end if
   end do
   state=saved_state;fsi_ws=saved_workspace;ctx=saved_context;hist=saved_history
   provider_macropore_exchange=research_exchange
   call evaluation_context%macropore%set_candidate_pond_lateral(pond_saved)
   write(u,'(a)')'NATIVE_STATE_RESTORED_FULL_COLUMN_CANDIDATE_NOT_COMMITTED'
   close(u)
end subroutine

subroutine research_coupled_residual(x,r,ok)
   real(8),intent(in)::x(:)
   real(8),intent(out)::r(:)
   logical,intent(out)::ok
   real(8),allocatable::domain(:,:)
   real(8)::fraction
   integer::node
   ! Refresh all actual matrix physical fields at every full-column candidate.
   state%h(:numnod)=x(:numnod)
   call evaluation_context%constitutive%evaluate(state%h,state%theta,fsi_ws%provider_k, &
        fsi_ws%provider_capacity,fsi_ws%provider_dkdh)
   state%k=fsi_ws%provider_k
   do node=1,numnod
      state%k(node)=state%k(node)*matrix_fraction(node)
      if(node>1)state%kmean(node)=hcomean(swkmean,state%k(node-1),state%k(node), &
           grid_dz(node-1),grid_dz(node),node,state%h(node-1),state%h(node))
   end do
   state%kmean(numnod+1)=state%k(numnod)
   do node=2,numnod
      fsi_ws%head_gradient(node)=(state%h(node-1)-state%h(node))/grid_disnod(node)+1d0
   end do
   call vector_F(2)
   fraction=x(numnod+1)
   if(research_branch==1)fraction=0d0
   if(research_branch==2)fraction=1d0
   if(research_branch==-1)then
      call research_macro%evaluate_rate(state%h,state%theta,research_current_exchange,ok)
   else
      call research_macro%research_contact_rates(state%h,state%theta,fraction,domain,ok)
      if(ok)research_current_exchange=sum(domain,dim=1)
   end if
   if(.not.ok)return
   select type(mp=>evaluation_context%macropore)
   type is(ppa_wu05a16_inner_macropore_provider_t)
      ok=.true.
   class default
      ok=.false.
   end select
   if(.not.ok)return
   r(:numnod)=fsi_ws%residual(:numnod)+provider_macropore_exchange-research_current_exchange
   r(numnod+1)=x(26)+x(27)
   ok=all(ieee_is_finite(r))
end subroutine

subroutine research_dense_solve(a,b,x,ok)
   real(8),intent(in)::a(:,:),b(:)
   real(8),intent(out)::x(:)
   logical,intent(out)::ok
   real(8)::m(size(b),size(b)),v(size(b)),row(size(b)),scale,factor,tmp
   integer::n,k,j,p
   n=size(b);m=a;v=b;ok=.false.;x=0d0
   do k=1,n
      scale=maxval(abs(m(k,:)))
      if(scale<=tiny(1d0))return
      m(k,:)=m(k,:)/scale;v(k)=v(k)/scale
   end do
   do k=1,n
      p=k-1+maxloc(abs(m(k:n,k)),dim=1)
      if(abs(m(p,k))<1d-18)return
      row=m(k,:);m(k,:)=m(p,:);m(p,:)=row
      tmp=v(k);v(k)=v(p);v(p)=tmp
      do j=k+1,n
         factor=m(j,k)/m(k,k)
         m(j,k:n)=m(j,k:n)-factor*m(k,k:n);v(j)=v(j)-factor*v(k)
      end do
   end do
   do k=n,1,-1
      x(k)=(v(k)-dot_product(m(k,k+1:n),x(k+1:n)))/m(k,k)
   end do
   ok=all(ieee_is_finite(x))
end subroutine
