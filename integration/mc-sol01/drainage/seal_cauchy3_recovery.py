"""Seal fresh reconstructed-source qualification; historical evidence is immutable."""
import base64,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;HERE=Path(__file__).resolve().parent
BASE='d04a8c3cca1ac9246e66dc913ba588472a5fb78c'
sha=lambda b:hashlib.sha256(b).hexdigest()
f={}
def folder(label,path):
 for p in sorted(path.rglob('*')):
  if not p.is_file()or p.is_symlink()or'__pycache__'in p.parts:continue
  b=p.read_bytes()
  if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):continue
  f[label+'/'+str(p.relative_to(path))]=b
for opt in ['O0','O2']:
 folder('native-'+opt,W/('fresh-native-O0'if opt=='O0'else'fresh-native2-O2'))
 folder('build-'+opt,W/('fresh-build-'+opt))
 folder('contracts-'+opt,W/('fresh-contract2-'+opt))
 folder('oldflux-'+opt,W/('fresh-oldflux-'+opt))
folder('cpu',W/'fresh-cpu')
owner=json.loads((W/'canonical-peer-owner.json').read_text());controls=json.loads((W/'canonical-peer-controls.json').read_text())
assert owner['qualified'] and len(controls)==46
f['canonical-peer.json']=json.dumps(dict(canonical=BASE,owner=owner,controls=controls,scope='Retained exact canonical NUT/FCT evidence; no fresh NUT/FCT physical execution claimed'),indent=2).encode()
f['canonical-commit.raw']=subprocess.check_output(['git','cat-file','commit',BASE],cwd=ROOT)
f['oldflux-preservation.json']=(W/'fresh-oldflux.json').read_bytes()
f['MANIFEST.json']=json.dumps({p:sha(b)for p,b in f.items()},sort_keys=True).encode()
stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(f.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mtime=0;info.mode=0o644;t.addfile(info,io.BytesIO(b))
b=stream.getvalue();path=HERE/'CAUCHY3_RECOVERY_EVIDENCE.tar.xz.b64';path.write_bytes(base64.b64encode(b))
SCIENCE=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
delta={l.split('\t')[1]:l.split('\t')[0]for l in subprocess.check_output(['git','diff','--name-status',BASE,'HEAD','--',*SCIENCE],cwd=ROOT,text=True).splitlines()}

paths=set(delta)|{'integration/mc-sol01/drainage/seal_cauchy3_recovery.py','integration/mc-sol01/drainage/CAUCHY3_CONTRACT.md'}
r=dict(baseline=BASE,implemented=True,persisted=True,tested=True,qualified=False,canonically_admitted=False,scientific_delta=delta,
 postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},
 fresh_evidence=dict(path=str(path.relative_to(ROOT)),sha256=sha(b),bytes=len(b),members=len(f)),
 historical_receipt='integration/mc-sol01/drainage/CAUCHY3_QUALIFICATION.json',
 test_source_recovery='Four files reconstructed, not recovered byte for byte; all fresh current assertions executed',
 launcher_original_hash_exact=True,production_build_inputs_original_hashes_exact=True,
 current_physical_execution='Fresh O0/O2 BBC481, split365/resume, Robin/Picard and typed contracts, flux481 and wet97 rejection',
 canonical_peer='46 controls and original NUT/FCT validators executed at exact canonical base; dated retained proof, not fresh current NUT/FCT model execution',
 next_action='Current owning/source/raw controls, original FSI35, docs and exact actual merge identity before admission',
 selected=['fresh checked O0/O2 BBC481 and restart365','real Picard/typed Robin contracts','old flux481 exact bytes','unchanged retained Cauchy output bytes','current source/raw controls','original FSI35'],
 not_selected=['highest low-air','RossFast expansion','new1e-6','full moving FCI','unchanged NUT/FCT process rebuild'])
(HERE/'CAUCHY3_RECOVERY_QUALIFICATION.json').write_text(json.dumps(r,indent=2)+'\n');print(r['fresh_evidence'])
