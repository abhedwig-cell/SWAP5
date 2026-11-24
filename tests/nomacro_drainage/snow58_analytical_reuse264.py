"""Restore actual complete264 model bytes to original paths for controls only."""
import argparse,json,subprocess,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2];P=ROOT/'integration/f-ci/nomacro-complete01'
p=argparse.ArgumentParser()
for key in ('proof','build-root','current-build-root','output'):p.add_argument('--'+key,type=Path,required=True)
p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();name='SNOW58_ANALYTICAL_UBUNTU_'+a.optimization+'_ORIGINAL264_V1';manifest=json.loads((P/(name+'.json')).read_text());archive=P/(name+'.zip');raw=archive.read_bytes();assert len(raw)==manifest['bytes'] and SHA(raw)==manifest['sha256'];old='26497facb174d26af47821171314df05263ff976';assert manifest['actual_source']==old and manifest['full35_scientific_contexts']==6
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip();assert not subprocess.check_output(['git','diff',old,head,'--','app','src','tools','reference'],cwd=ROOT);observed={}
with zipfile.ZipFile(archive) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(manifest['members'])
 for case in manifest['cases']:
  q=json.loads(z.read(case['profile_prefix']+'/RESULT.json'));assert Path(q['build_root']).is_relative_to(a.build_root) or Path(q['build_root']).is_relative_to(a.current_build_root);assert Path(q['input_root']).is_relative_to(a.proof)
 for member,item in manifest['members'].items():
  if member.startswith('current/') or member.startswith('bottom5-model7-water-dry-initial1-') or member.startswith('inputs/prepared/bottom5-model7-water-initial1/'):target=a.proof/member
  elif member.startswith('compiled/builds/'):target=a.build_root/member[len('compiled/builds/'):]
  elif member.startswith('compiled/current-builds/'):target=a.current_build_root/member[len('compiled/current-builds/'):]
  else:continue
  value=z.read(member);assert len(value)==item['bytes'] and SHA(value)==item['sha256'];target=target.resolve();assert any(target.is_relative_to(root.resolve()) for root in (a.proof,a.build_root,a.current_build_root));assert not target.exists();target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value);assert SHA(target.read_bytes())==item['sha256']
  if target.name in ('day_donor','day_kernel','actual-sampled-hydraulic') or target.suffix=='.so':target.chmod(target.stat().st_mode|0o111)
  observed[str(target)]=dict(original_member=member,sha256=item['sha256'])
assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT).decode().strip()==head
record=dict(status='GENUINE_ALL6_COMPLETED264_PERIODS_RESTORED_AT_ORIGINAL_PATHS_CONTROLS_ONLY',archive_sha256=manifest['sha256'],original_source=old,before_HEAD=head,after_HEAD=head,observed_files=observed,compiler_executions=0,model_executions=0,identities_rewritten=False)
a.output.write_text(json.dumps(record,indent=2)+'\n');print(record['status'],a.optimization,len(observed))
