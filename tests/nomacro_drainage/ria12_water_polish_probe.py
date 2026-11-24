"""Discriminating original wet-primary solve and exact cold; unchanged water oracle."""
import argparse,json,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_drainage'),str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
from ria12_water_polish_source import complete_inverse,git,SHA
from ria12_water_polish import POLICY,TIME_POLICY
from explicit_bottom9_runtime import m,own
from implicit_conductivity_forensics import water

def main():
    p=argparse.ArgumentParser()
    for key in ('input','reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();complete_inverse()
    head=git('rev-parse','HEAD').decode().strip();project=m.e.load(a.input,original_output=True,time_step_policy=TIME_POLICY,water_polish_policy=POLICY)
    assert project.water_polish_policy==POLICY
    a.output.mkdir();bundle=a.build_root/'bundle';started=time.perf_counter()
    q=dict(status='RUNNING_RIA_WATER_POLISH3_NOT_QUALIFIED',source=head,observer_source=head,actual_compiler_source=head,composition_core='e252e995eeece63d8f05531a10b746674c070685',days=3,optimization=a.optimization,kind='cde' if project.solute else 'water',layer_models=[12,12],input_root=str(a.input),input_inventory=m.e.inventory(a.input),build_root=str(bundle),water_polish_policy=POLICY,original_scientific_water_limit_cm='1e-10',canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        command=[sys.executable,'-B','tools/solute/run_water.py','--model',project.model,'--experimental-project',str(a.input),'--original-output','--experimental-time-step-policy',project.time_step_policy,'--experimental-water-polish-policy',POLICY,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(bundle)]
        with (a.output/'build.stdout').open('xb') as out,(a.output/'build.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=240)
        q['build']=dict(command=command,returncode=r.returncode,actual_completion_head=git('rev-parse','HEAD').decode().strip());save();r.check_returncode();assert q['build']['actual_completion_head']==head
        q['actual_BUILD_sha256']=SHA((bundle/'BUILD.json').read_bytes());m.validate_bundle(bundle,a.reference_work,project)
        q['polish_build']=json.loads((bundle/'RIA12_WATER_POLISH_BUILD_V1.json').read_text());assert q['polish_build']['original_scientific_day_and_global_water_limit_cm']=='1e-10'
        q['trajectory'],data=m.trajectory(bundle,a.reference_work,project,a.output/'trajectory',3,{1,2,3},240);save()
        q['independent_whole_water']=water(data);save()
        q['cold']=[own(bundle,a.reference_work,project,a.output/'trajectory',data,1,3,a.output/'own-1')];save()
        complete_inverse();q['status']='ACTUAL_RIA_ADDITIONAL_WATER_POLISH3_GLOBAL_NATIVE_COLD_USER_OUTPUT_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_RIA_WATER_POLISH3_NOT_QUALIFIED',error=repr(error));raise
    finally:q.update(actual_completion_head=git('rev-parse','HEAD').decode().strip(),seconds=time.perf_counter()-started);save()
    assert q['actual_completion_head']==head;print(q['status'],q['kind'],q['optimization'],q['independent_whole_water'])
if __name__=='__main__':main()
