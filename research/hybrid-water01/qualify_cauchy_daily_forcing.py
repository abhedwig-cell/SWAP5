"""Actual original Cauchy daily forcing, immutable source-bound binary reuse."""
import argparse
import contextlib
from dataclasses import replace
from datetime import date,timedelta
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,CAUCHY_FORCING,write_cauchy_case

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--opt',action='append',choices=['O0','O2'])
p.add_argument('--probe',action='store_true')
p.add_argument('--reuse-day20',type=Path,help='Previous exact current-bundle day20 files, verified before reuse')
a=p.parse_args();a.output.mkdir();base=a.workspace
idx=json.loads((base/'PROOF_INDEX.json').read_text());reference=base/idx['reference']
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','research/hybrid-water01/qualify_cauchy_daily_forcing.py']},'cases':[]}
started=[];real_start=h.start_process
def track(*args):
    proc,log=real_start(*args);started.append(proc);return proc,log
h.start_process=track
expired=[]
def stop():
    expired.append(True)
    for proc in started:
        if proc.poll() is None:proc.kill()
timer=threading.Timer(240,stop);timer.daemon=True;timer.start();begin=time.monotonic()
def rows(p):return [json.loads(l) for l in p.read_text().splitlines()]
def physical(r):return {k:v for k,v in r.items() if k not in ('coupling','revision','column','committed','candidate_only')}
def payload(p):
    with zipfile.ZipFile(p) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn):
    try:fn()
    except (ValueError,TypeError):return
    raise AssertionError('Invalid forcing/decision accepted')

try:
    for opt in a.opt or ['O0','O2']:
        item=idx['cases']['andelst-'+opt];bundle=base/item['build'];meta=json.loads((base/item['report']/'BUILD.json').read_text())
        for name in ['day_donor','day_kernel']:
            if os.name!='nt':h.executable(bundle,name).chmod(0o755)
        out=a.output/opt;out.mkdir();cut=2
        origin=base/item['continuous']/f'accepted-column-1-day-{cut}.zip'
        initial_hash=h.sha(origin);compatible=origin
        inherited=a.reuse_day20/opt/'warm-2-to-20/accepted-column-1-day-20.zip' if a.reuse_day20 else None
        if not a.probe and inherited is not None and inherited.exists():
            h.verify_checkpoint(inherited,20,meta['binding'],out/'verified-reused-day20')
            import shutil
            compatible=out/'accepted-origin-day-20.zip';shutil.copyfile(inherited,compatible)
            assert h.sha(inherited)==h.sha(compatible);cut=20
        elif not a.probe:
            # Old day20 in the capsule has a different build binding. Produce
            # current day20 once from its exact accepted2; never rebind old ZIPs.
            prefix=out/'warm-2-to-20';prefix.mkdir();unpacked=prefix/'origin'
            receipt=h.verify_checkpoint(origin,2,meta['binding'],unpacked)
            with contextlib.ExitStack() as stack:
                host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),
                    reference/'distribution/SWAP_4.3.1/cases'/h.ANDELST.case,prefix,
                    [h.ColumnStart(day=2,origin=unpacked,receipt=receipt,name='original')],
                    runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=h.ANDELST)
                pre=[]
                for day in range(3,21):pre.append(host.step(1,checkpoint=day==20))
                host.close()
            (prefix/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in pre))
            compatible=prefix/'accepted-column-1-day-20.zip';cut=20
        coupling='actual-cauchy-'+opt
        c=CoupledDailyColumn(bundle,reference,out/'external',h.ANDELST,coupling,
            origin=compatible,day=cut,adopt_native=True,forcing_mode=CAUCHY_FORCING)
        # Actual original table endpoints for this one-day source window.
        import re
        original=(c.case/'swap.bbc').read_text(encoding='cp1252')
        head=lambda d:float(re.search(rf'(?m)^\s*{date(1998,1,1)+timedelta(days=d)}\s+([-+0-9.]+)',original)[1])
        f=c.cauchy_forcing(head(cut),head(cut+1),'original-table-exact-control')
        state=(c.day,c.revision,c.checkpoint,h.sha(c.checkpoint),c._attempt)
        for bad in [replace(f,coupling_id='foreign'),replace(f,origin_sha256='0'*64),replace(f,origin_day=cut+1),
                    replace(f,t1_day1900=f.t1_day1900+1),replace(f,head_start_cm=float('nan')),
                    replace(f,head_end_cm=1001),replace(f,provenance=''),replace(f,head_end_cm=True)]:
            reject(lambda:c.prepare(cauchy=bad));assert state==(c.day,c.revision,c.checkpoint,h.sha(c.checkpoint),c._attempt)
        reject(lambda:c.prepare())
        first=c.prepare(cauchy=f);first_payload=payload(c._candidate[3]);first_raw=first.budget
        document=first.forcing;document['input']['head_start_cm']=999
        assert first.forcing['input']['head_start_cm']==f.head_start_cm
        reject(lambda:c.prepare(cauchy=f));c.discard(first)
        assert c.day==cut and c.revision==0 and h.sha(compatible)==state[3]
        retry=c.prepare(cauchy=f)
        assert retry.budget==first_raw and payload(c._candidate[3])==first_payload
        reject(lambda:c.accept(first))
        accepted=c.accept(retry);assert c.day==cut+1
        reject(lambda:c.prepare(cauchy=f))
        recovered=CoupledDailyColumn(bundle,reference,out/'recovered',h.ANDELST,coupling,
            origin=accepted,day=cut+1,forcing_mode=CAUCHY_FORCING)
        second=c.cauchy_forcing(head(cut+1),head(cut+2),'original-table-day2')
        p1=c.prepare(cauchy=second);p2=recovered.prepare(cauchy=second)
        assert p1.budget==p2.budget and payload(c._candidate[3])==payload(recovered._candidate[3])
        accepted2=c.accept(p1);recovered.accept(p2)
        # Corresponding original-forcing control from identical current day origin.
        control=CoupledDailyColumn(bundle,reference,out/'original-control',h.ANDELST,'original-control',
            origin=compatible,day=cut,adopt_native=True)
        reject(lambda:control.prepare(cauchy=f))
        cp=control.prepare();assert physical(cp.budget)==physical(first_raw) and payload(control._candidate[3])==first_payload
        control.discard(cp)
        # Independent source case uses unchanged DailyHost with manually selected
        # original table +0.001cm endpoint, not the new table-writing function.
        shifted=CoupledDailyColumn(bundle,reference,out/'shifted',h.ANDELST,coupling+'-shift',
            origin=compatible,day=cut,adopt_native=True,forcing_mode=CAUCHY_FORCING)
        sf=shifted.cauchy_forcing(head(cut),head(cut+1)+.001,'caller-shifted-one-day-endpoint')
        sp=shifted.prepare(cauchy=sf)
        assert physical(sp.budget)!=physical(first_raw),'Cauchy forcing did not reach original physics'
        manual=out/'manual-original-case'
        import shutil
        shutil.copytree(shifted.case,manual)
        bbc=manual/'swap.bbc';text=bbc.read_text(encoding='cp1252')
        end_date=date(1998,1,1)+timedelta(days=cut+1)
        text,count=re.subn(rf'(?m)^([ \t]*{end_date}[ \t]+)([-+0-9.]+)',
                           lambda m:m[1]+repr(float(m[2])+.001),text)
        assert count==1;bbc.write_text(text,encoding='cp1252')
        direct=out/'manual-control';direct.mkdir();unpacked=direct/'origin'
        receipt=h.verify_checkpoint(compatible,cut,meta['binding'],unpacked)
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),manual,direct,
                [h.ColumnStart(day=cut,origin=unpacked,receipt=receipt,name='original')],runtime=True,
                checkpoint_enabled=True,binding={**meta['binding'],'manual_cauchy_control':h.sha(bbc)},project=h.ANDELST)
            expected=host.step(1,checkpoint=True);host.close()
        assert physical(expected)==physical(sp.budget)
        assert payload(direct/f'accepted-column-1-day-{cut+1}.zip')==payload(shifted._candidate[3])
        (direct/'daily.jsonl').write_text(json.dumps(expected)+'\n')
        shifted.accept(sp)
        assert h.sha(origin)==initial_hash
        (out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
        result={'optimization':opt,'cut':cut,'end':cut+2,'original_origin_sha256':initial_hash,
            'compatible_origin_sha256':h.sha(compatible),'exact_original_control':True,'exact_retry_and_recovery':True,
            'exact_independently_edited_original_head_control':True,
            'invalid_pretrial_cases':8,'actual_head_perturbation_cm':.001,'unshifted_bottom_cm':first_raw['bottom_outward_cm'],
            'shifted_bottom_cm':sp.budget['bottom_outward_cm'],'external_terminal_sha256':h.sha(accepted2)}
        report['cases'].append(result);print(json.dumps(result),flush=True)
    assert not expired
    report['status']='ACTUAL_ORIGINAL_CAUCHY_DAILY_FORCING_RETRY_RECOVERY_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    timer.cancel();report['censored']=bool(expired);report['elapsed_seconds']=time.monotonic()-begin
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
