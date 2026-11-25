"""Real bounded calendar reader selection and excluded cadence/domain refusals."""
import argparse,json,re,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from experimental_project import load,inventory,auxiliary_magic
from frost_calendar_state_inputs import prepare
from frost_calendar_state import selection
from original_output_baseline import assignment


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    cases=json.loads((R/'integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_CONTRACT_V1.json').read_text())['representative_cases']
    q=dict(status='RUNNING_ACTUAL_CALENDAR_FRONTEND_NOT_ADMITTED',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),positive=[],negative=[],compiler_executions=0,model_executions=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def read(folder):return load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
    try:
        for case in cases:
            folder=a.output/'inputs'/case['name'];prepare(case['kind'],case['hysteresis'],case['initial'],case['implicit'],case['calendar'],folder,reset=case['reset'],start=case['start'])
            actual=selection(folder);assert actual and actual['kind']==case['kind'] and actual['implicit']==case['implicit'] and actual['hysteresis']==case['hysteresis']
            project=read(folder);codec=auxiliary_magic(project).decode();assert codec==('S5FCC' if case['kind']=='cde' else 'S5FCW')+('002' if case['implicit'] else '001')
            q['positive'].append(dict(case=case,codec=codec,original_input_inventory=inventory(folder)));save()
        for case in (cases[0],cases[1]):
            for key,value in [('NPRINTDAY',2),('FLPRINTDT','.TRUE.'),('PERIOD',367),('SWCSV',4),('SWMACRO',1),('SWSOLU',2),('SWKIMPL',2),('DUPLICATE','SWHYST')]:
                folder=a.output/(case['name']+'-'+key);shutil.copytree(a.output/'inputs'/case['name'],folder);p=folder/'swap.swp';text=p.read_text(encoding='cp1252')
                if key=='DUPLICATE':text+='\nSWHYST = '+str(case['hysteresis'])+'\n'
                elif re.search(r'(?mi)^\s*'+key+r'\s*=',text):text=assignment(text,key,value)
                else:text+='\n'+key+' = '+str(value)+'\n'
                p.write_text(text,encoding='cp1252')
                try:read(folder)
                except ValueError as error:q['negative'].append(dict(case=case['name'],key=key,value=value,status='ACTUAL_FRONTEND_REFUSED_NO_BUILD',diagnostic=str(error),inventory=inventory(folder)));save()
                else:raise AssertionError('Excluded calendar domain admitted: '+str(folder))
        assert len(q['positive'])==7 and len(q['negative'])==16
        q['status']='ACTUAL_SEVEN_CALENDAR_CONFIGURATIONS_AND_SIXTEEN_SCOPE_REFUSALS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_CALENDAR_FRONTEND_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
