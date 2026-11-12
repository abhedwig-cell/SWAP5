"""One bounded original shared-host project trajectory and its own seasonal continuations.

Actual original O2 physics, SWAP5 day transactions at the bundle optimization.
No native thermal-profile or whole-science acceptance is implied.
"""
import argparse,contextlib,hashlib,json,math,subprocess,sys,threading,time,traceback,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True);p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--days',type=int)
p.add_argument('--project',choices=['grass','hupsel'],default='grass')
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();a.bundle=a.bundle.resolve();a.reference=a.reference.resolve()
project=h.GRASSGROWTH if a.project=='grass' else h.HUPSEL
end_day=1827 if a.project=='grass' else 1096
a.days=end_day if a.days is None else a.days
assert a.days==end_day,'Only the original complete period is selected'
windows=[(2,4),(187,190),(365,367),(1792,1827)] if a.project=='grass' else [(2,4),(4,6),(5,7),(120,122),(365,367),(523,526),(583,585),(730,732),(1061,1096)]
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
b=json.loads((a.bundle/'BUILD.json').read_text());identity=b['identity'];binding=b['binding']
assert identity['host']==sha(Path(h.__file__)) and binding['case']==project.case
for key,name in [('adapter','donor_adapter.f90'),('driver','main.f90')]:assert identity[key]==sha(ROOT/'app/hybrid_water'/name)
for name,digest in identity['kernel_sources']:assert sha(ROOT/name)==digest
for name,digest in identity['donor_generated'].items():assert sha(a.bundle/name)==digest
for name,digest in identity['donor_objects'].items():assert sha(a.reference/'build/swap-obj'/name)==digest
assert sha(a.reference/'build/ttutil-obj/libttutil.a')==identity['ttutil_library']
donor=h.executable(a.bundle,'day_donor');kernel=h.executable(a.bundle,'day_kernel')
assert b['executable_sha256']=={'donor':sha(donor),'kernel':sha(kernel)}
case=a.reference/'distribution/SWAP_4.3.1/cases'/project.case
assert all(sha(case/name)==digest for name,digest in b['inputs'].items())
(a.output/'BUILD.json').write_text(json.dumps(b,indent=2)+'\n',encoding='utf-8')
processes=[];real_start=h.start_process

def track(*args):
 proc,log=real_start(*args);processes.append(proc);return proc,log
h.start_process=track
events=[]
@contextlib.contextmanager
def bounded(label,seconds):
 expired=[]
 def stop():
  expired.append(True)
  for proc in processes:
   if proc.poll() is None:proc.kill()
 timer=threading.Timer(seconds,stop);timer.daemon=True;timer.start();start=time.monotonic()
 try:
  yield
  assert not expired,'Selected wall-clock cap exceeded'
  events.append({'case':label,'seconds':time.monotonic()-start,'status':'PASS'})
 except Exception as e:
  events.append({'case':label,'seconds':time.monotonic()-start,'status':'FAILED','error':repr(e),'censored':bool(expired)})
  raise
 finally:
  timer.cancel();(a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n',encoding='utf-8')

def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision')}
def payload(path):
 with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
rows=[];cuts={value for pair in windows for value in pair}|({188} if a.project=='grass' else {584})
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'bundle_build_sha256':sha(a.bundle/'BUILD.json')}
try:
 full=a.output/'full';full.mkdir()
 with bounded(f'full-original{end_day}',60),contextlib.ExitStack() as stack:
  host=h.DailyHost(stack,donor,kernel,case,full,[h.ColumnStart()],runtime=True,checkpoint_enabled=True,binding=binding,project=project)
  with (full/'daily.jsonl').open('w',encoding='utf-8') as receipts:
   for day in range(1,a.days+1):
    r=host.step(1,checkpoint=day in cuts);receipts.write(json.dumps(r)+'\n');receipts.flush()
    assert r['committed'],r
    assert r['day']==day and r['revision']==day and len(r['pressure_head_cm'])==project.nodes
    assert abs(r['independent_residual_cm'])<=project.water_tolerance and abs(r['kernel_residual_cm'])<=project.water_tolerance
    rows.append(r)
    if day%100==0:print('ACCEPTED',day,flush=True)
  host.close()
 assert len(rows)==end_day
 (full/'RESULT.json').write_text(json.dumps({'status':f'FULL_ORIGINAL{end_day}_WATER_PASS','days':len(rows)})+'\n')
 restarts=[]
 for cut,end in windows:
  source=full/f'accepted-column-1-day-{cut}.zip';prior=sha(source)
  origin=a.output/f'origin-{cut}';receipt=h.verify_checkpoint(source,cut,binding,origin)
  out=a.output/f'own-{cut}-to-{end}';out.mkdir()
  with bounded(f'own-{cut}-to-{end}',60):
   result=h.run(donor,kernel,case,out,end,checkpoint_day=cut,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,checkpoint_binding=binding,project=project)
   assert result['first_refusal'] is None,result
  resumed=[json.loads(line) for line in (out/'daily.jsonl').read_text().splitlines()]
  assert list(map(physical,resumed))==list(map(physical,rows[cut:end])),f'Physical suffix {cut}'
  assert payload(out/f'accepted-column-1-day-{end}.zip')==payload(full/f'accepted-column-1-day-{end}.zip'),f'Complete payload {cut}'
  assert sha(source)==prior,'Accepted origin mutated'
  restarts.append({'cut':cut,'end':end,'exact_physical_suffix':True,'exact_native_and_auxiliary_payload':True,'origin_sha256':prior})
 report.update(status=f'FULL_ORIGINAL{end_day}_AND_OWN_SEASONAL_RESTARTS_PASS',days=len(rows),maximum_daily_water_residual_cm=max(abs(r['independent_residual_cm']) for r in rows),signed_cumulative_daily_residual_cm=math.fsum(r['independent_residual_cm'] for r in rows),day188=rows[187],restarts=restarts,scope='Original legacy heat/water trajectory controlled by SWAP5 day transactions. Not native1e-5C, complete energy or whole science.')
 if a.project=='hupsel':
  report.update(day584=rows[583],maximum_daily_solute_residual_mg_cm2=max(abs(r['solute_independent_residual_mg_cm2']) for r in rows),signed_cumulative_daily_solute_residual_mg_cm2=math.fsum(r['solute_independent_residual_mg_cm2'] for r in rows))
except Exception:
 report.update(status='FAILED',accepted_days=len(rows),traceback=traceback.format_exc())
 raise
finally:
 report['events']=events
 (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 print(json.dumps({k:report[k] for k in ('status',) if k in report}),flush=True)
