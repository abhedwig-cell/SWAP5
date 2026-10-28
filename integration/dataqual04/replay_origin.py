"""Same authentic origin-state diagnostic; never retag or qualify new histories."""
import argparse,hashlib,json,os,re,runpy,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--diagnostic',action='store_true');p.add_argument('--timeout',type=float,default=60);p.add_argument('--solver-max-iterations',type=int,choices=[64,128,256],default=64);a=p.parse_args();out=a.output.resolve();out.mkdir()
f=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual03_current.py'))['capsule']();r=json.loads(f['RECOVERY.json'])
for name,source in r['prepared_inputs'].items():(out/('origin.bin'if name=='restart.bin'else name)).write_bytes(f[source])
if a.solver_max_iterations!=64:
 path=out/'input.nml';doc,count=re.subn(r'(&column\b)',lambda m:m[0]+'\n solver_max_iterations='+str(a.solver_max_iterations)+',',path.read_text(),count=1,flags=re.I);assert count==1;path.write_text(doc)
origin=(out/'origin.bin').read_bytes();cmd=[str(a.exe.resolve()),*r['command'][1:]];env=dict(os.environ);env.pop('SWAP5_DIAG_MACRO_TEMPORAL',None)
if a.diagnostic:env['SWAP5_DIAG_MACRO_TEMPORAL']='1'
start=time.monotonic();censored=False;code=None
with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
 try:code=subprocess.run(cmd,cwd=out,env=env,stdout=so,stderr=se,timeout=a.timeout).returncode
 except subprocess.TimeoutExpired:censored=True
assert (out/'origin.bin').read_bytes()==origin
rollback=(out/'diagnostic-rejected.bin').exists()and(out/'diagnostic-rejected.bin').read_bytes()==origin
result=dict(command=cmd,seconds=time.monotonic()-start,returncode=code,censored=censored,origin_state_only=True,new_restart_qualified=False,solver_max_iterations=a.solver_max_iterations,authentic_origin_binding=r['command'][6],rollback_exact=rollback,executable_sha256=sha(a.exe.read_bytes()),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256={p.name:sha(p.read_bytes())for p in out.iterdir()if p.is_file()})
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
