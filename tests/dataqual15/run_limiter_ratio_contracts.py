"""Actual native subnormal demand and unchanged DATAQUAL07 storage owner, O0/O2."""
import argparse,hashlib,json,subprocess,time
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--compiler',required=True,type=Path)
p.add_argument('--output',required=True,type=Path)
p.add_argument('--expect-defect',action='store_true')
p.add_argument('--baseline',type=Path)
a=p.parse_args();out=a.output.resolve();out.mkdir()
provider=ROOT/'src/process/macropore/mod_ppa_wu05a6_top_inflow_limiter.f90'
fixture=ROOT/'tests/dataqual15/limiter_ratio_actual_request.txt'
drivers={'actual':'tests/dataqual15/limiter_ratio_driver.f90',
         'owner':'tests/nut-sol/test_dataqual07_storage_bounds.f90'}
paths=[provider,fixture,*[ROOT/n for n in drivers.values()]]
record=dict(status='RUNNING',expected_defect=a.expect_defect,
 source_sha256={str(n.relative_to(ROOT)):hashlib.sha256(n.read_bytes()).hexdigest()for n in paths},events=[])
for mode in ('O0','O2'):
 case=out/mode;case.mkdir()
 for name,driver in drivers.items():
  exe=case/(name+'.exe')
  compile=[str(a.compiler.resolve()),'-'+mode,'-std=f2008','-Wall','-Wextra','-Werror',
   '-Wno-compare-reals','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',
   '-J'+str(case),str(provider),str(ROOT/driver),'-o',str(exe)]
  for label,command in [('compile',compile),('native',[str(exe),str(fixture)]if name=='actual'else[str(exe)])]:
   start=time.monotonic();r=subprocess.run(command,cwd=case,capture_output=True,timeout=60)
   (case/f'{name}-{label}.stdout').write_bytes(r.stdout);(case/f'{name}-{label}.stderr').write_bytes(r.stderr)
   record['events'].append(dict(mode=mode,driver=name,label=label,command=command,
    returncode=r.returncode,seconds=time.monotonic()-start))
   (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
   if a.expect_defect and name=='actual'and label=='native':
    assert r.returncode!=0 and b'SIGFPE'in r.stderr,r.stderr.decode(errors='replace')
   else:assert r.returncode==0,r.stderr.decode(errors='replace')
   if a.baseline and name=='owner'and label=='native':
    assert r.stdout==(a.baseline/mode/f'{name}-{label}.stdout').read_bytes()
record['status']='ACTUAL_SUBNORMAL_OVERFLOW_REPRODUCED_O0_O2'if a.expect_defect else'ACTUAL_SUBNORMAL_AND_UNMODIFIED_STORAGE_OWNER_O0_O2_PASS'
(out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'])
