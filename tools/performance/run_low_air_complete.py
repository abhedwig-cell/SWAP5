#!/usr/bin/env python3
"""Execute the original complete B19 48-program low-air preservation matrix.

Explicit numerical policy and fine-worker lifetime are the only candidate driver
edits. All periods, physical configurations and original assertions remain.
Verified provider reuse is labelled warm; it is never a cold/10x claim.
"""
import argparse, concurrent.futures, hashlib, json, os, pathlib, re, subprocess, threading, time
from low_air_fine_worker_recipe import reuse_fine_workspace

ROOT = pathlib.Path(__file__).resolve().parents[2]
MATRIX = {
    'ppa_wu05b8_low_air_runtime': 0,
    'ppa_wu05b10_low_air_response_runtime': 0,
    'ppa_wu05b11_low_air_runtime': 0,
    'ppa_wu05b12_low_air_runtime': 5,
    'ppa_wu05b13_low_air_runtime': 6,
    'ppa_wu05b14_low_air_runtime': 4,
    'ppa_wu05b15_low_air_runtime': 6,
}

def sha(path):
    return hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest()

def candidate_recipe(text, fine_worker=True):
    for old, new in [
        ('    config%transaction%retry_scale = 0.5_real64', '    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64'),
        ('    cfg%numerical%transaction%retry_scale=.5_real64', '    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64'),
    ]:
        if text.count(old) != 1:
            raise ValueError('original policy configuration drift')
        text = text.replace(old, new)
    return reuse_fine_workspace(text) if fine_worker else text

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-o0', type=pathlib.Path, required=True)
    parser.add_argument('--build-o2', type=pathlib.Path, required=True)
    parser.add_argument('--output', type=pathlib.Path, required=True)
    parser.add_argument('--policy', choices=['baseline', 'candidate'], required=True)
    parser.add_argument('--build-workers', type=int, choices=range(1, 5), default=1)
    parser.add_argument('--workers', type=int, choices=range(1, 5), default=4)
    parser.add_argument('--only-program', choices=MATRIX)
    parser.add_argument('--only-family', type=int)
    parser.add_argument('--fresh-build', action='store_true', help='Require a complete fresh build manifest instead of inherited qualified objects.')
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    start = time.monotonic()
    parent_start = time.process_time()
    report = {'scope': 'FULL_ORIGINAL_48_LOW_AIR_WARM_PROVIDERS', 'policy': args.policy,
              'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'source_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD:src'], cwd=ROOT, text=True).strip(),
              'matrix': MATRIX, 'builds': {}, 'events': [], 'runs': [], 'complete': False,
              'workers': args.workers, 'build_workers': args.build_workers, 'tenfold_proved': False, 'canonical_admission': False}
    if args.only_program or args.only_family:
        report['scope'] = 'BOUNDED_FULL_DRIVER_DIAGNOSIS_NOT_48_QUALIFICATION'
    lock = threading.Lock()
    def persist():
        (out / 'RESULTS.json').write_text(json.dumps(report, indent=2) + '\n')
    def execute(command, label, stdout, stderr):
        started = time.monotonic()
        with stdout.open('w') as so, stderr.open('w') as se:
            process = subprocess.Popen(command, stdout=so, stderr=se, env={**os.environ, 'GFORTRAN_UNBUFFERED_ALL': 'y'})
            _, status, usage = os.wait4(process.pid, 0)
            process.returncode = os.waitstatus_to_exitcode(status)
        return {'label': label, 'command': command, 'wall': time.monotonic() - started,
                'cpu': usage.ru_utime + usage.ru_stime, 'exit': process.returncode}
    tasks = []
    build_tasks = []
    def build_driver(folder, name, opt, flags, manifest_flags, providers, extras, driver, obj, program):
        for label, command in [
            ('compile', ['gfortran', *flags, '-c', str(driver), '-o', str(obj)]),
            ('link', ['gfortran', *manifest_flags, *map(str, providers + extras), str(obj), '-o', str(program)]),
        ]:
            event = execute(command, f'{label}-{name}-o{opt}', folder / f'{name}-{label}.stdout', folder / f'{name}-{label}.stderr')
            with lock:
                report['events'].append(event)
                persist()
            if event['exit']: raise RuntimeError('compile/link failed')
    for opt, build in [(0, args.build_o0.resolve()), (2, args.build_o2.resolve())]:
        manifest = json.loads((build / 'RESULTS.json').read_text())
        if manifest['compiler'] != subprocess.check_output(['gfortran', '--version'], text=True):
            raise ValueError('compiler drift')
        for path, expected in manifest['sources'].items():
            if sha(path) != expected:
                raise ValueError('build source drift ' + path)
        if (build / 'mod_canonical_interval_runtime.f90').read_bytes() != (ROOT / 'src/runtime/mod_canonical_interval_runtime.f90').read_bytes():
            raise ValueError('compiled numerical provider drift')
        providers = [build / f'{i}.o' for i in range(len(manifest['ordered_sources']) - 1)]
        if args.fresh_build:
            provider_only = manifest.get('provider_only', False)
            expected_events = ({f'compile-{i}' for i in range(len(manifest['ordered_sources']) - 1)} if provider_only else {f'compile-{i}' for i in range(len(manifest['ordered_sources']))} | {'link'})
            terminal = 'PROVIDERS_ONLY_NOT_QUALIFICATION' if provider_only else 'BUILD_ONLY_NOT_QUALIFICATION'
            events = manifest['events']
            if manifest.get('terminal_status') != terminal or manifest.get('profile') or len(events) != len(expected_events) or {event['label'] for event in events} != expected_events or any(event['exit'] != 0 for event in events):
                raise ValueError('incomplete/instrumented fresh provider build')
            prior = {'objects': {str(path): sha(path) for path in providers}}
        else:
            # Completed science binds every reused artifact. Freshly compiled
            # providers instead acquire qualification through this native matrix.
            qualification = build.parent / f'qual-o{opt}'
            from verify_low_air_ab import verify
            verify(qualification)
            prior = json.loads((qualification / 'RESULTS.json').read_text())
            if prior['build_manifest_sha256'] != sha(build / 'RESULTS.json'):
                raise ValueError('completed provider binding drift')
            for path, expected in prior['objects'].items():
                if sha(path) != expected:
                    raise ValueError('provider object drift ' + path)
            if set(prior['objects']) != set(map(str, providers)):
                raise ValueError('provider set drift')
        folder = out / f'o{opt}'
        folder.mkdir()
        flags = manifest['flags'] + ['-J', str(build), '-I', str(build)]
        existing = {pathlib.Path(path).name for path in manifest['ordered_sources']}
        extras = []
        inputs = {}
        for name in ['mod_ppa_wu05b12_analytic_fixture', 'mod_ppa_wu05b13_empirical_fixture', 'mod_ppa_wu05b14_extended_fixture']:
            path = ROOT / f'tests/frost/{name}.f90'
            if path.name in existing:
                continue
            obj = folder / (name + '.o')
            command = ['gfortran', *flags, '-c', str(path), '-o', str(obj)]
            event = execute(command, f'extra-{name}-o{opt}', folder / (name + '.stdout'), folder / (name + '.stderr'))
            report['events'].append(event)
            persist()
            if event['exit']:
                raise RuntimeError('extra fixture compile failed')
            extras.append(obj)
            inputs[str(path.relative_to(ROOT))] = sha(path)
        report['builds'][opt] = {'manifest_sha256': sha(build / 'RESULTS.json'), 'compiler': manifest['compiler'],
                                'flags': manifest['flags'], 'providers': prior['objects'], 'extra_inputs': inputs}
        for name, families in MATRIX.items():
            if args.only_program and args.only_program != name:
                continue
            original = ROOT / f'tests/frost/test_{name}.f90'
            text = original.read_text()
            if args.policy == 'candidate':
                text = candidate_recipe(text, fine_worker=True)
            driver = folder / (name + '.f90')
            driver.write_text(text)
            obj = folder / (name + '.o')
            program = folder / name
            task = (folder, name, opt, flags, manifest['flags'], providers, extras, driver, obj, program)
            if args.build_workers == 1:
                build_driver(*task)
            else:
                if re.search(r'^\s*module\s+(?!procedure\b)', driver.read_text(), re.I | re.M):
                    raise ValueError('parallel main compilation must not publish shared modules')
                build_tasks.append(task)
            for family in (range(1, families + 1) if families else [None]):
                if args.only_family and family != args.only_family:
                    continue
                tasks.append((opt, name, family, program, sha(original), sha(driver), families))
    if build_tasks:
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.build_workers) as pool:
            list(pool.map(lambda task: build_driver(*task), build_tasks))
    persist()
    def run(task):
        opt, name, family, program, original_sha, recipe_sha, families = task
        label = f'o{opt}-{name}-family-{family}'
        stdout, stderr = out / (label + '.stdout'), out / (label + '.stderr')
        print('START ' + label, flush=True)
        record = execute([str(program)] + ([str(family)] if family else []), label, stdout, stderr)
        text = stdout.read_text()
        record.update(optimization=opt, program=name, family=family, original_sha256=original_sha,
                      recipe_sha256=recipe_sha, binary_sha256=sha(program), stdout_sha256=sha(stdout),
                      fine_comparisons=text.count('FINE_COMPARISON'),
                      counters=[list(map(int, row)) for row in re.findall(r'substeps=\s*(\d+)\s+rejections=\s*(\d+)', text)])
        record['complete'] = record['exit'] == 0 and text.count('_RUNTIME=PASS') == 1 and record['fine_comparisons'] == 6
        for head, temperature in re.findall(r'FINE_COMPARISON head_cm=\s*(\S+) temperature_c=\s*(\S+)', text):
            record['complete'] = record['complete'] and 0 <= float(head) <= 1.e-6 and 0 <= float(temperature) <= 1.e-4
        with lock:
            report['runs'].append(record)
            persist()
        print(json.dumps(record), flush=True)
        if not record['complete']:
            raise RuntimeError('original complete driver failed: ' + label)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        list(pool.map(run, tasks))
    for name, families in MATRIX.items():
        if args.only_program and args.only_program != name:
            continue
        for family in (range(1, families + 1) if families else [None]):
            if args.only_family and args.only_family != family:
                continue
            stem = f'{name}-family-{family}.stdout'
            if (out / ('o0-' + stem)).read_bytes() != (out / ('o2-' + stem)).read_bytes():
                raise ValueError('O0/O2 scientific output drift')
    report['complete'] = True
    report['native_cpu'] = sum(run['cpu'] for run in report['runs'])
    report['build_link_cpu'] = sum(event['cpu'] for event in report['events'])
    report['parent_cpu'] = time.process_time() - parent_start
    report['whole_wall'] = time.monotonic() - start
    report['cold_provider_build'] = 'FRESH_BUILDS_MEASURED_BY_ENCLOSING_CONTROLLER' if args.fresh_build else 'EXCLUDED_VERIFIED_WARM_PROVIDERS'
    persist()
    print(json.dumps({key: report[key] for key in ['scope', 'complete', 'whole_wall', 'native_cpu', 'build_link_cpu', 'parent_cpu']}), flush=True)

if __name__ == '__main__':
    main()
