"""Bounded real external discard/replay and cold recovery of original macro block."""
import argparse
import json
from pathlib import Path
import sys
import threading
import time
import traceback
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn


def payload(path):
    with zipfile.ZipFile(path) as z:
        return {n: z.read(n) for n in h.CHECKPOINT_FILES}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('bundle','reference','checkpoint','control','output'):
        p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    report={'status':'RUNNING','cap_seconds':20};workers=[];expired=threading.Event()
    original=h.start_process
    def start(*args,**kwargs):
        result=original(*args,**kwargs);workers.append(result[0]);return result
    def timeout():
        expired.set()
        for worker in workers:
            if worker.poll() is None:worker.kill()
    h.start_process=start;timer=threading.Timer(20,timeout);started=time.perf_counter();timer.start()
    try:
        owner=CoupledDailyColumn(a.bundle,a.reference,a.output/'owner',h.ANDELST,
            'macro-block-discard',origin=a.checkpoint,day=2,adopt_native=True)
        before=(owner.day,owner.revision,owner.checkpoint,h.sha(owner.checkpoint))
        first=owner.prepare();first_budget=first.budget
        first_payload=payload(owner._candidate[3])
        assert (owner.day,owner.revision,owner.checkpoint,h.sha(owner.checkpoint))==before
        owner.discard(first)
        assert (owner.day,owner.revision,owner.checkpoint,h.sha(owner.checkpoint))==before
        try:owner.accept(first)
        except ValueError:pass
        else:raise AssertionError('Discarded proposal accepted')
        second=owner.prepare()
        assert first_budget==second.budget
        assert first_payload==payload(owner._candidate[3])
        report.update(origin_unchanged=True, discarded_proposal_rejected=True,
            repeated_receipt_exact=True,repeated_complete_native_payload_exact=True)
        accepted=owner.accept(second)
        restored=CoupledDailyColumn(a.bundle,a.reference,a.output/'recovered',h.ANDELST,
            'macro-block-discard',origin=accepted,day=3)
        final=restored.accept(restored.prepare())
        actual,expected=payload(final),payload(a.control)
        report['cold_day3_to4_differing_bytes']={n:sum(x!=y for x,y in zip(actual[n],expected[n]))
            if len(actual[n])==len(expected[n]) else 'different lengths' for n in actual}
        with zipfile.ZipFile(final) as z,zipfile.ZipFile(a.control) as w:
            actual_receipt=json.loads(z.read('checkpoint.json'))['receipt']
            expected_receipt=json.loads(w.read('checkpoint.json'))['receipt']
        report['cold_day3_to4_physical_receipt_exact']=all(
            actual_receipt[k]==v for k,v in expected_receipt.items() if k!='revision')
        assert actual==expected, 'Complete auxiliary restart differs; physical equality is insufficient'
        report.update(status='DISCARD_REPLAY_COLD_RECOVERY_PASS',origin_unchanged=True,
            discarded_proposal_rejected=True,repeated_receipt_exact=True,
            repeated_complete_native_payload_exact=True,cold_day3_to4_native_exact=True,
            scope='External proposal discard; no claim of numerical rejected-timestep rollback')
    except Exception:
        report.update(status='MODEL_CAP_REACHED' if expired.is_set() else 'FAILED',error=traceback.format_exc())
    finally:
        timer.cancel()
        for worker in workers:
            if worker.poll() is None:worker.kill()
            worker.wait(timeout=10)
        report['elapsed_seconds']=time.perf_counter()-started
        (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report));return 0 if report['status']=='DISCARD_REPLAY_COLD_RECOVERY_PASS' else 2


if __name__=='__main__':raise SystemExit(main())
