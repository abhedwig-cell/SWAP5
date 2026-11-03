"""Diagnostic predecessor suffix only; never a restart or scientific admission."""
import argparse,hashlib,json,os,re,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True)
p.add_argument('--predecessor',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--end',type=int,default=931);p.add_argument('--timeout',type=int,default=7200)
p.add_argument('--from-start',action='store_true',help='Create state from original inputs instead of importing predecessor state')
a=p.parse_args();base=a.predecessor.resolve();out=a.output.resolve();out.mkdir(exist_ok=False)
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
files=[f for f in base.iterdir() if f.suffix.lower() in ('.swp','.crp','.met','.dra','.nml')]
for f in files:shutil.copyfile(f,out/f.name)
restart=base/'checkpoint-868.bin'
if not a.from_start:assert restart.is_file()
nml=(out/'input.nml').read_text()
ends=[float(v)for v in re.search('^ends_day=(.*)$',nml,re.M)[1].split(',')if v.strip()]
stop=next(i+1 for i,v in enumerate(ends)if v==a.end)
env=os.environ.copy()
if not a.from_start:env['SWAP5_DIAG_PREDECESSOR']='1'
cmd=[str(a.exe.resolve()),'input.nml','-' if a.from_start else str(restart),str(stop),'swap.swp','maize.crp']
record=dict(scope='DIAGNOSTIC_PREDECESSOR_SUFFIX_NOT_QUALIFICATION',command=cmd,
            executable_sha256=sha(a.exe),restart_sha256=None if a.from_start else sha(restart),from_start=a.from_start,
            inputs={f.name:sha(f)for f in files},scientific_admission=False)
(out/'START.json').write_text(json.dumps(record,indent=2))
start=time.monotonic()
with (out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
    try:
        r=subprocess.run(cmd,cwd=out,env=env,stdout=so,stderr=se,timeout=a.timeout)
        record['returncode']=r.returncode
    except subprocess.TimeoutExpired:record['returncode']=None
record['seconds']=time.monotonic()-start
(out/'RESULT.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record))
