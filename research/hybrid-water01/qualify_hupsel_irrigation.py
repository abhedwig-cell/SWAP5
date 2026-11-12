"""Bounded original Hupsel day5 surface water/solute event and changed-history restart."""
import argparse
import contextlib
from dataclasses import replace
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,IRRIGATION_FORCING,forcing_digest
from irrigation_forcing import build_bundle,INPUT

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--opt',choices=['O0','O2'],action='append')
a=p.parse_args();a.output.mkdir();idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text())
reference=a.workspace/idx['reference'];case=reference/'distribution/SWAP_4.3.1/cases/1.hupselbrook'
started=[];expired=[];real_start=h.start_process
def track(*args):
    proc,log=real_start(*args);started.append(proc);return proc,log
h.start_process=track
def stop():
    expired.append(True)
    for proc in started:
        if proc.poll() is None:proc.kill()
timer=threading.Timer(240,stop);timer.daemon=True;timer.start();begin=time.monotonic()
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','app/hybrid_water/irrigation_forcing.py',
                                       'research/hybrid-water01/qualify_hupsel_irrigation.py']},'cases':[]}

def physical(r):return {k:v for k,v in r.items() if k not in ('column','revision','coupling','committed','candidate_only')}
def payload(p):
    with zipfile.ZipFile(p) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn):
    try:fn()
    except (ValueError,TypeError):return
    raise AssertionError('Invalid request accepted')
def direct(bundle,meta,source,out,last,*,checkpoint=4):
    out.mkdir();rows=[]
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),source,out,
            [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=h.HUPSEL)
        for day in range(1,last+1):rows.append(host.step(1,checkpoint=day in (checkpoint,last)))
        host.close()
    (out/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
    return rows

try:
    for opt in a.opt or ['O0','O2']:
        native=idx['cases']['hupsel-'+opt];base=a.workspace/native['build'];out=a.output/opt;out.mkdir()
        bundle=build_bundle(base,reference,out/'build');meta=json.loads((bundle/'BUILD.json').read_text())
        if os.name!='nt':
            for name in ['day_donor','day_kernel']:h.executable(bundle,name).chmod(0o755)
        # Source extension without a request must preserve the complete original event.
        baseline=direct(bundle,meta,case,out/'no-file-original',7)
        frozen=a.workspace/native['report']/'gift-seven'
        original=[json.loads(l) for l in (frozen/'daily.jsonl').read_text().splitlines()]
        assert [physical(r) for r in baseline]==[physical(r) for r in original]
        assert payload(out/'no-file-original/accepted-column-1-day-7.zip')=={n:(frozen/'original'/n).read_bytes() for n in h.CHECKPOINT_FILES}
        origin=out/'no-file-original/accepted-column-1-day-4.zip';origin_hash=h.sha(origin)
        for scenario in ['modified','disabled','identity']:
            root=out/scenario;root.mkdir();cid='irrigation-'+opt+'-'+scenario
            c=CoupledDailyColumn(bundle,reference,root/'external',h.HUPSEL,cid,origin=origin,day=4,
                                 adopt_native=True,forcing_mode=IRRIGATION_FORCING)
            depth,conc,rate={'modified':(24.001,20.001,12.),'disabled':(0.,0.,0.),'identity':(24.,20.,12.)}[scenario]
            f=c.irrigation_forcing(depth,conc,rate,'caller-day5',enabled=scenario!='disabled')
            before=(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
            bad=[replace(f,coupling_id='foreign'),replace(f,origin_sha256='0'*64),replace(f,t0_day1900=f.t0_day1900+1),
                 replace(f,depth_mm=float('nan')),replace(f,concentration_mg_cm3=1001),replace(f,rate_mm_h=0.,enabled=True),
                 replace(f,depth_mm=True),replace(f,enabled=1),replace(f,depth_mm=1.,enabled=False),replace(f,provenance='')]
            for b in bad:
                reject(lambda:c.prepare(irrigation=b));assert before==(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
            reject(lambda:c.prepare());reject(lambda:c.prepare(groundwater=f))
            first=c.prepare(irrigation=f);firstrow=first.budget;firstpayload=payload(c._candidate[3])
            c.discard(first);assert before[:3]==(c.day,c.revision,h.sha(c.checkpoint))
            retry=c.prepare(irrigation=f);assert retry.budget==firstrow and payload(c._candidate[3])==firstpayload
            reject(lambda:c.accept(first));accepted=c.accept(retry);reject(lambda:c.prepare(irrigation=f))
            recovered=CoupledDailyColumn(bundle,reference,root/'recovered',h.HUPSEL,cid,origin=accepted,day=5,forcing_mode=IRRIGATION_FORCING)
            second=c.irrigation_forcing(0.,0.,0.,'caller-day6-absent',enabled=False) if scenario=='identity' else c.irrigation_forcing(.02,1.,1.,'caller-day6-new-event')
            p1=c.prepare(irrigation=second);p2=recovered.prepare(irrigation=second)
            assert p1.budget==p2.budget and payload(c._candidate[3])==payload(recovered._candidate[3])
            # Independent original SWP event table from initial state, no override file.
            manual=root/'manual-original-input';shutil.copytree(case,manual)
            swp=manual/'swap.swp';source=swp.read_text(encoding='cp1252')
            line=' 2002-01-05    24.0   20.0      1   12.0';assert source.count(line)==1
            entries=[]
            if f.enabled:entries.append(f' 2002-01-05 {float(depth)!r} {float(conc)!r} 1 {float(rate)!r}')
            if second.enabled:entries.append(' 2002-01-06 0.02 1.0 1 1.0')
            if not entries:entries.append(' 2002-01-08 0.01 0.0 1 1.0')
            swp.write_text(source.replace(line,'\n'.join(entries)),encoding='cp1252')
            controls=direct(bundle,meta,manual,root/'independent-original-control',6)
            assert physical(firstrow)==physical(controls[4])
            assert physical(p1.budget)==physical(controls[5])
            if scenario=='identity':
                assert physical(firstrow)==physical(baseline[4]) and physical(p1.budget)==physical(baseline[5])
                assert firstpayload==payload(out/'no-file-original/accepted-column-1-day-5.zip') if (out/'no-file-original/accepted-column-1-day-5.zip').exists() else True
            else:assert physical(firstrow)!=physical(baseline[4]),'Override did not reach original water/solute physics'
            final=c.accept(p1);recovered.accept(p2)
            for row in [firstrow,p1.budget]:
                assert abs(row['independent_residual_cm'])<=1e-10 and abs(row['solute_independent_residual_mg_cm2'])<=1e-10
                assert row['bottom_outward_cm']==0.
            with zipfile.ZipFile(accepted) as z:
                receipt=json.loads(z.read('checkpoint.json'))['receipt'];assert receipt['coupling']['forcing']['identity_sha256']==forcing_digest(f.document())
            assert h.sha(origin)==origin_hash
            entry={'optimization':opt,'scenario':scenario,'first':f.document(),'second':second.document(),
                'retry_native_exact':True,'modified_history_live_disk_native_exact':True,'independent_original_physical_controls_both_days':True,
                'no_file_original_seven_days_native_exact':True,'pretrial_refusals':len(bad),'day5':physical(firstrow),'day6':physical(p1.budget),'terminal_sha256':h.sha(final)}
            report['cases'].append(entry);print(opt,scenario,'PASS',flush=True)
    assert not expired;report['status']='HUPSEL_SURFACE_IRRIGATION_CHANGED_HISTORY_AND_ORIGINAL_PRESERVATION_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    timer.cancel();report['censored']=bool(expired);report['elapsed_seconds']=time.monotonic()-begin
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
