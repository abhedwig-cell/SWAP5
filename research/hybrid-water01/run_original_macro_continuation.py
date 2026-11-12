"""Source-bound original macro continuation with explicitly selected checkpoints."""
import argparse
import contextlib
import json
import math
from pathlib import Path
import sys
import threading
import time
import traceback

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('bundle','reference','checkpoint','output'):
        p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--cut',type=int,required=True)
    p.add_argument('--end',type=int,required=True)
    p.add_argument('--seconds',type=float,default=20)
    p.add_argument('--checkpoint-days',type=int,nargs='*')
    p.add_argument('--compare-journal',type=Path)
    a=p.parse_args()
    if not 0<a.cut<a.end<=481 or not 0<a.seconds<=60:
        raise ValueError('Original project period and short explicit cost bound required')
    cuts=set(a.checkpoint_days if a.checkpoint_days is not None else [a.end])
    if a.end not in cuts or any(not a.cut<d<=a.end for d in cuts):
        raise ValueError('Checkpoint selection must include end and lie in window')
    a.output.mkdir(parents=True,exist_ok=False)
    validation_start=time.perf_counter()
    meta,case=validate_bundle(a.bundle,a.reference,h.ANDELST)
    receipt=h.verify_checkpoint(a.checkpoint,a.cut,meta['binding'],a.output/'origin')
    expected={}
    if a.compare_journal:
        previous=json.loads(a.compare_journal.with_name('RESULT.json').read_text())
        if previous['build']!=meta:raise ValueError('Overlap comparator has another source/build')
        expected={row['day']:row for row in map(json.loads,a.compare_journal.read_text().splitlines())}
    report={'status':'RUNNING','origin_checkpoint_sha256':h.sha(a.checkpoint),
        'build':meta,'origin_day':a.cut,'requested_end_day':a.end,'cap_seconds':a.seconds,
        'selected_checkpoint_days':sorted(cuts),'last_accepted_day':a.cut,
        'last_durable_day':a.cut,'maximum_daily_residual_cm':0.0,'step_timings':[],
        'mass_step_retries':0,'validation_seconds':time.perf_counter()-validation_start}
    report['overlap_journal_sha256']=h.sha(a.compare_journal) if a.compare_journal else None
    report['overlap_days_exact']=[]
    workers=[];expired=threading.Event();original=h.start_process;residuals=[]
    def start(*args,**kwargs):
        result=original(*args,**kwargs);workers.append(result[0]);return result
    def timeout():
        expired.set()
        for worker in workers:
            if worker.poll() is None:worker.kill()
    def persist():
        report['model_and_controller_wall_seconds']=time.perf_counter()-started
        (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    h.start_process=start;started=time.perf_counter();timer=threading.Timer(a.seconds,timeout);timer.start()
    try:
        with contextlib.ExitStack() as stack,(a.output/'daily.jsonl').open('x') as journal:
            host=h.DailyHost(stack,h.executable(a.bundle,'day_donor'),h.executable(a.bundle,'day_kernel'),case,a.output,
                [h.ColumnStart(day=a.cut,origin=a.output/'origin',receipt=receipt,name='original')],
                runtime=True,checkpoint_enabled=True,binding=meta['binding'])
            report['initialization_seconds']=time.perf_counter()-started
            for day in range(a.cut+1,a.end+1):
                before=time.perf_counter();row=host.step(1,checkpoint=day in cuts)
                report['step_timings'].append({'day':day,'seconds':time.perf_counter()-before,'checkpoint':day in cuts})
                if day in expected:
                    keys=[k for k in row if k!='revision' and row[k]!=expected[day][k]]
                    if keys:
                        report['overlap_mismatch']={'day':day,'fields':keys,
                            'expected':{k:expected[day][k] for k in keys},'actual':{k:row[k] for k in keys}}
                        raise ValueError('Own durable restart changes retained accepted physical history')
                    report['overlap_days_exact'].append(day)
                journal.write(json.dumps(row)+'\n');journal.flush()
                if not row['committed']:raise ValueError('Unchanged daily acceptance refused candidate')
                residuals.append(row['independent_residual_cm'])
                report['last_accepted_day']=day
                if day in cuts:report['last_durable_day']=day
                report['maximum_daily_residual_cm']=max(report['maximum_daily_residual_cm'],abs(residuals[-1]))
                report['signed_water_residual_cm']=math.fsum(residuals)
                report['mass_step_retries']+=row['budget_step_retries']
                persist()
            host.close();report['status']='ORIGINAL_MACRO_CONTINUATION_COMPLETE'
    except Exception:
        report.update(status='MODEL_CAP_REACHED' if expired.is_set() else 'FAILED',error=traceback.format_exc())
    finally:
        timer.cancel()
        for worker in workers:
            if worker.poll() is None:worker.kill()
            worker.wait(timeout=10)
        persist()
    print(json.dumps({k:report[k] for k in ('status','last_accepted_day','last_durable_day','model_and_controller_wall_seconds','mass_step_retries')}))
    return 0 if report['status']=='ORIGINAL_MACRO_CONTINUATION_COMPLETE' else 2


if __name__=='__main__':raise SystemExit(main())
