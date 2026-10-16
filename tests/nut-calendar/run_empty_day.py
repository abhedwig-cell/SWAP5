#!/usr/bin/env python3
"""Fresh discriminating native driver; hash-audited same-session provider build."""
from pathlib import Path
import os,json,subprocess,time,hashlib
ROOT=Path(__file__).resolve().parents[2]
PARENT=Path(os.environ['CALENDAR_PRIMARY_DIR']).resolve();OUT=Path(os.environ['CALENDAR_EMPTY_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=True)
assert not (OUT/'result.json').exists()
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
primary=json.loads((PARENT/'result.json').read_text());events=json.loads((PARENT/'events.json').read_text())
assert primary['status']=='PASS'and primary['mode']=='joint'
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()==primary['source_tree']
for p,h in primary['input_sha256'].items():assert sha(ROOT/p)==h
r={'status':'RUNNING','primary_result_sha256':sha(PARENT/'result.json'),'source_tree':primary['source_tree'],'execution_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'compiler':subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0],'runs':{},'events':[],'input_sha256':{**primary['input_sha256'],str(Path(__file__).relative_to(ROOT)):sha(Path(__file__)),'tests/nut-calendar/test_calendar_empty_day.f90':sha(ROOT/'tests/nut-calendar/test_calendar_empty_day.f90')}}
assert r['compiler']==primary['compiler']
for opt in ['O0','O2']:
 build=PARENT/opt;dest=OUT/opt;dest.mkdir(exist_ok=True)
 artifacts={str(p.relative_to(PARENT)):sha(p)for p in build.iterdir()if p.suffix in ['.o','.mod']}
 original=next(e['command']for e in events if e['category']=='driver_compile'and '-'+opt in e['command']and e['command'][e['command'].index('-c')+1].endswith('/test_calendar_day.f90'))
 flags=original[:original.index('-c')];obj=dest/'test_empty.o';exe=dest/'test_empty'
 objects=[e['command'][e['command'].index('-o')+1]for e in events if e['category']=='compile'and '-'+opt in e['command']]
 for category,args in [('driver_compile',[*flags,'-c',ROOT/'tests/nut-calendar/test_calendar_empty_day.f90','-o',obj]),('link',[*flags,*objects,obj,'-o',exe]),('native',[exe])]:
  args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=dest,capture_output=True)
  for stream in ['stdout','stderr']:(dest/(category+'.'+stream)).write_bytes(getattr(p,stream))
  r['events'].append({'category':category,'command':args,'returncode':p.returncode,'seconds':time.perf_counter()-t,**{stream+'_file':opt+'/'+category+'.'+stream for stream in ['stdout','stderr']},**{stream+'_sha256':hashlib.sha256(getattr(p,stream)).hexdigest()for stream in ['stdout','stderr']}})
  (OUT/'events.json').write_text(json.dumps(r['events'],indent=2)+'\n')
  assert p.returncode==0,p.stderr.decode()
  if category=='native':assert b'CALENDAR_NO_EVENT_ACTUAL_CROP_SOIL_PENDING_EXACT_IDENTITY=PASS'in p.stdout
 assert all(sha(PARENT/p)==h for p,h in artifacts.items())
 r['runs'][opt]={'artifacts_before_and_after':artifacts,'native_results_reused':False}
r['status']='PASS';r['cost_seconds']={c:sum(e['seconds']for e in r['events']if e['category']==c)for c in ['driver_compile','link','native']}
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({'status':r['status'],'cost_seconds':r['cost_seconds']}))
