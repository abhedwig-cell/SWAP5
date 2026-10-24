"""Preserve original admitted BBC481 physical outputs on current trace ABI."""
import argparse,csv,hashlib,json,os,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];p=argparse.ArgumentParser();p.add_argument('--bundle',type=Path,required=True);p.add_argument('--prior',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir();b=json.loads((a.bundle/'bundle.json').read_text());exe=Path(b['exe']);prior=a.prior.resolve();meta=json.loads((exe.parent/'build-complete.json').read_text());sha=lambda x:hashlib.sha256(x).hexdigest();events=[]
for path,h in meta['input_sha256'].items():assert sha((ROOT/path).read_bytes())==h,path
assert sha(exe.read_bytes())==meta['executable_sha256']
for name,args in [('full',['--stop-after','481']),('split',['--stop-after','365']),('resumed',['--stop-after','481','--restart',str(out/'split')])]:
 cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_column.py'),'--exe',str(exe),'--input',str(prior/'input.nml'),'--swp',str(prior/'input.swp'),'--output',str(out/name),*args];start=time.monotonic();r=subprocess.run(cmd,capture_output=True);(out/(name+'.stdout')).write_bytes(r.stdout);(out/(name+'.stderr')).write_bytes(r.stderr);events.append(dict(command=cmd,returncode=r.returncode,seconds=time.monotonic()-start));(out/'events.json').write_text(json.dumps(events,indent=2));assert r.returncode==0,r.stderr.decode()[-3000:]
for f in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
 assert(out/'full'/f).read_bytes()==(prior/f).read_bytes(),f
 if f!='budget.csv':assert(out/'full'/f).read_bytes()==(out/'resumed'/f).read_bytes(),('restart',f)
read=lambda p:list(csv.DictReader(p.open()));rows=read(out/'full/budget.csv');assert len(rows)==481 and read(out/'resumed/budget.csv')==rows[365:]
for r in rows:assert abs(float(r['water_residual_cm']))<1e-10 and abs(float(r['solute_residual_mg_cm2']))<1e-10
result=dict(status='CURRENT_MACRO_TRACE_ABI_BBC481_EXACT_RESTART365_PASS',days=481,events=events,input_sha256={**meta['input_sha256'],str(Path(__file__).relative_to(ROOT)):sha(Path(__file__).read_bytes())},prior_sha256={f:sha((prior/f).read_bytes())for f in ['input.nml','input.swp','budget.csv','state.csv','endpoint.csv','restart.bin']},build=meta,qualified=False,canonically_admitted=False);(out/'RESULT.json').write_text(json.dumps(result,indent=2));print(result['status'])
