"""Seal fresh demand-selector science and explicit compiler-recovery failure."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];DEST=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--workspace',required=True,type=Path);a=p.parse_args();W=a.workspace.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for label,name in [('direct','nut-demand-direct-02'),('hist','nut-demand-hist'),('joint','nut-demand-joint-01')]:
 for f in sorted((W/name).rglob('*')):
  if not f.is_file():continue
  n=label+'/'+str(f.relative_to(W/name))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[n]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size);continue
  files[n]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
files['prior-hist-result.json']=(W/'nut-demand-prior/nut-current/hist/result.json').read_bytes()
files['prior-joint-result.json']=(W/'nut-demand-prior/nut-current/joint/result.json').read_bytes()
for f in (W/'nut-demand-direct-01').iterdir():
 if f.is_file()and f.suffix in ['.json','.stdout','.stderr']:files['failed/compiler-recovery/'+f.name]=f.read_bytes()
files['failed/compiler-recovery/runner.log']=(W/'nut-demand-direct-01.log').read_bytes()
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((DEST/'STATUS.json').read_text());r['evidence']=dict(path=str((DEST/'EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files),excluded='Objects, modules and executables are hashed, not embedded. All raw run/build receipts and native restart bytes retained.')
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
r['scientific_delta']={v.split('\t')[1]:v.split('\t')[0]for v in subprocess.check_output(['git','diff','--name-status',r['baseline'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
prior=json.loads((ROOT/'integration/mc-sol01/boesten/STATUS.json').read_text())['postimages']
r['incumbent_inputs']={p:h for p,h in prior.items()if p not in r['scientific_delta']}
paths=set(r['scientific_delta'])|{str((DEST/'CONTRACT.md').relative_to(ROOT)),str(Path(__file__).resolve().relative_to(ROOT)),'docs/science/MC_NUT01_UNUSED_DEMAND_CANDIDATE_20261023.md'}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',implemented=True,tested=True,qualified=True,canonically_admitted=False,results=dict(direct_cases_per_optimization=288,newly_accepted=144,incumbent_cases_byte_exact=144,default_byte_exact=True,fresh_HIST_compiles=654,fresh_HIST_processes=78,fresh_HIST_process_restarts=56,actual_coupled_runs=6,days_per_run=8,separate_process_restarts=12,previous_composition_rejection_probes=2),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),qualification_scope='Exhausted unused demand candidates only. Selected supply must remain strictly nondepleted. Original36 Boesten assertions preserved with one narrowly historical NUT source-identity read; current sources have separate fresh direct/HIST/crop/restart proof.')
(DEST/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
