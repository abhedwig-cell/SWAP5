"""Retain actual Cauchy proof, current default controls and failed probes."""
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
for name in ['cauchy','current','corruption','output']:p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--failed',type=Path,action='append',default=[])
p.add_argument('--inputs',type=Path)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--source-head',required=True);a=p.parse_args()
phases={'cauchy':a.cauchy,'current':a.current,'corruption':a.corruption,
        **{f'failed-{i}':path for i,path in enumerate(a.failed)}}
if a.inputs is not None:phases['recovery-inputs']=a.inputs
files={};sources={}
with tempfile.TemporaryDirectory(prefix='s5-cauchy-source-pack-') as tmp:
    for prefix,folder in phases.items():
        for path in folder.rglob('*'):
            if path.is_file():files[prefix+'/'+path.relative_to(folder).as_posix()]=path
        report=json.loads((folder/'RESULT.json').read_text());digests=report.get('sources',report.get('source_sha256',{}))
        ref=report.get('source_commit',a.source_head);sources[prefix]={}
        for name,digest in digests.items():
            raw=subprocess.check_output(['git','cat-file','blob',ref+':'+name],cwd=ROOT);lf=raw.replace(b'\r\n',b'\n')
            data=next(b for b in [raw,lf,lf.replace(b'\n',b'\r\n')] if hashlib.sha256(b).hexdigest()==digest)
            saved=Path(tmp)/(prefix+'-'+Path(name).name);saved.write_bytes(data)
            member='source/'+prefix+'/'+name;files[member]=saved;sources[prefix][name]=member
    sources['current'].update(sources['corruption'])
    index={'platform':a.platform,'source_head':a.source_head,'sources':sources,
        'base_sha256':{'windows':'678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1',
        'linux':'feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'}[a.platform],
        'scope':'Actual external original Cauchy20to22 plus unchanged three-project original-forcing/default owner controls; no full coupled run.'}
    hashes={n:hashlib.sha256(path.read_bytes()).hexdigest() for n,path in files.items()}
    with tarfile.open(a.output,'x:xz',preset=1) as t:
        for name,path in sorted(files.items()):t.add(path,arcname=name,recursive=False)
        for name,value in [('PROOF_INDEX.json',index),('MEMBER_SHA256.json',hashes)]:
            data=(json.dumps(value,indent=2)+'\n').encode();info=tarfile.TarInfo(name);info.size=len(data);t.addfile(info,io.BytesIO(data))
print(json.dumps({'archive':str(a.output),'bytes':a.output.stat().st_size,'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'raw_files':len(files)}))
