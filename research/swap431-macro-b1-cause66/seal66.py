"""Preserve unique raw data and new binary deltas; inherit the sealed base once."""
from pathlib import Path
import hashlib,json,zipfile,subprocess,io,gzip
R=Path(__file__).resolve().parent
ROOT=Path('C:/Users/Veldh012/SWAP5-work/01a1f3ce-667e-7091-82ae-a62485d14eca-8c08570e')
D=ROOT/'cause66-data/evidence/data'
def sha(p):
    with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
files=[('data/'+p.relative_to(D).as_posix(),p) for p in sorted(D.rglob('*')) if p.is_file()]
delta={};module_audit=[]
inherited=subprocess.check_output(['git','show','95a61203:research/swap431-macro-b1-reject64/REJECT64_EVIDENCE.zip'],cwd=R)
assert hashlib.sha256(inherited).hexdigest()=='f8931da9a481e3f29b0918282bb761ca9a4701c762f92a2c6cfd50243dccafb3'
for opt in ['O0','O2']:
    out=ROOT/('cause66-'+opt);initial=json.loads((R/(opt+'_RESTORED.json')).read_text())['object_hashes'];changed=[]
    for p in sorted((out/'obj').iterdir()):
        if not p.is_file():continue
        if p.name not in initial or sha(p)!=initial[p.name]:
            files.append(('build_delta/'+opt+'/obj/'+p.name,p));changed.append(dict(path=p.name,before=initial.get(p.name),after=sha(p)))
    assert {x['path'] for x in changed}=={'headcalc.o','swap.o','swap_exchange.mod'}
    with zipfile.ZipFile(io.BytesIO(inherited)) as z:
        before=gzip.decompress(z.read('native/'+opt+'/obj/swap_exchange.mod')).split(b'\n',1)
    after=gzip.decompress((out/'obj/swap_exchange.mod').read_bytes()).split(b'\n',1)
    assert before[1]==after[1]
    module_audit.append(dict(opt=opt,module='swap_exchange.mod',only_source_filename_header_changed=True,before_header=before[0].decode(),after_header=after[0].decode(),declarations_sha256=hashlib.sha256(after[1]).hexdigest()))
    for stage in ['OBS','REPAIR']:
        p=out/(stage+'.exe');identity=json.loads((R/(opt+'_'+stage+'_IDENTITY.json')).read_text());assert sha(p)==identity['exe_sha256']
        files.append(('executables/'+opt+'/'+p.name,p))
    for p in sorted((out/'source_check').iterdir()):
        if p.is_file():files.append(('source_check/'+opt+'/'+p.name,p))
    delta[opt]=changed
(R/'BUILD_DELTA.json').write_text(json.dumps(delta,indent=2)+'\n')
(R/'MODULE_INTERFACE_VERIFICATION.json').write_text(json.dumps(module_audit,indent=2)+'\n')
archive=R/'CAUSE66_RAW.zip';assert not archive.exists();manifest=[];seen=set()
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for name,p in files:
        raw=p.read_bytes();h=hashlib.sha256(raw).hexdigest();manifest.append(dict(path=name,bytes=len(raw),sha256=h))
        if h not in seen:z.writestr('blobs/'+h,raw);seen.add(h)
    z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
    for x in manifest:
        raw=z.read('blobs/'+x['sha256']);assert len(raw)==x['bytes'] and hashlib.sha256(raw).hexdigest()==x['sha256']
q=dict(file=archive.name,sha256=sha(archive),bytes=archive.stat().st_size,logical_files=len(manifest),unique_blobs=len(seen),all_members_verified=True,layout='manifest.json maps full relative paths to blobs/sha256; lossless; raw input/output/counterfactual and actual binaries retained',inherited_closure=dict(ref='95a61203d345ccbf2c8f5851c37a0bb138a00835',path='research/swap431-macro-b1-reject64/REJECT64_EVIDENCE.zip',sha256='f8931da9a481e3f29b0918282bb761ca9a4701c762f92a2c6cfd50243dccafb3'),inherited_baseline=dict(ref='3db3836f3ad887605a265be25acbf4ceebfd4dc9',path='research/swap431-macro-b1-coupled65/EVIDENCE.json'),models_launched_by_sealer=0)
(R/'EVIDENCE.json').write_text(json.dumps(q,indent=2)+'\n');print(json.dumps(q))
