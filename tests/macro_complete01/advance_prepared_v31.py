"""Advance one fixed V31 candidate over at most three original native days.
Each actual model route retains the existing20s cap. No retries of an existing
failed/censored directory; no source rebinding or input-period changes.
"""
from pathlib import Path
import sys,json,subprocess,os,time
ROOT=Path(__file__).resolve().parents[2];R=ROOT/'integration/macro-complete01';res=json.loads((R/'RESOURCE_PATHS.json').read_text());opt=sys.argv[1];start,end=map(int,sys.argv[2:4]);assert opt in ['O0','O2'] and 29<=start<=end<=min(481,start+2)
b=Path(res[opt]['path']);q=dict(opt=opt,start=start,end=end,status='RUNNING',pid=os.getpid(),routes=[]);record=R/('PERIOD31_'+opt+'_'+str(start)+'_'+str(end)+'.json');assert not record.exists()
def save():record.write_text(json.dumps(q,indent=2)+'\n')
save()
for day in range(start,end+1):
 if (R/'PERIOD31_STOP').exists():q['status']='STOP_FILE';break
 label='PREPARED_V31_DAY'+str(day);out=b/label
 if out.exists():q['status']='EXISTING_ROUTE_NOT_RERUN';break
 previous=b/'PREPARED_V31_OWN27TO28' if day==29 else b/('PREPARED_V31_DAY'+str(day-1))
 origin=previous/('accepted-column-1-day-'+str(day-1)+'.zip');assert origin.is_file()
 args=[sys.executable,'-B',str(ROOT/'tests/macro_complete01/run_worker_window.py'),'--bundle',str(b/'worker-coupled-prepared-publisher-v31'),'--reference',str(Path(res['O2']['path'])/'original-worker-reference'),'--checkpoint',str(origin),'--cut',str(day-1),'--end',str(day),'--output',str(out),'--cap-seconds','20']
 t=time.perf_counter();p=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=45);item=dict(day=day,returncode=p.returncode,wall_seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
 if (out/'RESULT.json').exists():
  r=json.loads((out/'RESULT.json').read_text());item.update(status=r['status'],model_route_seconds=r['elapsed_seconds'])
 q['routes'].append(item);save()
 if p.returncode:q['status']='STOPPED_AT_MODEL_REFUSAL_OR_CAP';break
else:q['status']='COMPLETED_REQUESTED_DAYS'
save();print(json.dumps(dict(opt=opt,status=q['status'],days=[x['day'] for x in q['routes']],last_model_status=q['routes'][-1].get('status') if q['routes'] else None)))
raise SystemExit(0 if q['status']=='COMPLETED_REQUESTED_DAYS' else 2)
