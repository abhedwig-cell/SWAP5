#!/usr/bin/env python3
"""Cold original 48-program qualification with actual enclosing wall and CPU.

No source/object/PASS reuse. This receipt alone cannot prove a matched 10x A/B.
"""
import argparse, json, os, pathlib, subprocess, time
ROOT = pathlib.Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--policy', choices=['baseline', 'candidate'], required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    start, own_start = time.monotonic(), time.process_time()
    events = []
    def execute(label, command):
        began = time.monotonic()
        with (out / (label + '.stdout')).open('w') as so, (out / (label + '.stderr')).open('w') as se:
            child = subprocess.Popen(command, cwd=ROOT, stdout=so, stderr=se, env={**os.environ, 'GFORTRAN_UNBUFFERED_ALL': 'y'})
            _, status, usage = os.wait4(child.pid, 0)
            child.returncode = os.waitstatus_to_exitcode(status)
        event = {'label': label, 'command': command, 'exit': child.returncode,
                 'wall': time.monotonic() - began, 'cpu': usage.ru_utime + usage.ru_stime}
        events.append(event)
        (out / 'EVENTS.json').write_text(json.dumps(events, indent=2) + '\n')
        print(json.dumps(event), flush=True)
        if event['exit']:
            raise RuntimeError('retain failed/censored cold stage ' + label)
    # Sequential provider builds avoid hidden overlap and make category clocks
    # directly additive. Native matrix uses the same global four-worker bound.
    for opt in [0, 2]:
        execute(f'providers-o{opt}', ['python', str(ROOT / 'tools/performance/run_low_air_diagnosis.py'),
                '--output', str(out / f'build-o{opt}'), '--opt', str(opt), '--full-driver', '--policy', '--build-only'])
    execute('full-matrix', ['python', str(ROOT / 'tools/performance/run_low_air_complete.py'),
            '--build-o0', str(out / 'build-o0'), '--build-o2', str(out / 'build-o2'),
            '--output', str(out / 'matrix'), '--policy', args.policy, '--workers', '4', '--fresh-build'])
    execute('full-verification', ['python', str(ROOT / 'tools/performance/verify_low_air_complete.py'),
            str(out / 'matrix'), '--check-binaries'])
    report = {'scope': 'COMPLETE_ORIGINAL_48_LOW_AIR_COLD_PROVIDERS', 'policy': args.policy,
              'whole_wall': time.monotonic() - start, 'whole_cpu': time.process_time() - own_start + sum(event['cpu'] for event in events),
              'events': events, 'original_programs': 48, 'original_fine_comparisons': 288,
              'tenfold_proved': False, 'canonical_admission': False}
    (out / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'events'}), flush=True)

if __name__ == '__main__':
    main()
