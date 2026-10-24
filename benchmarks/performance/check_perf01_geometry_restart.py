"""Exact day48 continuation and total evaporation of research Boesten/Picard."""
import csv,json,os,subprocess,time
from pathlib import Path
root=Path(os.environ.get('PERF01_RESTART_ROOT','/tmp/perf01-combined-screen-v7'));r=json.loads((root/'RESULT.json').read_text());checks={}
for name in r['cases']:
 case=root/name;full=case/'flux';previous=None;events=[]
 for part,stop in [('half',48),('resume',97)]:
  folder=case/part;folder.mkdir()
  for n in ['input.nml','input.swp']:(folder/n).write_bytes((full/n).read_bytes())
  cmd=[str(root/'project'),'input.nml',str(previous/'restart.bin')if previous else'-',str(stop),'input.swp'];start=time.perf_counter();p=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=60)
  for k in ['stdout','stderr']:(folder/k).write_bytes(getattr(p,k))
  events.append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=p.returncode));assert p.returncode==0,p.stderr.decode();previous=folder
 for n in ['state.csv','endpoint.csv','restart.bin']:assert(full/n).read_bytes()==(previous/n).read_bytes(),(name,n)
 rows=lambda d:list(csv.DictReader((d/'budget.csv').open()));f=rows(full);head=rows(case/'head');assert rows(previous)==f[48:]
 evaporation=[10*((float(a['soil_evaporation_cm'])+float(a['pond_evaporation_cm']))-(float(b['soil_evaporation_cm'])+float(b['pond_evaporation_cm'])))for a,b in zip(head,f)]
 assert max(map(abs,evaporation))<.01
 checks[name]=dict(events=events,restart_exact=True,max_total_evaporation_difference_mm=max(map(abs,evaporation)))
(root/'RESTART_CHECK.json').write_text(json.dumps(checks,indent=2)+'\n');print(json.dumps(checks,indent=2))
