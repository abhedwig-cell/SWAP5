"""One coherent original analytical Snow water/CDE dependency-surface batch."""
import argparse,json,subprocess,sys,time,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from explicit_bottom9_snow_analytical_source import ROOT,complete_inverse,git


def main():
 p=argparse.ArgumentParser()
 for key in ('reference-work','proof','build-root'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--reuse-map',type=Path);p.add_argument('--reference-component',type=Path);a=p.parse_args()
 complete_inverse();a.proof.mkdir(parents=True,exist_ok=True);a.build_root.mkdir(parents=True,exist_ok=True)
 head=git('rev-parse','HEAD').decode().strip();reuse=json.loads(a.reuse_map.read_text()) if a.reuse_map else {}
 name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_INPUTS_V1';folder=ROOT/'integration/f-ci/nomacro-complete01';raw=(folder/(name+'.zip')).read_bytes();record=json.loads((folder/(name+'.json')).read_text())
 assert len(raw)==record['bytes'] and SHA(raw)==record['sha256'] and len(record['members'])==120
 for suffix in ('.zip','.json'):(a.proof/(name+suffix)).write_bytes((folder/(name+suffix)).read_bytes())
 with zipfile.ZipFile(folder/(name+'.zip')) as z:
  assert len(z.namelist())==len(set(z.namelist()))==120 and set(z.namelist())==set(record['members'])
  for member,item in record['members'].items():
   value=z.read(member);assert len(value)==item['bytes'] and SHA(value)==item['sha256'];path=a.proof/'inputs'/member
   assert path.resolve().is_relative_to((a.proof/'inputs').resolve());path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(value)
 q=dict(status='RUNNING',source=head,optimization=a.optimization,input_archive_sha256=record['sha256'],contexts=[],canonical_admission=False,completed_model_periods_replayed=0);start=time.monotonic();component=a.reference_component
 def save():(a.proof/'BATCH.json').write_text(json.dumps(q,indent=2)+'\n')
 def run(command,label):
  assert git('rev-parse','HEAD').decode().strip()==head
  with (a.proof/(label+'.stdout')).open('xb') as out,(a.proof/(label+'.stderr')).open('xb') as err:done=subprocess.run([sys.executable,'-B',*map(str,command)],cwd=ROOT,stdout=out,stderr=err,timeout=1200)
  assert done.returncode==0,dict(label=label,returncode=done.returncode)
 save()
 try:
  for model in (3,7,11):
   for kind in ('water','cde'):
    case='model'+str(model)+'-'+kind;label=case+'-'+a.optimization;inputs=a.proof/'inputs'/(case+'-initial1');counter=a.proof/'inputs'/(case+'-initial2');q['active']=label;save()
    if label in reuse:
     profile=Path(reuse[label]['profile']);prior=json.loads((profile/'RESULT.json').read_text());assert prior['days']==35 and prior['status'].endswith('PASS_NOT_ADMITTED')
     assert dict(prior['input_inventory'])=={path.name:SHA(path.read_bytes()) for path in inputs.iterdir() if path.is_file()};reused=True
    else:
     profile=a.proof/label;reused=False
     run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_preflight.py','--input',inputs,'--reference-work',a.reference_work,'--build-root',a.build_root/label,'--output',profile,'--optimization',a.optimization,'--days','35'],label+'-runtime')
    science=a.proof/(label+'-INDEPENDENT.json')
    post=a.proof/(label+'-initial2')
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_postimage.py','--profile',profile,'--input',counter,'--reference-work',a.reference_work,'--build-root',a.build_root/(label+'-initial2'),'--output',post],label+'-postimage')
    sampled=a.proof/(label+'-original-samples');extra=['--reuse-component',component] if component else ['--build-root',a.build_root/'original-sampled-component']
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_reference_samples.py','--profile',profile,'--reference-work',a.reference_work,'--output',sampled,*extra],label+'-original-samples')
    if component is None:component=sampled
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_science.py','--profile',profile,'--output',science,'--reference-samples',sampled],label+'-reader')
    native=a.proof/(label+'-model-native')
    run(['tests/nomacro_drainage/explicit_bottom9_snow_analytical_native_controls.py','--profile',profile,'--output',native],label+'-model-native')
    root_controls=None;transactions=None
    if (model,kind) in ((3,'water'),(7,'cde')):
     root_controls=a.proof/(label+'-root-native')
     run(['tests/nomacro_drainage/explicit_bottom9_snow_history_native_controls.py','--profile',profile,'--reference-work',a.reference_work,'--output',root_controls],label+'-root-native')
    if model==7:
     transactions=a.proof/(label+'-transactions')
     run(['tests/nomacro_drainage/explicit_bottom9_snow_history_transactions.py','--profile',profile,'--reference-work',a.reference_work,'--output',transactions],label+'-transactions')
    prior=json.loads((profile/'RESULT.json').read_text());independent=json.loads(science.read_text())
    q['contexts'].append(dict(model=model,kind=kind,optimization=a.optimization,profile=str(profile),producer=prior['source'],completed_period_reused=reused,independent=str(science),independent_sha256=SHA(science.read_bytes()),current_complete_initial2_postimage=str(post),original_samples=str(sampled),model_native_controls=str(native),root_native_controls=str(root_controls) if root_controls else None,transactions=str(transactions) if transactions else None,status=independent['status']));save();print('ACTUAL_ANALYTICAL_SNOW_CONTEXT_PASS',label,flush=True)
  complete_inverse();assert len(q['contexts'])==6
  q.update(status='ALL6_ANALYTICAL_SNOW_CONTEXTS_INDEPENDENT_NATIVE_COLD_CURRENT_COMPILED_AND_ORIGINAL_SAMPLES_PASS_NOT_ADMITTED',seconds=time.monotonic()-start);q.pop('active',None)
 except Exception as error:q.update(status='FAILED_ANALYTICAL_SNOW_BATCH_NOT_QUALIFIED',error=repr(error));raise
 finally:q['actual_completion_head']=git('rev-parse','HEAD').decode().strip();save()
 assert q['actual_completion_head']==head;print(q['status'],a.optimization,q['seconds'],flush=True)


if __name__=='__main__':main()
