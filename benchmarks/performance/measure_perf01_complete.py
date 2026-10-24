"""Same-input paired complete project and native timing, admitted policy only."""
import csv,hashlib,importlib.util,json,os,statistics,subprocess,sys,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path('/tmp/perf01-complete-measure');OUT.mkdir()
BUNDLE=Path('/tmp/perf01-complete-O2');bundle=json.loads((BUNDLE/'bundle.json').read_text())
sys.path.insert(0,str(ROOT/'tools/solute'))
import run_project
sha=lambda b:hashlib.sha256(b).hexdigest()
r=dict(status='RUNNING',checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),events=[],cases={},changed_accuracy=True)
def save():(OUT/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n')
def execute(cmd,cwd,label):
 start=time.perf_counter();cp=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=60)
 n=len(r['events'])
 for s in ['stdout','stderr']:(OUT/(str(n)+'.'+s)).write_bytes(getattr(cp,s))
 e=dict(label=label,command=list(map(str,cmd)),seconds=time.perf_counter()-start,returncode=cp.returncode)
 r['events'].append(e);save();assert cp.returncode==0,cp.stderr.decode();return e['seconds']
with tarfile.open(ROOT/'benchmarks/performance/PERF01_NATIVE_431_WEATHER_20261023_EVIDENCE.tar.xz')as t:
 for rain in [1,4]:
  folder=OUT/(str(rain)+'x-input');folder.mkdir();prefix='raw/perf01-native-fixed-study/'+str(rain)+'x-input/'
  for name in ['swap.swp','crop.crp','weather.999']:(folder/name).write_bytes(t.extractfile(prefix+name).read())
  r['cases'][str(rain)]=dict(inputs={p.name:sha(p.read_bytes())for p in folder.iterdir()},samples=[])
for rain in [1,4]:
 row=r['cases'][str(rain)];swp=OUT/(str(rain)+'x-input/swap.swp')
 for repeat in range(3):
  for arm,typed in [('head',False),('flux',True)]:
   label=f'{rain}x-{arm}-{repeat}';native=OUT/(label+'-native');native.mkdir()
   start=time.perf_counter();doc,snapshot,audit,exe=run_project.prepare(bundle,swp,.001,surface_exfiltration='historical_zero',retain_step_proposal=True,water_flux_temporal=typed)
   prep=time.perf_counter()-start;(native/'input.nml').write_text(doc);(native/'input.swp').write_bytes(snapshot)
   seconds=execute([exe,'input.nml','-','97','input.swp'],native,label+'-native')
   target=OUT/(label+'-complete');cmd=[sys.executable,'-B',ROOT/'tools/solute/run_project.py',swp,'--bundle',BUNDLE,'--output',target,'--temporal-tolerance','.001','--surface-exfiltration','historical_zero','--retain-step-proposal']
   if typed:cmd+=['--water-flux-temporal']
   total=execute(cmd,ROOT,label+'-complete')
   for name in ['budget.csv','state.csv','endpoint.csv']:assert(native/name).read_bytes()==(target/name).read_bytes(),(label,name)
   rows=list(csv.DictReader((target/'budget.csv').open()));assert len(rows)==97
   assert max(abs(float(d['water_residual_cm']))for d in rows)<1e-10
   row['samples'].append(dict(arm=arm,repeat=repeat,prepare=prep,native=seconds,complete=total,physical_sha256={n:sha((target/n).read_bytes())for n in ['budget.csv','state.csv','endpoint.csv']}));save()
 for arm in ['head','flux']:
  samples=[s for s in row['samples']if s['arm']==arm];assert all(s['physical_sha256']==samples[0]['physical_sha256']for s in samples)
 row['medians']={arm:{key:statistics.median(s[key]for s in row['samples']if s['arm']==arm)for key in ['prepare','native','complete']}for arm in ['head','flux']}
 reference=list(csv.DictReader((OUT/f'{rain}x-head-0-complete/budget.csv').open()));current=list(csv.DictReader((OUT/f'{rain}x-flux-0-complete/budget.csv').open()))
 row['max_daily_difference_mm']={k:10*max(abs(float(a[k])-float(b[k]))for a,b in zip(reference,current))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm']}
 assert row['max_daily_difference_mm']['runoff_cm']<.01 and row['max_daily_difference_mm']['water_end_cm']<.01 and row['max_daily_difference_mm']['actual_transpiration_cm']<1e-8
r['build_input_sha256']=json.loads((BUNDLE/'column/build-complete.json').read_text())['input_sha256']
assert all(sha((ROOT/p).read_bytes())==h for p,h in r['build_input_sha256'].items())
r['status']='PAIRED_COMPLETE_AND_NATIVE_97_DAY_PASS';save();print(json.dumps({k:v['medians']for k,v in r['cases'].items()},indent=2))
