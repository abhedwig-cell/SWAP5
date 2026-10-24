"""Actual day240 disk continuation; accuracy qualification remains separate."""
import csv,json,os,subprocess,time
from pathlib import Path
CASE=Path(os.environ.get('PERF01_HISTORICAL_RESTART_CASE','/tmp/perf01-historical-incumbent-stages-v1/detailed/flux'))
EXE=Path(os.environ.get('PERF01_HISTORICAL_RESTART_EXE','/tmp/perf01-historical-incumbent-v1/project'))
OUT=Path(os.environ.get('PERF01_HISTORICAL_RESTART_OUT','/tmp/perf01-historical-restart-v1'));OUT.mkdir();events=[];previous=None
for part,stop in [('half',240),('resume',481)]:
 folder=OUT/part;folder.mkdir()
 for n in ['input.nml','input.swp']:(folder/n).write_bytes((CASE/n).read_bytes())
 cmd=[str(EXE),'input.nml',str(previous/'restart.bin')if previous else'-',str(stop),'input.swp'];start=time.perf_counter();p=subprocess.run(cmd,cwd=folder,capture_output=True,timeout=120)
 for k in ['stdout','stderr']:(folder/k).write_bytes(getattr(p,k))
 events.append(dict(command=cmd,seconds=time.perf_counter()-start,returncode=p.returncode));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr[-2000:];previous=folder
identity={n:(CASE/n).read_bytes()==(previous/n).read_bytes()for n in ['state.csv','endpoint.csv','restart.bin']};assert all(identity.values())
rows=lambda p:list(csv.DictReader((p/'budget.csv').open()));assert rows(previous)==rows(CASE)[240:]
r=dict(status='ACTUAL_DAY240_RESTART_EXACT',accuracy_qualified=False,full_case=str(CASE),events=events,identity=identity,continued_days=len(rows(previous)))
(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
