"""V4 research: current profile groundwater, macro exchange and real drainage."""
import json,sys
from pathlib import Path
import build_joint_current_view_candidate as current
from build_joint_entry_candidate import ROOT,once,sha
MODEL='ANDELST_JOINT_CURRENT_GROUNDWATER_DRAINAGE_GRAPH_V4'

def render(folder):
 shadow=current.render(folder)
 name='src/solver/mod_b110_source_sink_provider.f90';s=(ROOT/name).read_text()
 s=once(s,'  type, extends(source_sink_provider_t), public :: b110_source_sink_provider_t', '''  abstract interface
    subroutine current_drainage_ifc(head,theta,qdra,ok)
      import real64
      real(real64),intent(in)::head(:),theta(:)
      real(real64),intent(out)::qdra(:,:)
      logical,intent(out)::ok
    end subroutine
  end interface
  type, extends(source_sink_provider_t), public :: b110_source_sink_provider_t''')
 s=once(s,'     integer :: active_nodes = 0',
  '     procedure(current_drainage_ifc),pointer,nopass::current_drainage=>null()\n     integer :: active_nodes = 0')
 s=once(s,'    integer :: level, n',
  '    integer :: level, n\n    real(real64),allocatable::candidate_drainage(:,:)\n    logical::current_ok')
 s=once(s,'    do level = 1, self%drainage_levels', '''    if(associated(self%current_drainage))then
      allocate(candidate_drainage(self%drainage_levels,n))
      call self%current_drainage(pressure_head,water_content,candidate_drainage,current_ok)
      if(.not.current_ok)error stop 'V4 current drainage source refused'
      sink=sum(candidate_drainage,dim=1)
      return
    end if
    do level = 1, self%drainage_levels''')
 target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(s,newline='\n');shadow[ROOT/name]=target
 name='src/runtime/mod_fmr_serialized_reference_backend.f90';s=(ROOT/name).read_text()
 begin=s.index('  subroutine fmr_serialized_advance(');end=s.index('  end subroutine fmr_serialized_advance',begin)
 body=s[begin:end]
 body=once(body,'    type(soil_water_solve_request_t) :: request', '''    type(soil_water_solve_request_t) :: request
    type(b110_source_sink_provider_t),target::joint_drain_source
    type(fmr_drainage_response_diagnostics_t)::joint_drain_diagnostics
    real(real64),allocatable::joint_final_qdra(:,:)
    logical::joint_drain_active,joint_drain_ok''')
 body=once(body,'    outcome = trial_outcome_t()',
  '    joint_drain_active=.false.\n    outcome = trial_outcome_t()')
 marker='    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink'
 body=once(body,marker,'''    if(self%macropore_active.and.self%drainage_response_active.and.allocated(self%drainage_trial_distribution))then
      if(.not.associated(request%evaluation%source_sink,self%source_sink))return
      ! Local callback lifetime ends with this synchronous serialized advance.
      ! Its evaluations never overwrite the old qdra binding during Newton.
      joint_drain_source=self%source_sink
      joint_drain_source%current_drainage=>coupled_profile_drainage
      request%evaluation%source_sink=>joint_drain_source
      joint_drain_active=.true.
    end if
'''+marker)
 marker='    if (self%solute_state_layout_id /= FMR_SOLUTE_STATE_LAYOUT_NONE) then\n      select type (salt_physical => state)'
 body=once(body,marker,'''    if(joint_drain_active)then
      ! The identical functional source used by the converged residual, not a
      ! water/flux correction. Publish it before transport, mass and trace use.
      allocate(joint_final_qdra(size(self%qdra,1),size(self%qdra,2)))
      call coupled_profile_drainage(solve_result%candidate_state%pressure_head, &
        solve_result%candidate_state%water_content,joint_final_qdra,joint_drain_ok)
      if(.not.joint_drain_ok)return
      self%qdra=joint_final_qdra
      self%drainage_response_diagnostics=joint_drain_diagnostics
      self%last_observation%drainage_response=joint_drain_diagnostics
    end if
'''+marker)
 body+='''  contains
    subroutine coupled_profile_drainage(head,theta,qdra,ok)
      real(real64),intent(in)::head(:),theta(:)
      real(real64),intent(out)::qdra(:,:)
      logical,intent(out)::ok
      type(b111_profile_groundwater_projection_t)::projection
      type(process_hydraulic_view_t)::view
      type(fmr_drainage_response_diagnostics_t)::response
      type(drainage_node_transfer_t)::partition
      type(drainage_distribution_diagnostics_t)::distribution
      ok=.false.;qdra=0d0
      if(size(qdra,1)/=1.or.size(qdra,2)/=size(head).or.size(theta)/=size(head))return
      call evaluate_b111_profile_groundwater_projection(self%soil_parameters%z,self%soil_parameters%node_distance, &
        head,hydraulic_start%ponding_depth,projection)
      if(.not.projection%valid)return
      joint_drain_diagnostics=fmr_drainage_response_diagnostics_t()
      if(.not.projection%level_present)then
        ok=.true.;return
      end if
      view%active_nodes=size(head);view%pressure_head=head;view%water_content=theta
      view%ponding_depth=hydraulic_start%ponding_depth;view%groundwater_level=projection%level_cm
      call evaluate_fmr_drainage_response_bottom_lumped(self%drainage_response_levels, &
        self%drainage_response_controls,view,qdra,response,substep_t1=t1)
      if(response%status/=FMR_DRAIN_BIND_OK)return
      call distribute_fmr_scalar_drainage(self%drainage_trial_distribution,view,sum(qdra),partition, &
        distribution,self%soil_temperature_temporal_tolerance_c>0d0)
      if(distribution%status/=DRAIN_DIST_OK)return
      qdra(1,:)=partition%soil_to_drain_rate
      joint_drain_diagnostics=response
      ok=all(ieee_is_finite(qdra))
    end subroutine coupled_profile_drainage
'''
 s=s[:begin]+body+s[end:]
 target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(s,newline='\n');shadow[ROOT/name]=target
 name='src/legacy/b1_10_port/headcalc.f90';s=shadow[ROOT/name].read_text()
 marker='   ! The constitutive provider owns the storage increment for every explicit'
 s=once(s,marker,'''   ! V4's current drainage is a functional source of this exact candidate.
   ! The ordinary F-SI10 source was constant; refresh the research callback
   ! before every residual rather than merely at HeadCalc initialization.
   if(provider_source_sink_active)then
      call evaluation_context%source_sink%evaluate(state%h(1:numnod),state%theta(1:numnod), &
           fsi_ws%source(1:numnod),fsi_ws%sink(1:numnod))
   end if
'''+marker)
 shadow[ROOT/name].write_text(s,newline='\n')
 name='src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90';s=shadow[ROOT/name].read_text()
 s=once(s,'    call evaluate_sorptivity_rate(sorp_request,sorp_result)', '    ! A graph fraction also needs a consistent off-constraint extension when\n    ! a trial pressure puts the ordinary water-table face in the adjacent cell.\n    ! On the constrained face the existing 1e-10 geometry convention already\n    ! selects this same open cell. Publication still requires the exact plane.\n    if(allocated(request%perched_graph_fraction))then\n      ic=sorp_request%matrix_top_saturated_node\n      if(ic>=1.and.ic<=sorp_request%num_nodes)then\n        if(request%perched_graph_fraction(ic)>=0d0)sorp_request%matrix_top_saturated_node=ic+1\n      end if\n    end if\n    call evaluate_sorptivity_rate(sorp_request,sorp_result)')
 s=once(s,'request%sorptivity%matrix_top_saturated_node-1','sorp_request%matrix_top_saturated_node-1')
 shadow[ROOT/name].write_text(s,newline='\n')
 p=folder/'MODEL.json';record=json.loads(p.read_text());record.update(model=MODEL,
  drainage='Real DRAMET3 and signed DIVDRA from the same current heads as macro exchange. Scoped local source callback; same final rate precedes mass and accepted trace.',
  rendered_sources_sha256={str(n.relative_to(ROOT)):sha(p.read_bytes())for n,p in shadow.items()})
 p.write_text(json.dumps(record,indent=2)+'\n');return shadow

if __name__=='__main__':
 current.contact.base.render=render
 current.contact.base.main()
 p=Path(sys.argv[sys.argv.index('--output')+1])/'BUILD.json';record=json.loads(p.read_text())
 record['contact_model']=MODEL;p.write_text(json.dumps(record,indent=2)+'\n')
