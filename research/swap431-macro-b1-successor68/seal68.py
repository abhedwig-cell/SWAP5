"""Lossless bounded evidence, exact compiler bytes and changed closure only."""
from pathlib import Path
import hashlib,json,zipfile
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-follow67'
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e');D=ROOT/'successor68-data/evidence/data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
files=[('data/'+p.relative_to(D).as_posix(),p) for p in sorted(D.rglob('*')) if p.is_file()]
for p in R.glob('*.f90'):files.append(('sources/'+p.name,p))
delta={}
for opt in ['O0','O2']:
    out=ROOT/('successor68-'+opt);old=json.loads((R/(opt+'_RESTORED.json')).read_text())['objects'];changes=[]
    for p in sorted((out/'obj').iterdir()):
        if p.is_file() and sha(p)!=old.get(p.name):
            changes.append(dict(path=p.name,before=old.get(p.name),after=sha(p)));files.append(('build_delta/'+opt+'/obj/'+p.name,p))
    assert {x['path'] for x in changes}=={'jac63.o','potential68.o'}
    delta[opt]=changes
    ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert sha(out/'successor68.exe')==ident['exe_sha256']
    for n,h in ident['sources'].items():assert sha(R/n)==h
    files.append(('executables/'+opt+'/successor68.exe',out/'successor68.exe'))
(R/'BUILD_DELTA.json').write_text(json.dumps(delta,indent=2)+'\n')
archive=R/'SUCCESSOR68_RAW.zip';assert not archive.exists();manifest=[];seen=set()
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,p in files:
        raw=p.read_bytes();h=hashlib.sha256(raw).hexdigest();manifest.append(dict(path=name,bytes=len(raw),sha256=h))
        if h not in seen:z.writestr('blobs/'+h,raw);seen.add(h)
    z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
    for x in manifest:
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and hashlib.sha256(raw).hexdigest()==x['sha256']
q=dict(file=archive.name,sha256=sha(archive),bytes=archive.stat().st_size,logical_files=len(manifest),unique_blobs=len(seen),every_member_verified=True,layout='manifest.json maps paths to blobs/sha256; exact raw seven cases, inputs, transactional snapshots, probe results, compiler source bytes, actual executables and build delta',parent=dict(ref='3d4b0d378da190682fd9e30c3e9cf555104acec2',evidence=json.loads((P/'EVIDENCE.json').read_text())),models_launched=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps({k:v for k,v in q.items() if k!='parent'}))
