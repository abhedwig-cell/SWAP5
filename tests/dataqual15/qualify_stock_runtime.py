"""Run unchanged EB-I23/I24/I25 oracles on the current production compile closure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
RECIPE='tests/fkt/run_fkt22_eb_i25_preservation_gate.sh'
TESTS=['tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90',
       'tests/eb/test_eb_i24_top_liquid_sensible_inflow_runtime.f90',
       'tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90']


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    out=p.parse_args().output.resolve();out.mkdir(parents=True,exist_ok=False)
    recipe=(ROOT/RECIPE).read_text(encoding='utf-8')
    match=re.search(r'^MODULE_SRC=\(\n(.*?)^\)',recipe,re.M|re.S)
    assert match
    initial=[s.strip() for s in match[1].splitlines() if s.strip()]
    augment='tests/support/augment_bartholomeus_backend_sources.py'
    sources=list(dict.fromkeys(Path(s).as_posix() for s in subprocess.check_output(
        [sys.executable,str(ROOT/augment),'--all',*initial],cwd=ROOT,text=True).splitlines()))
    assert len(sources)==len(set(sources)) and all((ROOT/s).is_file() for s in sources)
    dependencies=[*sources,*TESTS,RECIPE,augment,'tests/dataqual15/qualify_stock_runtime.py']
    assert not subprocess.check_output(['git','diff','HEAD','--',*dependencies],cwd=ROOT)
    compiler=shutil.which('gfortran');assert compiler
    sha=lambda raw:hashlib.sha256(raw).hexdigest()
    record=dict(measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],
        scope='UNCHANGED_EB_I23_I24_I25_RUNTIME_ORACLES_ON_CURRENT_PRODUCTION',
        source_git_blob={s:subprocess.check_output(['git','rev-parse','HEAD:'+s],cwd=ROOT,text=True).strip() for s in dependencies},
        source_sha256={s:sha((ROOT/s).read_bytes()) for s in dependencies},provider_count=len(sources),
        full_energy_balance_complete=False,builds={})
    flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-fopenmp','-ffpe-trap=invalid,zero,overflow']
    for opt in ('O0','O2'):
        build=out/opt;build.mkdir();objects=[];events=[]
        for i,source in enumerate(sources):
            obj=build/(str(i)+'.o')
            cmd=[compiler,*flags,'-'+opt,'-J'+str(build),'-I'+str(build),'-c',str(ROOT/source),'-o',str(obj)]
            cp=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=120)
            (build/(str(i)+'.stderr')).write_text(cp.stderr,encoding='utf-8')
            assert cp.returncode==0,(source,cp.stderr)
            objects.append(obj);events.append(dict(source=source,command=cmd,object_sha256=sha(obj.read_bytes())))
        tests={}
        for i,test in enumerate(TESTS):
            obj=build/('test'+str(i)+'.o');exe=build/(str(i)+('.exe' if os.name=='nt' else '.native'))
            cp=subprocess.run([compiler,*flags,'-'+opt,'-J'+str(build),'-I'+str(build),'-c',str(ROOT/test),'-o',str(obj)],cwd=build,capture_output=True,text=True,timeout=60)
            assert cp.returncode==0,cp.stderr
            cp=subprocess.run([compiler,'-fopenmp','-'+opt,*map(str,objects),str(obj),'-o',str(exe)],cwd=build,capture_output=True,text=True,timeout=60)
            assert cp.returncode==0,cp.stderr
            cp=subprocess.run([str(exe)],cwd=build,capture_output=True,text=True,timeout=120)
            (build/(str(i)+'.stdout')).write_text(cp.stdout,encoding='utf-8')
            (build/(str(i)+'.run.stderr')).write_text(cp.stderr,encoding='utf-8')
            assert cp.returncode==0 and 'PASS' in cp.stdout,(test,cp.stdout,cp.stderr)
            tests[test]=dict(stdout=cp.stdout,stdout_sha256=sha(cp.stdout.encode()),executable_sha256=sha(exe.read_bytes()))
        record['builds'][opt]=dict(events=events,tests=tests)
    for test in TESTS:
        assert record['builds']['O0']['tests'][test]['stdout']==record['builds']['O2']['tests'][test]['stdout'],test
    record['status']='CURRENT_EB_I23_I24_I25_RUNTIME_O0_O2_PASS'
    (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(status=record['status'],provider_count=len(sources),tests=TESTS),indent=2))


if __name__=='__main__':main()
