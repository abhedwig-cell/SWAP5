! Isolated full-column nonlinear experiment; never publishes to native state.
subroutine research_coupled_contact()
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
   select type(mp=>evaluation_context%macropore)
   type is(ppa_wu05a16_inner_macropore_provider_t)
      call mp%research_contact_rates(state%h,state%theta,fraction,domain,ok)
   class default
      ok=.false.
   end select
   if(.not.ok)return
   r(:numnod)=fsi_ws%residual(:numnod)+provider_macropore_exchange-sum(domain,dim=1)
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
