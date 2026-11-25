"""Real public loading, bounded exclusions and exact unchanged root providers."""
import argparse,ast,hashlib,json,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_boundary_inputs import prepare
from original_output_baseline import assignment
import experimental_project as public
import frost_boundary_composition as boundary
import implicit_frost_root_state as root
BASE='3250f0c59337334994b0e8edda624afe8f91b11f'


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    actual=subprocess.check_output(['git','show',BASE+':app/hybrid_water/implicit_frost_root_state.py'],cwd=R)
    old={'__file__':str(R/'app/hybrid_water/implicit_frost_root_state.py')}
    exec(compile(actual,'actual-parent-root-bytes','exec'),old)
    for solute in (False,True):
        for mode in (0,1,2):assert root.source(solute,mode)==old['source'](solute,mode)
    cases=[]
    for bottom in (5,8):
        for kind in ('water','cde'):
            for implicit in (0,1):
                name=f'{kind}-bottom{bottom}-implicit{implicit}';folder=a.output/name
                prepare(kind,implicit,bottom,folder)
                selected=boundary.selection(folder,True);assert selected and selected['bottom']==bottom
                project=public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
                from frost_drainage_composition import codec,metadata
                assert codec(project)==boundary.codec(selected) and metadata(project)['boundary_composition']['bottom']==bottom
                if implicit:
                    assert root.boundary(project)==bottom
                    assert '(swbotb/='+str(bottom)+'.or.swfrost/=1' in root.source(project.solute,2,bottom)
                cases.append(dict(case=name,codec=codec(project).decode(),selection=selected))
    donor=a.output/'water-bottom5-implicit0';declined=[]
    changes=dict(SWHYST=0,SWINCO=1,SWBOTB=6,SWDRA=0,SWSOLU=2,SWBR=1,SWMETDETAIL=1,
                 SWMACRO=1,SWKIMPL=2,SWMONTH=1,SWODAT=1,SWRES=0,PERIOD=7,NPRINTDAY=2)
    for key,value in changes.items():
        folder=a.output/('outside-'+key);shutil.copytree(donor,folder)
        path=folder/'swap.swp';path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
        assert boundary.selection(folder,True) is None,key
        try:project=public.load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
        except ValueError as error:outcome=dict(public_refused=True,reason=str(error))
        else:
            assert key=='SWBOTB' and value==6
            assert root.boundary(project)==6
            outcome=dict(public_refused=False,existing_bottom6_parent_route_retained=True)
        declined.append(dict(selector=key,value=value,bounded_new_selector_declined=True,**outcome))
    q=dict(status='EIGHT_ACTUAL_PUBLIC_LOADS_FOUR_CODECS_FOURTEEN_BOUNDED_DECLINES_AND_SIX_EXACT_PARENT_ROOT_PROVIDERS_PASS',
           source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),
           cases=cases,declined=declined,default_bottom6_generated_providers_exact=6,
           compiler_executions=0,model_executions=0,scientific_equivalence='NOT_QUALIFIED')
    (a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');print(q['status'],flush=True)


if __name__=='__main__':main()
