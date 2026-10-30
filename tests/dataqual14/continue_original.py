"""Continue a bound original Grassgrowth checkpoint without changing inputs."""
import argparse,csv,hashlib,json,shutil,subprocess,time
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--restart',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--end',type=int,default=365);p.add_argument('--timeout',type=int,default=300);a=p.parse_args()
base=a.bundle.resolve();out=a.output.resolve();out.mkdir();sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest();b=json.loads((base/'BUILD.json').read_text())
assert all(sha(Path(s))==h for s,h in b['source_sha256'].items())
for n,h in b['original_inputs_sha256'].items():
 f=base/'original-interval'/n;assert sha(f)==h;shutil.copyfile(f,out/n)
shutil.copyfile(base/'original-interval/application.binding',out/'application.binding');exe=base/'swap5_grass_startup';assert sha(exe)==b['executable_sha256']
cmd=[str(exe),str(a.end),'retain-step','100000',str(a.restart.resolve())];t=time.monotonic()
with(out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
 try:r=subprocess.run(cmd,cwd=out,stdout=so,stderr=se,timeout=a.timeout);rc=r.returncode
 except subprocess.TimeoutExpired:rc=None
rows=list(csv.DictReader((out/'budget.csv').open()));assert rows and all(abs(float(r['residual_cm']))<1e-10 for r in rows)
report=dict(requested_days=a.end,completed_days=int(rows[-1]['day']),returncode=rc,seconds=time.monotonic()-t,command=cmd,source_sha256=b['source_sha256'],executable_sha256=b['executable_sha256'],restart_input_sha256=sha(a.restart),last_checkpoint_sha256=sha(out/'checkpoint.bin'),maximum_water_residual_cm=max(abs(float(r['residual_cm']))for r in rows),maximum_heat_accounting_residual_j_cm2=max(abs(float(r['heat_residual_j_cm2']))for r in rows),reason=(out/'stdout').read_text().splitlines()[-1])
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({k:report[k]for k in ['requested_days','completed_days','returncode','seconds','reason']}))
