"""Build an explicit corrected sharp-entry model from reviewed current owners."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()

def once(s,old,new):
 assert s.count(old)==1,(old[:80],s.count(old));return s.replace(old,new)

def render(folder):
 bodies={};sources={}
 def get(name):
  raw=(ROOT/name).read_bytes();sources[name]=sha(raw);return raw.decode().replace('\r\n','\n')
 name='src/process/macropore/mod_ppa_wu05a6_unsat_absorption_rate.f90';s=get(name)
 s=once(s,'    real(real64) :: entry_transition_width_cm = 0.0_real64','    real(real64) :: entry_transition_width_cm = 0.0_real64\n    real(real64),allocatable::entry_graph_fraction(:)')
 s=once(s,'    ok = self%sorptivity%valid()',"""    if(allocated(self%entry_graph_fraction))then
      ok=size(self%entry_graph_fraction)==self%sorptivity%num_nodes
      if(.not.ok)return
      ok=all(ieee_is_finite(self%entry_graph_fraction))
      if(.not.ok)return
      ok=all(self%entry_graph_fraction>=-1d0).and.all(self%entry_graph_fraction<=1d0)
      if(.not.ok)return
      if(any(self%entry_graph_fraction>=0d0).and.self%entry_transition_width_cm/=0d0)then
        ok=.false.;return
      end if
    end if
    ok = self%sorptivity%valid()""")
 marker='          recres = request%shape_factor'
 assert s.count(marker)==1;s=s.replace(marker,"""          if(allocated(request%entry_graph_fraction))then
            if(request%entry_graph_fraction(ic)>=0d0.and.hmp>1d-8)delh=max(0d0,hmp-request%pressure_head(ic))
          end if
"""+marker)
 marker='        selected = request%sorptivity%flow_reduction*selected'
 s=once(s,marker,"""        if(allocated(request%entry_graph_fraction))then
          if(request%entry_graph_fraction(ic)>=0d0)then
            selected=result%sorptivity_amount_cm(id,ic)+request%entry_graph_fraction(ic)* &
                     max(0d0,darcy_scaled-result%sorptivity_amount_cm(id,ic))
            if(request%entry_graph_fraction(ic)>0d0.and.darcy_scaled>result%sorptivity_amount_cm(id,ic))then
              ! Any actual Darcy occurrence terminates the sorption event.
              ! No convex averaging of elapsed clocks or persistent states.
              result%selected_by_sorptivity(id,ic)=.false.;result%end_event(id,ic)=.true.
            else
              result%selected_by_sorptivity(id,ic)=result%sorptivity_amount_cm(id,ic)>0d0
              result%end_event(id,ic)=.true.
              if(result%selected_by_sorptivity(id,ic))result%end_event(id,ic)=sorp_result%end_event(id,ic)
            end if
          end if
        end if
"""+marker);bodies[name]=s
 name='src/runtime/mod_ppa_wu05a16_inner_macropore_provider.f90';s=get(name)
 s=once(s,'    logical :: covering_layer_enabled=.false.','    real(real64),allocatable::entry_fraction(:)\n    logical :: covering_layer_enabled=.false.')
 s=once(s,'    self%configured=.true.',"    if(allocated(self%entry_fraction))deallocate(self%entry_fraction)\n    allocate(self%entry_fraction(size(dz)));self%entry_fraction=-1d0\n    self%configured=.true.")
 s=once(s,'    call evaluate_macropore_rate_bundle(request,rates)',"    if(allocated(self%entry_fraction))request%unsaturated%entry_graph_fraction=self%entry_fraction\n    call evaluate_macropore_rate_bundle(request,rates)")
 bodies[name]=s
 name='src/runtime/mod_macropore_single_column_runtime.f90';s=get(name)
 marker='      call evaluate_macropore_rate_bundle(rate_request,raw_rates)'
 assert s.count(marker)==2
 s=s.replace(marker,"""      if(any(inner_provider%entry_fraction>=0d0))then
        block
          integer::entry_node
          do entry_node=1,n
            if(inner_provider%entry_fraction(entry_node)<0d0)cycle
            if(abs(corrector%candidate_state%pressure_head(entry_node)- &
                (rate_request%unsaturated%entry_head(entry_node)-1d-8))>1d-12)then
              result%status=MACRO_RUNTIME_RETRY;return
            end if
          end do
        end block
        rate_request%unsaturated%entry_graph_fraction=inner_provider%entry_fraction
      end if
"""+marker,1);bodies[name]=s
 name='src/legacy/b1_10_port/headcalc.f90';s=get(name)
 s=once(s,'   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t','   use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t\n   use mod_ppa_wu05a16_inner_macropore_provider,only:ppa_wu05a16_inner_macropore_provider_t\n   use mod_reference_bordered_solver,only:reference_bordered_solve')
 s=once(s,'   integer::storage_rank,storage_additional_solves','   logical::entry_produced\n   integer::storage_rank,storage_additional_solves')
 marker='!     check on convergence of solution'
 s=once(s,marker,"""      if(provider_macropore_active.and.state%numbit>=3)then
        call joint_entry_candidate(entry_produced)
        if(entry_produced)then
          sump=.5d0*dot_product(fsi_ws%residual(:NN),fsi_ws%residual(:NN))
          Fmax=maxval(abs(fsi_ws%residual(:NN)))
        end if
      end if
"""+marker)
 s=once(s,'\ncontains\n','\ncontains\n'+(ROOT/'tests/dataqual15/research/joint_entry_headcalc.inc').read_text())
 bodies[name]=s;shadow={}
 for name,body in bodies.items():
  target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(body,newline='\n');shadow[ROOT/name]=target
 (folder/'MODEL.json').write_text(json.dumps(dict(model='ANDELST_SHARP_ENTRY_GRAPH_V1',original_historical_equivalence=False,baseline_sources_sha256=sources,rendered_sources_sha256={n:sha(s.encode())for n,s in bodies.items()},history='Unchanged sorption update; a positive Darcy occurrence ends the sorption event. No clock interpolation.',contact_width=0),indent=2)+'\n')
 return shadow

recipe=ROOT/'tests/dataqual15_hupsel/build_and_run.py';source=recipe.read_text().replace('timeout=120','timeout=300')
needle="program=a.driver.resolve()if a.driver else ROOT/'app/solute_project/main.f90';mapping={}"
source=once(source,needle,"shadow=render(out/'overlay')\n"+needle)
needle="for s in list((ROOT/'src').rglob('*.f90'))+list((ROOT/'app/solute_column').glob('*.f90'))+list((ROOT/'app/solute_project').glob('*.f90'))+[original]:"
source=once(source,needle,needle.replace('for s in','for original_source in')+'\n s=shadow.get(original_source,original_source)')
source=once(source,"visit(ROOT/'src/legacy/b1_10_port/headcalc.f90')","visit(shadow[ROOT/'src/legacy/b1_10_port/headcalc.f90'])")
namespace={'__name__':'__main__','__file__':str(recipe),'render':render}
exec(compile(source,str(recipe)+'[explicit joint entry candidate]', 'exec'),namespace)
build=namespace['out']/'BUILD.json';record=json.loads(build.read_text());record['contact_model']='ANDELST_SHARP_ENTRY_GRAPH_V1';record['original_historical_equivalence']=False;build.write_text(json.dumps(record,indent=2)+'\n')
