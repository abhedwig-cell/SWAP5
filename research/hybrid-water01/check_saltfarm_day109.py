"""Consume actual accepted day109 after the dry-surface repair; no prefix replay.

The independent no-override original-input control still starts cold at day1.
Existing qualified native builds and two-day caller histories are hash-checked.
"""
import argparse
import contextlib
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,SURFACE_IRRIGATION_FORCING,validate_bundle

p=argparse.ArgumentParser(description=__doc__)
for n in ['runs','reference','output']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();a.output.mkdir();bundle=a.runs/'build';project=h.SALTFARM
meta,original=validate_bundle(bundle,a.reference,project)
prior=json.loads((a.runs/'RESULT.json').read_text());assert prior['status']=='SURFACE_IRRIGATION_NO_MACRO_TRANSACTION_AND_ORIGINAL_CONTROLS_PASS'
workers=[];start=h.start_process
def track(*args):
    process,log=start(*args);workers.append(process);return process,log
h.start_process=track;expired=[]
def stop():
    expired.append(True)
    for worker in workers:
        if worker.poll() is None:worker.kill()
timer=threading.Timer(60,stop);timer.daemon=True;timer.start();begin=time.monotonic()
def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision','coupling','committed','candidate_only')}
results=[]
try:
    for case in prior['cases']:
        if case['cut']!=107:continue
        name=case['scenario'];out=a.output/name;out.mkdir()
        origins=[p for p in a.runs.glob('107-'+name+'-shared*/external/accepted-column-1-day-109.zip') if h.sha(p)==case['final_sha256']]
        assert len(origins)==1;origin=origins[0];digest=h.sha(origin);cid=case['first']['coupling_id']
        owners=[CoupledDailyColumn(bundle,a.reference,out/n,project,cid,origin=origin,day=109,
            forcing_mode=SURFACE_IRRIGATION_FORCING) for n in ['live-from-109','disk-from-109']]
        request=owners[0].irrigation_forcing(14.4,.401,.6,'original-day110')
        proposals=[c.prepare(irrigation=request) for c in owners]
        assert proposals[0].budget==proposals[1].budget and payload(owners[0]._candidate[3])==payload(owners[1]._candidate[3])
        for c,q in zip(owners,proposals):c.accept(q)
        source=original if name=='identity' else origin.parent.parent/'manual-original-input'
        assert not (source/'hybrid-irrigation-day.in').exists()
        control=out/'independent-original-input';control.mkdir();rows=[]
        binding={**meta['binding'],'independent_original_swp_sha256':h.sha(source/'swap.swp')}
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),source,control,
                [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=binding,project=project)
            for day in range(1,111):rows.append(host.step(1,checkpoint=day==110))
            host.close()
        assert physical(rows[-1])==physical(proposals[0].budget)
        (control/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
        assert h.sha(origin)==digest
        results.append(dict(scenario=name,origin_day=109,end_day=110,origin_sha256=digest,
            live_disk_native_exact=True,independent_original_physical_exact=True,
            independent_input_sha256=h.sha(source/'swap.swp'),day110=physical(proposals[0].budget)))
    assert len(results)==3 and not expired
finally:
    timer.cancel()
    for worker in workers:
        if worker.poll() is None:worker.kill()
        worker.wait(timeout=5)
report=dict(status='STRICT_DAY109_TO110_AND_ORIGINAL_INPUT_CONTROLS_PASS',cases=results,censored=bool(expired),
    elapsed_seconds=time.monotonic()-begin,prior_report_sha256=h.sha(a.runs/'RESULT.json'),
    source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True,cwd=ROOT).strip(),
    sources={n:h.sha(ROOT/n) for n in ['research/hybrid-water01/check_saltfarm_day109.py',
        'app/hybrid_water/daily_coupling.py','app/hybrid_water/daily_host.py','app/hybrid_water/irrigation_forcing.py']})
(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(report['status'],flush=True)
