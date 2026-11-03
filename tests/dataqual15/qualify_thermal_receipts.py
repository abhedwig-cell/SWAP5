"""Actual native accepted thermal observations, transaction selection and preservation."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from qualify_stock_runtime import ROOT, RECIPE, TESTS

CHECKS='tests/dataqual15/research/thermal_receipt_runtime_checks.inc'
COMPONENT='tests/dataqual15/research/thermal_receipt_component.f90'
SELF='tests/dataqual15/qualify_thermal_receipts.py'
HELPER='tests/support/augment_bartholomeus_backend_sources.py'


def runtime_driver():
    raw=(ROOT/TESTS[2]).read_text(encoding='utf-8')
    prefix,body=raw.split('program test_eb_i25_multisubstep_sensible_boundary_runtime',1)
    imports='''
 use mod_kernel_transactions,only:kernel_checkpoint_t,kernel_result_t,kernel_candidate_state_t,kernel_diagnostics_t
 use mod_transaction_reference,only:transaction_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_serialized_physical_observation_t
 use mod_soil_temperature_contract,only:copy_soil_temperature_profile,SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX
'''
    start=body.index('  call verify_two_half_inflow_materializes_complete_boundary()')
    end=body.index('\ncontains\n',start)
    body=body[:start]+'  call verify_thermal_receipts()\n'+body[end:]
    body=body.replace('\ncontains\n','\ncontains\n'+(ROOT/CHECKS).read_text(encoding='utf-8')+'\n',1)
    return prefix+'program test_eb_i25_multisubstep_sensible_boundary_runtime'+imports+body


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
    out=ap.parse_args().output.resolve();out.mkdir(parents=True,exist_ok=False)
    fc=shutil.which('gfortran');assert fc
    sha=lambda b:hashlib.sha256(b).hexdigest()
    recipe=(ROOT/RECIPE).read_text(encoding='utf-8')
    initial=[s.strip() for s in re.search(r'^MODULE_SRC=\(\n(.*?)^\)',recipe,re.M|re.S)[1].splitlines() if s.strip()]
    sources=list(dict.fromkeys(Path(p).as_posix() for p in subprocess.check_output(
        [sys.executable,ROOT/HELPER,'--all',*initial],cwd=ROOT,text=True).splitlines()))
    dependencies=[*sources,*TESTS,RECIPE,CHECKS,COMPONENT,SELF,HELPER,'tests/dataqual15/qualify_stock_runtime.py']
    assert not subprocess.check_output(['git','diff','HEAD','--',*dependencies],cwd=ROOT),'persist implementation first'
    driver=out/'runtime.f90';driver.write_text(runtime_driver(),encoding='utf-8')
    report=dict(scope='ACTUAL_ACCEPTED_THERMAL_OBSERVATIONS_NOT_COMPLETE_PHYSICAL_ENERGY',
        measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        compiler=subprocess.check_output([fc,'--version'],text=True).splitlines()[0],
        source_git_blob={p:subprocess.check_output(['git','rev-parse','HEAD:'+p],cwd=ROOT,text=True).strip() for p in dependencies},
        generated_driver_sha256=sha(driver.read_bytes()),full_energy_balance_complete=False,builds={})
    def run(command,folder,label,timeout=120):
        start=time.monotonic();cp=subprocess.run(list(map(str,command)),cwd=folder,capture_output=True,timeout=timeout)
        (folder/(label+'.stdout')).write_bytes(cp.stdout);(folder/(label+'.stderr')).write_bytes(cp.stderr)
        assert cp.returncode==0,(label,cp.stderr.decode(errors='replace')[-2500:],cp.stdout.decode(errors='replace')[-1000:])
        return dict(command=list(map(str,command)),seconds=time.monotonic()-start,stdout_sha256=sha(cp.stdout))
    flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-fopenmp','-ffpe-trap=invalid,zero,overflow']
    # The real thermal owner has a small independently tested closure first.
    spec=importlib.util.spec_from_file_location('closure',ROOT/HELPER);closure=importlib.util.module_from_spec(spec);spec.loader.exec_module(closure)
    small,_=closure.strict_closure(ROOT,[COMPONENT])
    for opt in ('O0','O2'):
        folder=out/opt;folder.mkdir();local=['-'+opt,*flags,'-J'+str(folder),'-I'+str(folder)]
        component=folder/'component.exe'
        run([fc,*local,*small,'-o',component],folder,'component-build')
        run([component],folder,'component')
        objects=[];events=[]
        for i,source in enumerate(sources):
            obj=folder/(str(i)+'.o');events.append(run([fc,*local,'-c',ROOT/source,'-o',obj],folder,'build-'+str(i)))
            objects.append(obj)
        tests={}
        for i,source in enumerate([*map(lambda p:ROOT/p,TESTS),driver]):
            exe=folder/('test'+str(i)+'.exe')
            run([fc,*local,source,*objects,'-o',exe],folder,'link-'+str(i))
            cmd=[exe]+([folder/'receipts.csv'] if i==3 else [])
            tests[str(i)]=run(cmd,folder,'test-'+str(i))
            tests[str(i)]['executable_sha256']=sha(exe.read_bytes())
            assert b'PASS' in (folder/('test-'+str(i)+'.stdout')).read_bytes()
        lines=(folder/'receipts.csv').read_text(encoding='utf-8').splitlines()
        accepted=[l.split(',') for l in lines if l.startswith('ACCEPTED,')]
        assert [int(r[1]) for r in accepted]==[1,2] and max(float(r[2]) for r in accepted)<1e-10
        nodes=[l.split(',') for l in lines if l.startswith('NODE,')]
        assert nodes and max(abs(float(r[-2])-float(r[-1])) for r in nodes)<1e-10
        report['builds'][opt]=dict(events=events,tests=tests,node_rows=len(nodes),accepted_intervals=3,
                                  max_nodal_error_j_cm2=max(abs(float(r[-2])-float(r[-1])) for r in nodes))
    assert (out/'O0/receipts.csv').read_bytes()==(out/'O2/receipts.csv').read_bytes()
    for i in range(4):assert (out/('O0/test-'+str(i)+'.stdout')).read_bytes()==(out/('O2/test-'+str(i)+'.stdout')).read_bytes()
    report['status']='ACTUAL_THERMAL_RECEIPTS_O0_O2_AND_EXISTING_EB_RUNTIME_PASS'
    (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:v for k,v in report.items() if k not in ('source_git_blob','builds')},indent=2))


if __name__=='__main__':main()
