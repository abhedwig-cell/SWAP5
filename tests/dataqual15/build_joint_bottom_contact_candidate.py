"""V5 research: complete the lower perched-contact action in the same solve.

No public production module or persisted restart schema is changed. V4 remains
available as the immutable negative. The extra fraction is trial-local only.
"""
import json, sys
from pathlib import Path
import build_joint_drainage_candidate as drainage
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_BOTH_PERCHED_CONTACTS_DRAINAGE_GRAPH_V5'


def render(folder):
    shadow = drainage.render(folder)
    name = 'src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90'
    s = shadow[ROOT/name].read_text()
    s = once(s, '::entry_graph_fraction(:),perched_graph_fraction(:)',
             '::entry_graph_fraction(:),perched_graph_fraction(:),perched_bottom_graph_fraction(:)')
    begin = s.index('    if(allocated(self%perched_graph_fraction))then')
    end = s.index('    ok = self%sorptivity%valid()', begin)
    validation = s[begin:end].replace('perched_graph_fraction', 'perched_bottom_graph_fraction')
    s = s[:end] + validation + '''    if(allocated(self%perched_graph_fraction).and.allocated(self%perched_bottom_graph_fraction))then
      if(any(self%perched_graph_fraction>=0d0.and.self%perched_bottom_graph_fraction>=0d0))then
        ok=.false.;return
      end if
    end if
''' + s[end:]
    s = once(s, '    call evaluate_sorptivity_rate(sorp_request,sorp_result)', '''    ! The lower contact acts on the first cell below the pocket. Make that
    ! cell eligible on both Newton sides before scaling its actual action.
    if(allocated(request%perched_bottom_graph_fraction).and.sorp_request%perched_active)then
      ic=sorp_request%perched_bottom_node
      if(ic>=1.and.ic<=sorp_request%num_nodes)then
        if(request%perched_bottom_graph_fraction(ic)>=0d0)then
          sorp_request%perched_bottom_node=ic-1
          if(sorp_request%perched_bottom_node<sorp_request%perched_top_node)sorp_request%perched_active=.false.
        end if
      end if
    end if
    call evaluate_sorptivity_rate(sorp_request,sorp_result)''')
    s = once(s, '        if (excluded_by_perched) cycle', '''        if(allocated(request%perched_bottom_graph_fraction))then
          if(request%perched_bottom_graph_fraction(ic)>=0d0)excluded_by_perched=.false.
        end if
        if (excluded_by_perched) cycle''')
    s = once(s, '        selected = request%sorptivity%flow_reduction*selected', '''        if(allocated(request%perched_bottom_graph_fraction))then
          if(request%perched_bottom_graph_fraction(ic)>=0d0)then
            selected=request%perched_bottom_graph_fraction(ic)*selected
            if(selected<=0d0)result%end_event(id,ic)=.true.
            if(result%selected_by_sorptivity(id,ic)) &
              result%sorptivity_action_fraction(id,ic)=request%perched_bottom_graph_fraction(ic)
          end if
        end if
        selected = request%sorptivity%flow_reduction*selected''')
    shadow[ROOT/name].write_text(s, newline='\n')

    name = 'src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90'
    s = shadow[ROOT/name].read_text()
    s = once(s, '::entry_fraction(:),perched_fraction(:)',
             '::entry_fraction(:),perched_fraction(:),bottom_fraction(:)')
    s = once(s, '    self%configured=.true.', '''    if(allocated(self%bottom_fraction))deallocate(self%bottom_fraction)
    allocate(self%bottom_fraction(size(dz)));self%bottom_fraction=-1d0
    self%configured=.true.''')
    s = once(s, '    call evaluate_macropore_rate_bundle(request,rates)', '''    if(allocated(self%bottom_fraction))request%unsaturated%perched_bottom_graph_fraction=self%bottom_fraction
    call evaluate_macropore_rate_bundle(request,rates)''')
    shadow[ROOT/name].write_text(s, newline='\n')

    name = 'src/runtime/mod_macropore_single_column_runtime.f90'
    s = shadow[ROOT/name].read_text()
    marker = '      call evaluate_macropore_rate_bundle(rate_request,raw_rates)'
    assert s.count(marker) == 2
    s = s.replace(marker, '''      if(any(inner_provider%bottom_fraction>=0d0))then
        block
          integer::contact_node
          real(real64)::contact_weight
          do contact_node=2,n
            if(inner_provider%bottom_fraction(contact_node)<0d0)cycle
            contact_weight=1d0-base_request%parameters%dz(contact_node-1)/(2d0* &
              abs(base_request%parameters%z(contact_node)-base_request%parameters%z(contact_node-1)))
            if(abs(contact_weight*corrector%candidate_state%pressure_head(contact_node-1)+ &
                (1d0-contact_weight)*corrector%candidate_state%pressure_head(contact_node))>1d-12)then
              result%status=MACRO_RUNTIME_RETRY;return
            end if
          end do
        end block
        rate_request%unsaturated%perched_bottom_graph_fraction=inner_provider%bottom_fraction
      end if
''' + marker, 1)
    shadow[ROOT/name].write_text(s, newline='\n')

    name = 'src/legacy/b1_10_port/headcalc.f90'
    s = shadow[ROOT/name].read_text()
    s = once(s, 'saved_fraction(:),saved_perched(:),weights(:)',
             'saved_fraction(:),saved_perched(:),saved_bottom(:),weights(:)')
    s = once(s, '  saved_perched=mp%perched_fraction;',
             '  saved_bottom=mp%bottom_fraction\n  saved_perched=mp%perched_fraction;')
    s = once(s, 'allocate(nodes(n),threshold(n),x(n),lambda(n),r(n),rp(n),rm(n),trial(n),candidate(n),theta0(n),weights(n),columns(2*n))',
             'allocate(nodes(2*n),threshold(n),x(n),lambda(2*n),r(n),rp(n),rm(n),trial(n),candidate(2*n),theta0(n),weights(n),columns(2*n))')
    s = once(s, '  allocate(gwl_distance(n),gwl_z(n));gwl_distance=0d0', '''  ! Positive-to-negative crossing: lower face of a perched pocket. Encode
  ! n+i separately from entry node i and upper-contact -i. Its action lives
  ! in cell i+1, while the same equality constrains heads i and i+1.
  do i=2,n-1
   if(x(i)<=0d0.or.x(i+1)>=0d0)cycle
   weights(i)=1d0-grid_dz(i)/(2d0*grid_disnod(i+1))
   if(weights(i)<=0d0.or.weights(i)>=1d0)cycle
   if(abs(weights(i)*x(i)+(1d0-weights(i))*x(i+1))>1d-3)cycle
   k=k+1;nodes(k)=n+i;x(i)=-(1d0-weights(i))*x(i+1)/weights(i);lambda(k)=0d0
   call joint_entry_residual(x,lambda(:k),nodes(:k),rp,valid)
   if(.not.valid)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=1d0;call joint_entry_residual(x,lambda(:k),nodes(:k),rm,valid)
   if(.not.valid.or.abs(rm(i+1)-rp(i+1))<1d-10)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   if(rp(i+1)*rm(i+1)>0d0)then
    k=k-1;x(i)=saved_state%h(i);cycle
   end if
   lambda(k)=min(1d0,max(0d0,-rp(i+1)/(rm(i+1)-rp(i+1))))
  end do
  allocate(gwl_distance(n),gwl_z(n));gwl_distance=0d0''')
    # All constraint, local Jacobian and line-search sites use the same map.
    split = s.index('\nsubroutine joint_entry_residual(')
    outer, residual = s[:split], s[split:]
    for j in ['j', 'jj']:
        marker = f'i=abs(nodes({j}))'
        assert outer.count(marker) >= 1
        outer = outer.replace(marker, marker+';if(i>n)i=i-n')
        outer = outer.replace(f'if(nodes({j})>0)', f'if(nodes({j})>0.and.nodes({j})<=n)')
        outer = outer.replace(f'if(nodes({j})<0)', f'if(nodes({j})<0.or.nodes({j})>n)')
    s = outer + residual
    s = once(s, '  mp%perched_fraction=saved_perched;',
             '  mp%bottom_fraction=saved_bottom\n  mp%perched_fraction=saved_perched;')
    s = once(s, '  mp%entry_fraction=-1d0;mp%perched_fraction=-1d0',
             '  mp%entry_fraction=-1d0;mp%perched_fraction=-1d0;mp%bottom_fraction=-1d0')
    s = once(s, '''   if(nodes(j)>0)then
    mp%entry_fraction(nodes(j))=fraction(j)
   else''', '''   if(nodes(j)>NN)then
    mp%bottom_fraction(nodes(j)-NN+1)=fraction(j)
   else if(nodes(j)>0)then
    mp%entry_fraction(nodes(j))=fraction(j)
   else''')
    shadow[ROOT/name].write_text(s, newline='\n')
    p = folder/'MODEL.json'
    record = json.loads(p.read_text())
    record.update(model=MODEL,
        lower_contact='Trial-local lower perched action fraction, solved with heads and all prior contacts; same weighted physical plane and unchanged1e-12 publication guard. Identical actual transfer and action history in accepted response; no elapsed-clock interpolation or persisted fraction.',
        rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes()) for n,p in shadow.items()})
    p.write_text(json.dumps(record, indent=2)+'\n')
    return shadow


if __name__ == '__main__':
    drainage.current.contact.base.render = render
    drainage.current.contact.base.main()
    p = Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json'
    record = json.loads(p.read_text()); record['contact_model'] = MODEL
    p.write_text(json.dumps(record, indent=2)+'\n')
