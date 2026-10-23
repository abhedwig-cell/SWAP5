"""Seal zero-rate ODE, current composition and the obsolete rejection fixture."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];DEST=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--workspace',required=True,type=Path);a=p.parse_args();W=a.workspace.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for label,name in [('direct','nut-zero-direct-02'),('hist','nut-zero-hist-02'),('joint','nut-zero-joint-01')]:
 for f in sorted((W/name).rglob('*')):
  if not f.is_file():continue
  n=label+'/'+str(f.relative_to(W/name))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[n]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size);continue
  files[n]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
files['prior-hist-result.json']=(W/'nut-demand-hist/result.json').read_bytes()
files['prior-joint-result.json']=(W/'nut-demand-joint-01/result.json').read_bytes()
for f in sorted((W/'nut-zero-hist').rglob('*')):
 if f.is_file()and f.suffix in ['.json','.stdout','.stderr']:files['failed/obsolete-fixture/'+str(f.relative_to(W/'nut-zero-hist'))]=f.read_bytes()
files['failed/obsolete-fixture/runner.log']=(W/'nut-zero-hist.log').read_bytes()
files['failed/obsolete-fixture/original-driver.f90']=subprocess.check_output(['git','show','1796633cdf367f53fefa7df201d8541904577117:tests/nut-crop/test_b112_retained_joint.f90'],cwd=ROOT)
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((DEST/'STATUS.json').read_text());r['evidence']=dict(path=str((DEST/'EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files),excluded='Objects, modules and executables are hashed, not embedded. All raw run/build receipts and native restart bytes retained.')
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
r['scientific_delta']={v.split('\t')[1]:v.split('\t')[0]for v in subprocess.check_output(['git','diff','--name-status',r['source_base'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
parent=json.loads((ROOT/'integration/mc-nut01/demand_candidate/STATUS.json').read_text());prior={**parent['incumbent_inputs'],**parent['postimages']}
r['incumbent_inputs']={p:h for p,h in prior.items()if p not in r['scientific_delta']}
paths=set(r['scientific_delta'])|{str((DEST/'CONTRACT.md').relative_to(ROOT)),str(Path(__file__).resolve().relative_to(ROOT)),'docs/science/MC_NUT01_ZERO_POOL_RATES_20261023.md'}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',implemented=True,tested=True,qualified=True,canonically_admitted=False,results=dict(direct_cases_per_optimization=168,formerly_rejected=168,nonzero_cases_byte_exact=24,helper_inputs_per_optimization=13,fresh_HIST_compiles=48,reused_HIST_compiles=606,fresh_HIST_processes=78,fresh_HIST_process_restarts=56,actual_coupled_runs=10,days_per_run=8,separate_process_restarts=20,previous_composition_rejection_probes=2),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),qualification_scope='Exactly zero biomass and humus receiving-pool turnover. Original52 predecessor controls preserved with three explicit archived source identities; fresh current direct/HIST/crop/restart proof. Selected mineral exhaustion remains unsupported.')
(DEST/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
