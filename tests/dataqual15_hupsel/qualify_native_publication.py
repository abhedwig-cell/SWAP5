"""Bounded literal-input rotation publication, restart and real decoder controls.

Two days exercise replacement of an existing checkpoint. A same-build restart
must reproduce the uninterrupted checkpoint bytes. This is not whole-period
scientific qualification or admission of the pending canopy correction.
"""
import argparse, hashlib, json, os, subprocess, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();bundle=a.bundle.resolve();out=a.output.resolve();out.mkdir()
events=[]
def run(script,args):
 command=[sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel'/script),*map(str,args)]
 result=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=180)
 event=dict(command=command,returncode=result.returncode,stdout=result.stdout.decode(errors='replace'),stderr=result.stderr.decode(errors='replace'))
 events.append(event);(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 assert result.returncode==0,event
for name,end,restart in [('day1',1,None),('continuous',2,None),('restart',2,out/'day1/checkpoint.bin')]:
 args=['--bundle',bundle,'--output',out/name,'--rotation','--prepare-days',2,'--end',end,'--timeout',120]
 if restart:args+=['--restart',restart]
 run('run.py',args)
 report=json.loads((out/name/'RESULT.json').read_text())
 assert report['returncode']==0 and not report['censored'] and report['completed_days']==end,report
 assert report['maximum_water_residual_cm']<=1e-10 and report['maximum_solute_residual_mg_cm2']<=1e-10,report
raw=(out/'continuous/checkpoint.bin').read_bytes()
assert raw==(out/'restart/checkpoint.bin').read_bytes(),'strict continuation differs from uninterrupted endpoint'
run('qualify_rotation_restart_guards.py',['--bundle',bundle,'--case',out/'continuous','--checkpoint',out/'continuous/checkpoint.bin','--output',out/'decoder'])
run('qualify_crc.py',['--build',bundle,'--output',out/'crc'])
build=json.loads((bundle/'BUILD.json').read_text())
result=dict(status='NATIVE_TWO_DAY_PUBLICATION_RESTART_AND_CORRUPTION_PASS',build=build,checkpoint_sha256=hashlib.sha256(raw).hexdigest(),decoder=json.loads((out/'decoder/RESULT.json').read_text()),crc=json.loads((out/'crc/RESULT.json').read_text()),scope='Literal input two-day native I/O only; no canopy correction or whole scientific admission')
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
print(result['status'])
