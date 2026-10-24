"""Retain a real downstream failure; no trace/heat/drainage admission."""
import base64,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];W=ROOT.parent;HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest();files={};excluded={};summary={}
for pattern in ['andelst-trace-gap-*','andelst-trace-receipts-*','andelst-trace-boundary-*']:
 for folder in sorted(W.glob(pattern)):
  if not folder.is_dir():continue
  for p in sorted(folder.rglob('*')):
   if not p.is_file()or p.is_symlink():continue
   b=p.read_bytes();key=folder.name+'/'+str(p.relative_to(folder))
   if p.suffix in ['.o','.mod','.a']or b.startswith(b'\x7fELF'):excluded[key]=dict(bytes=len(b),sha256=sha(b));continue
   files[key]=b
for opt in ['O0','O2']:
 prefix='andelst-trace-boundary-'+opt+'/';r=json.loads(files[prefix+'RESULT.json']);assert r['status']=='PHYSICAL_CANDIDATE_EXACT_TRACE_PUBLICATION_REJECTS_ATOMICALLY'
 for e in r['events']:assert e['returncode']==(1 if e['label']in ['canonical','counterfactual']else 0)
 def candidate(label):
  lines=[l for l in files[prefix+label+'.stdout'].splitlines()if l.startswith(b'TRACE_PHYSICS ')];assert len(lines)==1;return lines[0]
 assert candidate('control')==candidate('counterfactual')
 fail=files[prefix+'counterfactual.stderr'];assert b'COMPLETED=F'in fail and b'CANDIDATE_READY=F'in fail
 first=files['andelst-trace-gap-'+opt+'/counterfactual.stderr'];assert b'TEMP_REJ=5'in first and b'MASS_REJ=0'in first
 summary[opt]=dict(physical_candidate_sha256=sha(candidate('control')),physical_candidate_exact=True,canonical_trace_rejected=True,gate_only_temporal_rejections=5,preserving_metric_still_rejects_missing_trace=True,no_candidate_published=True)
assert summary['O0']['physical_candidate_sha256']==summary['O2']['physical_candidate_sha256']
r=dict(work_unit='HIST-INTEGRATION01 original Andelst accepted trace',baseline='32676715fe351beb548c8791bfda941fac8e031a',stage='REPRODUCED_EXTERNAL_MACRO_TRACE_CONTRACT_GAP',diagnostic_reproduced=True,qualified=False,canonically_admitted=False,production_edited=False,results=summary,
 findings=['Canonical rejects requested trace before execution.','Private first-guard-only counterfactual reaches five temporal rejections without a mass rejection.','Preserving the already admitted three-owner temporal metric yields an exact physical candidate, but final trace materialization correctly rejects and clears the candidate.'],
 relevant_sources={'src/runtime/mod_fmr_serialized_reference_backend.f90':sha((ROOT/'src/runtime/mod_fmr_serialized_reference_backend.f90').read_bytes()),'integration/mc-sol01/drainage/probe_andelst_trace_gap.py':sha((HERE/'probe_andelst_trace_gap.py').read_bytes())},
 source_boundaries=['fmr_serialized_temporal_identity: plain Boesten/trace branch must not select a different metric for combined macropore state','fmr_serialized_advance: accepted macro trace explicitly excludes nonzero external top, return, covering and rapid-drain receipts','fmr_serialized_backend_run_trial: incomplete accepted trace must reject, not publish'],
 next_action='Design and implement explicit surface-to-macropore accepted/returned/rapid water receipts in the existing trace owner; preserve temporal policy and exact physical results, then qualify source allocation and drainage, heat and native Andelst composition.',
 acceptance=['Observer ON/OFF keeps the physical candidate and temporal policy exact.','Per-domain macro and matrix stocks plus signed external receipts reconstruct whole-column water independently.','Returned pond water and rapid drainage are booked once; rejected trials publish no trace/candidate and preserve committed state.','Snapshot/restart source-window provenance and separate heat/chemistry consumption remain explicit.'],
 exclusions=['No tolerance change','No clamp','No SWBOTB1','No RossFast expansion','No new1e-6','No heat/drainage/full-project admission'])
files['RESULT.json']=json.dumps(r,indent=2).encode();files['EXCLUDED.json']=json.dumps(excluded,sort_keys=True).encode();files['MANIFEST.json']=json.dumps({p:sha(b)for p,b in files.items()},sort_keys=True).encode()
stream=io.BytesIO()
with tarfile.open(fileobj=stream,mode='w:xz')as t:
 for p,b in sorted(files.items()):
  m=tarfile.TarInfo(p);m.size=len(b);m.mtime=0;m.mode=0o644;t.addfile(m,io.BytesIO(b))
b=stream.getvalue();path=HERE/'ANDELST_TRACE_GAP_EVIDENCE.tar.xz.b64';path.write_bytes(base64.b64encode(b));r['evidence']=dict(path=str(path.relative_to(ROOT)),sha256=sha(b),bytes=len(b),members=len(files))
(HERE/'ANDELST_TRACE_GAP_STATUS.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(summary,indent=2))
