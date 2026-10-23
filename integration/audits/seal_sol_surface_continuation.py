"""Seal bounded development results; never publish an annual admission."""
import argparse,base64,csv,hashlib,io,json,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(raw):return hashlib.sha256(raw).hexdigest()
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--proof',type=Path,required=True)
 ap.add_argument('--output',type=Path,required=True);a=ap.parse_args();proof=a.proof.resolve()
 a.output=a.output.resolve()
 def result(name):return json.loads((proof/name/'result.json').read_text())
 assert result('pond-contract')['status']=='LEAF_PASS_NOT_RUNTIME_ADMISSION'
 d=result('default-daily')
 assert d['status']=='ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS'
 assert d['exact_default_files']==64 and d['fresh_restarts']==16
 assert result('default-transaction')['status']=='ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS'
 r=result('final-native-restart')
 assert r['exact_restart_files']==12 and r['invalids']==8 and r['surface_mode_rejections']==2
 assert r['status']=='PICARD_TRANSPORT_NATIVE_WITHIN_POLICY_RESTART_CROSS_POLICY_REJECT_O0_O2_PASS'
 source={};budgets={}
 for opt in ['O0','O2']:
  build=json.loads((proof/('final-build-'+opt)/'column/build-complete.json').read_text())
  assert '-'+opt in build['flags'] and '-fcheck=all' in build['flags']
  assert all(sha((ROOT/p).read_bytes())==h for p,h in build['input_sha256'].items())
  source.update(build['input_sha256'])
  assert all(sha(Path(p).read_bytes())==h for p,h in build['reused_artifact_sha256'].items())
  r=result('final-short-'+opt)
  assert r['status']=='NATIVE_PROJECT_SHORT_PASS_REFERENCE' and r['exact_single_files']==4
  r=result('final-day267-'+opt)
  assert r['status']=='ACTUAL_WATER_DAY_PASS' and r['production_historical_zero']
  assert r['historical_exfiltration_provider_sha256'] is None
  rows=list(csv.DictReader((proof/('final-day267-'+opt)/'budget.csv').open()))
  assert len(rows)==1;d={k:float(v)for k,v in rows[0].items()};budgets[opt]=d
  assert d['surface_exfiltration_cm']>0 and d['surface_solute_exfiltration_mg_cm2']==0
  for name,unit in [('water','cm'),('solute','mg_cm2')]:
   residual=d[name+'_end_'+unit]-d[name+'_start_'+unit]-d[name+'_in_'+unit]+d[name+'_out_'+unit]
   assert abs(residual)<1e-10 and abs(d[name+'_residual_'+unit])<1e-10
 assert budgets['O0']==budgets['O2']
 for name in ['budget.csv','state.csv','endpoint.csv','restart.bin']:
  assert(proof/'final-day267-O0'/name).read_bytes()==(proof/'final-day267-O2'/name).read_bytes()
 rejected=result('repair-day65-O0')
 assert rejected['status']=='ACTUAL_WATER_REJECTION_DIAGNOSTIC_REPLAY_OWNERS_EXACT'
 rejected=result('final-default-reject-O2')
 assert rejected['status']=='ACTUAL_WATER_REJECTION_DIAGNOSTIC_REPLAY_OWNERS_EXACT'
 assert not rejected['production_historical_zero']
 probe=proof/'saturation-metric-day65-local-O2'
 assert result('saturation-metric-day65-local-O2')['status']=='ACTUAL_WATER_REJECTION_DIAGNOSTIC_REPLAY_OWNERS_EXACT'
 assert any(b'SATURATION_METRIC_PROBE' in p.read_bytes()for p in probe.glob('*.stdout'))
 files={}
 for p in sorted(proof.rglob('*')):
  if not p.is_file()or p.is_symlink()or p.suffix.lower()in ['.o','.mod','.smod','.a','.so','.tmp']:continue
  raw=p.read_bytes()
  if raw.startswith(b'\x7fELF'):continue
  files['proof/'+str(p.relative_to(proof))]=raw
 # Preserve every intermediate runner version and failed build source too.
 paths=subprocess.check_output(['git','diff','--name-only','e2391404','HEAD'],cwd=ROOT,text=True).splitlines()
 paths=[p for p in paths if Path(p).suffix in ['.py','.f90']or p in [
  'docs/science/MC_SOL01_NATIVE_PROJECT_CONTRACT.md','integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json']]
 for p in set(paths)|set(source)|{str(Path(__file__).relative_to(ROOT))}:
  if (ROOT/p).is_file():files['source/'+p]=(ROOT/p).read_bytes()
 for rev in subprocess.check_output(['git','rev-list','e2391404..HEAD'],cwd=ROOT,text=True).splitlines():
  for p in paths:
   cp=subprocess.run(['git','show',rev+':'+p],cwd=ROOT,capture_output=True)
   if cp.returncode==0:files['source-versions/'+sha(cp.stdout)]=cp.stdout
 summary=dict(status='BOUNDED_DEVELOPMENT_PASS_ANNUAL_WATER_BLOCKED',qualified=False,
  canonically_admitted=False,full_historical_migration=False,
  source_checkpoint=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
  postimages=source,day267=budgets,default_exact_files=64,default_fresh_restarts=16,
  native_exact_restart_files=12,public_surface_mode_rejections=2,
  annual='NOT_RERUN_KNOWN_DAY65_WATER_BLOCKER',NUT_preservation='PENDING_ADMISSION_SELECTION',
  hosted='NOT_SELECTED_LOCAL_DEVELOPMENT',remote='BLOCKED_AUTO_REVIEW_NO_BYPASS',
  saturation_probe='Executed metric confirmed by three raw markers; same rejected day65/progress/counters. No annual admission.')
 files['SUMMARY.json']=(json.dumps(summary,indent=2)+'\n').encode()
 files['MANIFEST.json']=(json.dumps({p:sha(raw)for p,raw in sorted(files.items())},indent=2)+'\n').encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz')as t:
  for p,raw in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(raw);m.mode=0o644;m.mtime=0;t.addfile(m,io.BytesIO(raw))
 raw=stream.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
  manifest=json.load(t.extractfile('MANIFEST.json'))
  assert all(sha(t.extractfile(p).read())==h for p,h in manifest.items())
 print(json.dumps(dict(path=str(a.output.relative_to(ROOT)),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files))))
if __name__=='__main__':main()
