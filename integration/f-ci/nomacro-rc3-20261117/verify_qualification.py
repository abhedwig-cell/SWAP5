"""Reread fixed RC3 source and actual archived public rows/native payloads."""
from pathlib import Path
import hashlib,io,json,math,zipfile
root=Path(__file__).resolve().parent;source='2cedd9d0eaf8be8e8cdba321e3ab836835c558a3';package=json.loads((root/'PACKAGE.json').read_text());sha=lambda b:hashlib.sha256(b).hexdigest();assert sha((root/'candidate-source.zip').read_bytes())==package['sha256']
with zipfile.ZipFile(root/'candidate-source.zip') as z:
 manifest=json.loads(z.read('RELEASE_MANIFEST.json'));assert manifest['source_commit']==source
 for n,h in manifest['files'].items():assert sha(z.read(n))==h,n
report=dict(status='ALL_FIXED_RC3_CLEAN_SOURCE_COHORTS_VERIFIED',source_commit=source,archive_sha256=package['sha256'],kernel_optimization='O0short/O2full',provider_donor_optimization='O2',whole_scientific_equivalence='NOT_QUALIFIED',original_failed_science='PRESERVED',full_physical_energy='INCOMPLETE',tolerances_changed=False,cohorts={})
for platform in ('local','ubuntu','windows'):
 index=json.loads((root/(platform+'-raw.index.json')).read_text());assert sha((root/index['archive']).read_bytes())==index['sha256']
 with zipfile.ZipFile(root/index['archive']) as z:
  for n,d in index['files'].items():assert sha(z.read(n))==d['sha256'],n
  result=json.loads(z.read('RESULT.json'));assert result['status']=='COMMON_PROFILE_PUBLIC_O0_O2_FULL_OWN_PASS' and result['source']==source
  prepared=json.loads(z.read('provider/PREPARED.json'));assert prepared['status']=='SOURCE_PROVIDER_READY_NO_MODEL_EXECUTED'
  def rows(n):return [{k:v for k,v in json.loads(s).items() if k not in ('column','revision')} for s in z.read(n+'/daily.jsonl').decode().splitlines()]
  def csv(n):return [s for s in z.read(n+'/original/result_output.csv').decode().splitlines() if s.strip() and not s.startswith('*')]
  def native(n):
   with zipfile.ZipFile(io.BytesIO(z.read(n))) as t:return {k:t.read(k) for k in ('result.end','macro.bin')}
  profiles=[]
  assert len(result['profiles'])==6
  for p in result['profiles']:
   name=p['project']+'-'+p['opt'];end={'grass':1827,'hupsel':1096,'saltfarm':1461}[p['project']] if p['opt']=='O2' else 4;cut={'grass':365,'hupsel':365,'saltfarm':109}[p['project']] if p['opt']=='O2' else 2
   assert (p['days'],p['cut'])==(end,cut)
   control=name+'-control';full=name+'-candidate-full';resume=name+'-own-resume';c,f,r=rows(control),rows(full),rows(resume)
   assert [x['day'] for x in c]==list(range(1,end+1));assert c==f and r==f[cut:]
   assert all(x['committed'] and abs(x['independent_residual_cm'])<=1e-10 and abs(x['kernel_residual_cm'])<=1e-10 and abs(x.get('solute_independent_residual_mg_cm2',0))<=1e-10 for x in f+r)
   assert csv(control)==csv(full) and csv(resume)[-len(r):]==csv(full)[-len(r):]
   assert native(control+'/accepted-column-1-day-'+str(end)+'.zip')==native(resume+'/accepted-column-1-day-'+str(end)+'.zip')
   policy='configured-dtmax-physical-growth-v2' if p['project']=='saltfarm' else 'configured-dtmax-daily-v1';assert p['time_step_policy']==policy
   profiles.append(dict(project=p['project'],kernel_opt=p['opt'],days=end,restart_day=cut,exact_physical=True,exact_csv=True,exact_native_auxiliary=True,water_max_cm=max(abs(x['independent_residual_cm']) for x in f),solute_max_mg_cm2=max(abs(x.get('solute_independent_residual_mg_cm2',0)) for x in f),sum_daily_water_residual_cm=math.fsum(x['independent_residual_cm'] for x in f),sum_daily_solute_residual_mg_cm2=math.fsum(x.get('solute_independent_residual_mg_cm2',0) for x in f),policy=policy,model_seconds=p['model_seconds']))
  refusal=json.loads(z.read('refusals/RESULT.json'));assert refusal['status']=='INVOCATION_LOCAL_TOOLCHAIN_REFUSALS_PASS' and len(refusal['events'])==12
  external=json.loads(z.read('external/RESULT.json'));assert external['status']=='PUBLISHER_EXTERNAL_CONTRACT_PASS' and len(external['profiles'])==6
  for p in external['profiles']:assert all(p[k] for k in ('discard_replay_exact','interleaved_instance_native_exact','external_day1_restore_day2_exact','origin_unchanged','discarded_token_refused'))
  events=result['events'];assert all(e['returncode']==0 for e in events)
  report['cohorts'][platform]=dict(profiles=profiles,source_preparation_seconds=next(e['seconds'] for e in events if e['label']=='prepare'),build_command_seconds=sum(e['seconds'] for e in events if e['label'].endswith('-build')),all_public_command_seconds=sum(e['seconds'] for e in events),toolchain=prepared['toolchain'],refusals=12,external_profiles=6)
(root/'QUALIFICATION.json').write_text(json.dumps(report,indent=2));print(json.dumps({k:[(p['project'],p['days'],p['model_seconds']) for p in v['profiles'] if p['kernel_opt']=='O2'] for k,v in report['cohorts'].items()}))
