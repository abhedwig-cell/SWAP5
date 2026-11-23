"""Verify every owned compiled byte against committed central raw before release."""
import argparse,hashlib,io,json,zipfile
from pathlib import Path
from explicit_bottom9_combined_postimages import ROOT,SHA,git
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'

def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();proof=ROOT/'integration/f-ci/nomacro-complete01';q=json.loads((proof/'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_RAW_V1.json').read_text());parts=[];blobs={}
 for item in q['parts']:
  raw=(proof/item['file']).read_bytes();assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];path='integration/f-ci/nomacro-complete01/'+item['file'];digest=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest();assert git('rev-parse','HEAD:'+path).decode().strip()==digest;blobs[path]=digest;parts.append(raw)
 raw=b''.join(parts);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
 with zipfile.ZipFile(io.BytesIO(raw)) as z:projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'));assert len(projection)==56
 independent=json.loads((a.evidence/'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_CENTRAL_INDEPENDENT_V1.json').read_text());assert independent['raw_sha256']==q['sha256'] and len(independent['contexts'])==56 and independent['archive_members_extracted']==0
 state=json.loads((Path.home()/'.codex/storage/swap5/state.json').read_text());work=a.evidence.parent.resolve();roots={Path(path).parent.parent for path in projection};assert len(roots)==4;resources=[]
 def owner(root):
  assert root.is_absolute() and root.resolve()==root and root.is_relative_to(work) and not root.is_symlink() and not root.is_junction()
  matches=[(k,v) for k,v in state['resources'].items() if v['task']==TASK and Path(v['path'])==root and v['status']!='deleted'];assert len(matches)==1;return matches[0]
 for root in sorted(roots):
  key,registered=owner(root);assert registered['kind']=='build';files=[]
  for path in sorted(root.rglob('*')):
   assert not path.is_symlink() and not path.is_junction()
   if not path.is_file():continue
   candidates=[(Path(actual),item) for actual,item in projection.items() if path.is_relative_to(Path(actual))];assert len(candidates)==1;build,item=candidates[0];name=item['archive_prefix']+'/'+path.relative_to(build).as_posix();expected=q['members'][name];raw=path.read_bytes();assert len(raw)==expected['bytes'] and SHA(raw)==expected['sha256'];files.append(dict(path=path.relative_to(root).as_posix(),archive_member=name,bytes=len(raw),sha256=expected['sha256']))
  resources.append(dict(resource=key,path=str(root),kind='build',registered_source_ref=registered['source_ref'],recipe=registered['recipe'],files=files,bytes=sum(f['bytes'] for f in files)))
 stage=a.staging.resolve();key,registered=owner(stage);assert registered['kind']=='temp';archive=stage/q['archive'];assert len(list(stage.iterdir()))==1 and archive.stat().st_size==q['bytes'] and SHA(archive.read_bytes())==q['sha256'];resources.append(dict(resource=key,path=str(stage),kind='temp',bytes=q['bytes'],archive_sha256=q['sha256']))
 result=dict(status='ALL56_COMPILED_CLOSURES_IN_FOUR_OWNED_BUILD_RESOURCES_PLUS_STAGE_EXACT_COMMITTED_CENTRAL_BYTE_CUSTODY_VERIFIED',task=TASK,actual_custody_source=git('rev-parse','HEAD').decode().strip(),raw_sha256=q['sha256'],actual_central_Git_part_blobs=blobs,resources=resources,resource_count=5,total_registered_bytes=sum(r['bytes'] for r in resources),unique_scientific_evidence_retained_in_central_archive=True,compiler_executions=0,model_executions=0,resource_release_or_deletion_performed=False)
 with a.output.open('x') as f:json.dump(result,f,indent=2)
 print(result['status'],result['resource_count'],result['total_registered_bytes'])

if __name__=='__main__':main()
