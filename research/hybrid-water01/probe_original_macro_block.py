"""Bounded own-history replay of the opt-in macro candidate, never an admission gate."""
import argparse
import contextlib
import json
from pathlib import Path
import sys
import threading
import time
import traceback

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle', type=Path, required=True)
    p.add_argument('--reference', type=Path, required=True)
    p.add_argument('--checkpoint', type=Path)
    p.add_argument('--cut', type=int, default=2)
    p.add_argument('--end', type=int, default=4)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--cap-seconds', type=float, default=20)
    a = p.parse_args()
    if not 0 < a.cap_seconds <= 45:
        raise ValueError('Short discriminating probe only')
    cut=a.cut if a.checkpoint else 0
    if not 0<=cut<a.end<=min(481,cut+22):
        raise ValueError('Only bounded original-project windows are allowed')
    a.output.mkdir(parents=True, exist_ok=False)
    meta, case = validate_bundle(a.bundle, a.reference, h.ANDELST)
    receipt = h.verify_checkpoint(a.checkpoint, cut, meta['binding'], a.output / 'origin') if a.checkpoint else None
    report = dict(status='RUNNING', build=meta, origin_sha256=h.sha(a.checkpoint) if a.checkpoint else None,
                  cap_seconds=a.cap_seconds, rows=[], requested_day=None,origin_day=cut,end_day=a.end)
    target = a.output / 'RESULT.json'
    workers = []
    original_start = h.start_process
    expired = threading.Event()

    def start(*args, **kwargs):
        result = original_start(*args, **kwargs)
        workers.append(result[0])
        return result

    def timeout():
        expired.set()
        for worker in workers:
            if worker.poll() is None:
                worker.kill()

    def persist():
        report['elapsed_seconds'] = time.perf_counter() - started
        target.write_text(json.dumps(report, indent=2) + '\n')

    h.start_process = start
    started = time.perf_counter()
    timer = threading.Timer(a.cap_seconds, timeout)
    timer.start()
    try:
        with contextlib.ExitStack() as stack:
            host = h.DailyHost(stack, h.executable(a.bundle, 'day_donor'),
                h.executable(a.bundle, 'day_kernel'), case, a.output,
                [h.ColumnStart(day=cut, origin=a.output / 'origin' if receipt else None, receipt=receipt, name='original')],
                runtime=True, checkpoint_enabled=True, binding=meta['binding'])
            report['initial_state_exact'] = receipt is not None
            for day in range(cut+1,a.end+1):
                report['requested_day'] = day
                persist()
                row = host.step(1, checkpoint=True)
                report['rows'].append(row)
                persist()
                if not row['committed']:
                    raise ValueError('Daily mass gate refused candidate')
            host.close()
            report['status'] = ('OWN_RESTART_2_TO_4_COMPLETE' if (cut,a.end)==(2,4) else 'OWN_RESTART_WINDOW_COMPLETE') if receipt else ('FRESH_4_DAYS_COMPLETE' if a.end==4 else 'FRESH_WINDOW_COMPLETE')
    except Exception:
        report['status'] = 'MODEL_CAP_REACHED' if expired.is_set() else 'FAILED'
        report['error'] = traceback.format_exc()
    finally:
        timer.cancel()
        for worker in workers:
            if worker.poll() is None:
                worker.kill()
            worker.wait(timeout=10)
        persist()
    print(json.dumps({k: report[k] for k in ('status', 'elapsed_seconds', 'requested_day')}))
    return 0 if report['status'] in ('OWN_RESTART_2_TO_4_COMPLETE', 'FRESH_4_DAYS_COMPLETE','OWN_RESTART_WINDOW_COMPLETE','FRESH_WINDOW_COMPLETE') else 2


if __name__ == '__main__':
    raise SystemExit(main())
