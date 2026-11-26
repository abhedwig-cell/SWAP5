"""Prepare exact original source provider and existing-host strict macro workers."""
from pathlib import Path
import sys,os,json,shutil,time,traceback,subprocess
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
os.environ['PYTHONDONTWRITEBYTECODE']='1'
os.environ['PATH']=r'C:\msys64\ucrt64\bin;C:\Program Files\Git\cmd;'+os.environ.get('PATH','')
os.environ.setdefault('PATHEXT','.COM;.EXE;.BAT;.CMD')
sys.path[:0]=[str(ROOT/'app/hybrid_water'),str(ROOT/'tools/vq')]
import daily_host as h
from b0_source_runner import build_gfortran
from coupled_macro_policy import build_bundle,validate_bundle
res=json.loads((R/'RESOURCE_PATHS.json').read_text());ref=Path(res['O2']['path'])/'original-worker-reference'
phase=sys.argv[1];q=dict(phase=phase,checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),status='RUNNING',original_model_executions=0)
t=time.perf_counter()
try:
 if phase=='prepare':
  ref.mkdir(exist_ok=False);dist=ref/'distribution/SWAP_4.3.1';target=dist/'tools/SWAP/source';target.mkdir(parents=True)
  q['archives']={}
  for name,digest in [('SWAP.ZIP',h.DONOR_SOURCE_SHA),('TTUTIL.ZIP',h.TTUTIL_SOURCE_SHA)]:
   p=ROOT/'reference/swap-4.3.1/source-archives'/name;assert h.sha(p)==digest;shutil.copy2(p,target/name);q['archives'][name]=digest
  src=ROOT/'reference/swap-4.3.1/projects/3.macroporeflow';case=dist/'cases/3.macroporeflow';case.parent.mkdir(parents=True);shutil.copytree(src,case)
  q['inputs']={p.relative_to(case).as_posix():h.sha(p) for p in case.rglob('*') if p.is_file()}
  exe,logs=build_gfortran(dist,ref/'build');(ref/'compile.log').write_text(''.join(logs))
  q['compiler']=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0];q['compiler_sha256']=h.sha(Path(shutil.which('gfortran')))
  q['provider_files']={p.relative_to(ref).as_posix():h.sha(p) for folder in ['swap-selected','swap-obj','ttutil-obj'] for p in (ref/'build'/folder).iterdir() if p.is_file()}
  q['status']='ORIGINAL_PROVIDER_READY_NO_MODEL_EXECUTED'
 else:
  opt=phase;assert opt in ['O0','O2'];base=Path(res[opt]['path'])/'worker-base';target=Path(res[opt]['path'])/'worker-coupled'
  h.build(ref,base,budget_retry=True,shared_pond_transfer=True,refresh_macro_final=True,runtime_checkpoint=True,kernel_opt=opt,project=h.ANDELST)
  build_bundle(base,ref,target,owner_optimization=opt)
  meta,case=validate_bundle(target,ref);q['build']=meta;q['status']='STRICT_UNREDUCED_WORKER_BUILT_NOT_EXECUTED';q['optimization_scope']='kernel and changed macro/headcalc/main owners '+opt+'; unchanged original physical pool O2'
except Exception:
 q['status']='FAILED';q['error']=traceback.format_exc()
finally:
 q['seconds']=time.perf_counter()-t;(R/('WORKER_'+phase+'_RESULT.json')).write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({k:q[k] for k in ['phase','status','seconds']}),flush=True)
 if q['status']=='FAILED':print(q['error'],flush=True)
sys.exit(1 if q['status']=='FAILED' else 0)
