"""Record completed gates, keeping actual admission separate."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
PREFIX='benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261024'
STATUS=ROOT/'benchmarks/performance/PERF01_TYPED_WATER_FLUX_20261023_STATUS.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def main():
 r=json.loads(STATUS.read_text());live=r['live_composition']
 for p,h in live['postimages'].items():assert sha((ROOT/p).read_bytes())==h
 controls=json.loads(Path('/tmp/perf01-live-controls-v2.json').read_text());assert len(controls)==len(set(controls))==147
 assert not Path('/tmp/perf01-live-controls-v2.stderr').read_bytes()
 gates={}
 for name in ['general','history']:
  raw=Path('/tmp/perf01-live-'+name+'.json').read_bytes();assert json.loads(raw)['qualified']and not Path('/tmp/perf01-live-'+name+'.stderr').read_bytes()
  gates[name]=dict(qualified=True,sha256=sha(raw),result=json.loads(raw))
 stdout=Path('/tmp/perf01-live-fsi35-v2.stdout').read_text();stderr=Path('/tmp/perf01-live-fsi35-v2.stderr').read_text()
 assert stdout.rstrip().endswith('FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS')
 assert 'FCI93_FSI35_CURRENT_SEMANTIC_REPLAY=PASS'in stdout
 git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
 report=dict(status='CURRENT_CANONICAL_COMPOSITION_LOCALLY_QUALIFIED',qualification_checkpoint=git('rev-parse','HEAD'),
  source_trees={p:git('rev-parse','HEAD:'+p)for p in ['src','app','tests']},
  protected_source_sha256=live['postimages'],evidence=live['evidence'],current_controls=controls,
  historical_exact_owner_controls=dict(typed=241,canonical=179),
  current_native=dict(NUT_HIST=78,NUT_coupled=22,NUT_coupled_restarts=44,FCT_reactive_process=24,FCT_reactive_joint=24,FCT_pulse=36,FCT_disk=24,FCT_disk_separate_native=150),
  fsi35=dict(status='PASS',returncode=0,stdout=stdout,stderr=stderr),gates=gates,
  docs=dict(source_checks='PASS',strict_mkdocs='PASS'),canonically_admitted=False,
  scope='Explicit default-OFF changed-accuracy water/flux option; native194 input-exact inheritance; no full SOL/NUT closure')
 path=ROOT/(PREFIX+'_LIVE_QUALIFICATION.json');path.write_text(json.dumps(report,indent=2)+'\n')
 live.update(status='LOCALLY_QUALIFIED_PENDING_CANONICAL',qualified=True,current_controls=147,fsi35_native='PASS',qualification=dict(path=str(path.relative_to(ROOT)),sha256=sha(path.read_bytes())))
 r.update(status='CURRENT_CANONICAL_COMPOSITION_QUALIFIED_PENDING_ACTUAL_MERGE',qualified=True,canonically_admitted=False,
  latest_owner='integration/audits/verify_perf01_live_composition.py via canonical singular organic owner',
  next_action='Publish qualified tree, mark PR1408 ready, merge expected exact head and verify actual canonical tree and owner gates',
  latest_reconciliation='Canonical03c1c7a4 PR1409-1412 preserved by fresh affected HIST/NUT/FCT and original O0/O2 FSI35; current147 controls and general/history PASS')
 STATUS.write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(dict(report=str(path.relative_to(ROOT)),qualified=True,current_controls=147)))
if __name__=='__main__':main()
