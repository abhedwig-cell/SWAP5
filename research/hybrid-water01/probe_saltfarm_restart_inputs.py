"""One read-only first-soil-step comparison at the failed own1459 boundary.

Hypothesis: restored primary heads match, but reconstructed hydraulic or clock
inputs differ before the first new Richards step. No equations or guards change.
The traced cold trajectory must preserve every original physical day receipt.
"""
import argparse
import contextlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import threading
import time

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle',type=Path,required=True)
p.add_argument('--reference',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();a.bundle=a.bundle.resolve();a.reference=a.reference.resolve();a.output=a.output.resolve()
meta,case=validate_bundle(a.bundle,a.reference,h.SALTFARM);a.output.mkdir()
source=(a.bundle/'swap.f90').read_text(encoding='cp1252')
anchor='         if (.NOT.fldecdt) call SoilWater(2)'
assert source.count(anchor)==1
source=source.replace(anchor,'         if (flDayStart.and.t1900==42367d0) call saltfarm_restart_probe()\n'+anchor)
(a.output/'swap.f90').write_text(source,encoding='cp1252',newline='\n')
scalars=['t1900','t','dt','dtold','gwl','gwlm1','qbot','pond']
arrays=['h','theta','k','kmean','dimoca','qrot','rfcp','tsoil']
probe='''subroutine saltfarm_restart_probe()
 use MOD_grid,only:numnod
 use variables,only:t1900,t,dt,dtold,gwl,gwlm1,qbot,pond,h,theta,k,kmean,dimoca,qrot
 use MOD_frost,only:rfcp
 use MOD_SoilTemperature,only:tsoil
 implicit none
 integer::unit
 open(newunit=unit,file='first-step.bin',access='stream',form='unformatted',status='unknown',position='append')
 write(unit) t1900,t,dt,dtold,gwl,gwlm1,qbot,pond
 write(unit) h(1:numnod),theta(1:numnod),k(1:numnod),kmean(1:numnod),dimoca(1:numnod),qrot(1:numnod),rfcp(1:numnod),tsoil(1:numnod)
 close(unit)
end subroutine
'''
(a.output/'probe.f90').write_text(probe,newline='\n')
objects=a.reference/'build/swap-obj';ttutil=a.reference/'build/ttutil-obj'
commands=[]
def execute(command):
    start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=a.output,capture_output=True,text=True,timeout=30)
    commands.append(dict(command=list(map(str,command)),seconds=time.perf_counter()-start,returncode=r.returncode,stderr=r.stderr))
    (a.output/'COMMANDS.json').write_text(json.dumps(commands,indent=2)+'\n')
    assert r.returncode==0,r.stderr
flags=meta['identity']['donor_flags']
for name in ('swap','probe'):
    execute(['gfortran',*flags,'-I',a.bundle,'-I',objects,'-I',ttutil,'-c',name+'.f90'])
replacements={Path(name).with_suffix('.o').name:a.bundle/Path(name).with_suffix('.o') for name in meta['identity']['donor_generated']}
replacements['swap.o']=a.output/'swap.o'
donor=h.executable(a.output,'day_donor')
execute(['gfortran','-o',donor,*[replacements.get(f.name,f) for f in sorted(objects.glob('*.o'))],
         a.bundle/'hybrid_step_budget.o',a.output/'probe.o',ttutil/'libttutil.a'])
binding={**meta['binding'],'read_only_probe':{'source_sha256':h.sha(Path(__file__)),
    'swap_sha256':h.sha(a.output/'swap.f90'),'probe_sha256':h.sha(a.output/'probe.f90'),'donor_sha256':h.sha(donor)}}
workers=[];actual=h.start_process
def track(*args,**kwargs):
    proc,log=actual(*args,**kwargs);workers.append(proc);return proc,log
def stop():
    for proc in workers:
        if proc.poll() is None:proc.kill()
h.start_process=track;timer=threading.Timer(40,stop);timer.start()
try:
    kernel=h.executable(a.bundle,'day_kernel');full=a.output/'cold';full.mkdir()
    rows=[]
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,donor,kernel,case,full,[h.ColumnStart()],checkpoint_enabled=True,runtime=True,binding=binding,project=h.SALTFARM)
        with (full/'daily.jsonl').open('w') as f:
            for day in range(1,1462):
                row=host.step(1,checkpoint=day in (1459,1461));rows.append(row);f.write(json.dumps(row)+'\n');f.flush();assert row['committed']
        host.close()
    original=[json.loads(line) for line in (a.bundle/'full/daily.jsonl').read_text().splitlines()]
    assert rows==original,'Read-only trace changed original cold physical receipt'
    own=a.output/'own';own.mkdir();origin=own/'origin'
    receipt=h.verify_checkpoint(full/'accepted-column-1-day-1459.zip',1459,binding,origin)
    result=h.run(donor,kernel,case,own,1461,checkpoint_day=1459,origin=origin,origin_receipt=receipt,
        runtime=True,publish_day=1461,checkpoint_binding=binding,project=h.SALTFARM)
    assert result['first_refusal'] is None
    cold=(full/'original/first-step.bin').read_bytes();restored=(own/'original/first-step.bin').read_bytes()
    count=8+195*8;assert len(cold)==len(restored)==8*count
    x=struct.unpack('='+str(count)+'d',cold);y=struct.unpack('='+str(count)+'d',restored)
    difference={name:{'cold':x[i],'own':y[i]} for i,name in enumerate(scalars) if x[i]!=y[i]}
    for j,name in enumerate(arrays):
        first=8+195*j;changed=[i for i in range(195) if x[first+i]!=y[first+i]]
        if changed:difference[name]={'nodes_changed':len(changed),'maximum_delta':max(abs(x[first+i]-y[first+i]) for i in changed),'first_node':changed[0]+1,'cold_first':x[first+changed[0]],'own_first':y[first+changed[0]]}
    report=dict(status='READ_ONLY_PROBE_COMPLETE',cold_all1461_physical_receipts_exact=True,different_first_step_inputs=difference,
        scalar_layout=scalars,array_layout=arrays,nodes=195,original_build_sha256=h.sha(a.bundle/'BUILD.json'),binding=binding)
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'different_first_step_inputs':difference}))
finally:
    timer.cancel();h.start_process=actual
    for proc in workers:
        if proc.poll() is None:proc.kill()
        proc.wait(timeout=5)
