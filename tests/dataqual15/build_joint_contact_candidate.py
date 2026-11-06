"""Explicit V2 research graph: sharp entry plus dynamic perched sorptivity action."""
import json, sys
from pathlib import Path
import build_joint_entry_candidate as base
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_ENTRY_PERCHED_ACTION_GRAPH_V2'
entry_render = base.render

def render(folder):
    shadow = entry_render(folder)
    def get(name):
        return shadow.get(ROOT / name, ROOT / name).read_text()
    bodies = {}
    name = 'src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90'
    s = get(name)
    s = once(s, '    real(real64),allocatable::entry_graph_fraction(:)',
             '    real(real64),allocatable::entry_graph_fraction(:),perched_graph_fraction(:)')
    s = once(s, '    logical, allocatable :: end_event(:,:)',
             '    logical, allocatable :: end_event(:,:)\n    real(real64),allocatable::sorptivity_action_fraction(:,:)')
    s = once(s, '    ok = self%sorptivity%valid()', '''    if(allocated(self%perched_graph_fraction))then
      ok=size(self%perched_graph_fraction)==self%sorptivity%num_nodes
      if(.not.ok)return
      ok=all(ieee_is_finite(self%perched_graph_fraction))
      if(.not.ok)return
      ok=all(self%perched_graph_fraction>=-1d0).and.all(self%perched_graph_fraction<=1d0)
      if(.not.ok)return
      if(any(self%perched_graph_fraction>=0d0).and.self%entry_transition_width_cm/=0d0)then
        ok=.false.;return
      end if
    end if
    ok = self%sorptivity%valid()''')
    # Only the top contact cell is made eligible. Other perched exclusions remain.
    s = once(s, '    call evaluate_sorptivity_rate(sorp_request,sorp_result)', '''    if(allocated(request%perched_graph_fraction).and.sorp_request%perched_active)then
      ic=sorp_request%perched_top_node
      if(ic>=1.and.ic<=sorp_request%num_nodes)then
        if(request%perched_graph_fraction(ic)>=0d0)sorp_request%perched_top_node=ic+1
      end if
    end if
    call evaluate_sorptivity_rate(sorp_request,sorp_result)''')
    s = once(s, '    result%end_event = .true.', '''    result%end_event = .true.
    allocate(result%sorptivity_action_fraction(nd,n));result%sorptivity_action_fraction=-1d0''')
    s = once(s, '        if (excluded_by_perched) cycle', '''        if(allocated(request%perched_graph_fraction))then
          if(request%perched_graph_fraction(ic)>=0d0)excluded_by_perched=.false.
        end if
        if (excluded_by_perched) cycle''')
    s = once(s, '        selected = request%sorptivity%flow_reduction*selected', '''        if(allocated(request%perched_graph_fraction))then
          if(request%perched_graph_fraction(ic)>=0d0)then
            selected=request%perched_graph_fraction(ic)*selected
            if(selected<=0d0)result%end_event(id,ic)=.true.
            if(result%selected_by_sorptivity(id,ic)) &
              result%sorptivity_action_fraction(id,ic)=request%perched_graph_fraction(ic)
          end if
        end if
        selected = request%sorptivity%flow_reduction*selected''')
    bodies[name] = s
    name = 'src/process/macropore/mod_ppa_wu05a6_sorptivity_history.f90'
    s = get(name)
    s = once(s, '  implicit none', '  use ieee_arithmetic,only:ieee_is_finite\n  implicit none')
    s = once(s, '    real(real64)::time,delta_root,sorp,theta_ref',
             '    real(real64)::time,delta_root,sorp,theta_ref,fraction,increment')
    s = once(s, '    do id=1,nd', '''    if(allocated(absorption%sorptivity_action_fraction))then
      if(any(shape(absorption%sorptivity_action_fraction)/=[nd,n]))return
      if(any(.not.ieee_is_finite(absorption%sorptivity_action_fraction)))return
      if(any(absorption%sorptivity_action_fraction< -1d0).or.any(absorption%sorptivity_action_fraction>1d0))return
    end if
    do id=1,nd''')
    s = once(s, '            delta_root=sqrt(time+request%step_duration)-sqrt(time)', '''            delta_root=sqrt(time+request%step_duration)-sqrt(time)
            increment=request%step_duration
            if(allocated(absorption%sorptivity_action_fraction))then
              fraction=absorption%sorptivity_action_fraction(id,ic)
              if(fraction>=0d0)then
                delta_root=fraction*request%step_duration/(sqrt(time+request%step_duration)+sqrt(time))
                increment=delta_root*(2d0*sqrt(time)+delta_root)
              end if
            end if''')
    s = once(s, 'candidate_macro%absorption_time(id,ic)=time+request%step_duration',
             'candidate_macro%absorption_time(id,ic)=time+increment')
    bodies[name] = s
    name = 'src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90'
    s = get(name).replace('::entry_fraction(:)', '::entry_fraction(:),perched_fraction(:)')
    s = once(s, '    self%configured=.true.', '''    if(allocated(self%perched_fraction))deallocate(self%perched_fraction)
    allocate(self%perched_fraction(size(dz)));self%perched_fraction=-1d0
    self%configured=.true.''')
    s = once(s, '    call evaluate_macropore_rate_bundle(request,rates)', '''    if(allocated(self%perched_fraction))request%unsaturated%perched_graph_fraction=self%perched_fraction
    call evaluate_macropore_rate_bundle(request,rates)''')
    bodies[name] = s
    name = 'src/runtime/mod_macropore_single_column_runtime.f90'
    s = get(name)
    marker = '      call evaluate_macropore_rate_bundle(rate_request,raw_rates)'
    assert s.count(marker) == 2
    s = s.replace(marker, '''      if(any(inner_provider%perched_fraction>=0d0))then
        block
          integer::contact_node
          real(real64)::contact_weight
          do contact_node=1,n-1
            if(inner_provider%perched_fraction(contact_node)<0d0)cycle
            contact_weight=1d0-base_request%parameters%dz(contact_node)/(2d0* &
              abs(base_request%parameters%z(contact_node+1)-base_request%parameters%z(contact_node)))
            if(abs(contact_weight*corrector%candidate_state%pressure_head(contact_node)+ &
              (1d0-contact_weight)*corrector%candidate_state%pressure_head(contact_node+1))>1d-12)then
              result%status=MACRO_RUNTIME_RETRY;return
            end if
          end do
        end block
        rate_request%unsaturated%perched_graph_fraction=inner_provider%perched_fraction
      end if
''' + marker, 1)
    bodies[name] = s
    name = 'src/legacy/b1_10_port/headcalc.f90'
    s = get(name)
    s = once(s, (ROOT/'tests/dataqual15/research/joint_entry_headcalc.inc').read_text(),
             (ROOT/'tests/dataqual15/research/joint_contact_headcalc.inc').read_text())
    bodies[name] = s
    for name, body in bodies.items():
        target = folder/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(body, newline='\n')
        shadow[ROOT/name] = target
    record = json.loads((folder/'MODEL.json').read_text())
    record.update(model=MODEL, history='Perched fraction scales sorptivity action; no elapsed-clock interpolation.',
                  rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes()) for n,p in shadow.items()})
    (folder/'MODEL.json').write_text(json.dumps(record, indent=2)+'\n')
    return shadow

if __name__ == '__main__':
    base.render = render
    base.main()
    output = Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json'
    record = json.loads(output.read_text());record['contact_model'] = MODEL
    output.write_text(json.dumps(record, indent=2)+'\n')
