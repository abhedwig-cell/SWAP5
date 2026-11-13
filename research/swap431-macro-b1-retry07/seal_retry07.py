"""Seal current evidence and replacement native closure; does not launch models."""
from pathlib import Path
import hashlib,json,subprocess,zipfile
R=Path(__file__).resolve().parent
WORK=Path('C:/Users/Veldh012/swap431-retry07-work')
ORIG=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected')
sha=lambda b:hashlib.sha256(b).hexdigest()
checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
members={}
for p in R.rglob('*'):
    if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json' and '__pycache__' not in p.parts:
        members['research/'+p.relative_to(R).as_posix()]=p.read_bytes()
for opt in ['O0','O2']:
    identity=json.loads((R/(opt+'_IDENTITY.json')).read_text())
    exe=WORK/'native'/opt/'retry07.exe'
    assert sha(exe.read_bytes())==identity['exe_sha256']
    for name in ['retry07.exe','obj/soilwater.o','obj/swap.o','obj/mod_soilwater.mod']:
        members['native/'+opt+'/'+name]=(WORK/'native'/opt/name).read_bytes()
sources=json.loads((R/'NATIVE_IO_SOURCES.json').read_text())
for name,meta in sources.items():
    b=(ORIG/name).read_bytes();assert sha(b)==meta['sha256'];members['original-io/'+name]=b
manifest=[dict(path=name,bytes=len(b),sha256=sha(b)) for name,b in sorted(members.items())]
arc=R/'RETRY07_EVIDENCE.zip'
with zipfile.ZipFile(arc,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for name,b in sorted(members.items()):z.writestr(name,b)
    z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(arc) as z:
    assert set(z.namelist())=={x['path'] for x in manifest}|{'manifest.json'}
    for x in manifest:
        b=z.read(x['path']);assert len(b)==x['bytes'] and sha(b)==x['sha256']
meta=dict(file=arc.name,bytes=arc.stat().st_size,sha256=sha(arc.read_bytes()),members_verified=len(manifest),checkpoint=checkpoint,
    inherited_closures={name:json.loads((R.parent/name/'EVIDENCE.json').read_text())['sha256'] for name in [
        'swap431-macro-b1-state02','swap431-macro-b1-stagnation05','swap431-macro-b1-contract06']},
    contents='All seven final routes, two preserved setup failures, actual own binary/text checkpoints, native replacement objects/executables, harness sources, assessment, reports and original native I/O sources.',
    models_launched_by_seal=0)
(R/'EVIDENCE.json').write_text(json.dumps(meta,indent=2)+'\n')
print(json.dumps(meta,indent=2))
