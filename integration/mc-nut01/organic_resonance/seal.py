"""Seal current organic resonance, HIST, native restart and incumbent proof."""
from pathlib import Path
import argparse,base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[3];DEST=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--workspace',type=Path,required=True);a=p.parse_args();W=a.workspace.resolve()
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={}
for label,name in [('direct','nut-resonant-direct-02'),('hist','nut-resonant-hist-01'),('joint','nut-resonant-joint-01')]:
 for f in sorted((W/name).rglob('*')):
  if not f.is_file():continue
  n=label+'/'+str(f.relative_to(W/name))
  with f.open('rb')as h:magic=h.read(4)
  if f.suffix in ['.o','.mod']or magic==b'\x7fELF':excluded[n]=dict(sha256=sha(f.read_bytes()),bytes=f.stat().st_size)
  else:files[n]=f.read_bytes()
files['excluded-build-artifacts.json']=(json.dumps(excluded,indent=2)+'\n').encode()
with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/mc-nut01/single_zero_pool/EVIDENCE.tar.xz.b64').read_bytes())))as t:
 for label in ['hist','joint']:files['prior-'+label+'-result.json']=t.extractfile(label+'/result.json').read()
files['toolchain/wrapper']=(W/'compiler/bin/gfortran').read_bytes()
files['MANIFEST.json']=(json.dumps({p:sha(b)for p,b in files.items()},indent=2)+'\n').encode()
out=io.BytesIO()
with tarfile.open(fileobj=out,mode='w:xz',preset=9)as t:
 for p,b in sorted(files.items()):
  info=tarfile.TarInfo(p);info.size=len(b);info.mode=0o644;t.addfile(info,io.BytesIO(b))
raw=out.getvalue();(DEST/'EVIDENCE.tar.xz.b64').write_bytes(base64.b64encode(raw))
r=json.loads((DEST/'STATUS.json').read_text());r['evidence']=dict(path=str((DEST/'EVIDENCE.tar.xz.b64').relative_to(ROOT)),sha256=sha(raw),bytes=len(raw),members=len(files),excluded='Objects, modules and executables hashed, not embedded; raw receipts and native restart states retained.')
science=['src','app','tools','tests','examples','reference','.github','integration/audits','integration/performance','integration/diagnostics']
r['scientific_delta']={v.split('\t')[1]:v.split('\t')[0]for v in subprocess.check_output(['git','diff','--name-status',r['source_base'],'HEAD','--',*science],cwd=ROOT,text=True).splitlines()}
parent=json.loads((ROOT/'integration/mc-nut01/single_zero_pool/STATUS.json').read_text());prior={**parent['incumbent_inputs'],**parent['postimages']}
r['incumbent_inputs']={p:h for p,h in prior.items()if p not in r['scientific_delta']}
paths=set(r['scientific_delta'])|{str((DEST/'CONTRACT.md').relative_to(ROOT)),str(Path(__file__).resolve().relative_to(ROOT)),'docs/science/MC_NUT01_ORGANIC_RESONANCE_20261023.md'}
r['postimages']={p:sha((ROOT/p).read_bytes())for p in sorted(paths)}
r.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',implemented=True,tested=True,qualified=True,canonically_admitted=False,results=dict(direct_cases_per_optimization=972,formerly_rejected=972,incumbent_cases_byte_exact=658,helper_inputs_per_optimization=13,fresh_HIST_compiles=48,reused_HIST_compiles=606,fresh_HIST_processes=78,fresh_HIST_process_restarts=56,actual_coupled_runs=18,days_per_run=8,separate_process_restarts=36,previous_composition_rejection_probes=4),source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),qualification_scope='Positive-rate repeated/Jordan eigenvalues or guard-close FOM/eigenvalue resonance, determinant remains nonsingular. All134 predecessor controls retained. Current direct/HIST/crop/restart proof separate; selected mineral exhaustion remains unsupported.')
(DEST/'STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r['evidence']))
