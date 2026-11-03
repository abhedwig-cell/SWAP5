"""Diagnostic predecessor suffix only; never a restart or scientific admission."""
import argparse,hashlib,json,os,re,shutil,struct,subprocess,time,zlib
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--exe',type=Path,required=True)
p.add_argument('--predecessor',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--end',type=int,default=931);p.add_argument('--timeout',type=int,default=7200)
p.add_argument('--from-start',action='store_true',help='Create state from original inputs instead of importing predecessor state')
p.add_argument('--strict-restart',type=Path,help='Same-build checkpoint; never enable predecessor override')
p.add_argument('--compatibility-control',action='store_true',help='Explicit same-platform prior-build codec control; not same-build restart qualification')
p.add_argument('--capture',type=int,nargs='*',default=[],help='Retain CRC-valid accepted checkpoints at these exact days')
a=p.parse_args();base=a.predecessor.resolve();out=a.output.resolve();out.mkdir(exist_ok=False)
assert not(a.from_start and a.strict_restart)
assert not a.compatibility_control or a.strict_restart
sha=lambda f:hashlib.sha256(f.read_bytes()).hexdigest()
files=[f for f in base.iterdir() if f.suffix.lower() in ('.swp','.crp','.met','.dra','.nml')]
for f in files:shutil.copyfile(f,out/f.name)
restart=a.strict_restart.resolve() if a.strict_restart else base/'checkpoint-868.bin'
if not a.from_start:assert restart.is_file()
nml=(out/'input.nml').read_text()
ends=[float(v)for v in re.search('^ends_day=(.*)$',nml,re.M)[1].split(',')if v.strip()]
stop=next(i+1 for i,v in enumerate(ends)if v==a.end)
env=os.environ.copy()
env.pop('SWAP5_DIAG_PREDECESSOR',None)
if not a.from_start and not a.strict_restart:env['SWAP5_DIAG_PREDECESSOR']='1'
cmd=[str(a.exe.resolve()),'input.nml','-' if a.from_start else str(restart),str(stop),'swap.swp','maize.crp']
scope='STRICT_SAME_BUILD_RESTART_MEASUREMENT' if a.strict_restart else ('FROM_INPUT_MEASUREMENT' if a.from_start else 'DIAGNOSTIC_PREDECESSOR_SUFFIX_NOT_QUALIFICATION')
if a.compatibility_control:scope='INPUT_BOUND_SAME_PLATFORM_PRIOR_BUILD_CODEC_CONTROL_NOT_RESTART_QUALIFICATION'
record=dict(scope=scope,command=cmd,
            executable_sha256=sha(a.exe),restart_sha256=None if a.from_start else sha(restart),from_start=a.from_start,
            inputs={f.name:sha(f)for f in files},scientific_admission=False)
(out/'START.json').write_text(json.dumps(record,indent=2))
start=time.monotonic()
captured=set()
with (out/'stdout').open('wb')as so,(out/'stderr').open('wb')as se:
    proc=subprocess.Popen(cmd,cwd=out,env=env,stdout=so,stderr=se)
    while proc.poll()is None:
        try:
            raw=(out/'checkpoint.bin').read_bytes()
            assert raw[:8]==b'S5HR0003'and zlib.crc32(raw[:-4])==struct.unpack_from('=I',raw,len(raw)-4)[0]
            day=struct.unpack_from('=d',raw,8)[0]
            if day in a.capture and day not in captured:
                (out/f'checkpoint-{int(day)}.bin').write_bytes(raw);captured.add(day)
        except(OSError,AssertionError,struct.error):pass
        if time.monotonic()-start>a.timeout:
            proc.kill();proc.wait();record['returncode']=None;break
        time.sleep(.02)
    else:record['returncode']=proc.returncode
record['captured']=sorted(captured)
record['seconds']=time.monotonic()-start
(out/'RESULT.json').write_text(json.dumps(record,indent=2))
print(json.dumps(record))
