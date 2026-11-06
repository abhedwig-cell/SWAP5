! Explicit corrected sharp-entry graph. No production caller includes this file.
subroutine joint_entry_candidate(produced)
 type(reference_richards_state_binding_t)::saved_state
 type(reference_richards_workspace_t)::saved_ws
 type(a23bu_worker_context_t)::saved_ctx
 type(a23bu_solver_history_t)::saved_hist
 real(8),allocatable::x(:),trial(:),theta0(:),r(:),rp(:),rm(:),jac(:,:),border(:,:),ctest(:,:),corner(:,:),g(:),dh(:),dl(:)
 real(8),allocatable::a(:),b(:),c(:),left(:,:),right(:,:),lambda(:),candidate(:),saved_q(:),threshold(:),saved_fraction(:)
 real(8)::eps,norm,alpha,previous_pond,one(1),q0,q1
 integer,allocatable::nodes(:)
 integer::i,j,n,k,it,ls,code,extra,u,rank
 logical,intent(out)::produced
 logical::valid,restored_flags(6)
 produced=.false.;n=NN
 if(.not.provider_macropore_active.or..not.provider_constitutive_active.or.swkimpl/=0.or.storage_rank/=0)return
 if(consistent_provider_conductivity.or.picard_conductivity_iteration)return
 select type(mp=>evaluation_context%macropore)
 type is(ppa_wu05a16_inner_macropore_provider_t)
  if(.not.allocated(mp%entry_fraction))return
  saved_state=state;saved_ws=fsi_ws;saved_ctx=ctx;saved_hist=hist
  saved_fraction=mp%entry_fraction;saved_q=provider_macropore_exchange;previous_pond=mp%candidate_pond_lateral()
  restored_flags=[provider_macropore_rate_active,provider_macropore_partition_evaluated,provider_tuple_valid, &
                  provider_tuple_from_candidate,provider_runoff_resolved,typed_bottom_invalid]
  allocate(nodes(n),threshold(n),x(n),lambda(n),r(n),rp(n),rm(n),trial(n),candidate(n),theta0(n))
  x=state%h(:n);threshold=mp%rate_template%unsaturated%entry_head(:n)-1d-8;k=0
  ! Locate the actual discontinuity; no model-specific node number or clock.
  do i=2,n-1
   if(abs(x(i)-threshold(i))>1d-3)cycle
   if(mp%rate_template%unsaturated%entry_transition_width_cm/=0d0)cycle
   k=k+1;nodes(k)=i;x(i)=threshold(i);lambda(k)=0d0
   call joint_entry_residual(x,lambda(:k),nodes(:k),rp,valid)
   if(.not.valid)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=1d0;call joint_entry_residual(x,lambda(:k),nodes(:k),rm,valid)
   if(.not.valid.or.abs(rm(i)-rp(i))<1d-10)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   if(rp(i)*rm(i)>0d0)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=min(1d0,max(0d0,-rp(i)/(rm(i)-rp(i))))
  end do
  if(k==0)goto 990
  allocate(jac(n,n),border(n,k),ctest(n,k),corner(k,k),g(k),dh(n),dl(k),a(n),b(n),c(n),left(n,n),right(n,n))
  ctest=0d0;corner=0d0;right=0d0
  do i=1,k;ctest(nodes(i),i)=1d0;end do
  do i=1,n;right(i,i)=1d0;end do
  do it=0,25
   call joint_entry_residual(x,lambda(:k),nodes(:k),r,valid);if(.not.valid)exit
   norm=maxval(abs(r));g=x(nodes(:k))-threshold(nodes(:k))
   if(norm<=min(CritDevBalCp,1d-8).and.maxval(abs(g))<=1d-12)then
    produced=.true.;exit
   end if
   do j=1,n
    eps=1d-5*max(1d0,abs(x(j)));trial=x;trial(j)=x(j)+eps
    call joint_entry_residual(trial,lambda(:k),nodes(:k),rp,valid);if(.not.valid)exit
    trial(j)=x(j)-eps;call joint_entry_residual(trial,lambda(:k),nodes(:k),rm,valid);if(.not.valid)exit
    jac(:,j)=(rp-rm)/(2d0*eps)
   end do
   if(.not.valid)exit
   do j=1,k
    candidate(:k)=lambda(:k);candidate(j)=1d0
    call joint_entry_residual(x,candidate(:k),nodes(:k),rp,valid);if(.not.valid)exit
    candidate(j)=0d0;call joint_entry_residual(x,candidate(:k),nodes(:k),rm,valid);if(.not.valid)exit
    border(:,j)=rp-rm
   end do
   if(.not.valid)exit
   ! Preserve every off-band derivative in worker-local low-rank factors.
   left=jac;a=0d0;b=0d0;c=0d0
   do j=1,n
    b(j)=jac(j,j);left(j,j)=0d0
    if(j>1)then
     a(j)=jac(j,j-1);left(j,j-1)=0d0
    end if
    if(j<n)then
     c(j)=jac(j,j+1);left(j,j+1)=0d0
    end if
   end do
   call reference_bordered_solve(a,b,c,r,border,ctest,corner,g,dh,dl,code,extra,left,right)
   if(code/=0)exit
   alpha=1d0
   do ls=0,24
    candidate(:k)=lambda(:k)-alpha*dl
    if(all(candidate(:k)>=0d0).and.all(candidate(:k)<=1d0))then
     trial=x-alpha*dh;trial(nodes(:k))=threshold(nodes(:k))
     call joint_entry_residual(trial,candidate(:k),nodes(:k),rp,valid)
     if(valid)then
      if(maxval(abs(rp))<norm)exit
     end if
    end if
    alpha=alpha*.5d0
   end do
   if(ls>24)exit
   x=trial;lambda(:k)=candidate(:k)
  end do
  open(newunit=u,file='entry-contact.csv',status='unknown',position='append')
  write(u,*)'CANDIDATE',dt,produced,k,it,maxval(abs(r)),nodes(:k),lambda(:k)
  close(u)
  if(produced)then
   call joint_entry_residual(x,lambda(:k),nodes(:k),r,valid)
   produced=valid.and.maxval(abs(r))<=CritDevBalCp
   if(produced)return
  end if
990 continue
  state=saved_state;fsi_ws=saved_ws;ctx=saved_ctx;hist=saved_hist
  mp%entry_fraction=saved_fraction;call mp%set_candidate_pond_lateral(previous_pond)
  provider_macropore_exchange=saved_q
  provider_macropore_rate_active=restored_flags(1);provider_macropore_partition_evaluated=restored_flags(2)
  provider_tuple_valid=restored_flags(3);provider_tuple_from_candidate=restored_flags(4)
  provider_runoff_resolved=restored_flags(5);typed_bottom_invalid=restored_flags(6)
 end select
end subroutine

subroutine joint_entry_residual(x,fraction,nodes,r,ok)
 real(8),intent(in)::x(:),fraction(:)
 integer,intent(in)::nodes(:)
 real(8),intent(out)::r(:)
 logical,intent(out)::ok
 integer::j
 ok=.false.
 select type(mp=>evaluation_context%macropore)
 type is(ppa_wu05a16_inner_macropore_provider_t)
  mp%entry_fraction=-1d0
  do j=1,size(nodes);mp%entry_fraction(nodes(j))=fraction(j);end do
  state%h(:NN)=x
  call evaluation_context%constitutive%evaluate(state%h(:NN),state%theta(:NN),fsi_ws%provider_k, &
                                               fsi_ws%provider_capacity,fsi_ws%provider_dkdh)
  provider_tuple_valid=.false.;fsi_ws%unsaturated_flags(3)=.false.
  do j=2,NN
   fsi_ws%head_gradient(j)=(state%h(j-1)-state%h(j))/grid_disnod(j)+1d0
  end do
  call vector_F(2);r=fsi_ws%residual(:NN)
  ok=.not.typed_bottom_invalid.and.all(ieee_is_finite(r))
 end select
end subroutine
