"""Actual opt-in project qualification using hash-verified unchanged providers."""
import argparse,copy,csv,hashlib,json,os,statistics,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def rows(p):return list(csv.DictReader(p.open()))
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',type=Path,required=True)
 ap.add_argument('--base-prefix',type=Path,default=Path('/tmp/perf01-native-fixed'))
 ap.add_argument('--baseline-study',type=Path,default=Path('/tmp/perf01-native-fixed-study'))
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 report=dict(status='RUNNING',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  inputs={p:sha(ROOT/p)for p in ['app/solute_project/main.f90','tools/solute/run_project.py',str(Path(__file__).relative_to(ROOT))]},
  events=[],cases={},builds={},negative_controls=[],rollback_cases=[])
 def save():(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
 def run(cmd,cwd,label,success=True):
  start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=60)
  for stream in ['stdout','stderr']:(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
  report['events'].append(dict(label=label,command=list(map(str,cmd)),returncode=r.returncode,wall_seconds=time.perf_counter()-start));save()
  if success:r.check_returncode()
  else:assert r.returncode!=0,label
  return r
 core=min(os.sched_getaffinity(0));report['core']=core;save()
 for opt in ['O0','O2']:
  base=Path(str(a.base_prefix)+'-'+opt);bundle=json.loads((base/'bundle.json').read_text());old=Path(bundle['exe'])
  meta=json.loads((old.parent/'build-complete.json').read_text());assert sha(old)==meta['executable_sha256']
  for p,h in meta['input_sha256'].items():
   if p!='app/solute_project/main.f90':assert sha(ROOT/p)==h,p
  for p,h in meta['reused_artifact_sha256'].items():assert sha(Path(p))==h,p
  b=out/opt;b.mkdir();exe=b/'project';cmd=meta['events'][-1]['command']
  cmd=[str(ROOT/'app/solute_project/main.f90')if p.endswith('/app/solute_project/main.f90')else str(exe)if p==cmd[-1]else p for p in cmd]
  run(cmd,b,opt+'-build')
  m=copy.deepcopy(meta);m.update(candidate=report['candidate'],executable_sha256=sha(exe))
  m['input_sha256']['app/solute_project/main.f90']=sha(ROOT/'app/solute_project/main.f90')
  (b/'build-complete.json').write_text(json.dumps(m,indent=2)+'\n')
  bundle=copy.deepcopy(bundle);bundle['exe']=str(exe);bundle['executable_sha256'].pop(str(old));bundle['executable_sha256'][str(exe)]=sha(exe)
  (b/'bundle.json').write_text(json.dumps(bundle,indent=2)+'\n');report['builds'][opt]=dict(executable_sha256=sha(exe),input_sha256=m['input_sha256'],reused_artifact_sha256=m['reused_artifact_sha256'])
  # Test instrumentation exports the complete committed joint generation around
  # every real proposal rejection. Production orchestration is called unchanged.
  source=(ROOT/'app/solute_project/main.f90').read_text()
  source=source.replace('  integer :: nodes=4','  character(1024)::probe_before_path,probe_after_path\n  integer :: nodes=4',1)
  anchor='    if(dynamic_temperature)then\n      forcing%soil_temperature%prescribed_surface_temperature_c'
  assert source.count(anchor)==1
  source=source.replace(anchor,"    if(retain_accepted_step_proposal)then\n      write(probe_before_path,'(A,I0,A)')'before-',j,'.bin'\n      call write_matrix_joint_restart_file(trim(probe_before_path),column_id,template,p%parameter_set_id, &\n        water,solute,code,allow_surface_mass=.true.)\n      call require(code==JOINT_OK,'probe before export')\n    end if\n"+anchor)
  anchor='    if(retain_accepted_step_proposal.and.result%status==JOINT_WATER_REJECTED)then\n'
  assert source.count(anchor)==1
  source=source.replace(anchor,anchor+"      write(probe_after_path,'(A,I0,A)')'after-',j,'.bin'\n      call write_matrix_joint_restart_file(trim(probe_after_path),column_id,template,p%parameter_set_id, &\n        water,solute,code,allow_surface_mass=.true.)\n      call require(code==JOINT_OK,'probe after export')\n")
  driver=b/'rollback_probe.f90';driver.write_text(source);probe=b/'rollback_probe'
  run([str(driver)if p==str(ROOT/'app/solute_project/main.f90')else str(probe)if p==str(exe)else p for p in cmd],b,opt+'-rollback-build')
  for rain in [1,4]:
   previous=a.baseline_study/f'{rain}x-0-current';default_input=(previous/'input.nml').read_text()
   enabled=default_input.replace('&column\n','&column\n retain_accepted_step_proposal=.true.\n',1)
   repeat=3 if opt=='O2'else 1
   samples=[]
   for repetition in range(repeat):
    for arm,text in [('off',default_input),('on',enabled)]:
     label=f'{opt}-{rain}x-{arm}-{repetition}';folder=out/label;folder.mkdir()
     (folder/'input.nml').write_text(text);(folder/'input.swp').write_bytes((previous/'input.swp').read_bytes())
     run(['taskset','-c',core,exe,'input.nml','-','2048','input.swp'],folder,label)
     data=rows(folder/'budget.csv');assert len(data)==97
     assert max(abs(float(r['water_residual_cm']))for r in data)<1e-10
     assert max(abs(float(r['water_end_cm'])-float(r['water_start_cm'])-float(r['water_in_cm'])+float(r['water_out_cm']))for r in data)<1e-10
     assert all(float(r['solute_start_mg_cm2'])==float(r['solute_end_mg_cm2'])==0 for r in data)
     target=previous if arm=='off'else out/f'{opt}-{rain}x-on-0'
     for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (folder/name).read_bytes()==(target/name).read_bytes(),(label,name)
     samples.append(dict(arm=arm,repeat=repetition,wall_seconds=report['events'][-1]['wall_seconds'],
       output_sha256={name:sha(folder/name)for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']}))
   on=out/f'{opt}-{rain}x-on-0';data=rows(on/'budget.csv');reference=rows(previous/'budget.csv')
   differences={k:dict(max_daily_mm=10*max(abs(float(r[k])-float(s[k]))for r,s in zip(reference,data)),sum_difference_mm=10*sum(float(s[k])-float(r[k])for r,s in zip(reference,data)))for k in ['runoff_cm','water_end_cm','soil_evaporation_cm','pond_evaporation_cm','actual_transpiration_cm']}
   assert differences['runoff_cm']['max_daily_mm']<.01 and abs(differences['runoff_cm']['sum_difference_mm'])<.01
   assert differences['water_end_cm']['max_daily_mm']<.01
   assert differences['actual_transpiration_cm']['max_daily_mm']<1e-8
   assert 10*max(abs(float(r['soil_evaporation_cm'])+float(r['pond_evaporation_cm'])-float(s['soil_evaporation_cm'])-float(s['pond_evaporation_cm']))for r,s in zip(reference,data))<1e-8
   fallbacks=[line for line in (out/(f'{opt}-{rain}x-on-0.stdout')).read_text().splitlines()if 'SWAP5_PROJECT_STEP_PROPOSAL_FALLBACK'in line]
   report['cases'][f'{opt}-{rain}x']=dict(differences=differences,samples=samples,fallbacks=fallbacks,
     accepted_substeps=sum(int(r['accepted_substeps'])for r in data),native_wall_median={arm:statistics.median(s['wall_seconds']for s in samples if s['arm']==arm)for arm in ['off','on']})
   # Same input and executable, genuine fresh-process midpoint continuation.
   half=out/f'{opt}-{rain}x-half';half.mkdir();resume=out/f'{opt}-{rain}x-resume';resume.mkdir()
   for folder in [half,resume]:
    for name in ['input.nml','input.swp']:(folder/name).write_bytes((on/name).read_bytes())
   run(['taskset','-c',core,exe,'input.nml','-','48','input.swp'],half,f'{opt}-{rain}x-half')
   run(['taskset','-c',core,exe,'input.nml',half/'restart.bin','2048','input.swp'],resume,f'{opt}-{rain}x-resume')
   for name in ['state.csv','endpoint.csv','restart.bin']:assert (resume/name).read_bytes()==(on/name).read_bytes()
   assert rows(resume/'budget.csv')==data[48:]
   folder=out/f'{opt}-{rain}x-rollback';folder.mkdir()
   for name in ['input.nml','input.swp']:(folder/name).write_bytes((on/name).read_bytes())
   run(['taskset','-c',core,probe,'input.nml','-','2048','input.swp'],folder,f'{opt}-{rain}x-rollback')
   after=list(folder.glob('after-*.bin'));assert len(after)==len(fallbacks)>0
   for p in after:assert p.read_bytes()==(folder/p.name.replace('after-','before-')).read_bytes()
   for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (folder/name).read_bytes()==(on/name).read_bytes()
   report['rollback_cases'].append(dict(optimization=opt,rain=rain,days=[int(p.stem.split('-')[1])for p in after],complete_joint_bytes_exact=True))
   save()
  for label,needle,insertion in [('positive-tracer','&surface\n',' dry_mg_cm2_day=1d-6\n'),('picard','&column\n',' picard_conductivity_iteration=.true.\n'),('implicit-transport','&column\n',' solute_transport_scheme=1\n')]:
   folder=out/f'{opt}-reject-{label}';folder.mkdir();text=enabled.replace(needle,needle+insertion,1)
   (folder/'input.nml').write_text(text);(folder/'input.swp').write_bytes((previous/'input.swp').read_bytes())
   r=run([exe,'input.nml','-','1','input.swp'],folder,f'{opt}-reject-{label}',False)
   assert b'native proposal'in r.stdout and not(folder/'budget.csv').exists()
   report['negative_controls'].append(opt+'-'+label)
 for rain in [1,4]:
  for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
   assert (out/f'O0-{rain}x-on-0'/name).read_bytes()==(out/f'O2-{rain}x-on-0'/name).read_bytes(),(rain,name)
 # Actual outer project route and atomic publication, measured separately.
 for rain in [1,4]:
  source=a.baseline_study/f'{rain}x-input/swap.swp';samples=[]
  for repetition in range(3):
   for arm in ['off','on']:
    label=f'frontend-{rain}x-{arm}-{repetition}';folder=out/label
    cmd=['taskset','-c',core,sys.executable,'-B',ROOT/'tools/solute/run_project.py',source,'--bundle',out/'O2','--output',folder,'--temporal-tolerance','.001','--surface-exfiltration','historical_zero']
    if arm=='on':cmd+=['--retain-step-proposal']
    run(cmd,ROOT,label)
    for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:assert (folder/name).read_bytes()==(out/f'O2-{rain}x-{arm}-0'/name).read_bytes()
    samples.append(dict(arm=arm,repeat=repetition,wall_seconds=report['events'][-1]['wall_seconds']))
  report['cases'][f'O2-{rain}x']['frontend_samples']=samples
  report['cases'][f'O2-{rain}x']['frontend_wall_median']={arm:statistics.median(s['wall_seconds']for s in samples if s['arm']==arm)for arm in ['off','on']}
 report['status']='NATIVE_PROPOSAL_O0_O2_DEFAULT_RESTART_FALLBACK_AND_NEGATIVES_PASS';save()
 print(json.dumps({k:{p:v for p,v in c.items()if p in ['native_wall_median','frontend_wall_median','accepted_substeps','differences','fallbacks']}for k,c in report['cases'].items()},indent=2))
if __name__=='__main__':main()
