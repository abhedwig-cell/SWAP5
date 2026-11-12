"""Pack only the new Cauchy changed-history proof; inherit unchanged preservation."""
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
for n in ['runs','output']:p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--platform',choices=['windows','linux'],required=True)
p.add_argument('--controlled-instances',action='store_true');a=p.parse_args()
r=json.loads((a.runs/'RESULT.json').read_text());files={path.relative_to(a.runs).as_posix():path for path in a.runs.rglob('*') if path.is_file()}
with tempfile.TemporaryDirectory(prefix='s5-cauchy-history-source-') as tmp:
    sources={}
    for name,digest in r['sources'].items():
        raw=subprocess.check_output(['git','cat-file','blob',r['source_commit']+':'+name],cwd=ROOT);lf=raw.replace(b'\r\n',b'\n')
        data=next(x for x in [raw,lf,lf.replace(b'\n',b'\r\n')] if hashlib.sha256(x).hexdigest()==digest)
        path=Path(tmp)/Path(name).name;path.write_bytes(data);member='source/'+name;files[member]=path;sources[name]=member
    index={'platform':a.platform,'source_commit':r['source_commit'],'sources':sources,
        'base_archive':'hybrid-hupsel-'+a.platform+'-20261111.tar.xz',
        'base_sha256':{'windows':'678be090346a13ffd3b68f2a3447a947f86e52b8854fdc46f9fef798ab8b21c1','linux':'feaec2daeada9b5f01f0391352a7b15910f406c4a0034123e65c58418cd67bde'}[a.platform],
        'prior_archive':'irrigation-'+a.platform+'-20261112.tar.xz',
        'prior_sha256':{'windows':'90080f1ec5b582fe62e1c7891cc9694facc5fb9463d9fde51a270a39ff5d6fbe','linux':'9ddbbefcec649fef7f3c016fe3be65e7d17bd3b2199d5598828ef8bfe21537f4'}[a.platform],
        'scope':'Actual changed-state Cauchy day20to22, both-day native retry/original control and second-day cold recovery. Unchanged three-project and controlled-boundary preservation inherited from PR1648 at exact unchanged model dependency graph.'}
    if a.controlled_instances:
        index['prior_cauchy_history_archive']='cauchy-history-'+a.platform+'-20261112.tar.xz'
        index['prior_cauchy_history_sha256']={'windows':'25fb937504d8481bf35bae2107f426c32823be26f3d7597b4a75a7a59b54b271','linux':'cca335421f59b6ada4b602db41c88051b55f4af7b4db05cf90f785b8baaa1bc3'}[a.platform]
        index['scope']='Interleaved independent controlled Cauchy/GWL/irrigation accepted and pending state, discarded proposals and cold reconstruction, exact against reused qualified single-instance physical/native controls. No shared physics/model change or full run.'
    hashes={name:hashlib.sha256(path.read_bytes()).hexdigest() for name,path in files.items()}
    with tarfile.open(a.output,'x:xz',preset=1) as t:
        for name,path in sorted(files.items()):t.add(path,arcname=name,recursive=False)
        for name,value in [('PROOF_INDEX.json',index),('MEMBER_SHA256.json',hashes)]:
            data=(json.dumps(value,indent=2)+'\n').encode();info=tarfile.TarInfo(name);info.size=len(data);t.addfile(info,io.BytesIO(data))
print(json.dumps({'archive':str(a.output),'bytes':a.output.stat().st_size,'sha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'raw_files':len(files)}))
