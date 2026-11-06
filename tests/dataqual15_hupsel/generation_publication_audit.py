"""Remeasure native generation data, pinned provider cohorts and actual process tests."""
import argparse,json,re,struct,zlib
from functools import lru_cache
from pathlib import Path
import generation_publication_policy as policy
from generation_crc_posix_evidence import valid_generation
from generation_publication_models import projected
sha=policy.sha
before=lru_cache(maxsize=None)(policy.before)
STEPS=('accepted','csv','joint','cold','saved')

def audit(base,override=None):
 base=base.resolve();override=override or {}
 initial=json.loads((base/'RESULT.json').read_bytes())
 original=initial['events'][0]['command'][-1].replace('\\','/').split('/publication/')[0]
 def local(p):
  n=str(p).replace('\\','/')
  return base/n[len(original)+1:] if n.startswith(original+'/') else Path(p)
 def raw(p):
  p=local(p);return override[str(p)] if str(p) in override else p.read_bytes()
 def load(p):return json.loads(raw(p))
 r=load(base/'RESULT.json');assert r['status']=='FULL_PRIVATE_PLATFORM_MODEL_EXECUTION_COMPLETE' and r['role']=='candidate'
 assert not r['production_admission'] and not r['whole_scientific_admission']
 windows=r['platform']=='nt';positive={};objects={};links=0
 assert raw(base/'publication'/'publication.c').decode()==policy.candidate_c()
 for n in [*policy.SOURCES,policy.C]:
  expected=policy.candidate_c() if n==policy.C else policy.candidate(n)
  assert r['source_sha256'][n]==sha(expected.encode())
 for step in STEPS:
  folder=base/step;q=load(folder/'result.json');assert q==r['results'][step]
  recipe=load(base/(step+'-RECIPE.json'));name=recipe['original_recipe'].replace('\\','/').rsplit('/',1)[1];original_recipe=before('tests/nut-output/'+name)
  assert recipe['original_sha256']==sha(original_recipe.encode()) and recipe['source_projection']==projected(original_recipe,name,windows)
  assert recipe['projected_sha256']==sha(recipe['source_projection'].encode())
  assert q['results']['O0']==q['results']['O2'],(step,'optimization drift')
  assert sha(raw(folder/'driver.f90'))==q['generated_driver_sha256']
  if step=='accepted':
   for opt in ('O0','O2'):
    assert sha(raw(folder/opt/'default.endpoint'))==q['results'][opt]['physical']
    assert sha(raw(folder/opt/'default.endpoint.output'))==q['results'][opt]['output']
  for key in ('input_sha256','physical_input_sha256','cold_input_sha256'):
   for n,h in q.get(key,{}).items():
    n=n.replace('\\','/')
    expected=policy.candidate(n) if n in policy.SOURCES else before(n)
    assert sha(expected.replace('\r\n','\n').encode())==h,(step,n)
  for key in ('pinned_object_sha256','pinned_artifacts'):
   for n,h in q.get(key,{}).items():assert sha(raw(n))==h,(step,n);objects[n]=h
  events=load(folder/'events.json');assert events and all(e['returncode']==0 for e in events)
  for e in events:
   for stream in ('stdout','stderr'):raw(folder/e[stream])
  ledger=load(base/(step+'-EFFECTIVE_COMPILER.json'))
  for e in ledger:
   cmd=e['effective_command']
   if '-o' in cmd and '-c' not in cmd and e['returncode']==0:
    links+=1;exe=local(cmd[cmd.index('-o')+1]);exe=exe if exe.is_file() else Path(str(exe)+'.exe');b=raw(exe)
    assert '-fcheck=all' in cmd and '-ffpe-trap=invalid,zero,overflow' in cmd
    assert original+'/publication/'+('O0.o' if '-O0' in cmd else 'O2.o') in [n.replace('\\','/') for n in cmd]
    if windows:
     pe=struct.unpack_from('<I',b,0x3c)[0];assert b[pe:pe+4]==b'PE\0\0' and struct.unpack_from('<Q',b,pe+24+72)[0]==67108864
     if e.get('response_sha256'):
      actual=e['executed_command'];assert len(actual)==2 and actual[1].startswith('@');assert sha(raw(actual[1][1:]))==e['response_sha256']
  if step in ('joint','saved'):
   for opt in ('O0','O2'):
    for p in (folder/opt).iterdir():
     if p.is_file() and raw(p)[:8] in (b'S5NO0001',b'S5NS0001'):
      data=raw(p)
      # Malformed reader cases are intentionally present alongside positives.
      if (step=='joint' and p.name in ('model.restart.generation','model.endpoint.generation')) or (step=='saved' and re.fullmatch(r'endpoint(?:\.stages)?\.(?:saved|deferred)\.(?:phase-[123]|day-[34])',p.name)):
       valid_generation(data);positive[str(p)]=sha(data)
    crashes=q['results'][opt]['crashes']
    if windows:assert crashes=={}
    else:assert set(crashes)=={'before','after'} and all(v['returncode']==-9 and v['complete'] for v in crashes.values())
 assert len(positive)>=8 and len(objects)>300 and links>=10
 return dict(platform=r['platform'],positive_generation_sha256=positive,pinned_objects=len(objects),actual_links=links,production_admission=False)

def fault_audit(base,folder):
 r=json.loads((folder/'RESULT.json').read_text());assert r['status']=='ACTUAL_WINDOWS_PUBLIC_GENERATION_FAILURES_AND_NATIVE_TERMINATION_PASS'
 assert len(r['reports'])==4 and len(r['events'])==20
 for e in r['events']:
  assert e['returncode']==0 and b'PUBLIC_GENERATION_PRECOMMIT_FAILURE_AND_AUTHORITY=PASS' in (folder/e['stdout']).read_bytes()
 for report in r['reports']:
  opt=report['optimization'];family=report['family'];case=folder/(opt+'-'+family)
  assert report['precommit_failures']==[2,3,4,5,6]
  if family=='joint':old=base/family/opt/'model.restart.generation';good=base/family/opt/'model.endpoint.generation'
  else:
   prefix=base/family/opt/'endpoint.stages.saved'
   if not Path(str(prefix)+'.phase-3').exists():prefix=base/family/opt/'endpoint.saved'
   old=Path(str(prefix)+'.phase-2');good=Path(str(prefix)+'.phase-3')
  for stage in report['precommit_failures']:
   c=case/('failure-'+str(stage));assert (c/'authority').read_bytes()==old.read_bytes() and (c/'after').read_bytes()==good.read_bytes()
  assert {v['phase'] for v in report['termination']}=={'before','after'}
  for v in report['termination']:
   expected=(old if v['phase']=='before' else good).read_bytes();c=case/('terminate-'+v['phase'])
   assert v['actual_termination_returncode']!=0 and v['fresh_reconstruction'] and v['complete_authority_sha256']==sha(expected)
   assert (c/'authority').read_bytes()==expected and (c/'recovered').read_bytes()==expected
 return dict(actual_precommit_failures=20,actual_process_terminations=8,fresh_reconstructions=8)

def controls(base,result):
 targets=[base/'joint'/'driver.f90',Path(next(iter(result['positive_generation_sha256']))),base/'publication'/'publication.c']
 refused=[]
 for target in targets:
  try:audit(base,{str(target.resolve()):target.read_bytes()+b'!corrupt'})
  except (AssertionError,ValueError,KeyError,struct.error):refused.append(target.name)
  else:raise AssertionError('corrupt native proof admitted: '+str(target))
 record=json.loads((base/'RESULT.json').read_text());record['source_sha256'][policy.C]='0'*64
 try:audit(base,{str((base/'RESULT.json').resolve()):json.dumps(record).encode()})
 except AssertionError:refused.append('resealed-source-record')
 else:raise AssertionError('resealed source record admitted')
 return refused

def main():
 p=argparse.ArgumentParser();p.add_argument('--models',type=Path,required=True);p.add_argument('--faults',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args();policy.guard();result=audit(a.models)
 targets=[a.models/'joint'/'driver.f90',Path(next(iter(result['positive_generation_sha256']))),a.models/'RESULT.json']
 for target in targets:
  try:audit(a.models,{str(target.resolve()):target.read_bytes()+b'!corrupt'})
  except (AssertionError,ValueError,KeyError,struct.error):pass
  else:raise AssertionError('corrupt native proof admitted: '+str(target))
 result['actual_data_refusals']=[str(p) for p in targets]
 if a.faults:result['native_windows_faults']=fault_audit(a.models,a.faults)
 a.output.write_text(json.dumps(result,indent=2)+'\n');print('PRIVATE_PUBLICATION_RAW_MODELS_AND_THREE_DATA_REFUSALS_PASS')
if __name__=='__main__':main()
