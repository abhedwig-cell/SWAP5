#!/usr/bin/env python3
"""Run unchanged incumbent physical gates with an opt-in compiler wrapper."""
import argparse
from collections import Counter
import datetime
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
BASE = 'c31fc81059e7e4388198c38eaf75558e58d75059'
GATES = {'root': 'tests/f-app07/run_mc_irr01_allocated_root_restart.sh',
         'sensor': 'tests/f-app07/run_mc_irr01_allocated_sensor_restart.sh'}

def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def clock():return datetime.datetime.now(datetime.timezone.utc).isoformat()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--compiler',required=True)
    ap.add_argument('--profile',required=True);ap.add_argument('--output',required=True)
    args=ap.parse_args();out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
    assert not git('status','--porcelain'), 'persist exact clean trial before running'
    assert git('merge-base','--is-ancestor',BASE,'HEAD')==''
    for surface in ['src','reference','tests/f-app07','tests/mc-irr01','tests/support','tests/fmr']:
        assert git('rev-parse','HEAD:'+surface)==git('rev-parse',BASE+':'+surface),surface
    for p in GATES.values():assert git('hash-object',p)==git('rev-parse',BASE+':'+p),p
    script=ROOT/'tools/fci/compile_cache_trial.py';wrapper=out/'bin';wrapper.mkdir()
    fc=wrapper/'gfortran';fc.write_text('#!/bin/sh\nexec '+shlex.quote(sys.executable)+' '+shlex.quote(str(script))+' "$@"\n');fc.chmod(0o755)
    env={**os.environ,'PATH':str(wrapper)+os.pathsep+os.environ['PATH'],
         'SWAP5_REAL_FC':str(Path(args.compiler).resolve()),'SWAP5_CACHE_PROFILE':str(Path(args.profile).resolve()),
         'SWAP5_CACHE_DIR':str(out/'cache'),'RUNNER_TEMP':str(out/'runner')}
    (out/'runner').mkdir();record={'head':git('rev-parse','HEAD'),'tree':git('rev-parse','HEAD^{tree}'),
        'baseline':BASE,'source_tree':git('rev-parse','HEAD:src'),'compiler_profile':json.loads(Path(args.profile).read_text()),
        'started_utc':clock(),'runs':[],'terminal':'RUNNING'}
    (out/'CONTROL.json').write_text(json.dumps(record,indent=2)+'\n')
    sequence=[('root-uncached','root',True),('root-fill','root',False),('root-warm','root',False),
              ('sensor-uncached','sensor',True),('sensor-cross','sensor',False),('sensor-warm','sensor',False)]
    for name,owner,disabled in sequence:
        events=out/(name+'.jsonl');stdout=out/(name+'.stdout');stderr=out/(name+'.stderr')
        execution={**env,'SWAP5_CACHE_EVENTS':str(events),'SWAP5_CACHE_DISABLED':'1' if disabled else '0'}
        started=clock();tick=time.monotonic()
        with stdout.open('wb') as so,stderr.open('wb') as se:
            result=subprocess.run(['bash',GATES[owner]],cwd=ROOT,env=execution,stdout=so,stderr=se)
        rows=[json.loads(x) for x in events.read_text().splitlines()]
        receipt={'name':name,'gate':GATES[owner],'disabled':disabled,'started_utc':started,'ended_utc':clock(),
                 'wall_seconds':time.monotonic()-tick,'exit':result.returncode,'events':dict(Counter(r['event'] for r in rows)),
                 'stdout_sha256':sha(stdout),'stderr_sha256':sha(stderr),'events_sha256':sha(events)}
        record['runs'].append(receipt);(out/'CONTROL.json').write_text(json.dumps(record,indent=2)+'\n')
        print(name,result.returncode,round(receipt['wall_seconds'],3),receipt['events'],flush=True)
        assert result.returncode==0,(name,stderr)
        assert b'MC_IRR01_MANAGEMENT_PHYSICAL_MASS=PASS' in stdout.read_bytes(),name
    for owner in GATES:
        names=['root-uncached','root-fill','root-warm'] if owner=='root' else ['sensor-uncached','sensor-cross','sensor-warm']
        assert len({sha(out/(n+'.stdout')) for n in names})==1,(owner,'scientific output differs')
        def artifacts(name):
            return [(r['source'],r['flags'],r['object_sha256'],r['pool_sha256'])
                    for r in map(json.loads,(out/(name+'.jsonl')).read_text().splitlines()) if 'object_sha256' in r]
        assert artifacts(names[0])==artifacts(names[1])==artifacts(names[2]),(owner,'cached artifact drift')
        warm=next(r for r in record['runs'] if r['name']==names[2])
        assert warm['events'].get('MISS',0)==0 and warm['events'].get('HIT',0)>0
    cross=next(r for r in record['runs'] if r['name']=='sensor-cross');assert cross['events'].get('HIT',0)>0
    assert git('rev-parse','HEAD')==record['head'] and not git('status','--porcelain')
    record.update(ended_utc=clock(),terminal='PASS',head_unchanged=True,clean_at_end=True,
                  scientific_stdout_equal=True,cold_warm_objects_and_modules_equal=True)
    (out/'CONTROL.json').write_text(json.dumps(record,indent=2)+'\n')
    print('FCI_BUILD_CACHE_EQUAL_GATES_O0_O2=PASS',flush=True)

if __name__=='__main__':main()
