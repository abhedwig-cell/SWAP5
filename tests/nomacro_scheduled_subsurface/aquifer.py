"""Actual mixed-aquifer daily host: full periods and exact native windows."""
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


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input-root',type=Path,required=True)
    p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reuse-soil-o0',type=Path)
    a=p.parse_args();out=a.output.resolve();out.mkdir()
    report=dict(source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                status='RUNNING',cases={},guard_mg_cm2=1e-10,science='NOT_QUALIFIED')
    def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    save()
    try:
        for case in ('soil-transfer','box-release','sorption-decay','stiff-loss'):
            project=m.e.load(a.input_root/case)
            for opt in ('O0','O2'):
                key=case+'-'+opt;r=report['cases'][key]={};save()
                build=a.reuse_soil_o0 if case=='soil-transfer' and opt=='O0' and a.reuse_soil_o0 else out/(key+'-build')
                if not (build/'BUILD.json').exists():
                    cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',m.e.MODEL,
                         '--experimental-project',str(a.input_root/case),'--reference-work',str(a.reference_work),
                         '--build-only','--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
                    started=time.perf_counter();run=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,timeout=180)
                    (out/(key+'-build.stdout')).write_text(run.stdout);(out/(key+'-build.stderr')).write_text(run.stderr)
                    r.update(build_seconds=time.perf_counter()-started,build_returncode=run.returncode);save()
                    assert run.returncode==0,run.stderr
                m.validate_bundle(build,a.reference_work,project)
                full=out/(key+'-full')
                r['trajectory'],data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,199,201,365,367,530,532,1096},90)
                fields=('aquifer_residual_mg_cm2','aquifer_exchange_residual_mg_cm2','soil_aquifer_residual_mg_cm2')
                r['maximum_residuals']={f:max(abs(row[f]) for row in data) for f in fields}
                assert all(v<=1e-10 for v in r['maximum_residuals'].values())
                r['final_aquifer_state']=data[-1]['aquifer_state'];save()
                r['own']=[m.own(build,a.reference_work,project,full,data,start,start+2,out/(key+'-own'+str(start))) for start in (2,199,365,530)]
                r['status']='FULL_COMPOUND_AND_EXACT_NATIVE_PASS';save();print(key,r['status'],flush=True)
        report['status']='EIGHT_FULL_PERIODS_COMPOUND_NATIVE_PASS'
    except Exception as error:report.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
