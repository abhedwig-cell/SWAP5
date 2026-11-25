"""Actual44 selected original contexts; failed cohorts stay failed and retained."""
import argparse,hashlib,io,json,subprocess,tarfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_state_calendar_archive_science import case_audit
from frost_calendar_state_portable_custody import source as scientific_custody
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
def local_source(store,producer,new=False):
 if new=='trial':
  tarname='sources/FROST_BOUNDARY_STATE_CALENDAR04_TRIAL_FLUX_ACTUAL_SOURCE_'+producer+'.tar';commitname='sources/FROST_BOUNDARY_STATE_CALENDAR04_TRIAL_FLUX_ACTUAL_COMMIT_'+producer+'.bin'
 elif new:
  tarname='sources/FROST_BOUNDARY_STATE_CALENDAR04_PLATE_CLOCK_ACTUAL_SOURCE_'+producer+'.tar';commitname='sources/FROST_BOUNDARY_STATE_CALENDAR04_PLATE_CLOCK_ACTUAL_COMMIT_'+producer+'.bin'
 else:
  tarname='source/actual-compiler-git-archive-'+producer+'.tar';commitname='source/actual-compiler-commit-'+producer+'.bin'
 commit=store.get(commitname);assert hashlib.sha1(b'commit '+str(len(commit)).encode()+b'\0'+commit).hexdigest()==producer and commit==git('cat-file','commit',producer)
 entries={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',producer).decode().splitlines()}
 raw=store.get(tarname);line_endings=[]
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  files=[x for x in t.getmembers() if x.isfile()]
  for item in files:
   value=t.extractfile(item).read();normal=value.replace(b'\r\n',b'\n');blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
   assert item.name in entries and entries[item.name] in (blob(value),blob(normal)),('Original Git archive member identity differs',item.name,entries.get(item.name))
   if entries[item.name]!=blob(value):line_endings.append(dict(path=item.name,actual_raw_sha256=SHA(value),actual_LF_sha256=SHA(normal),actual_original_Git_blob=entries[item.name]))
 return dict(actual_source=producer,source_type='EXPLICIT_GENUINE_GIT_ARCHIVE_DATA_OF_ACTUAL_LOCAL_COMPILER_NOT_CURRENT_CHECKOUT',tar_sha256=SHA(raw),source_files=len(files),commit_bytes_exact=True,explicit_original_raw_and_LF_source_identities=line_endings)
def audit(proof):
 contract=json.loads((P/'FROST_BOUNDARY_STATE_CALENDAR04_CONTRACT_V1.json').read_text());cases=contract['representative_cases'];assert len(cases)==11
 result=[];provenance=[];used={}
 with ExitStack() as stack:
  stores={}
  def get(name):
   if name not in stores:
    store=Archive(proof,name,stack);stores[name]=store
    # Every byte, including raw failures, is retained and freshly checked.
    for member in store.names:store.get(member)
   return stores[name]
  local_old=get('FROST_BOUNDARY_STATE_CALENDAR04_LOCAL_WINDOWS_O0_O2_RAW_V1')
  local_new=get('FROST_BOUNDARY_STATE_CALENDAR04_TRIAL_FLUX_LOCAL_WINDOWS_RAW_V1')
  old_producer='3feb51229a980331bc12be2d1d265bef7ae6691a';new_producer='dfb4337cb5fffcf70b1fa20a672683c6ea034690'
  provenance.extend([local_source(local_old,old_producer),local_source(local_new,new_producer,'trial')])
  producers={1:'71806beaee8e532af407ab88298b7bde4ac766c2',2:'83810c95b433bf48f8b1bc7c87b005dbe24af197',3:'dcae412aae8f65acb48b1e37431334c2c522c071',4:'0fae846dec07fb3b1a317a55b975accbbf110128',5:'36be92ae8aa7fe56b604c685d55af32c4a89f3b4'}
  for platform in ('WINDOWS','UBUNTU'):
   for opt in ('O0','O2'):
    for index,case in enumerate(cases):
     name=case['name'];control=None;refusals=None
     if platform=='WINDOWS' and index==0:
      store=local_old;producer=old_producer;prefix='current/'+opt+'/'+name;build='compiled/'+opt+'/'+name+'/bundle';provider=local_old;control=prefix+'/completed-controls-v2';refusals=prefix+'/controls'
     elif platform=='WINDOWS' and index==3:
      store=local_new;producer=new_producer;prefix='current/'+opt+'/'+name;build='compiled/'+opt+'/'+name+'/bundle';provider=local_old
     else:
      if case['bottom']==8:version=5
      elif index in (0,1):version=1
      elif index in (4,5,6):version=2
      elif index==8:version=2 if platform=='WINDOWS' else 3
      elif index==9:version=3
      else:raise AssertionError(('Unmapped actual original science',index,name))
      stem=f'FROST_BOUNDARY_STATE_CALENDAR04_{platform}_{opt}_ORIGINAL_V{version}';store=get(stem);producer=producers[version];provider=store;prefix='current/'+name
      if stem not in used:
       workflow=f'.github/workflows/nomacro-frost-boundary-state-calendar04-{platform.lower()}.yml'
       with ExitStack() as source_stack:_,p=scientific_custody(store,source_stack,producer,producer,workflow)
       provenance.append(dict(archive=stem,**p));used[stem]=True
      science=json.loads(store.get(prefix+'/science/RESULT.json'));projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));entry=projection[science['build_root']];build=entry['archive_prefix']
      assert SHA(store.get(build+'/BUILD.json'))==entry['actual_BUILD_sha256']
      batch=json.loads(store.get('current/RESULT.json'));items=[x for x in batch['contexts'] if x['case']['name']==name]
      assert len(items)==1 and items[0]['science'] is not None
     x=case_audit(store,prefix,build,provider,case,producer,opt,control,refusals,trial_flux=case['bottom']==8);result.append(dict(platform=platform,original_archive_sha256=store.record['sha256'],**x))
     print('INDEPENDENT_ACTUAL_FROST_BOUNDARY_CALENDAR_CONTEXT_PASS',platform,opt,name,flush=True)
  reopened=[]
  from explicit_bottom9_archive_science import ReadView
  from frost_boundary_archive_science import case_audit as parent_audit
  from frost_boundary_convergence import require_convergence
  from frost_boundary_terminal_trial import receipt_source,head_source
  from time_event_closure import source as original_event_source
  for platform in ('WINDOWS','UBUNTU'):
   for opt in ('O0','O2'):
    store=get(f'FROST_BOUNDARY_STATE_CALENDAR04_{platform}_{opt}_ORIGINAL_V5')
    for kind in ('water','cde'):
     name=kind+'-bottom8-implicit0-hys2-initial2';case=dict(name=name,kind=kind,bottom=8,implicit=0,hysteresis=2,initial=2,days=35)
     x=parent_audit(store,name,case);assert x['actual_compiler_source']==producers[5]
     profile=ReadView(store,'current/'+name+'/science');x['convergence']=require_convergence(profile)
     record=json.loads((profile/'RESULT.json').read_text());projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));build=ReadView(store,projection[record['build_root']]['archive_prefix'])
     assert (build/'timecontrol.f90').read_bytes().replace(b'\r\n',b'\n')==original_event_source(store.get('original-provider-build/swap-selected/timecontrol.f90'))
     # The old dense route retains its actual interval receipt, not a day-frame substitution.
     from frost_calendar_terminal_water import PARENT
     assert (build/'terminal_water_receipt.f90').read_text(encoding='cp1252')==receipt_source(PARENT.read_text(encoding='cp1252'))
     reopened.append(dict(platform=platform,original_archive_sha256=store.record['sha256'],**x))
     print('INDEPENDENT_REOPENED_PARENT_CONVERGENCE_NATIVE_COLD_CONTROLS_PASS',platform,opt,name,flush=True)
  # The original implicit year failure is a real numerical block, not a PASS.
  blocked=contract['known_numerically_blocked_cases'];assert len(blocked)==1;failures=[]
  for platform in ('WINDOWS','UBUNTU'):
   for opt in ('O0','O2'):
    store=get(f'FROST_BOUNDARY_STATE_CALENDAR04_{platform}_{opt}_ORIGINAL_V3');prefix='current/'+blocked[0]['name']+'/science/trajectory/'
    data=[json.loads(t) for t in store.get(prefix+'daily.jsonl').splitlines()];assert len(data)==4 and all(x['committed'] for x in data)
    assert b'Implicit original retry reached clock resolution' in store.get(prefix+'original/donor.stderr')
    failures.append(dict(platform=platform,optimization=opt,source=producers[3],accepted_days=4,next_day=5,error='Implicit original retry reached clock resolution',classification='NUMERICAL_FAILURE_NOT_ADMITTED'))
 assert len(result)==len({(x['platform'],x['optimization'],x['case']['name']) for x in result})==44
 out=dict(status='INDEPENDENT_ACTUAL44_ORIGINAL_BUDGETS_NATIVE_COLD_TRANSACTIONS_AND_FAILED_IMPLICIT_YEAR_RAW_AUDIT_PASS_NOT_ADMITTED',contexts=44,full35_contexts=sum(x['case']['days']==35 for x in result),year12_contexts=sum(x['case']['days']==12 for x in result),primary_days=sum(x['case']['days'] for x in result),native_samples=sum(x['native_samples'] for x in result),exact_cold_windows=sum(x['exact_cold_windows'] for x in result),actual_compiled_refusals=sum(x.get('controls',{}).get('actual_compiled_refusals',0) for x in result),transaction_contexts=sum(len(x.get('controls',{}).get('transactions',[])) for x in result),reopened_parent_contexts=reopened,reopened_parent_primary_days=sum(x['science']['days'] for x in reopened),reopened_parent_context_count=len(reopened),actual_contexts=result,actual_producer_source_and_provider_custody=provenance,known_numerical_failures=failures,canonical_admission=False,compiler_executions=0,model_executions=0,whole_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
 assert len(reopened)==8 and out['reopened_parent_primary_days']==280
 assert (out['full35_contexts'],out['year12_contexts'],out['primary_days'],out['native_samples'],out['exact_cold_windows'],out['transaction_contexts'])==(36,8,1356,268,116,72)
 return out
if __name__=='__main__':
 p=argparse.ArgumentParser();g=p.add_mutually_exclusive_group(required=True);g.add_argument('--proof',type=Path);g.add_argument('--source-ref');p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists()
 if a.source_ref:
  from frost_boundary_git_archive import GitArchiveSource
  proof=GitArchiveSource(R,a.source_ref)
 else:proof=a.proof
 q=audit(proof);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['actual_compiled_refusals'],flush=True)

