"""Replay the known rejected window from authenticated evidence in an empty cwd."""
import argparse,hashlib,json,os,runpy,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir()
f=runpy.run_path(str(ROOT/'integration/audits/verify_dataqual03_current.py'))['capsule']();r=json.loads(f['RECOVERY.json'])
exe=out/r['executable'];exe.parent.mkdir();exe.write_bytes(f[r['executable']]);os.chmod(exe,0o755)
assert hashlib.sha256(exe.read_bytes()).hexdigest()==r['executable_sha256']
cwd=out/r['cwd'];cwd.mkdir()
for name,source in r['prepared_inputs'].items():(cwd/('origin.bin'if name=='restart.bin'else name)).write_bytes(f[source])
origin=(cwd/'origin.bin').read_bytes();start=time.monotonic()
with(cwd/'stdout').open('wb')as so,(cwd/'stderr').open('wb')as se:
 cp=subprocess.run(r['command'],cwd=cwd,stdout=so,stderr=se,timeout=60)
assert cp.returncode!=0 and b'NATIVE_WATER_REJECTED'in(cwd/'stdout').read_bytes()
assert (cwd/'origin.bin').read_bytes()==origin
assert (cwd/'diagnostic-rejected.bin').read_bytes()==origin
result=dict(returncode=cp.returncode,seconds=time.monotonic()-start,expected_rejection=True,complete_checkpoint_preserved_exact=True,rollback_restart_exact=True,source='verified capsule; fresh inputs-only cwd',three_day_complete=False)
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
