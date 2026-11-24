"""Rehydrate genuine original scientific bytes without changing producer identity."""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2];P=ROOT/'integration/f-ci/nomacro-complete01'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
p=argparse.ArgumentParser()
for key in ('proof','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
name='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_FIRST4D_UBUNTU_'+a.optimization+'_ORIGINAL_V1'
manifest=json.loads((P/(name+'.json')).read_text());archive=P/(name+'.zip')
assert SHA(archive.read_bytes())==manifest['sha256'] and archive.stat().st_size==manifest['bytes']
assert manifest['actual_source']=='4d284a5e543d29555bd1c5497a12b3a4b5408a13'
label='model3-water-'+a.optimization;profile=a.proof/label;build=a.build_root/label/'bundle';before=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip();observed={}
with zipfile.ZipFile(archive) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(manifest['members'])
 q=json.loads(z.read(label+'/RESULT.json'));projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
 assert q['source']==q['actual_completion_head']==manifest['actual_source'] and q['days']==35 and q['status'].endswith('PASS_NOT_ADMITTED')
 assert Path(q['build_root'])==build and Path(q['input_root'])==a.proof/'inputs/model3-water-initial1','Original scientific paths differ from these real Linux runner paths; no identity relocation inferred'
 entry=projection[q['build_root']];prefix=entry['archive_prefix']+'/'
 assert SHA(z.read(prefix+'BUILD.json'))==entry['actual_BUILD_sha256']==q['actual_BUILD_sha256']
 for member,item in manifest['members'].items():
  if member.startswith(label+'/'):target=a.proof/member
  elif member.startswith(prefix):target=build/member[len(prefix):]
  else:continue
  raw=z.read(member);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
  target=target.resolve();assert target.is_relative_to(profile.resolve()) or target.is_relative_to(build.resolve());assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
  assert SHA(target.read_bytes())==item['sha256'];observed[str(target)]=dict(original_member=member,sha256=item['sha256'])
  if target.name in ('day_donor','day_kernel') or target.suffix=='.so':target.chmod(target.stat().st_mode|0o111)
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==before
a.output.write_text(json.dumps({label:dict(profile=str(profile))},indent=2)+'\n')
a.output.with_suffix('.custody.json').write_text(json.dumps(dict(status='GENUINE_FIRST4D_UBUNTU_MODEL3_PERIOD_AND_ALL_COMPILED_BYTES_REHYDRATED_NO_MODEL_OR_IDENTITY_REWRITE',actual_source=q['source'],archive=archive.name,archive_sha256=manifest['sha256'],observed_files=observed,before_HEAD=before,after_HEAD=before,compiler_executions=0,model_executions=0,identities_rewritten=False),indent=2)+'\n')
print('GENUINE_ACTUAL_FIRST4D_PERIOD_REUSED',label,len(observed))
