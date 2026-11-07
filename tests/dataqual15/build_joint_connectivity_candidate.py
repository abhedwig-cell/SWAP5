"""Private V7 experiment: complete the single-node connectivity graph at h=0."""
import json, sys
from pathlib import Path
import build_joint_saturation_contact_candidate as previous
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_SINGLE_NODE_CONNECTIVITY_GRAPH_V7'


def render(folder):
    shadow = previous.render(folder)
    name = 'src/solver/mod_b110_source_sink_provider.f90'
    s = shadow[ROOT/name].read_text()
    s = once(s, '     integer :: active_nodes = 0', '''     integer :: connection_node = 0
     real(real64) :: connection_fraction = 0d0
     real(real64) :: connection_pond_cm = 0d0
     real(real64) :: connection_seed_level_cm = 999d0
     integer :: active_nodes = 0''')
    shadow[ROOT/name].write_text(s,newline='\n')

    name = 'src/legacy/b1_10_port/headcalc.f90'
    s = shadow[ROOT/name].read_text()
    s = once(s,'   use mod_reference_bordered_solver,only:reference_bordered_solve',
        '   use mod_reference_bordered_solver,only:reference_bordered_solve\n   use mod_b110_source_sink_provider,only:b110_source_sink_provider_t')
    s = once(s,' real(8)::saved_surface_area',' real(8)::saved_surface_area,saved_connection_fraction,increment\n integer::saved_connection_node')
    s = once(s,' integer::saved_connection_node',''' integer::saved_connection_node,contact_trial,old_contact,hit_node
 real(8)::active_alpha,hit_alpha,contact_level,connection_pond
 logical::contact_swap,contact_trial_valid''')
    s = once(s,'  saved_surface_area=provider_macropore_surface_area_fraction','''  saved_surface_area=provider_macropore_surface_area_fraction
  saved_connection_node=0;saved_connection_fraction=0d0
  if(associated(evaluation_context%source_sink))then
   select type(drain=>evaluation_context%source_sink)
   type is(b110_source_sink_provider_t)
    saved_connection_node=drain%connection_node;saved_connection_fraction=drain%connection_fraction
   end select
  end if''')
    marker='''  allocate(gwl_distance(n),gwl_z(n));gwl_distance=0d0
  do i=1,n;gwl_z(i)=grid_z(i);end do
  gwl_distance(2:n)=abs(gwl_z(2:n)-gwl_z(1:n-1))'''
    s = once(s,marker,marker+'''
  ! A single zero-head node can disconnect two otherwise saturated regions.
  ! Its drainage jump is nonlocal: use the whole bordered residual to decide
  ! whether the bounded contact exists, not a one-row endpoint sign test.
  if(k==0.and.associated(evaluation_context%source_sink))then
   select type(drain=>evaluation_context%source_sink)
   type is(b110_source_sink_provider_t)
    if(associated(drain%current_drainage))then
     if(minval(state%hm1(:n))==0d0.and.state%hm1(1)>0d0.and.state%hm1(n)>0d0)then
      call evaluate_b111_profile_groundwater_projection(gwl_z,gwl_distance,state%hm1(:n),drain%connection_pond_cm,gwl_view)
      if(gwl_view%valid.and.gwl_view%level_present)then
       do i=n-1,2,-1
        if(state%hm1(i)/=0d0)cycle
        if(drain%connection_seed_level_cm<gwl_z(i).or.drain%connection_seed_level_cm>=gwl_view%level_cm)cycle
        k=1;nodes(k)=3*n+i;x=state%hm1(:n)
        lambda(k)=(drain%connection_seed_level_cm-gwl_z(i))/(gwl_view%level_cm-gwl_z(i))
        exit
       end do
      end if
     end if
     if(k==0)then
      i=minloc(x,dim=1)
      if(i>1.and.i<n.and.abs(x(i))<=1d-3)then
       if(all(x(:i-1)>0d0).and.all(x(i+1:)>0d0))then
        k=1;nodes(k)=3*n+i;x(i)=0d0;lambda(k)=0d0
       end if
      end if
     end if
    end if
   end select
  end if
''')
    for j in ('j','jj'):
        s=s.replace(f'i=abs(nodes({j}));if(i>2*n)i=i-n\n    if(i>n)i=i-n',f'i=mod(abs(nodes({j}))-1,n)+1')
    s = once(s,'''    candidate(:k)=lambda(:k);candidate(j)=1d0''','''    if(nodes(j)>3*n)then
     increment=1d-5
     if(lambda(j)>1d0-increment)increment=-increment
     candidate(:k)=lambda(:k);candidate(j)=lambda(j)+increment
     call joint_entry_residual(x,candidate(:k),nodes(:k),rp,valid);if(.not.valid)exit
     border(:,j)=(rp-r)/increment
     cycle
    end if
    candidate(:k)=lambda(:k);candidate(j)=1d0''')
    s = once(s,'''   alpha=1d0
   do ls=0,24
    candidate(:k)=lambda(:k)-alpha*dl''','''   alpha=1d0
   do ls=0,24
    contact_swap=.false.;contact_trial_valid=.true.
    candidate(:k)=lambda(:k)-alpha*dl''')
    s = once(s,'''     call joint_entry_residual(trial,candidate(:k),nodes(:k),rp,valid)
     if(valid)then
      if(maxval(abs(rp))<norm)exit
     end if''','''     if(k==1)then
      if(nodes(1)>3*n)then
       old_contact=nodes(1)-3*n;hit_node=0;active_alpha=alpha
       do jj=2,n-1
        if(jj==old_contact.or.dh(jj)<=0d0)cycle
        if(trial(jj)>=0d0)cycle
        hit_alpha=x(jj)/dh(jj)
        if(hit_alpha>=0d0.and.hit_alpha<active_alpha)then
         hit_node=jj;active_alpha=hit_alpha
        end if
       end do
       if(hit_node>0.and.active_alpha>0d0)then
        ! The first other node to reach zero becomes the constraint. Carry
        ! the same physical level through this exact boundary intersection.
        trial=x-active_alpha*dh;trial(old_contact)=0d0;trial(hit_node)=0d0
        candidate(1)=lambda(1)-active_alpha*dl(1)
        select type(drain=>evaluation_context%source_sink)
        type is(b110_source_sink_provider_t)
         connection_pond=drain%connection_pond_cm
        class default
         connection_pond=state%pondm1
        end select
        call evaluate_b111_profile_groundwater_projection(gwl_z,gwl_distance,trial,connection_pond,gwl_view)
        contact_trial_valid=gwl_view%valid.and.gwl_view%level_present.and.all(trial>=0d0)
        if(contact_trial_valid)then
         contact_level=(1d0-candidate(1))*gwl_z(old_contact)+candidate(1)*gwl_view%level_cm
         contact_trial_valid=gwl_view%level_cm>gwl_z(hit_node)
         if(contact_trial_valid)then
          candidate(1)=(contact_level-gwl_z(hit_node))/(gwl_view%level_cm-gwl_z(hit_node))
          contact_trial_valid=candidate(1)>=0d0.and.candidate(1)<=1d0
         end if
        end if
        contact_trial=3*n+hit_node;contact_swap=.true.
       end if
      end if
     end if
     if(contact_trial_valid)then
      if(contact_swap)then
       call joint_entry_residual(trial,candidate(:1),[contact_trial],rp,valid)
      else
       call joint_entry_residual(trial,candidate(:k),nodes(:k),rp,valid)
      end if
      if(valid)then
       if(maxval(abs(rp))<norm)exit
      end if
     end if''')
    s = once(s,'   x=trial;lambda(:k)=candidate(:k)','''   if(contact_swap)then
    nodes(1)=contact_trial;ctest(:,1)=0d0;ctest(contact_trial-3*n,1)=1d0
   end if
   x=trial;lambda(:k)=candidate(:k)''')
    s = once(s,'  provider_macropore_surface_area_fraction=saved_surface_area','''  provider_macropore_surface_area_fraction=saved_surface_area
  if(associated(evaluation_context%source_sink))then
   select type(drain=>evaluation_context%source_sink)
   type is(b110_source_sink_provider_t)
    drain%connection_node=saved_connection_node;drain%connection_fraction=saved_connection_fraction
   end select
  end if''')
    s = once(s,''' integer::j
 ok=.false.
 select type(mp=>evaluation_context%macropore)''',''' integer::j,connection
 ok=.false.;r=0d0;connection=0
 if(associated(evaluation_context%source_sink))then
  select type(drain=>evaluation_context%source_sink)
  type is(b110_source_sink_provider_t)
   drain%connection_node=0;drain%connection_fraction=0d0
   do j=1,size(nodes)
    if(nodes(j)<=3*NN)cycle
    connection=nodes(j)-3*NN
    if(any(x(:connection-1)<0d0).or.any(x(connection+1:)<0d0))return
    drain%connection_node=connection;drain%connection_fraction=fraction(j)
   end do
  end select
 end if
 select type(mp=>evaluation_context%macropore)''')
    s = once(s,'''   if(nodes(j)>2*NN)then
    mp%zero_head_fraction(nodes(j)-2*NN)=fraction(j)''','''   if(nodes(j)>3*NN)then
    mp%zero_head_fraction(nodes(j)-3*NN)=fraction(j)
   else if(nodes(j)>2*NN)then
    mp%zero_head_fraction(nodes(j)-2*NN)=fraction(j)''')
    shadow[ROOT/name].write_text(s,newline='\n')

    name='src/runtime/mod_fmr_serialized_reference_backend.f90';s=shadow[ROOT/name].read_text()
    s=once(s,'    logical::joint_drain_active,joint_drain_ok','    logical::joint_drain_active,joint_drain_ok\n    real(real64)::joint_drain_level')
    s=once(s,'      joint_drain_source=self%source_sink','''      joint_drain_source=self%source_sink
      joint_drain_source%connection_pond_cm=hydraulic_start%ponding_depth
      joint_drain_source%connection_seed_level_cm=hydraulic_start%groundwater_level''')
    s=once(s,'''          hydraulic_start%groundwater_level=profile_projection%level_cm
          self%last_observation%drainage_qbot_projection_available=.true.''','''          if(self%macropore_active)call retain_connection_projection(self%soil_parameters%z, &
            hydraulic_start%pressure_head,hydraulic_start%groundwater_level,profile_projection)
          hydraulic_start%groundwater_level=profile_projection%level_cm
          self%last_observation%drainage_qbot_projection_available=.true.''')
    s=once(s,'      allocate(joint_final_qdra(size(self%qdra,1),size(self%qdra,2)))','''      if(joint_drain_source%connection_node>0)then
        block
          integer::ic
          ic=joint_drain_source%connection_node
          if(abs(solve_result%candidate_state%pressure_head(ic))>1d-12)return
          if(any(solve_result%candidate_state%pressure_head(:ic-1)<0d0).or. &
             any(solve_result%candidate_state%pressure_head(ic+1:)<0d0))return
        end block
      end if
      allocate(joint_final_qdra(size(self%qdra,1),size(self%qdra,2)))''')
    s=once(s,'      if(profile_projection%level_present)solve_result%candidate_state%groundwater_level=profile_projection%level_cm',
      '''      if(profile_projection%level_present)solve_result%candidate_state%groundwater_level=profile_projection%level_cm
      if(joint_drain_active.and.joint_drain_source%connection_node>0) &
        solve_result%candidate_state%groundwater_level=joint_drain_level''')
    begin=s.index('    subroutine coupled_profile_drainage(');end=s.index('    end subroutine coupled_profile_drainage',begin)
    body=s[begin:end]
    body=once(body,'      ok=.false.;qdra=0d0','''      real(real64)::projected_head(size(head)),fraction
      integer::ic
      ok=.false.;qdra=0d0;joint_drain_level=999d0''')
    body=once(body,'''      call evaluate_b111_profile_groundwater_projection(self%soil_parameters%z,self%soil_parameters%node_distance, &
        head,hydraulic_start%ponding_depth,projection)''','''      projected_head=head
      ic=joint_drain_source%connection_node
      if(ic>0)then
        if(any(head(:ic-1)<0d0).or.any(head(ic+1:)<0d0))ic=0
      end if
      if(ic>0)projected_head(ic)=0d0
      call evaluate_b111_profile_groundwater_projection(self%soil_parameters%z,self%soil_parameters%node_distance, &
        projected_head,hydraulic_start%ponding_depth,projection)''')
    body=once(body,'      view%active_nodes=size(head);view%pressure_head=head;view%water_content=theta','''      if(ic>0)then
        fraction=joint_drain_source%connection_fraction
        if(.not.ieee_is_finite(fraction))return
        if(fraction<0d0.or.fraction>1d0)return
        projection%level_cm=(1d0-fraction)*self%soil_parameters%z(ic)+fraction*projection%level_cm
      end if
      joint_drain_level=projection%level_cm
      view%active_nodes=size(head);view%pressure_head=head;view%water_content=theta''')
    s=s[:begin]+body+s[end:]
    marker='  real(real64) function trial_drainage_exchange_error(self,full,half,dt) result(error)'
    s=once(s,marker,'''  pure subroutine retain_connection_projection(z,head,level,projection)
    real(real64),intent(in)::z(:),head(:),level
    type(b111_profile_groundwater_projection_t),intent(inout)::projection
    integer::i,n
    if(.not.projection%valid.or..not.projection%level_present.or..not.ieee_is_finite(level))return
    n=size(head)
    if(n<3.or.size(z)/=n)return
    if(minval(head)/=0d0.or.head(1)<=0d0.or.head(n)<=0d0.or.level>=projection%level_cm)return
    do i=n-1,2,-1
      if(head(i)/=0d0.or.level<z(i))cycle
      projection%level_cm=level
      return
    end do
  end subroutine retain_connection_projection

'''+marker)
    s=once(s,'''        state%pressure_head,state%ponding_depth,projection)
      if(.not.projection%valid)return
      if(projection%level_present)then
        view%active_nodes=state%active_nodes''','''        state%pressure_head,state%ponding_depth,projection)
      if(.not.projection%valid)return
      if(self%macropore_active)call retain_connection_projection(self%soil_parameters%z, &
        state%pressure_head,state%groundwater_level,projection)
      if(projection%level_present)then
        view%active_nodes=state%active_nodes''')
    shadow[ROOT/name].write_text(s,newline='\n')
    p=folder/'MODEL.json';r=json.loads(p.read_text())
    r.update(model=MODEL,connection='At a limiting interior zero head with the other heads nonnegative, solve a bounded level between actual disconnected/connected limits; evaluate DRAMET3/DIVDRA at that same level in the residual and its accepted receipt. An exact first boundary intersection can change the limiting node while carrying the same physical level. Trial scratch only.',rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes())for n,p in shadow.items()})
    p.write_text(json.dumps(r,indent=2)+'\n')
    return shadow


if __name__=='__main__':
    previous.previous.drainage.current.contact.base.render=render
    previous.previous.drainage.current.contact.base.main()
    p=Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json'
    r=json.loads(p.read_text());r['contact_model']=MODEL;p.write_text(json.dumps(r,indent=2)+'\n')
