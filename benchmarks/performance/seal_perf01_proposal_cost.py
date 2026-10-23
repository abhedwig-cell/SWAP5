"""Seal and independently replay bounded proposal-cost research evidence."""
import argparse,copy,csv,hashlib,io,json,statistics,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_PROPOSAL_COST_20261024'
STATUS=PREFIX+'_STATUS.json'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda b:hashlib.sha256(b).hexdigest()
def archive(raw):
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms})
  assert all(m.isfile()and not Path(m.name).is_absolute()and'..'not in Path(m.name).parts for m in ms)
  f={m.name:t.extractfile(m).read()for m in ms}
 assert json.loads(f.pop('MANIFEST.json'))=={p:sha(b)for p,b in f.items()}
 return f
def validate(f):
 def js(p):return json.loads(f[p])
 def rows(p):return list(csv.DictReader(io.StringIO(f[p].decode())))
 predecessor=json.loads((ROOT/'benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_STATUS.json').read_bytes())
 prior_raw=(ROOT/predecessor['evidence']['path']).read_bytes();assert sha(prior_raw)==predecessor['evidence']['sha256']
 prior=archive(prior_raw)
 measured={}
 for opt in ['O0','O2']:
  base=f'profile-{opt}/';r=js(base+'RESULT.json')
  assert r['status']=='CURRENT_NATIVE_OFF_ON_PROFILE_PHYSICAL_BYTES_EXACT'
  assert r['script_sha256']==sha(f['sources/profile_perf01_proposal_cost.py'])
  for p,h in r['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('profile source',p)
  assert len(r['runs'])==(24 if opt=='O2'else 8)
  assert all(e['returncode']==0 for e in r['events'])
  for run in r['runs']:
   label=f"{run['rain']}x-{run['arm']}-{run['repeat']}-{run['kind']}"
   assert run['seconds']==next(e['seconds']for e in r['events']if e['label']==label)
   expected=f"qualified/{opt}-{run['rain']}x-{run['arm']}-0/"
   for n in FILES:
    raw=f[base+label+'/'+n]
    assert raw==prior[expected+n]and sha(raw)==run['output_sha256'][n],('profile physics',base,label,n)
   if run['kind']=='profile':
    assert rows(base+label+'/profile.csv')==run['timers']
    actual=[l.split()for l in f[base+label+'/regimes.txt'].decode().splitlines()]
    assert len(actual)==5
    for k,g in enumerate(run['regimes']):
     assert int(actual[k][0])==g['regime']==k+1
     assert float(actual[k][1])==g['seconds']and float(actual[k][2])==g['rejected_seconds']
     assert list(map(int,actual[k][3:]))==g['counts']and len(g['counts'])==12 and g['counts'][5]==0
    assert sum(g['counts'][7]for g in run['regimes'])==int(run['timers'][3]['calls'])
    if run['arm']=='off':
     count=run['regimes'][0]['counts']
     assert [count[i]for i in [0,3,4,7,9]]==([37371,1352,31041,109826,35142]if run['rain']==1 else[32702,1597,27528,95709,25640])
  for rain in [1,4]:
   for arm in ['off','on']:
    c=r['cases'][f'{rain}x-{arm}'];s=[v for v in r['runs']if v['rain']==rain and v['arm']==arm]
    assert c['native_seconds']==statistics.median(v['seconds']for v in s if v['kind']=='ordinary')
    p=[v for v in s if v['kind']=='profile']
    assert c['profile_seconds']==statistics.median(v['seconds']for v in p)
    for key,idx in [('headcalc_seconds',4),('rejected_seconds',5),('output_serialization_seconds',6),('input_setup_seconds',10)]:
     assert c[key]==statistics.median(float(v['timers'][idx-1]['seconds'])for v in p)
  measured[opt]=r['cases']
 for study,script in [('fixed-cap','cap_initial.py'),('recovery','recovery_initial.py'),('bounded-recovery','probe_perf01_solver_cap.py')]:
  prefix=study+'/';r=js(prefix+'RESULT.json')
  assert r['script_sha256']==sha(f['sources/'+script])
  assert r['status']=='GENERATED_SOLVER_CAP_O0_O2_WATER_RUNOFF_DEFAULT_BYTES_RESTART_PASS'
  assert all(e['returncode']==0 for e in r['events'])
  for opt,b in r['builds'].items():
   for p,h in b['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,('probe source',p)
   assert sha(f[prefix+opt+'/runtime.f90'])==b['generated_runtime_sha256']
  for opt in ['O0','O2']:
   for rain in [1,4]:
    case=prefix+f'{opt}-{rain}x-0-cap/'
    data=rows(case+'budget.csv');assert len(data)==97
    c=r['cases'][f'{opt}-{rain}x']
    assert c['accepted_substeps']==sum(int(d['accepted_substeps'])for d in data)
    for sample in c['samples']:
     label=f"{opt}-{rain}x-{sample['repeat']}-{sample['kind']}"
     assert sample['seconds']==next(e['seconds']for e in r['events']if e['label']==label)
     assert sample['fallback_days']==[int(l.split()[1])for l in f[prefix+label+'.stdout'].decode().splitlines()if'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'in l]
    for kind in ['ordinary','cap']:assert c['native_median'][kind]==statistics.median(s['seconds']for s in c['samples']if s['kind']==kind)
    old=prior[f'qualified/{opt}-{rain}x-off-0/budget.csv']
    reference=list(csv.DictReader(io.StringIO(old.decode())))
    original=list(csv.DictReader(l for l in f[f'original/{rain}x.csv'].decode().splitlines()if not l.startswith('*')))[1:]
    assert len(original)==97
    for d,s,o in zip(data,reference,original):
     assert abs(float(d['water_residual_cm']))<1e-10
     assert 10*abs(float(d['water_end_cm'])-float(d['water_start_cm'])-float(o['RAIN'])+float(d['runoff_cm'])+float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])+float(d['actual_transpiration_cm'])-float(o['BOT']))<1e-9
     assert float(d['solute_start_mg_cm2'])==float(d['solute_end_mg_cm2'])==0
     assert 10*abs(float(d['runoff_cm'])-float(s['runoff_cm']))<.01
     assert 10*abs(float(d['water_end_cm'])-float(s['water_end_cm']))<.01
     assert 10*abs(float(d['actual_transpiration_cm'])-float(s['actual_transpiration_cm']))<1e-8
     assert 10*abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))<1e-8
    assert 10*abs(sum(float(d['runoff_cm'])-float(s['runoff_cm'])for d,s in zip(data,reference)))<.01
    for rep in range(3 if opt=='O2'else 1):
     for n in FILES:
      assert f[prefix+f'{opt}-{rain}x-{rep}-ordinary/'+n]==prior[f'qualified/{opt}-{rain}x-on-0/'+n]
      assert f[prefix+f'{opt}-{rain}x-{rep}-cap/'+n]==f[case+n]
    for n in FILES:
     assert f[prefix+f'{opt}-{rain}x-default/'+n]==prior[f'qualified/{opt}-{rain}x-off-0/'+n]
     if n!='budget.csv':assert f[prefix+f'{opt}-{rain}x-resume/'+n]==f[case+n]
     assert f[prefix+f'O0-{rain}x-0-cap/'+n]==f[prefix+f'O2-{rain}x-0-cap/'+n]
    assert rows(prefix+f'{opt}-{rain}x-resume/budget.csv')==data[48:]
    if study=='bounded-recovery':
     assert r['proposal_substep_cap']==1024 and r['recovery_factor']==1.1
     matches=[s for s in r['rollbacks']if s['optimization']==opt and s['rain']==rain]
     assert len(matches)==1 and matches[0]['complete_joint_bytes_exact']and matches[0]['days']
     observed=[]
     for line in f[prefix+f'{opt}-{rain}x-rollback.stdout'].decode().splitlines():
      if'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'in line:
       fields=list(map(int,line.split()[1:]));observed.append(fields[0])
       assert fields[1]in[2,4]
       if fields[1]==4:assert fields[2]<1500
     assert observed==matches[0]['days']
     for day in observed:assert f[prefix+f'{opt}-{rain}x-rollback/before-{day}.bin']==f[prefix+f'{opt}-{rain}x-rollback/after-{day}.bin']
     for n in FILES:assert f[prefix+f'{opt}-{rain}x-rollback/'+n]==f[case+n]
     for n in FILES:assert f[case+n]==f[f'recovery/{opt}-{rain}x-0-cap/'+n],('bounded rejection changed physical outcome',opt,rain,n)
  measured[study]=r['cases']
 return dict(status='PROPOSAL_COST_AND_GENERATED_RECOVERY_RESEARCH_VALIDATED',production_changed=False,measured=measured)
def controls(f):
 validate(f);passed=[]
 for p in ['profile-O2/1x-on-0-profile/state.csv','profile-O0/4x-off-0-profile/regimes.txt','fixed-cap/O0-1x-resume/restart.bin','recovery/O2-4x-0-cap/budget.csv','recovery/O2-1x-default/state.csv','original/4x.csv','bounded-recovery/O2-1x-rollback/after-18.bin','bounded-recovery/O0-4x-resume/restart.bin']:
  bad=dict(f);bad[p]+=b'!'
  try:validate(bad)
  except(AssertionError,KeyError,ValueError):passed.append(p);continue
  raise AssertionError('accepted evidence corruption '+p)
 return passed
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--seal',action='store_true');ap.add_argument('--self-test',action='store_true')
 a=ap.parse_args()
 if a.seal:
  f={}
  for label,path in [('profile-O0','/tmp/perf01-proposal-cost-current-O0'),('profile-O2','/tmp/perf01-proposal-cost-current-O2'),('fixed-cap','/tmp/perf01-solver-cap-study'),('recovery','/tmp/perf01-solver-recovery-study'),('bounded-recovery','/tmp/perf01-solver-bounded-recovery-study')]:
   root=Path(path)
   for p in sorted(root.rglob('*')):
    if p.is_file()and(p.suffix in ['.json','.f90','.csv','.bin','.nml','.swp','.stdout','.stderr','.txt']):f[label+'/'+str(p.relative_to(root))]=p.read_bytes()
  for n in ['profile_perf01_proposal_cost.py','probe_perf01_solver_cap.py',Path(__file__).name]:f['sources/'+n]=(ROOT/'benchmarks/performance'/n).read_bytes()
  f['sources/cap_initial.py']=subprocess.check_output(['git','show','ca0e26e:benchmarks/performance/probe_perf01_solver_cap.py'],cwd=ROOT)
  f['sources/recovery_initial.py']=subprocess.check_output(['git','show','f6e14ff:benchmarks/performance/probe_perf01_solver_cap.py'],cwd=ROOT)
  for rain in [1,4]:f[f'original/{rain}x.csv']=Path(f'/tmp/perf01-native-fixed-study/{rain}x-0-legacy/result_output.csv').read_bytes()
  result=validate(f);result['negative_controls']=controls(f)
  f['VALIDATION.json']=(json.dumps(result,indent=2)+'\n').encode()
  f['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in sorted(f.items())},indent=2)+'\n').encode()
  dest=ROOT/(PREFIX+'_EVIDENCE.tar.xz')
  with tarfile.open(dest,'w:xz')as t:
   for p,b in sorted(f.items()):
    info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
  summary=dict(result,evidence=dict(path=str(dest.relative_to(ROOT)),sha256=sha(dest.read_bytes()),bytes=dest.stat().st_size,members=len(f)))
  (ROOT/(PREFIX+'_RESULT.json')).write_text(json.dumps(summary,indent=2)+'\n')
  print(json.dumps(dict(status=result['status'],evidence=summary['evidence'],controls=len(result['negative_controls']))))
 else:
  r=json.loads((ROOT/(PREFIX+'_RESULT.json')).read_text());raw=(ROOT/r['evidence']['path']).read_bytes()
  assert sha(raw)==r['evidence']['sha256']and len(raw)==r['evidence']['bytes']
  f=archive(raw);assert len(f)+1==r['evidence']['members']
  assert validate(f)['measured']==r['measured'],'published summary differs from validated evidence'
  print(json.dumps(controls(f)if a.self_test else validate(f)['status'],indent=2))
if __name__=='__main__':main()
