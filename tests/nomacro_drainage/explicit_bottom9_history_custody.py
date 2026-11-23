"""Readonly byte closure of owned reproducible resources before shared cleanup."""
import argparse,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage')]
from analytical_hydraulic_archives import SHA
from explicit_bottom9_source_inverse import git

TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'


def main():
 p=argparse.ArgumentParser()
 for key in ('evidence','staging','output'):p.add_argument('--'+key,type=Path,required=True)
 a=p.parse_args();proof=ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((proof/'EXPLICIT_BOTTOM9_HISTORY_WINDOWS_RAW_V1.json').read_text());parts=[];git_parts={}
 for item in record['parts']:
  raw=(proof/item['file']).read_bytes();assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];path='integration/f-ci/nomacro-complete01/'+item['file'];digest=hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest();assert git('rev-parse','HEAD:'+path).decode().strip()==digest;git_parts[path]=digest;parts.append(raw)
 raw=b''.join(parts);assert len(raw)==record['bytes'] and SHA(raw)==record['sha256'];import io,zipfile
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  projection=json.loads(z.read('COMPILED_PROJECTION_V1.json'));diagnostic=json.loads(z.read('DIAGNOSTIC_COMPILED_PROJECTION_V1.json'));assert len(projection)==36 and len(diagnostic)==1
 independent=json.loads((a.evidence/'EXPLICIT_BOTTOM9_HISTORY_WINDOWS_CENTRAL_INDEPENDENT_V1.json').read_text());assert independent['raw_sha256']==record['sha256'] and len(independent['contexts'])==16 and independent['archive_members_extracted']==0
 state=json.loads((Path.home()/'.codex/storage/swap5/state.json').read_text());work=a.evidence.parent.resolve();resources=[]
 def registered(path):
  assert path.is_absolute() and path.resolve()==path and path.is_relative_to(work) and not path.is_symlink() and not path.is_junction()
  matches=[(key,value) for key,value in state['resources'].items() if value['task']==TASK and Path(value['path'])==path and value['status']!='deleted'];assert len(matches)==1
  return matches[0]
 def check(root,prefix):
  key,owner=registered(root);assert owner['kind'] in ('build','debug');files=[]
  for path in sorted(root.rglob('*')):
   assert not path.is_symlink() and not path.is_junction()
   if not path.is_file():continue
   relative=path.relative_to(root).as_posix();name=prefix+'/'+relative;assert name in record['members'],'Unpreserved resource file: '+str(path)
   raw=path.read_bytes();item=record['members'][name];assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'];files.append(dict(path=relative,archive_member=name,bytes=len(raw),sha256=item['sha256']))
  resources.append(dict(resource=key,path=str(root),kind=owner['kind'],source_ref=owner['source_ref'],recipe=owner['recipe'],files=files,bytes=sum(x['bytes'] for x in files)))
 for path,item in projection.items():
  actual=Path(path);assert actual.name=='bundle';check(actual.parent,item['archive_prefix'].removesuffix('/bundle'))
 for path,item in diagnostic.items():check(Path(path),item['archive_prefix'])
 assert len(resources)==37
 stage=a.staging.resolve();key,owner=registered(stage);assert owner['kind']=='temp';archive=stage/record['archive'];assert archive.is_file() and len(list(stage.iterdir()))==1 and archive.stat().st_size==record['bytes'] and SHA(archive.read_bytes())==record['sha256'];resources.append(dict(resource=key,path=str(stage),kind='temp',bytes=record['bytes'],archive_sha256=record['sha256']))
 result=dict(status='ALL37_OWNED_HISTORY9_COMPILED_AND_DIAGNOSTIC_RESOURCES_PLUS_ARCHIVE_STAGE_EXACT_CENTRAL_BYTE_CUSTODY_VERIFIED',task=TASK,actual_custody_source=git('rev-parse','HEAD').decode().strip(),raw_sha256=record['sha256'],actual_central_Git_part_blobs=git_parts,resources=resources,resource_count=38,total_registered_bytes=sum(r['bytes'] for r in resources),unique_scientific_evidence_retained_in_central_archive=True,compiler_executions=0,model_executions=0,resource_release_or_deletion_performed=False)
 with a.output.open('x') as f:json.dump(result,f,indent=2)
 print(result['status'],result['resource_count'],result['total_registered_bytes'],flush=True)


if __name__=='__main__':main()
