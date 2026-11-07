"""Private research drainage through a vanishing unsaturated matrix pocket."""
import json
import sys
from pathlib import Path

import build_joint_connectivity_candidate as previous
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_PORE_VOLUME_CONNECTIVITY_V8'


def render(folder):
    shadow = previous.render(folder)
    name = 'src/solver/mod_b111_profile_groundwater_projection.f90'
    p = shadow[ROOT / name]
    s = once(p.read_text(), '  public :: evaluate_b111_profile_groundwater_projection',
             '  public :: evaluate_b111_profile_groundwater_projection, evaluate_b111_pore_volume_connectivity')
    helper = Path(__file__).with_name('joint_pore_volume_projection.inc').read_text()
    s = once(s, 'end module mod_b111_profile_groundwater_projection',
             helper + '\n\nend module mod_b111_profile_groundwater_projection')
    p.write_text(s, newline='\n')

    name = 'src/runtime/mod_fmr_serialized_reference_backend.f90'
    p = shadow[ROOT / name]
    s = p.read_text()
    marker = '    subroutine coupled_profile_drainage(head,theta,qdra,ok)'
    # Keep the same signed drainage owners, budgets, and callback lifetime.
    i = s.index('      real(real64)::projected_head(size(head)),fraction', s.index(marker))
    j = s.index('      joint_drain_level=projection%level_cm', i)
    s = s[:i] + '''      ok=.false.;qdra=0d0;joint_drain_level=999d0
      if(size(qdra,1)/=1.or.size(qdra,2)/=size(head).or.size(theta)/=size(head))return
      call evaluate_pore_volume_profile(self,head,theta,hydraulic_start%ponding_depth,projection)
      if(.not.projection%valid)return
      joint_drain_diagnostics=fmr_drainage_response_diagnostics_t()
      if(.not.projection%level_present)then
        ok=.true.;return
      end if
''' + s[j:]
    s = once(s, '''        call evaluate_b111_profile_groundwater_projection(self%soil_parameters%z,self%soil_parameters%node_distance, &
          hydraulic_start%pressure_head,hydraulic_start%ponding_depth,profile_projection)''',
             '''        if(self%macropore_active)then
          call evaluate_pore_volume_profile(self,hydraulic_start%pressure_head,hydraulic_start%water_content, &
            hydraulic_start%ponding_depth,profile_projection)
        else
          call evaluate_b111_profile_groundwater_projection(self%soil_parameters%z,self%soil_parameters%node_distance, &
            hydraulic_start%pressure_head,hydraulic_start%ponding_depth,profile_projection)
        end if''')
    s = once(s, '''          if(self%macropore_active)call retain_connection_projection(self%soil_parameters%z, &
            hydraulic_start%pressure_head,hydraulic_start%groundwater_level,profile_projection)
''', '')
    s = once(s, '''      if(joint_drain_active.and.joint_drain_source%connection_node>0) &
        solve_result%candidate_state%groundwater_level=joint_drain_level''',
             '''      if(joint_drain_active)solve_result%candidate_state%groundwater_level=joint_drain_level''')
    s = once(s, '''      if(self%macropore_active)call retain_connection_projection(self%soil_parameters%z, &
        state%pressure_head,state%groundwater_level,projection)''',
             '''      ! Reassess the exact level used by the accepted drainage receipt.
      if(self%macropore_active.and.projection%level_present)projection%level_cm=state%groundwater_level''')
    i = s.index('  pure subroutine retain_connection_projection(')
    end = '  end subroutine retain_connection_projection'
    j = s.index(end, i) + len(end)
    s = s[:i] + '''  subroutine evaluate_pore_volume_profile(self,head,theta,pond,projection)
    use mod_b111_profile_groundwater_projection,only:evaluate_b111_pore_volume_connectivity
    class(fmr_serialized_reference_model_t),intent(in)::self
    real(real64),intent(in)::head(:),theta(:),pond
    type(b111_profile_groundwater_projection_t),intent(out)::projection
    if(.not.allocated(self%macropore_config%rate_template%unsaturated%sorptivity%theta_s))then
      projection=b111_profile_groundwater_projection_t()
      return
    end if
    call evaluate_b111_pore_volume_connectivity(self%soil_parameters%z,self%soil_parameters%node_distance, &
      self%soil_parameters%dz,head,theta,self%macropore_config%rate_template%unsaturated%sorptivity%theta_s, &
      pond,self%macropore_config%rate_template%critical_under_saturated_volume_cm,projection)
  end subroutine evaluate_pore_volume_profile''' + s[j:]
    p.write_text(s, newline='\n')

    # Reuse the converged inner rate owner for the published macro receipt.
    # Reconstructing from the solver's different pond view changes exchange
    # after Richards already consumed it, accumulating a real matrix defect.
    name = 'src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90'
    p = shadow[ROOT / name]
    a = '    procedure, public :: evaluate_rate => evaluate_inner_macropore_rate'
    p.write_text(once(p.read_text(), a, a + '\n    procedure, public :: evaluate_converged_rates => evaluate_current_rates'),
                 newline='\n')

    name = 'src/runtime/mod_macropore_single_column_runtime.f90'
    p = shadow[ROOT / name]
    s = p.read_text()
    a = '    type(matrix_saturated_zone_view_t)::matrix_view'
    s = once(s, a, a + '\n    type(soil_water_physical_state_t)::converged_rate_matrix')
    s = once(s, '''      call prepare_standard_macropore_rate_request(rate_template_attempt,accepted_macro,geometry,accepted_view, &
           corrector%candidate_state,base_request%parameters%z,base_request%parameters%dz,dt, &
           rate_request,matrix_view,ok)''',
             '''      call inner_provider%evaluate_converged_rates(corrector%candidate_state%pressure_head, &
        corrector%candidate_state%water_content,rate_request,raw_rates,matrix_view,converged_rate_matrix,ok)''')
    a = '      call evaluate_macropore_rate_bundle(rate_request,raw_rates)'
    assert s.count(a) == 2
    s = s.replace(a, '''      result%requested_top_input_cm=sum(rate_request%limiter%potential_top_vertical_cm)+ &
        sum(rate_request%limiter%potential_top_lateral_cm)''', 1)
    s = once(s, '''      if(present(shrinkage_config))then
        if(shrinkage_config%enabled)then
          call evaluate_macropore_geometry_return(accepted_macro,geometry,geometry_return,ok)
          if(.not.ok)then
            result%status=MACRO_RUNTIME_FAILED
            return
          end if
          raw_rates%qexc_to_matrix_rate=raw_rates%qexc_to_matrix_rate+geometry_return/dt
        end if
      end if
''', '')
    p.write_text(s, newline='\n')

    m = folder / 'MODEL.json'
    receipt = json.loads(m.read_text())
    receipt.update(model=MODEL,
                   connection='Use the existing physical pore-deficit scale for bounded drainage connectivity between saturated regions; keep the exact zero-head transfer graph for macropore flow.',
                   macro_receipt='The converged inner rate evaluator also supplies the accepted macropore rate bundle and its top partition; no post-solve rate reconstruction.',
                   rendered_sources_sha256={str(n.relative_to(ROOT)): sha(p.read_bytes()) for n, p in shadow.items()})
    m.write_text(json.dumps(receipt, indent=2) + '\n')
    return shadow


if __name__ == '__main__':
    previous.previous.previous.drainage.current.contact.base.render = render
    previous.previous.previous.drainage.current.contact.base.main()
    p = Path(sys.argv[sys.argv.index('--output') + 1]) / 'BUILD.json'
    r = json.loads(p.read_text())
    r['contact_model'] = MODEL
    p.write_text(json.dumps(r, indent=2) + '\n')

