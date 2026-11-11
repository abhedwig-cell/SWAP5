"""Retain actual observed original heat, preserving separate initial/remaining runs."""
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
p.add_argument('--runs',action='append',type=Path,required=True)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--source-head',required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();files={};cases={};digests={};patches={}
for i,folder in enumerate(a.runs):
    prefix=f'phase-{i}'
    for path in folder.rglob('*'):
        if not path.is_file():continue
        member=prefix+'/'+path.relative_to(folder).as_posix()
        if path.name=='bad-heat-face.txt':
            original=path.parent/'original/original-heat-accounting.txt'
            old=original.read_bytes().splitlines(keepends=True);bad=path.read_bytes().splitlines(keepends=True)
            assert len(old)==len(bad)
            changes=[{'line':i,'replacement_hex':right.hex()} for i,(left,right) in enumerate(zip(old,bad)) if left!=right]
            assert len(changes)==1
            reconstructed=old.copy()
            for change in changes:reconstructed[change['line']]=bytes.fromhex(change['replacement_hex'])
            assert hashlib.sha256(b''.join(reconstructed)).digest()==hashlib.sha256(path.read_bytes()).digest()
            patches[member+'.patch.json']={'source':prefix+'/'+original.relative_to(folder).as_posix(),
                'source_sha256':hashlib.sha256(original.read_bytes()).hexdigest(),
                'reconstructed_bad_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'changes':changes}
            del old,bad,reconstructed
        else:files[member]=path
    report=json.loads((folder/'RESULT.json').read_text())
    assert report['status']=='ORIGINAL_HEAT_OBSERVATION_PHYSICAL_PRESERVATION_PASS'
    receipt_file=folder/('THERMAL_CARRIERS.json' if (folder/'THERMAL_CARRIERS.json').exists() else 'HEAT_RECEIPTS.json')
    digests.update(report['sources']);digests.update(json.loads(receipt_file.read_text())['sources'])
    for case in report['cases']:
        key=case['project']+'-'+case['optimization'];assert key not in cases
        cases[key]={'directory':prefix+'/'+key,**case}
assert len(cases)==6
with tempfile.TemporaryDirectory(prefix='s5-heat-pack-sources-') as temp:
    sources={}
    for i,(name,value) in enumerate(patches.items()):
        path=Path(temp)/('negative-'+str(i)+'.json');path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8');files[name]=path
    for name,digest in digests.items():
        raw=subprocess.check_output(['git','cat-file','blob',a.source_head+':'+name],cwd=ROOT)
        lf=raw.replace(b'\r\n',b'\n')
        matching=next(b for b in [raw,lf,lf.replace(b'\n',b'\r\n')] if hashlib.sha256(b).hexdigest()==digest)
        path=Path(temp)/Path(name).name;path.write_bytes(matching)
        member='source/'+name;files[member]=path;sources[name]=member
    base={'windows':'678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1',
          'linux':'feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'}[a.platform]
    index={'platform':a.platform,'cases':cases,'sources':sources,'source_head':a.source_head,
           'base_archive_sha256':base,'base_canonical':'30026511e8d03f6c77bc30377d60a65259afb2fc',
           'scope':'Actual original numerical conduction/storage observation; original full physical energy remains unqualified.'}
    hashes={n:hashlib.sha256(path.read_bytes()).hexdigest() for n,path in files.items()}
    assert not a.output.exists()
    with tarfile.open(a.output,'x:xz',preset=3) as archive:
        for name,path in sorted(files.items()):archive.add(path,arcname=name,recursive=False)
        for name,value in [('MEMBER_SHA256.json',hashes),('PROOF_INDEX.json',index)]:
            data=(json.dumps(value,indent=2)+'\n').encode();info=tarfile.TarInfo(name);info.size=len(data)
            archive.addfile(info,io.BytesIO(data))
print(json.dumps({'archive':str(a.output),'bytes':a.output.stat().st_size,
                 'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'raw_files':len(files)}))
