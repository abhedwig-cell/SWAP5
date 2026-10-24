"""Observe real rain-segment work counters; require unchanged physical bytes."""
import csv,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];BUILD=Path(os.environ.get('PERF01_WORK_BUILD','/tmp/perf01-historical-current-v2'));CASE=Path(os.environ.get('PERF01_WORK_CASE','/tmp/perf01-historical-stages-v4/detailed/flux'));OUT=Path(os.environ.get('PERF01_WORK_OUT','/tmp/perf01-historical-work-v1'));OUT.mkdir()
r=json.loads((BUILD/'RESULT.json').read_text());link=next(e['command']for e in r['events']if e['label']=='project-build')
source=(BUILD/'main.f90').read_text();needle='      if(part%status/=JOINT_OK)then'
fields=['attempts','solver_rejections','temporal_rejections','mass_rejections','headcalc_calls','nonlinear_iterations','linear_solves','accepted_substeps']
statement="      write(*,*)'PERF01_SEGMENT_WORK',j,cursor,endpoint,"+', &\n        '.join('part%diagnostics%'+k for k in fields)+'\n'
assert source.count(needle)==1;main=OUT/'main.f90';main.write_text(source.replace(needle,statement+needle))
cmd=[str(main)if x==str(BUILD/'main.f90')else str(OUT/'project')if x==str(BUILD/'project')else '-J'+str(OUT)if x.startswith('-J')else x for x in link]
events=[]
def run(cmd,cwd,label):
 start=time.perf_counter();p=subprocess.run(cmd,cwd=cwd,capture_output=True,timeout=120)
 for k in ['stdout','stderr']:(OUT/(label+'.'+k)).write_bytes(getattr(p,k))
 events.append(dict(command=cmd,returncode=p.returncode,seconds=time.perf_counter()-start));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert p.returncode==0,p.stderr[-2000:]
 return p
run(cmd,OUT,'build')
for n in ['input.nml','input.swp']:(OUT/n).write_bytes((CASE/n).read_bytes())
p=run([str(OUT/'project'),'input.nml','-','481','input.swp'],OUT,'native')
assert all((OUT/n).read_bytes()==(CASE/n).read_bytes()for n in ['budget.csv','state.csv','endpoint.csv','restart.bin'])
rows=[]
for line in p.stdout.decode().splitlines():
 if 'PERF01_SEGMENT_WORK'not in line:continue
 parts=line.split();assert len(parts)==4+len(fields)
 rows.append(dict(day=int(parts[1]),t0=float(parts[2]),t1=float(parts[3]),**dict(zip(fields,map(int,parts[4:])))))
assert rows and rows[0]['t0']==0 and rows[-1]['t1']==481
with(OUT/'segment-work.csv').open('w')as f:
 writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
result=dict(status='OBSERVATIONAL_COUNTERS_PHYSICAL_BYTES_EXACT',source_build=str(BUILD),source_case=str(CASE),events=events,segments=len(rows),totals={k:sum(v[k]for v in rows)for k in fields})
result['top_days_by_headcalc']=sorted([dict(day=day,**{k:sum(v[k]for v in rows if v['day']==day)for k in fields})for day in range(1,482)],key=lambda v:v['headcalc_calls'],reverse=True)[:12]
(OUT/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
