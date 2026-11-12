"""Bounded exact same-platform RC1/successor public-route qualification."""
import argparse,hashlib,json,subprocess,sys,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--baseline-root',type=Path,required=True);p.add_argument('--baseline-reference',type=Path,required=True)
p.add_argument('--reference',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--baseline-bundles',type=Path)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();events=[];reports=[]
bundles=json.loads(a.baseline_bundles.read_text()) if a.baseline_bundles else {}
def call(label,root,args):
 command=[sys.executable,'-B','tools/solute/run_water.py',*map(str,args)];t=time.perf_counter()
 result=subprocess.run(command,cwd=root,capture_output=True,text=True,timeout=120)
 (a.output/(label+'.log')).write_text(result.stdout+result.stderr)
 events.append(dict(label=label,command=command,root=str(root),seconds=time.perf_counter()-t,returncode=result.returncode))
 (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 assert result.returncode==0,(label,result.stdout,result.stderr)
 print(label,round(events[-1]['seconds'],3),'seconds',flush=True)
def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision')}
def rows(path):return [physical(json.loads(s)) for s in (path/'daily.jsonl').read_text().splitlines()]
def payload(path):
 with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}
def csv(path):return [s for s in (path/'original/result_output.csv').read_text().splitlines() if s.strip() and not s.startswith('*')]
for name,model,last,cut in [('grass','HYBRID_GRASSGROWTH_WATER',1827,365),('hupsel','HYBRID_HUPSEL_WATER',1096,365),('saltfarm','HYBRID_SALTFARM_WATER',1461,109)]:
 for opt in ('O0','O2'):
  label=name+'-'+opt;end=4 if opt=='O0' else last;origin_day=2 if opt=='O0' else cut
  base=['--no-macro-release','--model',model,'--reference-work',a.baseline_reference.resolve()]
  new=['--no-macro-release','--model',model,'--reference-work',a.reference.resolve()]
  before=Path(bundles[label]) if label in bundles else a.output/(label+'-baseline-build')
  after=a.output/(label+'-candidate-build')
  if label not in bundles:call(label+'-baseline-build',a.baseline_root,base+['--build-only','--kernel-opt',opt,'--output',before])
  call(label+'-candidate-build',ROOT,new+['--build-only','--kernel-opt',opt,'--output',after])
  full=a.output/(label+'-baseline-full');candidate=a.output/(label+'-candidate-full');resume=a.output/(label+'-own-resume')
  call(label+'-baseline-full',a.baseline_root,base+['--build-bundle',before,'--output',full,'--days',end,'--checkpoint-at',end])
  call(label+'-candidate-full',ROOT,new+['--build-bundle',after,'--output',candidate,'--days',end,'--checkpoint-at',origin_day])
  saved=candidate/f'accepted-column-1-day-{origin_day}.zip';old=hashlib.sha256(saved.read_bytes()).hexdigest()
  call(label+'-own-resume',ROOT,new+['--build-bundle',after,'--output',resume,'--restart',saved,'--restart-day',origin_day,'--days',end,'--checkpoint-at',end])
  f,n,r=rows(full),rows(candidate),rows(resume)
  assert len(f)==len(n)==end and len(r)==end-origin_day
  assert f==n and r==f[origin_day:]
  assert payload(resume/f'accepted-column-1-day-{end}.zip')==payload(full/f'accepted-column-1-day-{end}.zip')
  assert csv(full)==csv(candidate) and csv(resume)[-len(r):]==csv(full)[-len(r):]
  assert hashlib.sha256(saved.read_bytes()).hexdigest()==old
  for row in n+r:
   assert row['committed'] and abs(row['independent_residual_cm'])<=1e-10 and abs(row.get('solute_independent_residual_mg_cm2',0))<=1e-10
  b=json.loads((full/'RESULT.json').read_text());c=json.loads((candidate/'RESULT.json').read_text())
  before_wall=next(e['seconds'] for e in events if e['label']==label+'-baseline-full');after_wall=next(e['seconds'] for e in events if e['label']==label+'-candidate-full')
  item=dict(project=name,opt=opt,days=end,cut=origin_day,exact_all_physical=True,exact_all_printed_csv=True,exact_own_native_auxiliary=True,origin_unchanged=True,
   baseline_wall_seconds=before_wall,candidate_wall_seconds=after_wall,baseline_model_seconds=b['model_and_controller_seconds'],candidate_model_seconds=c['model_and_controller_seconds'],
   baseline_nonmodel_overhead_seconds=before_wall-b['model_and_controller_seconds'],candidate_nonmodel_overhead_seconds=after_wall-c['model_and_controller_seconds'],
   maximum_water_cm=max(abs(x['independent_residual_cm']) for x in n),maximum_solute_mg_cm2=max(abs(x.get('solute_independent_residual_mg_cm2',0)) for x in n))
  reports.append(item);(a.output/'PROFILES.json').write_text(json.dumps(reports,indent=2)+'\n');print(json.dumps(item),flush=True)
(a.output/'RESULT.json').write_text(json.dumps(dict(status='RC1_PERF_EXACT_PUBLIC_ROUTE_PASS',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),profiles=reports,events=events),indent=2)+'\n')
