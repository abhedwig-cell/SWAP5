"""One six-case original Snow5/8 dependency batch, retaining real producer IDs."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
from snow58_analytical_source import ROOT,complete_inverse,git
from analytical_hydraulic_archives import SHA


def norm(path):return str(path).replace(chr(92),'/').rstrip('/')


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','proof','build-root'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-map',type=Path);p.add_argument('--reference-component',type=Path);p.add_argument('--use-original-local-short-builds',action='store_true');a=p.parse_args()
 complete_inverse();head=git('rev-parse','HEAD').decode().strip();a.proof.mkdir(parents=True,exist_ok=True);a.build_root.mkdir(parents=True,exist_ok=True);assert not (a.proof/'BATCH.json').exists()
 reuse=json.loads(a.reuse_map.read_text()) if a.reuse_map else {};folder=ROOT/'integration/f-ci/nomacro-complete01';name='SNOW58_ANALYTICAL_INPUTS_V1';record=json.loads((folder/(name+'.json')).read_text());raw=(folder/(name+'.zip')).read_bytes();assert len(raw)==record['bytes'] and SHA(raw)==record['sha256'] and len(record['cases'])==6
 for suffix in ('.json','.zip'):(a.proof/(name+suffix)).write_bytes((folder/(name+suffix)).read_bytes())
 with zipfile.ZipFile(folder/(name+'.zip')) as z:
  assert len(z.namelist())==len(set(z.namelist()))==len(record['members']) and set(z.namelist())==set(record['members'])
  for member,item in record['members'].items():
   value=z.read(member);assert len(value)==item['bytes'] and SHA(value)==item['sha256'];path=a.proof/'inputs'/member;assert path.resolve().is_relative_to((a.proof/'inputs').resolve());path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(value)
 q=dict(status='RUNNING',source=head,optimization=a.optimization,input_archive_sha256=record['sha256'],contexts=[],canonical_admission=False,completed_full35_periods_replayed=0);start=time.perf_counter();component=a.reference_component
 def save():(a.proof/'BATCH.json').write_text(json.dumps(q,indent=2)+'\n')
 def run(command,label):
  assert git('rev-parse','HEAD').decode().strip()==head
  with (a.proof/(label+'.stdout')).open('xb') as out,(a.proof/(label+'.stderr')).open('xb') as err:r=subprocess.run([sys.executable,'-B',*map(str,command)],cwd=ROOT,stdout=out,stderr=err,timeout=1200)
  assert r.returncode==0,dict(label=label,returncode=r.returncode)
 save()
 try:
  for case in record['cases']:
   label=case['case']+'-'+a.optimization;q['active']=label;save();roles=[role for role,path in record['roles'].items() if norm(path)==norm(case['input_root'])];assert len(roles)==1;role=roles[0];inputs=a.proof/'inputs'/role
   expected={name[len(role)+1:]:item['sha256'] for name,item in record['members'].items() if name.startswith(role+'/')};assert len(expected)==10
   if label in reuse:
    profile=Path(reuse[label]['profile']);prior=json.loads((profile/'RESULT.json').read_text());assert prior['days']==35 and prior['status']=='ACTUAL_SNOW58_ANALYTICAL_PHYSICAL_NATIVE_COLD_PREFLIGHT_PASS_NOT_ADMITTED' and prior['optimization']==a.optimization and prior['layer_models']==[case['model']]*2 and prior['kind']==case['kind'];assert dict(prior['input_inventory'])==expected and not git('diff',prior['source'],head,'--','app','src','tools','reference');reused=True
   else:
    profile=a.proof/label;reused=False;short=case.get('reuse_short_profiles',{}).get(a.optimization) if a.use_original_local_short_builds else None
    if short:
     old=json.loads((Path(short)/'RESULT.json').read_text());inputs=Path(old['input_root']);assert {p.name:SHA(p.read_bytes()) for p in inputs.iterdir() if p.is_file()}==expected;extra=['--reuse-profile',short]
    else:extra=['--build-root',a.build_root/label]
    run(['tests/nomacro_drainage/snow58_analytical_period.py','--input',inputs,'--reference-work',a.reference_work,'--output',profile,'--optimization',a.optimization,*extra],label+'-runtime')
   prior=json.loads((profile/'RESULT.json').read_text());assert dict(prior['input_inventory'])==expected
   if case.get('requires_actual_lysimeter_outflow'):assert any(value>0 for value in prior['actual_bottom_outward_cm']),'Selected lysimeter never drained'
   post=a.proof/(label+'-opposite-initialization');run(['tests/nomacro_drainage/snow58_analytical_postimage.py','--profile',profile,'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-opposite-initialization'),'--output',post],label+'-postimage')
   samples=a.proof/(label+'-original-samples');extra=['--reuse-component',component] if component else ['--build-root',a.build_root/'original-saturated-component'];run(['tests/nomacro_drainage/snow58_analytical_reference_samples.py','--profile',profile,'--reference-work',a.reference_work,'--output',samples,*extra],label+'-original-samples')
   if component is None:component=samples
   science=a.proof/(label+'-INDEPENDENT.json');run(['tests/nomacro_drainage/snow58_analytical_science.py','--profile',profile,'--reference-samples',samples,'--output',science],label+'-independent')
   native=a.proof/(label+'-model-native');run(['tests/nomacro_drainage/snow58_analytical_native_controls.py','--profile',profile,'--output',native],label+'-model-native')
   root=None;transactions=None;vapor=None
   if case['case'] in ('bottom5-model7-water-dry-initial1','bottom8-model11-cde-wet-initial2'):
    root=a.proof/(label+'-root-native');run(['tests/nomacro_drainage/explicit_bottom9_snow_history_native_controls.py','--profile',profile,'--reference-work',a.reference_work,'--output',root],label+'-root-native')
    transactions=a.proof/(label+'-transactions');run(['tests/nomacro_drainage/explicit_bottom9_snow_history_transactions.py','--profile',profile,'--reference-work',a.reference_work,'--output',transactions],label+'-transactions')
   if case['model']==11:
    vapor=a.proof/(label+'-vapor-refusal');run(['tests/nomacro_drainage/snow58_analytical_vapor_refusal.py','--profile',profile,'--output',vapor],label+'-vapor-refusal')
   independent=json.loads(science.read_text());q['contexts'].append(dict(case=case['case'],model=case['model'],bottom=case['bottom'],kind=case['kind'],initial=case['initial'],optimization=a.optimization,actual_input_archive_role=role,profile=str(profile),actual_compiler_producer=prior['source'],actual_period_observer=prior['observer_source'],completed_period_reused=reused,independent=str(science),independent_sha256=SHA(science.read_bytes()),current_opposite_initialization_postimage=str(post),original_samples=str(samples),model_native_controls=str(native),root_native_controls=str(root) if root else None,transactions=str(transactions) if transactions else None,foreign_active_vapor_refusal=str(vapor) if vapor else None,status=independent['status']));save();print('ACTUAL_SNOW58_CONTEXT_ALL_GATES_PASS',label,flush=True)
  complete_inverse();assert len(q['contexts'])==6;q.update(status='ALL6_SNOW58_CONTEXTS_INDEPENDENT_LEDGER_NATIVE_COLD_CURRENT_COMPILED_AND_ORIGINAL_SAMPLES_PASS_NOT_ADMITTED',seconds=time.perf_counter()-start);q.pop('active',None)
 except Exception as error:q.update(status='FAILED_SNOW58_BATCH_NOT_QUALIFIED',error=repr(error));raise
 finally:q['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
 assert q['actual_completion_head']==head;print(q['status'],a.optimization,q['seconds'],flush=True)


if __name__=='__main__':main()
