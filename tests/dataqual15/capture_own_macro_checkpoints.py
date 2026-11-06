"""Copy published S5WM0001 checkpoints unchanged for exact own continuation.

GNU little-endian native layout only: the time offset follows the actual writer's
eight-int64 plus int32 template, not a portable or replacement stream schema.
"""
import argparse,hashlib,json,shutil,struct,time,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--run',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
p.add_argument('--days',default='3,4,43,44,365,366,481');p.add_argument('--seconds',type=float,default=1800)
a=p.parse_args();origin=a.run.resolve();out=a.output.resolve();out.mkdir()
launch=json.loads((origin/'LAUNCH.json').read_text());wanted={int(x)for x in a.days.split(',')}
sha=lambda b:hashlib.sha256(b).hexdigest()
for n,h in launch['original_input_sha256'].items():assert sha((origin/n).read_bytes())==h
assert sha(Path(launch['command'][0]).read_bytes())==launch['executable_sha256']
record=dict(scope='UNCHANGED_PUBLISHED_OWN_STREAM_COPIES_NOT_CONTINUATION_PASS',
 run=str(origin),executable_sha256=launch['executable_sha256'],captures={},
 layout_source_sha256={n:sha((ROOT/n).read_bytes())for n in (
  'app/solute_column/macro_water_restart.f90','src/runtime/mod_fmr_runtime_core.f90')})
start=time.monotonic()
while time.monotonic()-start<a.seconds:
 try:raw=(origin/'restart.bin').read_bytes()
 except (FileNotFoundError,PermissionError):raw=b''
 if len(raw)>=216 and raw[:8]==b'S5WM0001':
  assert raw[8:72].decode()==launch['command'][6]
  assert struct.unpack_from('<ii',raw,72)==(112,5)
  assert zlib.crc32(raw[:-4])==struct.unpack_from('<I',raw,len(raw)-4)[0]
  clock=struct.unpack_from('<d',raw,204)[0]
  if clock in wanted and str(int(clock))not in record['captures']:
   day=int(clock);folder=out/str(day);folder.mkdir()
   # Preserve the native binding and every byte, including its original CRC.
   (folder/'restart.bin').write_bytes(raw)
   shutil.copyfile(origin/'LAUNCH.json',folder/'LAUNCH.json')
   for n in launch['original_input_sha256']:shutil.copyfile(origin/n,folder/n)
   assert (folder/'restart.bin').read_bytes()==raw
   record['captures'][str(day)]=dict(sha256=sha(raw),elapsed_seconds=time.monotonic()-start)
   (out/'CAPTURES.json').write_text(json.dumps(record,indent=2)+'\n')
   print('CAPTURED',day,sha(raw),flush=True)
 if (origin/'RESULT.json').exists()or len(record['captures'])==len(wanted):break
 time.sleep(.05)
record.update(seconds=time.monotonic()-start,missing=sorted(wanted-set(map(int,record['captures']))),
 native_terminal=(origin/'RESULT.json').exists())
(out/'CAPTURES.json').write_text(json.dumps(record,indent=2)+'\n')
