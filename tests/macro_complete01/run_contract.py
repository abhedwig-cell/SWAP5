"""Measured real production closure; immutable logs, no default broad suite."""
from pathlib import Path
import sys,os,json,hashlib,subprocess,time,importlib.util,shutil
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01'
sp=importlib.util.spec_from_file_location('deps',ROOT/'tests/support/augment_bartholomeus_backend_sources.py');dep=importlib.util.module_from_spec(sp);sp.loader.exec_module(dep)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 opt,label,driver=sys.argv[1:4];baseline='--baseline' in sys.argv[4:];res=json.loads((R/'RESOURCE_PATHS.json').read_text());out=Path(res[opt]['path'])/label
 out.mkdir(exist_ok=False)
 stub='tests/fsi/fsi04_real_headcalc_stubs.f90'
 order,_=dep.strict_closure(ROOT,[driver],[stub,driver]);sources=order[:-1]+[ROOT/'src/legacy/b1_10_port/headcalc.f90',order[-1]]
 if baseline:
  p=out/'baseline_headcalc.f90';p.write_bytes(subprocess.check_output(['git','show','9af88c3de6198ddec40c2674dd1542a89fa9c0d7:src/legacy/b1_10_port/headcalc.f90'],cwd=ROOT));sources=[p if s.name=='headcalc.f90' else s for s in sources]
 flags=['-'+opt,'-save-temps=obj','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow'];exe=out/'probe.exe';cc=shutil.which('gfortran');command=[cc,*flags,'-J',str(out),'-I',str(out),*[str(p) for p in sources],'-o',str(exe)]
 q=dict(label=label,opt=opt,driver=driver,baseline=baseline,checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=cc,compiler_sha256=sha(cc),version=subprocess.check_output([cc,'--version'],text=True),source_sha256={str(p):sha(p) for p in sources},command=command)
 (out/'IDENTITY.json').write_text(json.dumps(q,indent=2)+'\n');t=time.perf_counter()
 try:
  p=subprocess.run(command,cwd=out,capture_output=True,timeout=120);q['compile_seconds']=time.perf_counter()-t;q['compile_returncode']=p.returncode
  (out/'compile.stdout').write_bytes(p.stdout);(out/'compile.stderr').write_bytes(p.stderr)
  if p.returncode:
   print(p.stderr.decode(errors='replace')[-4000:]);return
  q['exe_sha256']=sha(exe);t=time.perf_counter()
  q['runs']=[]
  for mode in (['fresh','no-macro','dtmin-refusal'] if 'macro_complete01/test_fresh_coupled' in driver else ['fresh']):
   t=time.perf_counter();p=subprocess.run([str(exe)]+([] if mode=='fresh' else [mode]),cwd=out,capture_output=True,timeout=20)
   q['runs'].append(dict(mode=mode,seconds=time.perf_counter()-t,returncode=p.returncode,stdout_sha256=hashlib.sha256(p.stdout).hexdigest()))
   (out/(mode+'.stdout')).write_bytes(p.stdout);(out/(mode+'.stderr')).write_bytes(p.stderr);print(mode,p.returncode,p.stdout.decode(errors='replace').strip());print(p.stderr.decode(errors='replace')[-300:])
  q['run_seconds']=sum(x['seconds'] for x in q['runs']);q['run_returncode']=max(x['returncode'] for x in q['runs'])
 except subprocess.TimeoutExpired as e:
  q['censored']=True;q['timeout_seconds']=e.timeout
  (out/'timeout.stdout').write_bytes(e.stdout or b'');(out/'timeout.stderr').write_bytes(e.stderr or b'')
 finally:
  (out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n');(R/(opt+'_'+label+'.json')).write_text(json.dumps(q,indent=2)+'\n');print({k:q[k] for k in ['label','opt','compile_seconds','compile_returncode','run_seconds','run_returncode','censored'] if k in q})
if __name__=='__main__':main()
