"""Actual six-provider macropore storage/candidate/vertical closure, O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
p.add_argument('--expect-defect',action='store_true')
a=p.parse_args();out=a.output.resolve();out.mkdir()
names=['src/runtime/mod_macropore_continuation_state.f90',
 'src/process/macropore/mod_ppa_wu05a5_top_partition.f90',
 'src/process/macropore/mod_ppa_wu05a5_multi_domain_process.f90',
 'src/process/macropore/mod_macropore_standard_storage.f90',
 'src/process/macropore/mod_ppa_wu05a6_vertical_flux_reconstruction.f90',
 'tests/dataqual15/empty_pocket_driver.f90']
sources=[ROOT/n for n in names]
report=dict(status='RUNNING',expected_defect=a.expect_defect,source_sha256={n:hashlib.sha256((ROOT/n).read_bytes()).hexdigest()for n in names},events=[])
for mode in ('O0','O2'):
 case=out/mode;case.mkdir();exe=case/'contract.exe'
 commands=[[str(a.compiler.resolve()),'-'+mode,'-ffree-line-length-none','-fcheck=all',
  '-ffpe-trap=invalid,zero,overflow','-J'+str(case),*map(str,sources),'-o',str(exe)],[str(exe)]]
 for label,command in zip(('compile-link','native'),commands):
  start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=60)
  (case/(label+'.stdout')).write_bytes(r.stdout);(case/(label+'.stderr')).write_bytes(r.stderr)
  report['events'].append(dict(optimization=mode,label=label,command=command,seconds=time.monotonic()-start,returncode=r.returncode))
  (out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
  if label=='native'and a.expect_defect:
   assert r.returncode!=0 and b'positive regular pocket discarded'in r.stderr,r.stderr.decode(errors='replace')
  else:assert r.returncode==0,r.stderr.decode(errors='replace')
report['status']='BASELINE_POSITIVE_WATER_LOSS_REPRODUCED_O0_O2'if a.expect_defect else'POSITIVE_POCKET_CLOSURE_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'])
