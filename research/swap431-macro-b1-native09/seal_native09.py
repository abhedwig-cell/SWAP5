"""Seal all native own-restart evidence without launching models."""
from pathlib import Path
import hashlib,json,subprocess,zipfile
R=Path(__file__).resolve().parent;W=Path('C:/Users/Veldh012/swap431-native09-work')
S=Path('C:/Users/Veldh012/swap431-state02-work/audit/build/swap-selected')
C=Path('C:/Users/Veldh012/swap431-state02-work/phase/O2/V1/case')
sha=lambda b:hashlib.sha256(b).hexdigest()
members={}
for p in R.rglob('*'):
 if p.is_file() and p.suffix!='.zip' and p.name!='EVIDENCE.json' and '__pycache__' not in p.parts:
  members['research/'+p.relative_to(R).as_posix()]=p.read_bytes()
for opt in ['O0','O2']:
 ident=json.loads((R/(opt+'_IDENTITY.json')).read_text());exe=W/'native'/opt/'native09.exe'
 assert sha(exe.read_bytes())==ident['exe_sha256']
 for n in ['native09.exe','obj/mod_meteo.o','obj/macropore.o','obj/native09.o','obj/swapoutput.o','obj/soilwater.o','obj/swap.o',
           'obj/mod_meteo.mod','obj/mod_macropore.mod','obj/mod_native09.mod','obj/mod_soilwater.mod']:
  members['native/'+opt+'/'+n]=(W/'native'/opt/n).read_bytes()
for n in ['MOD_meteo.f90','macropore.f90','swapoutput.f90','swap.f90']:
 members['original-selected/'+n]=(S/n).read_bytes()
for x in json.loads((R/'CASE_IDENTITY.json').read_text()):
 b=(C/x['path']).read_bytes();assert sha(b)==x['sha256'];members['original-bounded-case/'+x['path']]=b
manifest=[dict(path=n,bytes=len(b),sha256=sha(b)) for n,b in sorted(members.items())]
arc=R/'NATIVE09_EVIDENCE.zip'
with zipfile.ZipFile(arc,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for n,b in sorted(members.items()):z.writestr(n,b)
 z.writestr('manifest.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(arc) as z:
 assert set(z.namelist())=={x['path'] for x in manifest}|{'manifest.json'}
 for x in manifest:
  b=z.read(x['path']);assert len(b)==x['bytes'] and sha(b)==x['sha256']
meta=dict(file=arc.name,bytes=arc.stat().st_size,sha256=sha(arc.read_bytes()),members_verified=len(manifest),
 checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
 inherited_closures={n:json.loads((R.parent/n/'EVIDENCE.json').read_text())['sha256'] for n in [
 'swap431-macro-b1-state02','swap431-macro-b1-stagnation05','swap431-macro-b1-contract06','swap431-macro-b1-retry07']},
 contents='Final eleven routes and three preserved implementation postimages/all15 preliminary routes, setup failures, own files, primitive assessments, complete changed native object/module closure, sources and bounded original input identity.',models_launched_by_seal=0)
(R/'EVIDENCE.json').write_text(json.dumps(meta,indent=2)+'\n');print(json.dumps(meta,indent=2))
