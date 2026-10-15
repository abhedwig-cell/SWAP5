"""Resume this live measured build after a driver-only correction.

Explicit same-session recovery, not a persistent cache. The caller names the
frozen provider commit; all provider inputs must still have those Git bytes.
Reuse is labelled per event and all reused artifacts and raw events are retained.
New/changed driver commands and every O2 command execute normally.
"""
from pathlib import Path
import hashlib,json,os,subprocess,sys,time,shutil
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ['N_THERMAL_COMPOSITION_DIR']).resolve()
PREVIOUS=Path(os.environ['N_THERMAL_REUSE_DIR']).resolve()
PIN=os.environ['N_THERMAL_REUSE_COMMIT']
assert subprocess.check_output(['git','diff',PIN,'--','src'],cwd=ROOT)==b''
prior_events=json.loads((PREVIOUS/'events.json').read_text())
old_generation=json.loads((PREVIOUS/'GENERATION.json').read_text())
assert hashlib.sha256((PREVIOUS/'executed_runner.py').read_bytes()).hexdigest()==old_generation['runner_sha256']
artifacts={}
for p in (PREVIOUS/'O0').iterdir():
 if p.suffix in ['.o','.mod','.bin']or p.name.endswith('.opaque')or p.name in ['test_calendar','test_calendar_day','test_calendar_joint']:
  q=OUT/'O0'/p.name;shutil.copyfile(p,q);artifacts[str(q.relative_to(OUT))]=hashlib.sha256(q.read_bytes()).hexdigest()
providers={}
for e in prior_events:
 if e['category']=='compile'and e['returncode']==0:
  p=Path(e['command'][e['command'].index('-c')+1])
  if p.is_relative_to(ROOT):
   relative=str(p.relative_to(ROOT));expected=subprocess.check_output(['git','show',PIN+':'+relative],cwd=ROOT)
   assert p.read_bytes()==expected;providers[relative]=hashlib.sha256(expected).hexdigest()
receipt=dict(provider_commit=PIN,providers=providers,previous_directory=str(PREVIOUS),previous_events_sha256=hashlib.sha256((PREVIOUS/'events.json').read_bytes()).hexdigest(),artifacts=artifacts)
(OUT/'REUSE.json').write_text(json.dumps(receipt,indent=2)+'\n')
runner=(OUT/'executed_runner.py').read_text()
inject='''
original_run=run
def run(args,cwd,category):
 args=list(map(str,args))
 # The new driver must always compile/link/execute after its correction.
 eligible=('/O0/' in ' '.join(args) and not any(Path(a).name.startswith('test_thermal_joint') for a in args))
 if eligible:
  for index,e in enumerate(prior_events):
   normalized=[a.replace(str(PREVIOUS),str(OUT)) for a in e['command']]
   if e['returncode']!=0 or normalized!=args or e['category']!=category:continue
   begin=time.perf_counter()
   if category in ['compile','driver_compile']:
    p=Path(args[args.index('-c')+1]);previous=Path(e['command'][e['command'].index('-c')+1])
    if p.read_bytes()!=previous.read_bytes():continue
   for p,h in receipt['artifacts'].items():
    assert hashlib.sha256((OUT/p).read_bytes()).hexdigest()==h,'reused artifact changed'
   i=len(events);entry=dict(e);entry.update(command=args,seconds=0.0,reused_from_event=index,reuse_validation_seconds=time.perf_counter()-begin)
   for stream in ['stdout','stderr']:
    raw=(PREVIOUS/e[stream+'_file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==e[stream+'_sha256']
    name=f'{i:04d}.{stream}';(OUT/name).write_bytes(raw);entry[stream+'_file']=name
   events.append(entry);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\\n')
   return (PREVIOUS/e['stdout_file']).read_text()
 return original_run(args,cwd,category)
'''
needle="archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'"
assert runner.count(needle)==1;runner=runner.replace(needle,inject+'\n'+needle)
(OUT/'resumed_runner.py').write_text(runner)
os.environ['CALENDAR_RESULT_DIR']=str(OUT);sys.argv=[__file__,'joint']
exec(compile(runner,str(OUT/'resumed_runner.py'),'exec'),globals())
