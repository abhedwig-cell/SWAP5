"""Retain actual external coupling proof and its measured pre-reuse control."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
for arg in ['current','corruption','previous','output']:
    p.add_argument('--'+arg,type=Path,required=True)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--source-head',required=True)
a=p.parse_args();files={};sources={}
for folder,prefix in [(a.current,'current'),(a.corruption,'corruption'),(a.previous,'before')]:
    for path in folder.rglob('*'):
        if path.is_file():files[prefix+'/'+path.relative_to(folder).as_posix()]=path
stage_owner=tempfile.TemporaryDirectory(prefix='s5-coupling-pack-'+a.platform+'-')
stage=Path(stage_owner.name)
for prefix,ref in [('current',a.source_head),('before','88116fdc9c237570f3f218a430ac868bf348dc27')]:
    report=json.loads((a.current if prefix=='current' else a.previous).joinpath('RESULT.json').read_text())
    digests=report['source_sha256'].copy()
    if prefix=='current':digests.update(json.loads((a.corruption/'RESULT.json').read_text())['source_sha256'])
    sources[prefix]={}
    for name,digest in digests.items():
        blob=subprocess.check_output(['git','cat-file','blob',ref+':'+name],cwd=ROOT)
        lf=blob.replace(b'\r\n',b'\n')
        raw=next(data for data in [blob,lf,lf.replace(b'\n',b'\r\n')]
                 if hashlib.sha256(data).hexdigest()==digest)
        path=stage/(prefix+'-'+Path(name).name);path.write_bytes(raw)
        member='source/'+prefix+'/'+name;files[member]=path;sources[prefix][name]=member
base_hash={'windows':'678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1',
           'linux':'feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'}[a.platform]
index={'platform':a.platform,'source_head':a.source_head,'sources':sources,
       'base_archive':'hybrid-hupsel-'+a.platform+'-20261111.tar.xz','base_sha256':base_hash,
       'base_canonical':'30026511e8d03f6c77bc30377d60a65259afb2fc',
       'scope':'External serial original-forcing prepare/accept/discard; no physical owner change or full application repeat.'}
hashes={n:hashlib.sha256(p.read_bytes()).hexdigest() for n,p in files.items()}
assert not a.output.exists()
with tarfile.open(a.output,'x:xz',preset=3) as archive:
    for name,path in sorted(files.items()):archive.add(path,arcname=name,recursive=False)
    for name,value in [('MEMBER_SHA256.json',hashes),('PROOF_INDEX.json',index)]:
        raw=(json.dumps(value,indent=2)+'\n').encode();info=tarfile.TarInfo(name);info.size=len(raw)
        archive.addfile(info,io.BytesIO(raw))
print(json.dumps({'archive':str(a.output),'bytes':a.output.stat().st_size,
                  'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'raw_files':len(files)}))
