"""Compare corrected and literal predecessor accounting in current EB runtime tests.

Build the unchanged current runtime once per optimization. Only the accounting
object is exchanged between the two executables; every production contract test
is executed afresh. Existing test failures remain failures, even when identical.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/support'))
from augment_bartholomeus_backend_sources import strict_closure
MODULE='src/process/mod_whole_column_sensible_energy_accounting.f90'
DRIVERS=[
 'tests/eb/test_eb_i22_whole_column_sensible_energy_accounting.f90',
 'tests/eb/test_eb_i23_sensible_boundary_runtime_materialization.f90',
 'tests/eb/test_eb_i24_top_liquid_sensible_inflow_runtime.f90',
 'tests/eb/test_eb_i25_multisubstep_sensible_boundary_runtime.f90',
]
STUB='tests/fsi/fsi04_real_headcalc_stubs.f90'


def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--output',type=Path,required=True)
 p.add_argument('--compiler',type=Path,default=Path('/usr/bin/x86_64-linux-gnu-gfortran-13'))
 a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 sha=lambda raw:hashlib.sha256(raw).hexdigest()
 targets=DRIVERS+['src/legacy/b1_10_port/headcalc.f90']
 order,_=strict_closure(ROOT,targets,extra_sources=[STUB,*DRIVERS])
 providers=[x for x in order if str(x.relative_to(ROOT)) not in DRIVERS]
 source_sha={str(x.relative_to(ROOT)):sha(x.read_bytes()) for x in order}
 assert not subprocess.check_output(['git','diff','HEAD','--',*source_sha],cwd=ROOT),'persist tested source first'
 predecessor=json.loads((ROOT/'integration/dataqual15/STOCK_PROJECTION_CANDIDATE_RESULT_20261102.json').read_text())['original_module_git_blob']
 original=out/'predecessor.f90';original.write_bytes(subprocess.check_output(['git','cat-file','blob',predecessor],cwd=ROOT))
 report=dict(scope='CURRENT_RUNTIME_CORRECTED_VERSUS_ONE_OBJECT_PREDECESSOR',
   measurement_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
   predecessor_module_git_blob=predecessor,source_sha256=source_sha,
   compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0],
   provider_count=len(providers),events=[],results={},full_energy_qualified=False)
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,folder,label,timeout=120):
  i=len(report['events']);t=time.monotonic()
  r=subprocess.run(list(map(str,cmd)),cwd=folder,capture_output=True,timeout=timeout)
  (out/f'{i}.stdout').write_bytes(r.stdout);(out/f'{i}.stderr').write_bytes(r.stderr)
  report['events'].append(dict(command=list(map(str,cmd)),label=label,returncode=r.returncode,seconds=time.monotonic()-t))
  save();return r
 for opt in ['O0','O2']:
  d=out/opt;d.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(d),'-J'+str(d)]
  objects=[]
  for i,source in enumerate(providers):
   obj=d/f'{i}.o';r=run([a.compiler,*flags,'-c',source,'-o',obj],d,'compile')
   assert r.returncode==0,r.stderr.decode();objects.append(obj)
  alternate=d/'predecessor.o'
  r=run([a.compiler,*flags,'-c',original,'-o',alternate],d,'compile_predecessor');assert r.returncode==0,r.stderr
  idx=providers.index(ROOT/MODULE)
  for test in DRIVERS:
   name=Path(test).stem;obs={}
   for variant in ['corrected','predecessor']:
    selected=objects.copy()
    if variant=='predecessor':selected[idx]=alternate
    exe=d/(name+'-'+variant)
    r=run([a.compiler,*flags,ROOT/test,*selected,'-o',exe],d,'link');assert r.returncode==0,r.stderr.decode()
    r=run([exe],d,'native_'+name+'_'+variant)
    obs[variant]=dict(returncode=r.returncode,stdout_sha256=sha(r.stdout),stderr_sha256=sha(r.stderr))
    (d/(name+'-'+variant+'.stdout')).write_bytes(r.stdout)
    (d/(name+'-'+variant+'.stderr')).write_bytes(r.stderr)
   # A compiler backtrace includes the executable address, which is not a
   # physical assertion. Compare actual ERROR STOP reasons and all stdout.
   failure=lambda variant:[s for s in (d/(name+'-'+variant+'.stderr')).read_text().splitlines() if s.startswith('ERROR STOP')]
   obs['same_exit_and_stdout']=obs['corrected']['returncode']==obs['predecessor']['returncode'] and obs['corrected']['stdout_sha256']==obs['predecessor']['stdout_sha256']
   obs['same_error_stop_reason']=failure('corrected')==failure('predecessor')
   assert obs['same_exit_and_stdout'] and obs['same_error_stop_reason'],(opt,test,obs)
   obs['qualification']='PASS' if obs['corrected']['returncode']==0 else 'FAIL_RETAINED_IDENTICAL_PREDECESSOR'
   report['results'][opt+'/'+name]=obs;save()
 assert all(sha((ROOT/s).read_bytes())==pin for s,pin in source_sha.items())
 report['status']='ONE_OBJECT_RUNTIME_PRESERVATION_MEASURED_FAILURES_RETAINED';save()
 print(json.dumps(dict(status=report['status'],provider_count=len(providers),results=report['results']),indent=2))

if __name__=='__main__':main()
