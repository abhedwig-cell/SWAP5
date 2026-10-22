"""Deterministic source/raw capsule for the bounded root substep successor."""
import argparse,base64,hashlib,io,json,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(b):return hashlib.sha256(b).hexdigest()
def main():
 ap=argparse.ArgumentParser()
 for p in ['proof','crop-O0','crop-O2','root-O0','root-O2','failed-build-log','output']:ap.add_argument('--'+p,type=Path,required=True)
 a=ap.parse_args();proof=a.proof.resolve();files={}
 def add_tree(prefix,folder):
  for p in sorted(folder.rglob('*')):
   if not p.is_file() or p.is_symlink() or p.suffix in ['.o','.mod','.a','.so']:continue
   raw=p.read_bytes()
   if raw.startswith(b'\x7fELF'):continue
   files[prefix+'/'+str(p.relative_to(folder))]=raw
 for prefix,folder in [('daily',proof/'daily'),('transaction',proof/'transaction'),('column-O0',proof/'current-O0'),
                       ('column-O2',proof/'current-O2'),('crop-O0',a.crop_O0),('crop-O2',a.crop_O2),
                       ('root-O0',a.root_O0),('root-O2',a.root_O2),('nut/cold',proof/'nut-cold'),('nut/thermal',proof/'nut-thermal'),
                       ('calendar-nut/cold',proof/'nut-cold'),('calendar-nut/calendar',proof/'nut-calendar')]:
  assert folder.is_dir(),folder
  add_tree(prefix,folder)
 for path,status in [('daily/result.json','ROOT_SUBSTEP_DAILY_O0_O2_MASS_RESTART_DEFAULT_EXACT_PASS'),
                     ('transaction/result.json','ROOT_SUBSTEP_REAL_TRACE_REJECT_RETRY_ABA_O0_O2_PASS'),
                     ('nut/cold/result.json','NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'),
                     ('nut/thermal/result.json','THERMAL_OUTPUT_ACTUAL_O0_O2_RESTART_ATOMIC_PASS'),
                     ('calendar-nut/calendar/result.json','NATIVE_CALENDAR_OUTPUT_ACTUAL_O0_O2_FRESH_PASS')]:assert json.loads(files[path])['status']==status
 # Original arithmetic proof, old physical/report endpoints and predecessor receipt
 # remain immutable. The new cold/thermal runs must reproduce them, not replace them.
 import runpy
 old=runpy.run_path(str(ROOT/'integration/audits/verify_nut_thermal_output.py'))['capsule']()
 for p,v in old.items():
  if p.startswith('original/') or p in ['preservation.json','PREDECESSOR.json']:files['nut/'+p]=v
 old_calendar=runpy.run_path(str(ROOT/'integration/audits/verify_nut_calendar_output.py'))['capsule']()
 for p in ['preservation.json','PREDECESSOR.json']:files['calendar-nut/'+p]=old_calendar[p]
 files['diagnostics/initial-build.json']=(proof/'column-O0/build.json').read_bytes()
 files['diagnostics/initial-build.stderr']=a.failed_build_log.read_bytes()
 files['diagnostics/initial-build-disposition.json']=json.dumps(dict(status='REJECTED_CHANGED_BUILD_INPUT',
   scientific_result='NOT_QUALIFIED',reason='Trace source extended while first compilation was active; strict builder refused certification. Final O0/O2 rebuilt stable source completely.')).encode()
 files['MANIFEST.json']=(json.dumps({p:sha(v) for p,v in sorted(files.items())},indent=2)+'\n').encode()
 stream=io.BytesIO()
 with tarfile.open(fileobj=stream,mode='w:xz') as archive:
  for p,v in sorted(files.items()):
   m=tarfile.TarInfo(p);m.size=len(v);m.mode=0o644;m.mtime=0;archive.addfile(m,io.BytesIO(v))
 raw=stream.getvalue();a.output.write_bytes(base64.encodebytes(raw))
 print(json.dumps(dict(path=str(a.output.resolve().relative_to(ROOT)),decoded_sha256=sha(raw),decoded_bytes=len(raw),members=len(files))))
if __name__=='__main__':main()
