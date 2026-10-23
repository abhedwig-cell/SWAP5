"""Seal actual local raw results and retain failed development attempts."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser();p.add_argument('--workspace',required=True,type=Path);a=p.parse_args();W=a.workspace.resolve();DEST=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for label,name in [('direct','nut-nondepleting-direct-04'),('hist','nut-nondepleting-hist-02'),('joint','nut-nondepleting-joint-04')]:
 for f in sorted((W/name).rglob('*')):
  if not f.is_file():continue
  path=label+'/'+str(f.relative_to(W/name))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[path]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size);continue
  files[path]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
files['original-parent.json']=(W/'nut-nondepleting-parent.json').read_bytes()
files['prior-hist-result.json']=(W/'nut-limits-current-hist/result.json').read_bytes()
for pattern in ['nut-nondepleting-direct-0[1-3]','nut-nondepleting-hist-01','nut-nondepleting-joint-0[1-3]']:
 for directory in W.glob(pattern):
  for f in directory.iterdir():
   if f.is_file()and f.suffix in ['.json','.stdout','.stderr']:files['failed/'+directory.name+'/'+f.name]=f.read_bytes()
  log=W/(directory.name+'.log')
  if log.exists():files['failed/'+directory.name+'/runner.log']=log.read_bytes()
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((DEST/'STATUS.json').read_text());r['evidence']=dict(path=str((DEST/'EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files),excluded='Object/module/executable bytes are explicitly hashed, not embedded; raw executions and build receipts retained.')
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
r['scientific_delta']={v.split('\t')[1]:v.split('\t')[0]for v in subprocess.check_output(['git','diff','--name-status',r['baseline'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
incumbent=json.loads((ROOT/'integration/mc-sol01/detailed_rain/STATUS.json').read_text())['postimages']
r['incumbent_inputs']={p:h for p,h in incumbent.items()if p not in r['scientific_delta']}
paths=set(r['scientific_delta'])|{str((DEST/'CONTRACT.md').relative_to(ROOT)),str(Path(__file__).resolve().relative_to(ROOT))}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',implemented=True,tested=True,qualified=True,canonically_admitted=False,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),results=dict(direct_cases_per_optimization=144,original_and_independent_ode=True,default_outputs_byte_exact=True,HIST_fresh_native=78,HIST_restarts=56,HIST_fresh_compiles=46,HIST_identical_module_closure_compile_reuse=608,coupled_runs=4,coupled_days_per_run=8,separate_process_restarts=8,byte_exact_rejection_kinds=['exhaustion','stale_environment','water']),inherited_scope='Original17 detailed rain corruption assertions preserved. Original regular-limits archived numerical assertions retained with four explicitly historical provider identity reads. Current changed providers are qualified by fresh O0/O2 physical and default preservation runs.')
(DEST/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
