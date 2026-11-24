"""Restore untouched first143 bytes at their actual original Linux paths."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'integration/f-ci/nomacro-complete01'
p=argparse.ArgumentParser()
for key in ('proof','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();name='SNOW58_ANALYTICAL_FIRST143_UBUNTU_'+a.optimization+'_ORIGINAL_V1';manifest=json.loads((P/(name+'.json')).read_text());archive=P/(name+'.zip');raw=archive.read_bytes();assert len(raw)==manifest['bytes'] and SHA(raw)==manifest['sha256'];old='1438907b876f91605b0c41af24c73377bab7c7e3';assert manifest['actual_source']==old
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip();assert not subprocess.check_output(['git','diff',old,head,'--','app','src','tools','reference'],cwd=ROOT)
label='bottom5-model7-water-dry-initial1-'+a.optimization;observed={}
with zipfile.ZipFile(archive) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(manifest['members'])
 q=json.loads(z.read(label+'/RESULT.json'));post=json.loads(z.read(label+'-opposite-initialization/RESULT.json'));component=json.loads(z.read(label+'-original-samples/COMPONENT.json'));projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'))
 assert q['source']==q['observer_source']==q['actual_completion_head']==old and q['days']==35 and q['status'].endswith('PASS_NOT_ADMITTED')
 assert Path(q['input_root'])==a.proof/'inputs/prepared/bottom5-model7-water-initial1' and Path(q['build_root'])==a.build_root/label/'bundle'
 assert Path(post['build_root'])==a.build_root/(label+'-opposite-initialization')/'bundle' and Path(component['build_root'])==a.build_root/'original-saturated-component'
 for build,entry in projection.items():assert SHA(z.read(entry['archive_prefix']+'/BUILD.json'))==entry['actual_BUILD_sha256']
 prefixes=(label+'/',label+'-opposite-initialization/',label+'-original-samples/','inputs/prepared/bottom5-model7-water-initial1/')
 for member,item in manifest['members'].items():
  if member.startswith(prefixes):target=a.proof/member
  elif member.startswith('compiled/builds/'):target=a.build_root/member[len('compiled/builds/'):]
  else:continue
  value=z.read(member);assert len(value)==item['bytes'] and SHA(value)==item['sha256'];target=target.resolve();assert target.is_relative_to(a.proof.resolve()) or target.is_relative_to(a.build_root.resolve());assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value);assert SHA(target.read_bytes())==item['sha256']
  if target.name in ('day_donor','day_kernel','actual-sampled-hydraulic') or target.suffix=='.so':target.chmod(target.stat().st_mode|0o111)
  observed[str(target)]=dict(original_member=member,sha256=item['sha256'])
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==head
a.output.write_text(json.dumps({label:dict(profile=str(a.proof/label),postimage=str(a.proof/(label+'-opposite-initialization')))},indent=2)+'\n')
a.output.with_suffix('.custody.json').write_text(json.dumps(dict(status='GENUINE_FIRST143_PROFILE_INPUTS_AND_COMPLETE_BUILD_BYTES_AT_ACTUAL_ORIGINAL_PATHS_NO_IDENTITY_REWRITE',original_source=old,original_archive_sha256=manifest['sha256'],observed_files=observed,before_HEAD=head,after_HEAD=head,compiler_executions=0,model_executions=0,old_BUILD_checkpoint_binding_or_producer_rewritten=False),indent=2)+'\n');print('GENUINE_FIRST143_ORIGINAL_COMPLETE_PERIOD_REUSED',a.optimization,len(observed))
