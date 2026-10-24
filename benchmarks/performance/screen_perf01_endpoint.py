"""Real Boesten endpoint reset plus output-amount research; no production edits."""
import csv,json,os,subprocess,time
from pathlib import Path
OUT=Path(os.environ.get('PERF01_ENDPOINT_OUT','/tmp/perf01-endpoint-check-v1'));OUT.mkdir();BASE=Path('/tmp/perf01-historical-endpoint-v1');events=[]
def run(cmd,cwd,label,cap):
 start=time.perf_counter()
 try:p=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=cap);code=p.returncode;out=p.stdout;err=p.stderr
 except subprocess.TimeoutExpired as e:code='TIMEOUT';out=e.stdout or b'';err=e.stderr or b''
 (OUT/(label+'.stdout')).write_bytes(out);(OUT/(label+'.stderr')).write_bytes(err);events.append(dict(label=label,command=cmd,returncode=code,seconds=time.perf_counter()-start));save();return code
def save():(OUT/'RESULT.json').write_text(json.dumps(dict(status='RESEARCH_ENDPOINT_CHECK',production_qualified=False,events=events),indent=2)+'\n')
cmd=next(e['command']for e in json.loads((BASE/'RESULT.json').read_text())['events']if e['label']=='project-build');cmd=[str(OUT/'project')if x==str(BASE/'project')else '/tmp/perf01-output-amount-v1/metric.o'if x=='/tmp/perf01-historical-current-O2/shared/0007.o'else '-J'+str(OUT)if x.startswith('-J')else x for x in cmd];assert run(cmd,OUT,'link',30)==0
phases=[('full481',481,'-',120)]if os.environ.get('PERF01_ENDPOINT_ONLY_FULL')=='1'else[('replay146',146,'/tmp/perf01-historical-4x-v1/head-stop145/restart.bin',20),('full481',481,'-',120)]
for phase,stop,restart,cap in phases:
 for arm in ['head','flux']:
  d=OUT/(phase+'-'+arm);d.mkdir()
  for n in ['input.nml','input.swp']:(d/n).write_bytes((Path(os.environ.get('PERF01_ENDPOINT_SOURCE','/tmp/perf01-historical-4x-v1'))/arm/n).read_bytes())
  exe=str(BASE/'project')if arm=='head'else str(OUT/'project');code=run([exe,'input.nml',restart,str(stop),'input.swp'],d,phase+'-'+arm,cap)
  if code==0:
   rows=list(csv.DictReader((d/'budget.csv').open()));events[-1]['published_days']=len(rows);events[-1]['max_water_residual_cm']=max(abs(float(v['water_residual_cm']))for v in rows);assert events[-1]['max_water_residual_cm']<1e-10;save()
  if phase=='replay146':assert code==0,'replay must pass before full selection'
print(json.dumps(events[-4:],indent=2))
