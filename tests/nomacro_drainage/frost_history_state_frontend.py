"""Exercise actual Frost/hysteresis inputs and existing public reader."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from experimental_project import load,inventory
from frost_hysteresis_composition import selection
from original_output_baseline import assignment


def main():
    p=argparse.ArgumentParser()
    for name in ('evidence','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),checks=[],compiler_executions=0,model_executions=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def read(folder):return load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
    def record(folder,label,status):q['checks'].append(dict(label=label,status=status,input_root=str(folder),input_inventory=inventory(folder)));save()
    try:
        for kind,hys,initial in [('water',0,1),('water',1,1),('cde',0,2),('cde',1,2)]:
            original=a.evidence/('frost-history-state01-explicit-'+kind+'-hys'+str(hys)+'-initial'+str(initial)+'-input-v1')
            assert selection(original) is not None;read(original);record(original,original.name,'CURRENT_NEW_ROUTE_SELECTED')
            if hys!=int(kind=='cde'):continue
            edits=[('SWMACRO',1),('SWSOLU',2),('SWKIMPL',1),('SWSNOW',0),('SWHEA',0),('SWCALT',1),('SWSOPHY',1),('SWDRA',0),('SWBOTB',5),('SWBR',1),('SWMETDETAIL',1),('IHWCKMODEL',8),('NPRINTDAY',2),('PERIOD',2),('SWMONTH',1),('FLPRINTDT','.TRUE.'),('SWINCO',3),('SWRES',0),('DRAIN',0),('DUPLICATE','SWHYST')]
            for index,(key,value) in enumerate(edits):
                folder=a.output/(kind+'-refusal-'+str(index));shutil.copytree(original,folder);p=folder/'swap.swp';s=p.read_text(encoding='cp1252')
                if key=='DRAIN':p=folder/'swap.dra';s=assignment(p.read_text(encoding='cp1252'),'SWDIVD',value)
                elif key=='DUPLICATE':s+='\nSWHYST = '+str(hys)+'\n'
                elif key in ('IHWCKMODEL','FLPRINTDT') and not re.search(r'(?mi)^\s*'+key+r'\s*=',s):s+='\n'+key+' = '+str(value)+'\n'
                else:s=assignment(s,key,value)
                p.write_text(s,encoding='cp1252')
                try:selected=selection(folder)
                except ValueError:selected=None
                assert selected is None
                try:read(folder)
                except ValueError:record(folder,key+'='+str(value),'ACTUAL_PUBLIC_FRONTEND_REFUSED_NO_BUILD')
                else:raise AssertionError('Unexpected public admission '+folder.name)
            folder=a.output/(kind+'-retained-hys2');shutil.copytree(original,folder);p=folder/'swap.swp';p.write_text(assignment(p.read_text(encoding='cp1252'),'SWHYST',2),encoding='cp1252');assert selection(folder) is None;read(folder);record(folder,folder.name,'EXISTING_HYS2_ROUTE_RETAINED')
        assert len(q['checks'])==46
        q['status']='ACTUAL_NEW_FRONTEND_FOUR_POSITIVES_FORTY_REFUSALS_TWO_OLD_HYS2_RETAINED'
    except Exception as error:q.update(status='FAILED_ACTUAL_FRONTEND',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
