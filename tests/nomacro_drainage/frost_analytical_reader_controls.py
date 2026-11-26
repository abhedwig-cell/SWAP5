"""Actual bounded public analytical Frost reader controls; no model execution."""
import argparse,hashlib,json,re,shutil,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_analytical_inputs import prepare
from frost_analytical_input_contract import source
from original_output_baseline import assignment
from experimental_project import load
from frost_analytical_composition import selected


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    actor,contract=source();a.output.mkdir();q=dict(status='RUNNING_PUBLIC_ANALYTICAL_FROST_READER_CONTROLS_NOT_QUALIFIED',actual_observer=actor,positive=[],refused=[],compiler_executions=0,model_executions=0,canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def inventory(root):return {p.relative_to(root).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
    save()
    try:
        for index in [0,8,9,11]:
            case=contract['representative_cases'][index];good=a.output/(case['name']+'-positive');prepare(case,good)
            project=load(good,original_output=True,time_step_policy='original-adaptive-event-closure-v1');domain=selected(project)
            assert domain['analytical_frost_models']==(case['models']*2 if len(case['models'])==1 else case['models'])
            q['positive'].append(dict(case=case,input_sha256=inventory(good),actual_selected=domain));save()
            attacks=[('implicit','SWKIMPL','1'),('hysteresis1','SWHYST','1'),('hysteresis2','SWHYST','2'),('drainage','SWDRA','1'),('bottom9','SWBOTB','9'),('model2','iHWCKmodel','2 2'),('model12','iHWCKmodel','12 12'),('wrong-model-array','iHWCKmodel','3 3 3'),('active-vapor','SWVAPOR','1 1')]
            if any(x>=8 for x in case['models']):attacks.append(('wrong-vapor-array','SWVAPOR','0'))
            if 3 in case['models']:attacks.append(('original-model3-oxygen2','SWOXYGEN','2'))
            for label,key,value in attacks:
                folder=a.output/(case['name']+'-'+label);shutil.copytree(good,folder)
                paths=list(folder.glob('*.crp')) if key=='SWOXYGEN' else [folder/'swap.swp']
                for path in paths:path.write_text(assignment(path.read_text(encoding='cp1252'),key,value),encoding='cp1252')
                before=inventory(folder)
                try:load(folder,original_output=True,time_step_policy='original-adaptive-event-closure-v1')
                except ValueError as error:q['refused'].append(dict(case=case['name'],attack=label,error=repr(error),input_sha256=before))
                else:raise AssertionError('Public bounded analytical Frost mutant accepted: '+case['name']+'/'+label)
                assert inventory(folder)==before;save()
        assert len(q['positive'])==4 and len(q['refused'])==40
        assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==actor
        q['status']='FOUR_ACTUAL_PUBLIC_ANALYTICAL_FROST_POSITIVES_AND40_BOUNDED_READER_REFUSALS_PASS_NO_MODEL_DAYS'
    except Exception as error:q.update(status='FAILED_PUBLIC_ANALYTICAL_FROST_READER_CONTROLS_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
