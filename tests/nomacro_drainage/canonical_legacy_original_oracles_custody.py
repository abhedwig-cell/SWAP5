"""Close registered legacy compiler resources against committed original raw."""
import argparse,hashlib,json
from pathlib import Path
from explicit_bottom9_source_inverse import ROOT,git
from analytical_hydraulic_archives import SHA
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'

def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();proof=ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((proof/'CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1.json').read_text());archive=proof/record['archive'];raw=archive.read_bytes();assert len(raw)==record['bytes'] and SHA(raw)==record['sha256'];path='integration/f-ci/nomacro-complete01/'+archive.name;digest=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest();assert git('rev-parse','HEAD:'+path).decode().strip()==digest
 independent=json.loads((a.evidence/'CANONICAL_LEGACY_ORIGINAL_ORACLES_CENTRAL_INDEPENDENT_V2.json').read_text());assert independent['raw_sha256']==record['sha256'] and len(independent['contexts'])==len(independent['exact_original_Ubuntu_workflows'])==2 and independent['actual_original_compilers']==106 and independent['actual_original_native_components']==12
 registry=json.loads((Path.home()/'.codex/storage/swap5/state.json').read_text());work=a.evidence.parent.resolve();resources=[]
 def owner(root):
  assert root.is_absolute() and root.resolve()==root and root.is_relative_to(work) and not root.is_symlink() and not root.is_junction()
  matches=[(k,v) for k,v in registry['resources'].items() if v['task']==TASK and Path(v['path'])==root and v['status']!='deleted'];assert len(matches)==1;return matches[0]
 for role in record['builds']:
  root=Path(role['path']);key,item=owner(root);assert item['kind']=='build';files=[]
  for path in sorted(root.rglob('*')):
   assert not path.is_symlink() and not path.is_junction()
   if not path.is_file():continue
   name=role['archive_prefix']+'/'+path.relative_to(root).as_posix();expected=record['members'][name];actual=path.read_bytes();assert len(actual)==expected['bytes'] and SHA(actual)==expected['sha256'];files.append(dict(path=path.relative_to(root).as_posix(),archive_member=name,bytes=len(actual),sha256=expected['sha256']))
  resources.append(dict(resource=key,path=str(root),kind='build',files=files,bytes=sum(f['bytes'] for f in files)))
 stage=a.staging.resolve();key,item=owner(stage);assert item['kind']=='temp';original=stage/record['archive'];assert len(list(stage.iterdir()))==1 and original.stat().st_size==record['bytes'] and SHA(original.read_bytes())==record['sha256'];resources.append(dict(resource=key,path=str(stage),kind='temp',bytes=record['bytes'],archive_sha256=record['sha256']))
 assert len(resources)==5;result=dict(status='ALL4_REGISTERED_LEGACY_COMPILED_CLOSURES_AND_STAGE_EXACT_COMMITTED_CENTRAL_RAW_CUSTODY_VERIFIED',task=TASK,actual_custody_source=git('rev-parse','HEAD').decode().strip(),raw_sha256=record['sha256'],actual_committed_archive_Git_blob=digest,resources=resources,resource_count=5,total_registered_bytes=sum(r['bytes'] for r in resources),resource_release_or_deletion_performed=False,compiler_executions=0,model_executions=0)
 with a.output.open('x') as f:json.dump(result,f,indent=2)
 print(result['status'],result['total_registered_bytes'])

if __name__=='__main__':main()
