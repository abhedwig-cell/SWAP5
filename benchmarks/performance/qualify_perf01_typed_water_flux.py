"""Real typed native option against sealed PR1404 base/root inputs and oracles."""
import argparse,csv,hashlib,io,json,os,statistics,subprocess,tarfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_SOLVER_FAILURE_20261023'
FILES=['budget.csv','state.csv','endpoint.csv','restart.bin']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(b):return list(csv.DictReader(io.StringIO(b.decode())))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--bundle-prefix',type=Path,required=True);ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
 out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);events=[]
 ref=json.loads((ROOT/(PREFIX+'_RESULT.json')).read_text());cap=ROOT/ref['evidence']['path'];assert sha(cap)==ref['evidence']['sha256']
 with tarfile.open(cap,'r:xz')as t:archive={m.name:t.extractfile(m).read()for m in t.getmembers()}
 default_status=json.loads((ROOT/'benchmarks/performance/PERF01_NATIVE_PROPOSAL_20261023_STATUS.json').read_text())
 default_cap=ROOT/default_status['evidence']['path'];assert sha(default_cap)==default_status['evidence']['sha256']
 with tarfile.open(default_cap,'r:xz')as t:default_archive={m.name:t.extractfile(m).read()for m in t.getmembers()}
 report=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),changed_accuracy=True,
  events=events,cases={},builds={},capsule_sha256=sha(cap),default_capsule_sha256=sha(default_cap),original_water_max_mm=0.)
 # Admit both completed builds before starting any physical execution.
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text())
  assert bundle['status']=='BUILT'
  assert all(sha(Path(p))==h for p,h in bundle['executable_sha256'].items())
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def execute(binary,case,label,restart='-',stop='97',required=True):
  cmd=['taskset','-c',str(min(os.sched_getaffinity(0))),str(binary),'input.nml',str(restart),str(stop),'input.swp'];start=time.perf_counter()
  r=subprocess.run(cmd,cwd=case,capture_output=True,timeout=60);idx=len(events)
  for stream in ['stdout','stderr']:(out/f'{idx:03}.{stream}').write_bytes(getattr(r,stream))
  events.append(dict(label=label,command=cmd,seconds=time.perf_counter()-start,returncode=r.returncode));save()
  if required and r.returncode:raise RuntimeError(label+'\n'+r.stdout.decode()+r.stderr.decode())
  return r
 def case_input(path,document,swp):
  path.mkdir();(path/'input.nml').write_bytes(document);(path/'input.swp').write_bytes(swp)
 for opt in ['O0','O2']:
  bundle=json.loads((Path(str(a.bundle_prefix)+'-'+opt)/'bundle.json').read_text());exe=Path(bundle['exe'])
  meta=json.loads((exe.parent/'build-complete.json').read_text());assert sha(exe)==meta['executable_sha256']
  assert all(sha(ROOT/p)==h for p,h in meta['input_sha256'].items())
  assert all(sha(Path(p))==h for p,h in meta['reused_artifact_sha256'].items())
  report['builds'][opt]=meta
  for rain in [1,4]:
   prefix=f'qualified/{opt}-{rain}x-off-0/';label=f'{opt}-{rain}x-incumbent-no-proposal';case=out/label
   case_input(case,default_archive[prefix+'input.nml'],default_archive[prefix+'input.swp']);execute(exe,case,label)
   for name in FILES:assert(case/name).read_bytes()==default_archive[prefix+name],(label,name,'incumbent default OFF')
  for fixture in ['base','stress']:
   for rain in [1,4]:
    key=f'{opt}-{fixture}-{rain}x';refkey=f'separate-{fixture}/{opt}-{rain}x-ordinary-0/'
    source=archive[refkey+'input.nml'];swp=archive[refkey+'input.swp']
    assert b'retain_accepted_step_proposal=.true.'in source
    document=source.replace(b'&column',b'&column\n water_flux_temporal=.true.',1)
    samples=[]
    for repeat in range(3 if opt=='O2'else 1):
     for arm,text in [('default',source),('typed',document)]:
      label=f'{key}-{arm}-{repeat}';case=out/label;case_input(case,text,swp);execute(exe,case,label)
      samples.append(dict(arm=arm,seconds=events[-1]['seconds']))
      target=archive if arm=='default'else None
      for name in FILES:
       expected=archive[refkey+name]if arm=='default'else(out/f'{key}-typed-0'/name).read_bytes()
       assert(case/name).read_bytes()==expected,(label,name,'default oracle or repeat drift')
    current=out/f'{key}-typed-0';data=rows((current/'budget.csv').read_bytes());old=rows(archive[refkey+'budget.csv']);assert len(data)==len(old)==97
    prototype_key=f'separate-{fixture}/{opt}-{rain}x-water-0/'
    prototype_exact={n:(current/n).read_bytes()==archive[prototype_key+n]for n in FILES}
    diff={k:dict(max_mm=10*max(abs(float(d[k])-float(o[k]))for d,o in zip(data,old)),sum_mm=10*sum(float(d[k])-float(o[k])for d,o in zip(data,old)))for k in ['runoff_cm','water_end_cm','actual_transpiration_cm','soil_evaporation_cm','pond_evaporation_cm']}
    criteria=dict(internal_water=max(abs(float(d['water_residual_cm']))for d in data)<1e-10,runoff_daily=diff['runoff_cm']['max_mm']<.01,
     runoff_season=abs(diff['runoff_cm']['sum_mm'])<(.05 if fixture=='stress'else .01),storage=diff['water_end_cm']['max_mm']<.01,
     transpiration=diff['actual_transpiration_cm']['max_mm']<(.01 if fixture=='stress'else 1e-8),
     total_evaporation=10*max(abs(float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])-float(o['soil_evaporation_cm'])-float(o['pond_evaporation_cm']))for d,o in zip(data,old))<(.01 if fixture=='stress'else 1e-8))
    if fixture=='stress':criteria['season_transpiration']=abs(diff['actual_transpiration_cm']['sum_mm'])<.05
    original=archive[f'original/{rain}x.csv'].decode().splitlines();forcing=list(csv.DictReader(l for l in original if not l.startswith('*')))[1:];assert len(forcing)==97
    for d,o in zip(data,forcing):
     residual=10*abs(float(d['water_end_cm'])-float(d['water_start_cm'])-float(o['RAIN'])+float(d['runoff_cm'])+float(d['soil_evaporation_cm'])+float(d['pond_evaporation_cm'])+float(d['actual_transpiration_cm'])-float(o['BOT']))
     assert residual<1e-9 and float(d['solute_start_mg_cm2'])==float(d['solute_end_mg_cm2'])==0.
     report['original_water_max_mm']=max(report['original_water_max_mm'],residual)
    for part,stop in [('half',48),('resume',97)]:
     label=key+'-'+part;case=out/label;case_input(case,document,swp)
     execute(exe,case,label,out/(key+'-half')/'restart.bin'if part=='resume'else'-',stop)
     if part=='resume':
      for n in FILES[1:]:assert(case/n).read_bytes()==(current/n).read_bytes(),(key,n,'restart')
      assert rows((case/'budget.csv').read_bytes())==data[48:]
    report['cases'][key]=dict(criteria=criteria,differences=diff,prototype_bytes_exact=prototype_exact,
     medians={arm:statistics.median(s['seconds']for s in samples if s['arm']==arm)for arm in ['default','typed']})
    save();assert all(criteria.values()),(key,criteria)
  # Native parser/application negatives must fail without publishing a restart.
  refkey=f'separate-base/{opt}-1x-ordinary-0/';source=archive[refkey+'input.nml'];swp=archive[refkey+'input.swp']
  for name,extra in [('no_proposal',b'retain_accepted_step_proposal=.false.'),('tracer',b'rain_c=.001'),('boesten',b'boesten_evaporation=.true.,boesten_cofred=.35'),('picard',b'picard_conductivity_iteration=.true.'),('budget',b'temporal_tolerance=.0001')]:
   text=source.replace(b'&column',b'&column\n water_flux_temporal=.true.\n '+extra,1)
   if name=='no_proposal':text=text.replace(b' retain_accepted_step_proposal=.true.',b'')
   if name=='budget':text=text.replace(b' temporal_tolerance=1.00000000000000002e-03',b'')
   label=opt+'-negative-'+name;case=out/label;case_input(case,text,swp)
   r=execute(exe,case,label,required=False);assert r.returncode!=0 and not(case/'restart.bin').exists(),label
 for fixture in ['base','stress']:
  for rain in [1,4]:
   for name in FILES:assert(out/f'O0-{fixture}-{rain}x-typed-0'/name).read_bytes()==(out/f'O2-{fixture}-{rain}x-typed-0'/name).read_bytes(),(fixture,rain,name,'O0/O2')
 report['status']='TYPED_NATIVE_BASE_ROOT_O0_O2_DEFAULT_RESTART_CRITERIA_PASS';save();print(json.dumps({k:c['medians']for k,c in report['cases'].items()},indent=2))
if __name__=='__main__':main()
