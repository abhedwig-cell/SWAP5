"""Lossless raw evidence, exact source bytes and binary delta; no model calls."""
from pathlib import Path
import json,hashlib,zipfile
R=Path(__file__).resolve().parent;P=R.parent/'swap431-macro-b1-cause66'
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e');D=ROOT/'follow67-data/evidence/data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
files=[('data/'+p.relative_to(D).as_posix(),p) for p in sorted(D.rglob('*')) if p.is_file()]
for p in sorted(R.glob('*.f90')):files.append(('sources/'+p.name,p))
delta={}
for opt in ['O0','O2']:
    out=ROOT/('follow67-'+opt);old=json.loads((R/(opt+'_RESTORED.json')).read_text())['objects'];changes=[]
    for p in sorted((out/'obj').iterdir()):
        if p.is_file() and sha(p)!=old.get(p.name):
            changes.append(dict(path=p.name,before=old.get(p.name),after=sha(p)));files.append(('build_delta/'+opt+'/obj/'+p.name,p))
    assert {x['path'] for x in changes}=={'headcalc.o','swap.o','soilwater.o','swap_exchange.mod','mod_soilwater.mod'}
    delta[opt]=changes
    ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());assert sha(out/'follow67.exe')==ident['exe_sha256']
    for n,h in ident['sources'].items():assert sha(R/n)==h
    files.append(('executables/'+opt+'/follow67.exe',out/'follow67.exe'))
(R/'BUILD_DELTA.json').write_text(json.dumps(delta,indent=2)+'\n')
# Assert inherited physics, Jacobian eligibility and serialization objects unchanged.
for opt in ['O0','O2']:
    old=json.loads((R/(opt+'_RESTORED.json')).read_text())['objects'];obj=ROOT/('follow67-'+opt)/'obj'
    for n in ['jac63.o','macrorate.o','macropore.o','native09.o','timecontrol.o','boundbottom.o','integral.o']:
        assert sha(obj/n)==old[n]
archive=R/'FOLLOW67_RAW.zip';assert not archive.exists();manifest=[];seen=set()
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,p in files:
        raw=p.read_bytes();h=hashlib.sha256(raw).hexdigest();manifest.append(dict(path=name,bytes=len(raw),sha256=h))
        if h not in seen:z.writestr('blobs/'+h,raw);seen.add(h)
    z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
    for x in manifest:
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and hashlib.sha256(raw).hexdigest()==x['sha256']
q=dict(file=archive.name,sha256=sha(archive),bytes=archive.stat().st_size,logical_files=len(manifest),unique_blobs=len(seen),all_members_verified=True,layout='manifest.json maps paths to unique blobs/sha256; exact source bytes, actual executables, build delta and all raw cases retained',parent_cause66=dict(ref='96f1a1f7b4325d4933f32235bbd724767dad808f',evidence=json.loads((P/'EVIDENCE.json').read_text())),unchanged_closure_inherited=True,models_launched=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
