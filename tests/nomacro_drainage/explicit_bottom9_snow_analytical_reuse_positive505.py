"""Materialize exact original Linux source505 data and compiled files, unmodified."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'integration/f-ci/nomacro-complete01'
p=argparse.ArgumentParser()
for key in ('proof','build-root'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_UBUNTU_'+a.optimization+'_ORIGINAL_V2';manifest=json.loads((P/(name+'.json')).read_text());archive=P/(name+'.zip')
assert archive.stat().st_size==manifest['bytes'] and SHA(archive.read_bytes())==manifest['sha256'] and manifest['actual_source']=='505954d2943b3f7f478efbb617c53f53dc5f5126'
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip();a.proof.mkdir(parents=True,exist_ok=True);copied={}
with zipfile.ZipFile(archive) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(manifest['members']);batch=json.loads(z.read('BATCH.json'));assert batch['source']==batch['actual_completion_head']==manifest['actual_source'] and len(batch['contexts'])==6 and batch['status'].startswith('ALL6_')
 projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'));rules=[]
 for item in batch['contexts']:
  label='model'+str(item['model'])+'-'+item['kind']+'-'+a.optimization;profile=a.proof/label
  assert Path(item['profile'])==profile
  original=json.loads(z.read(label+'/RESULT.json'));build=Path(original['build_root']);assert build==a.build_root/label/'bundle' and Path(original['input_root'])==a.proof/'inputs'/('model'+str(item['model'])+'-'+item['kind']+'-initial1')
  entry=projection[str(build)];assert SHA(z.read(entry['archive_prefix']+'/BUILD.json'))==entry['actual_BUILD_sha256']==original['actual_BUILD_sha256']
  rules.extend([(label+'/',profile),(entry['archive_prefix']+'/',build)])
 rules.append(('inputs/',a.proof/'inputs'))
 for member,item in manifest['members'].items():
  matches=[(prefix,root) for prefix,root in rules if member.startswith(prefix)]
  if not matches:continue
  assert len(matches)==1;prefix,root=matches[0];target=(root/member[len(prefix):]).resolve();assert target.is_relative_to(root.resolve()) and not target.exists();raw=z.read(member);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  if target.name in ('day_donor','day_kernel') or target.suffix=='.so':target.chmod(target.stat().st_mode|0o111)
  assert SHA(target.read_bytes())==item['sha256'];copied[str(target)]=dict(original_member=member,sha256=item['sha256'])
 (a.proof/'BATCH.json').write_bytes(z.read('BATCH.json'))
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==head
(a.proof/'ACTUAL505_REHYDRATION_CUSTODY.json').write_text(json.dumps(dict(status='ORIGINAL_SOURCE505_FULL_PERIOD_AND_COMPILED_BYTES_MATERIALIZED_NO_IDENTITIES_CHANGED',archive=archive.name,archive_sha256=manifest['sha256'],files=copied,before_HEAD=head,after_HEAD=head,compiler_executions=0,model_executions=0,bindings_rewritten=False),indent=2)+'\n')
print('ACTUAL_ORIGINAL505_SCIENCE_REUSED_NO_MODEL_REPLAY',a.optimization,len(copied))
