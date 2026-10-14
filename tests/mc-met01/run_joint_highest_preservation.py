#!/usr/bin/env python3
"""Original complete highest gates on the exact delegated joint successor.

Only source eligibility, output location, process scheduling and the explicitly
selected opt-in variant differ. Frozen Fortran assertions, forcing, fine counts,
tolerances, default-OFF cases and flags are retained.
"""
from pathlib import Path
import argparse
import concurrent.futures
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/modularity'))
from joint_admission_authority import verify_source, git


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--route', choices=['normal', 'low_air'], required=True)
    ap.add_argument('--policy', choices=['OFF', 'ON'], default='OFF')
    ap.add_argument('--workers', type=int, choices=[1, 2, 3], default=3)
    args = ap.parse_args()
    if args.policy == 'ON' and args.route != 'low_air':
        raise ValueError('opt-in qualification is the low-air owner route')
    source = verify_source()
    output = args.output.resolve(); output.mkdir(parents=True, exist_ok=False)
    runner = ROOT / 'tests/frost/run_ppa_wu05b15_runtime.py'
    frozen = subprocess.check_output(['git', 'show', source['baseline'] + ':' + str(runner.relative_to(ROOT))], cwd=ROOT)
    if runner.read_bytes() != frozen:
        raise ValueError('original highest runner changed')
    driver = ROOT / f'tests/frost/test_ppa_wu05b15_{args.route}_runtime.f90'
    original = driver.read_bytes()
    if subprocess.check_output(['git', 'show', source['baseline'] + ':' + str(driver.relative_to(ROOT))], cwd=ROOT) != original:
        raise ValueError('original highest driver changed')
    events = []
    identity = {'source': source, 'head': git('rev-parse', 'HEAD'), 'route': args.route,
                'policy': args.policy, 'workers': args.workers,
                'runner_sha256': sha(runner), 'original_driver_sha256': sha(driver),
                'compiler': subprocess.check_output(['gfortran', '--version'], text=True),
                'scope': 'FULL_ORIGINAL_HIGHEST_JOINT_SOURCE_NOT_FCI_ADMISSION'}
    compiler = Path(shutil.which('gfortran')).resolve()
    identity['compiler_inputs'] = {'launcher': str(compiler), 'launcher_sha256': sha(compiler),
                                  'environment_sha256': hashlib.sha256(json.dumps(dict(os.environ), sort_keys=True).encode()).hexdigest()}
    for option in ['-print-prog-name=f951', '-print-file-name=libgfortran.a',
                   '-print-file-name=libgfortran.so.5', '-print-libgcc-file-name']:
        path = Path(subprocess.check_output(['gfortran', option], text=True).strip()).resolve()
        identity['compiler_inputs'][option] = {'path': str(path), 'sha256': sha(path)}
    (output / 'IDENTITY.json').write_text(json.dumps(identity, indent=2) + '\n')
    text = frozen.decode()
    guard = 'assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source'
    assert text.count(guard) == 1
    text = text.replace(guard, guard.replace('==source', '==' + repr(source['source_tree'])))
    prefix = "prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')"
    assert text.count(prefix) == 1
    text = text.replace(prefix, "prefix='ppa-wu05b15-joint-' + args.route + '-' + " + repr(args.policy.lower()))
    build = output / ('ppa-wu05b15-joint-' + args.route + '-' + args.policy.lower())
    if args.policy == 'ON':
        policy = original.decode().replace('    config%transaction%retry_scale = 0.5_real64',
            '    config%retain_accepted_step_proposal = .true.\n    config%transaction%retry_scale = 0.5_real64').replace(
            '    cfg%numerical%transaction%retry_scale=.5_real64',
            '    cfg%numerical%retain_accepted_step_proposal=.true.\n    cfg%numerical%transaction%retry_scale=.5_real64')
        assert policy != original.decode()
        generated = output / 'policy_driver.f90'; generated.write_text(policy)
        selection = "ROOT/f'tests/frost/test_ppa_wu05b15_{args.route}_runtime.f90'"
        assert text.count(selection) == 1
        text = text.replace(selection, 'pathlib.Path(' + repr(str(generated)) + ')')
        identity['executed_driver_sha256'] = sha(generated)
    else:
        identity['executed_driver_sha256'] = sha(driver)
    # Keep every original configuration, native assertion and sorted output.
    start = text.index(' output=[]\n'); end = text.index(" (out/'output.txt').write_text", start)
    old = text[start:end]
    assert 'for configuration in range(1,7):' in old
    replacement = ''' def run_configuration(configuration):
  stdout=out/f'configuration-{configuration}.txt';stderr=out/f'configuration-{configuration}.err'
  begin=time.monotonic()
  assert all(sha(path)==digest for path,digest in artifacts.items()),'highest artifact drift before native'
  with stdout.open('w')as so,stderr.open('w')as se:
   cp=subprocess.Popen([str(out/'test'),str(configuration)],stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
   _,status,usage=os.wait4(cp.pid,0);cp.returncode=os.waitstatus_to_exitcode(status)
  value=stdout.read_text()
  record={'kind':'native','opt':opt,'configuration':configuration,'exit':cp.returncode,'wall_seconds':time.monotonic()-begin,'child_cpu_seconds':usage.ru_utime+usage.ru_stime,'stdout_sha256':sha(stdout)}
  events.append(record)
  (output/'PROGRESS.json').write_text(json.dumps({'identity':identity,'events':events},indent=2)+'\\n')
  assert cp.returncode==0
  assert all(sha(path)==digest for path,digest in artifacts.items()),'highest artifact drift after native'
  assert value.count('_RUNTIME=PASS')==1 and value.count('FINE_COMPARISON')==6
  assert 'PPA_WU05B15_EXTENDED_APPLICATION=PASS' in value and 'PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS' in value
  print(f'JOINT_HIGHEST_{args.route.upper()}_O{opt}_CONFIGURATION_{configuration}=PASS',flush=True)
  return value
 with concurrent.futures.ThreadPoolExecutor(max_workers=workers)as pool:
  output_values=list(pool.map(run_configuration,range(1,7)))
'''
    # Avoid shadowing the outer output directory with the original output list.
    text = text[:start] + replacement + text[end:]
    text = text.replace("'\n'.join(output)", "'\n'.join(output_values)")
    text = text.replace("''.join(output)", "''.join(output_values)")
    text = text.replace('subprocess.run(', 'measured_run(')
    boundary = ' def run_configuration(configuration):'
    assert text.count(boundary) == 1
    text = text.replace(boundary, " artifacts={p:sha(p)for p in out.iterdir()if p.is_file()and(p.suffix in ['.o','.mod']or p.name=='test')}\n (out/'ARTIFACTS.json').write_text(json.dumps({str(p):h for p,h in artifacts.items()},indent=2)+'\\n')\n" + boundary)
    def measured_run(command, **kwargs):
        begin = time.monotonic()
        try:
            cp = subprocess.run(command, **kwargs)
        except subprocess.CalledProcessError as error:
            events.append({'kind': 'build', 'command': command, 'exit': error.returncode,
                           'wall_seconds': time.monotonic() - begin})
            raise
        events.append({'kind': 'compile' if '-c' in command else 'link', 'command': command,
                       'exit': cp.returncode, 'wall_seconds': time.monotonic() - begin})
        return cp
    (output / 'executed_controller.py').write_text(text)
    identity['executed_controller_sha256'] = hashlib.sha256(text.encode()).hexdigest()
    (output / 'IDENTITY.json').write_text(json.dumps(identity, indent=2) + '\n')
    sys.argv = [str(runner), '--route', args.route, '--opts', '0', '2', '--build', str(build)]
    begin = time.monotonic()
    namespace = {'__file__': str(runner), '__name__': '__main__', 'measured_run': measured_run,
                 'events': events, 'identity': identity, 'output': output, 'sha': sha,
                 'time': time, 'json': json, 'workers': args.workers, 'concurrent': concurrent}
    try:
        exec(compile(text, str(runner), 'exec'), namespace)
        verify_source()
        result_dependencies = {str(p): sha(p) for p in namespace['ordered']}
        natives = [e for e in events if e['kind'] == 'native']
        assert len(natives) == 12 and all(e['exit'] == 0 for e in natives)
        assert len({(e['opt'], e['configuration']) for e in natives}) == 12
        assert (build / 'o0/output.txt').read_bytes() == (build / 'o2/output.txt').read_bytes()
        result = {'status': 'PASS', 'identity': identity, 'wall_seconds': time.monotonic() - begin,
                  'events': events, 'configurations': 12, 'fine_comparisons': 72,
                  'dependency_sha256': result_dependencies,
                  'qualified': False, 'admitted': False}
    except BaseException as error:
        (output / 'FAILED.json').write_text(json.dumps({'error': repr(error), 'identity': identity, 'events': events}, indent=2) + '\n')
        raise
    (output / 'RESULTS.json').write_text(json.dumps(result, indent=2) + '\n')
    print('JOINT_FULL_HIGHEST_O0_O2=PASS', flush=True)


if __name__ == '__main__':
    main()
