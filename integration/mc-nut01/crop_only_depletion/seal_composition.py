"""Seal fresh shared-water HIST/crop execution without replacing historical receipts."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile,runpy
ROOT=Path(__file__).resolve().parents[3];DEST=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args();W=a.workspace.resolve()
n=runpy.run_path(str(ROOT/'integration/audits/verify_nut_crop_depletion_composed.py'))
sha=n['sha'];own=n['OWN'];peer=n['PEER']
def before(ref,p):return subprocess.check_output(['git','show',ref+':'+p],cwd=ROOT)
status=json.loads(before(own,'integration/mc-nut01/crop_only_depletion/STATUS.json'))
raw=base64.b64decode(before(own,status['evidence']['path']),validate=True);assert sha(raw)==status['evidence']['sha256']
files=n['unpack'](raw);excluded=json.loads(files['excluded-build-artifacts.json'])
files['frozen/own/joint-result.json']=files['joint/result.json']
for label in ['hist','joint']:
 for key in list(files):
  if key.startswith(label+'/'):del files[key]
 for key in list(excluded):
  if key.startswith(label+'/'):del excluded[key]
 folder=W/('nut-crop-depletion-composed-'+label)
 for f in sorted(folder.rglob('*')):
  if not f.is_file():continue
  key=label+'/'+str(f.relative_to(folder))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[key]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size)
  else:files[key]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
files['frozen/own/commit.raw']=subprocess.check_output(['git','cat-file','commit',own],cwd=ROOT)
for path in [n['CROP'],'integration/mc-nut01/crop_only_depletion/STATUS.json']:
 files['frozen/own/source/'+path]=before(own,path)
 for i in range(len(Path(path).parts)):
  directory='/'.join(Path(path).parts[:i]);spec=own+(':'+directory if directory else '^{tree}')
  tree=subprocess.check_output(['git','rev-parse',spec],cwd=ROOT,text=True).strip()
  files['frozen/own/trees/'+tree]=subprocess.check_output(['git','cat-file','tree',tree],cwd=ROOT)
for name,source in [('controls','nut-crop-depletion-pre-controls.json'),('verify','nut-crop-depletion-pre-owner.json')]:files['frozen/own/'+name+'.json']=(W/source).read_bytes()
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode();out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'COMPOSITION.tar.xz.b64').write_bytes(base64.b64encode(raw))
delta={s.split('\t')[1]:s.split('\t')[0]for s in subprocess.check_output(['git','diff','--name-status',peer,'HEAD','--',*n['SCIENCE']],cwd=ROOT,text=True).splitlines()}
peerrecord=json.loads(before(peer,'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'))['live_composition']
paths=set(peerrecord['postimages'])|set(status['incumbent_inputs'])|set(status['postimages'])|set(delta)
paths|={'integration/audits/verify_nut_crop_depletion_composed.py','integration/mc-nut01/crop_only_depletion/seal_composition.py','integration/mc-nut01/crop_only_depletion/COMPOSITION_CONTRACT.md'}
r=dict(own=own,peer=peer,status='CURRENT_COMPOSITION_EVIDENCE_SEALED_PENDING_GATES',canonically_admitted=False,full_mc_nut01_closed=False,
 scientific_delta=delta,postimages={p:sha((ROOT/p).read_bytes())for p in sorted(paths)},
 evidence=dict(path='integration/mc-nut01/crop_only_depletion/COMPOSITION.tar.xz.b64',sha256=sha(raw),bytes=len(raw),members=len(files)),
 results=dict(fresh_hist_compiles=208,reused_hist_compiles=446,fresh_hist_processes=78,hist_restarts=56,coupled_runs=30,coupled_restarts=60),
 selection='COMPOSITION_CONTRACT.md; original HIST/crop assertions, exact unchanged direct inputs; no full FCI/highest low-air/RossFast selection',
 historical_own_qualification=own,current_physics='Original current HIST and all30 actual crop profiles. Default endpoint/ledger results exact pre-composition; competing constant sinks and full NUT remain open.')
(DEST/'COMPOSITION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
