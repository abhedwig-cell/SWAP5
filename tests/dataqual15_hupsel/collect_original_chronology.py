"""Collect explicit actual-run artifacts, without regenerating any measured output."""
import argparse,json,tarfile,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def compiled_sources(root,target,record_path):
 record=json.loads((root/record_path).read_text())
 for i,(name,digest) in enumerate(record['source_sha256'].items()):
  raw=Path(name).read_bytes();assert hashlib.sha256(raw).hexdigest()==digest
  f=target/'compiled-source'/(str(i)+'.f90');f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(raw)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--collection',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 config=json.loads(a.collection.read_text());out=a.output.resolve();out.mkdir()
 for label,item in config['roots'].items():
  assert '/' not in label and '\\' not in label and label not in ('.','..')
  root=Path(item['root']).resolve();selected=set()
  for pattern in item['patterns']:selected.update(x for x in root.glob(pattern) if x.is_file())
  assert selected,label
  for f in sorted(selected):
   target=out/label/f.relative_to(root);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(f.read_bytes())
  if 'compiled_sources' in item:compiled_sources(root,out/label,item['compiled_sources'])
 parent=ROOT/'integration/dataqual15_hupsel';manifest=json.loads((parent/'SPRINT03_SCIENCE_MANIFEST.json').read_text());archive=parent/manifest['archive']
 assert hashlib.sha256(archive.read_bytes()).hexdigest()==manifest['archive_sha256']
 with tarfile.open(archive) as t:
  for cap in ('0.000625','0.0003125'):
   name='original/dtmax-'+cap+'/result_output.csv';raw=t.extractfile(name).read()
   assert hashlib.sha256(raw).hexdigest()==manifest['members'][name]
   f=out/'reference-archive'/('dtmax-'+cap)/'result_output.csv';f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(raw)
 (out/'COLLECTION.json').write_text(json.dumps(config,indent=2)+'\n')
 (out/'COLLECTED.json').write_text(json.dumps(dict(collection_sha256=hashlib.sha256((out/'COLLECTION.json').read_bytes()).hexdigest(),complete=True),indent=2)+'\n')
