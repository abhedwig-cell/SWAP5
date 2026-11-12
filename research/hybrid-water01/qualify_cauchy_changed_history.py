"""Actual second-day Cauchy recovery from modified accepted physical state."""
import argparse
import contextlib
from datetime import date,timedelta
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,CAUCHY_FORCING
p=argparse.ArgumentParser(description=__doc__)
for n in ['workspace','origins','output']:p.add_argument('--'+n,type=Path,required=True)
a=p.parse_args();a.output.mkdir();idx=json.loads((a.workspace/'PROOF_INDEX.json').read_text())
reference=a.workspace/idx['reference'];started=[];expired=[];real_start=h.start_process
def track(*args):
    proc,log=real_start(*args);started.append(proc);return proc,log
h.start_process=track
def stop():
    expired.append(True)
    for proc in started:
        if proc.poll() is None:proc.kill()
timer=threading.Timer(120,stop);timer.daemon=True;timer.start();begin=time.monotonic()
sources=['app/hybrid_water/daily_coupling.py','app/hybrid_water/daily_host.py','research/hybrid-water01/qualify_cauchy_changed_history.py']
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'sources':{n:h.sha(ROOT/n) for n in sources},'cases':[]}
def physical(r):return {k:v for k,v in r.items() if k not in ('coupling','revision','column','committed','candidate_only')}
def payload(p):
    with zipfile.ZipFile(p) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn):
    try:fn()
    except (ValueError,TypeError):return
    raise AssertionError('Stale decision/input accepted')
try:
    for opt in ['O0','O2']:
        item=idx['cases']['andelst-'+opt];bundle=a.workspace/item['build'];meta=json.loads((bundle/'BUILD.json').read_text())
        for name in ['day_donor','day_kernel']:
            if os.name!='nt':h.executable(bundle,name).chmod(0o755)
        out=a.output/opt;out.mkdir();candidates=[a.origins/opt/'accepted-origin-day-20.zip',
            a.origins/opt/'warm-2-to-20/accepted-column-1-day-20.zip']
        found=[x for x in candidates if x.exists()];assert found,'Required published day20 origin absent; no warm-prefix fallback'
        source=found[0];h.verify_checkpoint(source,20,meta['binding'],out/'verified-inherited-day20')
        origin=out/'accepted-origin-day-20.zip';shutil.copyfile(source,origin);assert h.sha(origin)==h.sha(source)
        cid='changed-cauchy-'+opt
        c=CoupledDailyColumn(bundle,reference,out/'external',h.ANDELST,cid,origin=origin,day=20,
                             adopt_native=True,forcing_mode=CAUCHY_FORCING)
        original=(c.case/'swap.bbc').read_text(encoding='cp1252')
        def head(day):
            stamp=date(1998,1,1)+timedelta(days=day)
            return float(re.search(rf'(?m)^\s*{stamp}\s+([-+0-9.]+)',original)[1])
        requests=[];rows=[];digests=[]
        parent=origin;parent_binding=meta['binding']
        for offset in [0,1]:
            day=20+offset
            f=c.cauchy_forcing(head(day)+(0 if offset==0 else .001),head(day+1)+(.001 if offset==0 else .002),
                               'actual-changed-history-day-'+str(day+1))
            requests.append(f.document());state=(c.day,c.revision,h.sha(c.checkpoint))
            if offset:
                reject(lambda:c.prepare(cauchy=previous))
                recovered=CoupledDailyColumn(bundle,reference,out/'recovered',h.ANDELST,cid,origin=parent,day=day,forcing_mode=CAUCHY_FORCING)
            trial=c.prepare(cauchy=f);data=payload(c._candidate[3]);row=trial.budget
            c.discard(trial);assert state==(c.day,c.revision,h.sha(c.checkpoint))
            retry=c.prepare(cauchy=f);assert retry.budget==row and payload(c._candidate[3])==data
            reject(lambda:c.accept(trial))
            if offset:
                disk=recovered.prepare(cauchy=f);assert disk.budget==row and payload(recovered._candidate[3])==data
            # Independently edit the full original table; do not call the adapter writer.
            manual=out/f'manual-case-{day}';shutil.copytree(c.case,manual);text=original
            for stamp,value in [(date(1998,1,1)+timedelta(days=day),f.head_start_cm),
                                (date(1998,1,1)+timedelta(days=day+1),f.head_end_cm)]:
                def edit(m):return m[0] if float(m[2])==value else m[1]+repr(float(value))
                text,count=re.subn(rf'(?m)^([ \t]*{stamp}[ \t]+)([-+0-9.]+)',edit,text);assert count==1
            (manual/'swap.bbc').write_text(text,encoding='cp1252')
            direct=out/f'manual-control-{day}';direct.mkdir();unpacked=direct/'origin'
            receipt=h.verify_checkpoint(parent,day,parent_binding,unpacked)
            with contextlib.ExitStack() as stack:
                host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),manual,direct,
                    [h.ColumnStart(day=day,origin=unpacked,receipt=receipt,name='original')],runtime=True,checkpoint_enabled=True,
                    binding={**meta['binding'],'independent_cauchy_control':h.sha(manual/'swap.bbc')},project=h.ANDELST)
                expected=host.step(1,checkpoint=True);host.close()
            assert physical(expected)==physical(row)
            assert payload(direct/f'accepted-column-1-day-{day+1}.zip')==data
            (direct/'daily.jsonl').write_text(json.dumps(expected)+'\n')
            accepted=c.accept(retry)
            if offset:
                recovered.accept(disk);assert payload(accepted)==payload(recovered.checkpoint)
            assert h.sha(origin)==h.sha(source)
            rows.append(physical(row));digests.append(h.sha(accepted));parent,parent_binding=accepted,c.binding;previous=f
        (out/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
        entry={'optimization':opt,'origin_day':20,'end_day':22,'origin_sha256':h.sha(origin),'requests':requests,'physical_days':rows,
               'exact_native_retry_both_days':True,'exact_native_modified_history_live_disk_recovery':True,
               'exact_independent_original_input_physical_and_native_both_days':True,'accepted_sha256':digests}
        report['cases'].append(entry);print(opt,'modified-state Cauchy two-day PASS',flush=True)
    assert not expired;report['status']='CAUCHY_ACTUAL_MODIFIED_HISTORY_RETRY_RECOVERY_ORIGINAL_CONTROL_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    timer.cancel();report['censored']=bool(expired);report['elapsed_seconds']=time.monotonic()-begin
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
