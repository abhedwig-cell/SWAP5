"""Actual original age host full trajectories, native state and all age outputs."""
import argparse
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('mixtures',ROOT/'tests/nomacro_mixtures/run.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def own(build,reference,project,full,data,start,end,out):
    report=m.own(build,reference,project,full,data,start,end,out)
    for name in ('result.ageProfile.csv','result.ageeffluent.csv','result.ageeffluentqdrain.csv'):
        assert m.csvlines(out/'original'/name)[-(end-start):]==m.csvlines(full/'original'/name)[start+1:end+1],name
    report['all_three_age_csv_exact']=True
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('input-root','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--reuse-zero-o0',type=Path);a=p.parse_args();a.output.mkdir()
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles={},
                units='cm day',whole_scientific_equivalence='NOT_QUALIFIED',chemical_mass_guard_changed=False,water_guard_cm=1e-10)
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for initial in ('0','100'):
            project=m.e.load(a.input_root/initial)
            for opt in ('O0','O2'):
                name=initial+'-'+opt;r=result['profiles'][name]={};save()
                build=a.reuse_zero_o0 if initial=='0' and opt=='O0' and a.reuse_zero_o0 else a.output/(name+'-build')
                if not (build/'BUILD.json').exists():
                    command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                        '--experimental-project',str(a.input_root/initial),'--reference-work',str(a.reference_work),
                        '--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                    started=time.perf_counter();run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
                    (a.output/(name+'-build.log')).write_text(run.stdout+run.stderr)
                    r.update(build_seconds=time.perf_counter()-started,build_returncode=run.returncode);save();assert run.returncode==0,run.stderr
                m.validate_bundle(build,a.reference_work,project)
                short=a.output/(name+'-short');r['short'],data=m.trajectory(build,a.reference_work,project,short,5,{2,4},30)
                r['short']['own']=own(build,a.reference_work,project,short,data,2,4,a.output/(name+'-short-own'));save()
                full=a.output/(name+'-full');r['full'],data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,199,201,365,367,530,532,1096},90)
                assert data[-1]['age_state_cm_day'][3]>0 and data[-1]['age_state_cm_day'][4]>0 and data[-1]['age_state_cm_day'][10]>0
                r['maximum_residual_cm_day']={key:max(abs(row[key]) for row in data) for key in ('age_soil_residual_cm_day','age_pond_residual_cm_day','age_combined_residual_cm_day')}
                r['maximum_fraction_of_accepted_age_tolerance']=max(abs(row[key])/row['age_tolerance_cm_day'] for row in data for key in r['maximum_residual_cm_day'])
                assert r['maximum_fraction_of_accepted_age_tolerance']<=1
                r['final_state_cm_day']=data[-1]['age_state_cm_day'];save()
                r['own']=[own(build,a.reference_work,project,full,data,start,start+2,a.output/(name+'-own'+str(start))) for start in (2,199,365,530)]
                r['status']='FULL_ORIGINAL_AGE_LEDGER_NATIVE_AND_OUTPUT_PASS';save();print(name,r['status'],flush=True)
        result['status']='FOUR_FULL_ORIGINAL_AGE_HOST_O0_O2_NATIVE_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
