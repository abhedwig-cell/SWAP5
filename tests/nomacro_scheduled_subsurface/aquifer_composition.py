"""Corrected fixed SSDI source composed with sorbing/decaying mixed aquifer."""
import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('aquifer_native',Path(__file__).with_name('aquifer_native_controls.py'))
q=importlib.util.module_from_spec(spec);spec.loader.exec_module(q);m=q.m


def main():
    p=argparse.ArgumentParser()
    for key in ('input','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();case=a.output/'input';shutil.copytree(a.input,case)
    path=case/'swap.swp';text=path.read_text(encoding='cp1252')
    for key,value in dict(SWBR=1,DAQUIF='100.0',POROS='0.35',KFSAT='0.2',DECSAT='0.001',CDRAINI='0.25').items():
        text=q.ref.assignment(text,key,value)
    path.write_text(text,encoding='cp1252');project=m.e.load(case)
    result=dict(status='RUNNING',profiles={},source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),science='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    save()
    try:
        for opt in ('O0','O2'):
            build=a.output/(opt+'-build')
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,
                '--experimental-project',str(case),'--reference-work',str(a.reference_work),'--build-only',
                '--kernel-opt',opt,'--donor-opt',opt,'--output',str(build)]
            run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
            (a.output/(opt+'-build.log')).write_text(run.stdout+run.stderr);assert run.returncode==0,run.stderr
            full=a.output/(opt+'-full');r,data=m.trajectory(build,a.reference_work,project,full,1096,{2,4,6,365,367,1096},90)
            r['actual_ssdi_mass_mg_cm2']=sum(row['solute_ledger_mg_cm2'][3] for row in data)
            assert abs(r['actual_ssdi_mass_mg_cm2']-48)<=1e-10
            assert data[4]['solute_ledger_mg_cm2'][3]>0
            r['maximum_compound_residual_mg_cm2']=max(abs(row['soil_aquifer_residual_mg_cm2']) for row in data)
            assert r['maximum_compound_residual_mg_cm2']<=1e-10
            r['own']=[m.own(build,a.reference_work,project,full,data,start,start+2,a.output/(opt+'-own'+str(start))) for start in (2,4,365)]
            result['profiles'][opt]=r;save();print(opt,'AQUIFER_FIXED_CHEMICAL_FULL_NATIVE_PASS',flush=True)
        result['status']='AQUIFER_FIXED_CHEMICAL_FULL_O0_O2_COMPOSITION_PASS'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
