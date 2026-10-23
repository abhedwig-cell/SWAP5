"""Seal zero-rate ODE, current composition and the obsolete rejection fixture."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];DEST=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--workspace',required=True,type=Path);a=p.parse_args();W=a.workspace.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for label,name in [('direct','nut-single-direct-03'),('hist','nut-single-hist-04'),('joint','nut-single-joint-01')]:
 for f in sorted((W/name).rglob('*')):
  if not f.is_file():continue
  n=label+'/'+str(f.relative_to(W/name))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[n]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size);continue
  files[n]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/zero_pool_rates/EVIDENCE.tar.xz.b64').read_bytes())),mode='r:xz')as t:
 for label in ['hist','joint']:files['prior-'+label+'-result.json']=t.extractfile(label+'/result.json').read()
for f in sorted((W/'nut-single-direct-01').rglob('*')):
 if f.is_file()and f.suffix in ['.json','.stdout','.stderr','.f90']:files['failed/optimization-order/'+str(f.relative_to(W/'nut-single-direct-01'))]=f.read_bytes()
files['failed/optimization-order/runner.log']=(W/'nut-single-direct-01.log').read_bytes()
files['failed/predecessor-source-guard.log']=(W/'nut-single-predecessor-attempt.log').read_bytes()
for f in sorted((W/'nut-single-hist').rglob('*')):
 if f.is_file()and f.suffix in ['.json','.stdout','.stderr','.f90','.inc']:files['failed/negative-fixture/'+str(f.relative_to(W/'nut-single-hist'))]=f.read_bytes()
files['failed/negative-fixture/runner.log']=(W/'nut-single-hist.log').read_bytes()
files['failed/negative-fixture/driver.f90']=subprocess.check_output(['git','show','4689d335:tests/nut-crop/test_b112_retained_joint.f90'],cwd=ROOT)
files['failed/literal-recovery.log']=(W/'nut-single-hist-02.log').read_bytes()
files['failed/source-mutation/runner.log']=(W/'nut-single-hist-03.log').read_bytes()
files['failed/source-mutation/events.json']=(W/'nut-single-hist-03/events.json').read_bytes()
for f in sorted((W/'nut-single-hist-03').rglob('*')):
 if not f.is_file():continue
 with f.open('rb')as h:magic=h.read(4)
 name='failed/source-mutation/'+str(f.relative_to(W/'nut-single-hist-03'))
 if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[name]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size)
 else:files[name]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
files['toolchain/gfortran-wrapper']=(W/'compiler/bin/gfortran').read_bytes()
files['toolchain/packages.json']=(json.dumps({f.name:sha(f.read_bytes())for f in (W/'compiler/packages').glob('*.deb')},indent=2)+'\n').encode()
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((DEST/'STATUS.json').read_text());r['evidence']=dict(path=str((DEST/'EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files),excluded='Objects, modules and executables are hashed, not embedded. All raw run/build receipts and native restart bytes retained.')
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
r['scientific_delta']={v.split('\t')[1]:v.split('\t')[0]for v in subprocess.check_output(['git','diff','--name-status',r['source_base'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
parent=json.loads((ROOT/'integration/mc-nut01/zero_pool_rates/STATUS.json').read_text());prior={**parent['incumbent_inputs'],**parent['postimages']}
prior.update(json.loads((ROOT/'integration/mc-sol01/drainage/STATUS.json').read_text())['postimages'])
r['incumbent_inputs']={p:sha((ROOT/p).read_bytes())for p in prior if p not in r['scientific_delta']}
paths=set(r['scientific_delta'])|{str((DEST/'CONTRACT.md').relative_to(ROOT)),str(Path(__file__).resolve().relative_to(ROOT)),'docs/science/MC_NUT01_SINGLE_ZERO_POOL_20261023.md'}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',implemented=True,tested=True,qualified=True,canonically_admitted=False,results=dict(direct_cases_per_optimization=466,formerly_rejected=466,incumbent_cases_byte_exact=192,helper_inputs_per_optimization=13,fresh_HIST_compiles=74,reused_HIST_compiles=580,fresh_HIST_processes=78,fresh_HIST_process_restarts=56,actual_coupled_runs=14,days_per_run=8,separate_process_restarts=28,previous_composition_rejection_probes=4),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),qualification_scope='Exactly one stationary receiving pool. Original36 drainage plus75 zero-pool controls preserved; three explicit archived NUT source identities. Current direct/HIST/crop/restart proof separate. Selected mineral exhaustion remains unsupported.')
(DEST/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
