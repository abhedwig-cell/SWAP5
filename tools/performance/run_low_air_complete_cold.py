#!/usr/bin/env python3
"""Cold original 48-program qualification with actual enclosing wall and CPU.

No source/object/PASS reuse. This receipt alone cannot prove a matched 10x A/B.
"""
import argparse, concurrent.futures, json, os, pathlib, subprocess, threading, time
ROOT = pathlib.Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--fast-builds', action='store_true', help='Parallel isolated provider/main builds; omit unused bootstrap compilation.')
    parser.add_argument('--policy', choices=['baseline', 'candidate'], required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    start, own_start = time.monotonic(), time.process_time()
    events = []
    lock = threading.Lock()
    def execute(label, command):
        began = time.monotonic()
        with (out / (label + '.stdout')).open('w') as so, (out / (label + '.stderr')).open('w') as se:
            child = subprocess.Popen(command, cwd=ROOT, stdout=so, stderr=se, env={**os.environ, 'GFORTRAN_UNBUFFERED_ALL': 'y'})
            _, status, usage = os.wait4(child.pid, 0)
            child.returncode = os.waitstatus_to_exitcode(status)
        event = {'label': label, 'command': command, 'exit': child.returncode,
                 'wall': time.monotonic() - began, 'cpu': usage.ru_utime + usage.ru_stime}
        with lock:
            events.append(event)
            (out / 'EVENTS.json').write_text(json.dumps(events, indent=2) + '\n')
        print(json.dumps(event), flush=True)
        if event['exit']:
            raise RuntimeError('retain failed/censored cold stage ' + label)
    provider_start = time.monotonic()
    if args.fast_builds:
        def build(opt):
            execute(f'providers-o{opt}', ['python', str(ROOT / 'tools/performance/build_low_air_providers.py'),
                    '--output', str(out / f'build-o{opt}'), '--opt', str(opt)])
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(build, [0, 2]))
    else:
        for opt in [0, 2]:
            execute(f'providers-o{opt}', ['python', str(ROOT / 'tools/performance/run_low_air_diagnosis.py'),
                    '--output', str(out / f'build-o{opt}'), '--opt', str(opt), '--full-driver', '--policy', '--build-only'])
    provider_phase_wall = time.monotonic() - provider_start
    execute('full-matrix', ['python', str(ROOT / 'tools/performance/run_low_air_complete.py'),
            '--build-o0', str(out / 'build-o0'), '--build-o2', str(out / 'build-o2'),
            '--output', str(out / 'matrix'), '--policy', args.policy, '--workers', '4', '--fresh-build'] + (['--build-workers', '4'] if args.fast_builds else []))
    execute('full-verification', ['python', str(ROOT / 'tools/performance/verify_low_air_complete.py'),
            str(out / 'matrix'), '--check-binaries'])
    report = {'scope': 'COMPLETE_ORIGINAL_48_LOW_AIR_COLD_PROVIDERS', 'policy': args.policy,
              'build_mode': 'PARALLEL_ISOLATED_PROVIDERS_AND_MAIN_OBJECTS' if args.fast_builds else 'SEQUENTIAL_PROVIDERS_AND_MAIN_OBJECTS',
              'provider_phase_wall': provider_phase_wall,
              'whole_wall': time.monotonic() - start, 'whole_cpu': time.process_time() - own_start + sum(event['cpu'] for event in events),
              'events': events, 'original_programs': 48, 'original_fine_comparisons': 288,
              'tenfold_proved': False, 'canonical_admission': False}
    (out / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'events'}), flush=True)

if __name__ == '__main__':
    main()
