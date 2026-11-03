subroutine research_nonlinear_contact()
   type(nonlinear_contact_pair_result_t)::answer
   real(8)::offset,net,stock0,stock1,remaining,take,balance
   real(8),allocatable::domain(:,:),candidate_stock(:,:)
   integer::u,kind,id,node
   logical::ok
   if(research_logged.or.NN/=112.or.storage_rank/=0.or..not.provider_constitutive_active)return
   research_logged=.true.
   research_h=state%h;research_theta=state%theta
   research_f=fsi_ws%residual
   research_increment=research_theta
   call evaluation_context%constitutive%evaluate_water_content_increment(research_h,state%hm1, &
        research_theta,state%thetm1,research_increment)
   allocate(research_exchange(numnod))
   call evaluation_context%macropore%evaluate_rate(research_h,research_theta,research_exchange,ok)
   if(.not.ok)return
   open(newunit=u,file='nonlinear-contact.csv',status='replace')
   do kind=0,4
      research_branch=0;offset=0d0
      if(kind==1)offset=-1d-3
      if(kind==2)offset=1d-3
      if(kind==3)research_branch=1
      if(kind==4)research_branch=2
      call trial_nonlinear_contact_pair(research_contact_residual,research_h(26)+offset,.25d0,1d-10,answer)
      write(u,'(a,a,i0,a,l1,2(a,i0),4(a,es25.17e3))')'TRIAL',',',kind,',',answer%produced, &
           ',',answer%iterations,',',answer%evaluations,',',answer%head,',',answer%fraction,',',answer%residual(1),',',answer%residual(2)
      if(.not.answer%produced)cycle
      call research_contact_domain(answer%head,answer%fraction,domain,ok)
      if(.not.ok)error stop 'contact donor reevaluation failed'
      select type(mp=>evaluation_context%macropore)
      type is(ppa_wu05a16_inner_macropore_provider_t)
         candidate_stock=mp%accepted_macro%water_domain_cp
         do id=1,size(domain,1)
            ! Isolated exchange transaction, not a full vertical macro lifecycle.
            ! Apply the identical signed two-cell amount to the actual donor stock.
            net=dt*sum(domain(id,26:27));stock0=sum(candidate_stock(id,:))
            remaining=abs(net)
            do node=mp%geometry%top_node,mp%accepted_macro%icp_bottom_domain(id)
               if(net>=0d0)then
                  take=min(remaining,candidate_stock(id,node));candidate_stock(id,node)=candidate_stock(id,node)-take
               else
                  take=min(remaining,max(0d0,mp%accepted_macro%volume_domain_cp(id,node)-candidate_stock(id,node)))
                  candidate_stock(id,node)=candidate_stock(id,node)+take
               end if
               remaining=remaining-take
               if(remaining<=0d0)exit
            end do
            stock1=sum(candidate_stock(id,:));balance=stock1-stock0+net
            write(u,'(a,2(a,i0),5(a,es25.17e3))')'DONOR',',',kind,',',id,',',net,',',stock0,',',stock1,',',balance,',',remaining
            if(remaining>1d-18.or.abs(balance)>128d0*epsilon(1d0)*max(1d0,abs(stock0)))error stop 'contact donor budget'
         end do
         if(any(mp%accepted_macro%water_domain_cp/=candidate_stock))then
            ! Only the local copy changes; the production provider is intent(in).
            write(u,'(a,a,i0)')'PRIVATE_DONOR_CANDIDATE',',',kind
         end if
      class default
         error stop 'contact provider type'
      end select
   end do
   if(any(state%h/=research_h).or.any(state%theta/=research_theta))error stop 'research changed native Newton state'
   write(u,'(a)')'NATIVE_STATE_UNCHANGED_NONLINEAR_PAIR_ONLY_FULL_STEP_OPEN'
   close(u)
end subroutine

subroutine research_contact_domain(x,fraction,domain,ok)
   real(8),intent(in)::x,fraction
   real(8),allocatable,intent(out)::domain(:,:)
   logical,intent(out)::ok
   real(8)::h(numnod),theta(numnod),k(numnod),capacity(numnod),dk(numnod)
   h=research_h;h(26)=x;h(27)=-x
   call evaluation_context%constitutive%evaluate(h,theta,k,capacity,dk)
   select type(mp=>evaluation_context%macropore)
   type is(ppa_wu05a16_inner_macropore_provider_t)
      call mp%research_contact_rates(h,theta,fraction,domain,ok)
   class default
      ok=.false.
   end select
end subroutine

subroutine research_contact_residual(x,fraction,residual,ok)
   real(8),intent(in)::x,fraction
   real(8),intent(out)::residual(2)
   logical,intent(out)::ok
   real(8)::h(numnod),theta(numnod),k(numnod),capacity(numnod),dk(numnod),inc(numnod),effective
   real(8),allocatable::domain(:,:)
   integer::row
   h=research_h;h(26)=x;h(27)=-x
   call evaluation_context%constitutive%evaluate(h,theta,k,capacity,dk)
   call evaluation_context%constitutive%evaluate_water_content_increment(h,state%hm1,theta,state%thetm1,inc)
   effective=fraction
   if(research_branch==1)effective=0d0
   if(research_branch==2)effective=1d0
   select type(mp=>evaluation_context%macropore)
   type is(ppa_wu05a16_inner_macropore_provider_t)
      call mp%research_contact_rates(h,theta,effective,domain,ok)
   class default
      ok=.false.
   end select
   if(.not.ok)return
   do row=26,27
      residual(row-25)=research_f(row)+(inc(row)-research_increment(row))*matrix_fraction(row)*grid_dz(row)/dt &
       -sum(domain(:,row))+research_exchange(row) &
       -state%kmean(row)*((h(row-1)-research_h(row-1))-(h(row)-research_h(row)))/grid_disnod(row) &
       +state%kmean(row+1)*((h(row)-research_h(row))-(h(row+1)-research_h(row+1)))/grid_disnod(row+1)
   end do
end subroutine
