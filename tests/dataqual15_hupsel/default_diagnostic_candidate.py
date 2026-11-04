"""Default numerical runtime: exact qualified objects, private app-body successor."""
import argparse, hashlib, json, shutil, subprocess, time
from pathlib import Path
from pressure_diagnostic_candidate import ROOT, REL, candidate
from qualify_pressure_diagnostic_candidate import qualify

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
BASE = ROOT/'integration/dataqual15_hupsel'


def build(parent, out, compiler):
    pressure = json.loads((parent/'BUILD.json').read_text())
    baseline = pressure['baseline']
    opt = next(x[1:] for x in baseline['flags'] if x in ('-O0', '-O2'))
    authority = json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text())
    assert sha(parent/'BUILD.json') == authority['files_sha256']['build-'+opt+'/BUILD.json']
    assert subprocess.check_output([str(compiler), '--version'], text=True).splitlines()[0] == baseline['compiler']
    for section in ('source_sha256', 'object_sha256'):
        for name, digest in baseline[section].items(): assert sha(Path(name)) == digest, name
    provider = baseline['publication_provider']
    for key in ('source', 'object'): assert sha(Path(provider[key])) == provider[key+'_sha256']
    assert sha(Path(baseline['ttutil_archive'])) == baseline['archive_sha256']
    modules = Path(next(x[2:] for x in baseline['flags'] if x.startswith('-J')))
    out.mkdir()
    for p in modules.glob('*.mod'): shutil.copyfile(p, out/p.name)
    old_interface = sha(out/'mod_hupsel_rotation_restart.mod')
    src = out/'hupsel_rotation_restart.f90'
    src.write_text(candidate((ROOT/REL).read_text()), encoding='utf-8', newline='\n')
    flags = [x for x in baseline['flags'] if not x.startswith(('-I', '-J'))]+['-I'+str(out), '-J'+str(out)]
    events = []
    def run(cmd):
        start = time.monotonic(); r = subprocess.run(list(map(str, cmd)), cwd=out, capture_output=True, timeout=240)
        i = len(events); (out/f'{i}.stdout').write_bytes(r.stdout); (out/f'{i}.stderr').write_bytes(r.stderr)
        events.append(dict(command=list(map(str, cmd)), returncode=r.returncode, seconds=time.monotonic()-start))
        (out/'EVENTS.json').write_text(json.dumps(events, indent=2)+'\n'); assert r.returncode == 0, r.stderr
    obj = out/'rotation.o'; run([compiler, *flags, '-c', src, '-o', obj])
    assert sha(out/'mod_hupsel_rotation_restart.mod') == old_interface, 'ABI changed: coherent rebuild required'
    objects = list(baseline['object_sha256']); changed = []
    for i, name in enumerate(baseline['source_sha256']):
        if Path(name) == ROOT/REL: objects[i] = str(obj); changed.append(i)
    assert changed == [225] and len(objects) == 236
    exe = out/'default-diagnostic.exe'
    args = ['-fopenmp', '-Wl,--stack,16777216', *objects, provider['object'], baseline['ttutil_archive'], '-o', str(exe)]
    response = out/'link.args'; response.write_text('\n'.join('"'+s.replace('\\', '/')+'"' for s in args)+'\n')
    run([compiler, '@'+str(response)])
    result = dict(status='EXACT_DEFAULT_OBJECT_CLOSURE_PRIVATE_BODY_SUCCESSOR_BUILT_NOT_ADMITTED',
                  parent_build_sha256=sha(parent/'BUILD.json'), baseline=baseline,
                  changed_source=REL, source_sha256=sha(src), compiled_object_sha256=sha(obj),
                  unchanged_public_interface_sha256=old_interface,
                  linked_objects_sha256={p:sha(Path(p)) for p in objects},
                  executable_sha256=sha(exe), events=events, production_admission=False)
    (out/'BUILD.json').write_text(json.dumps(result, indent=2)+'\n')
    return exe


def check_refusals(folder):
    result = json.loads((folder/'RESULT.json').read_text())
    rejected = [r for r in result['events'] if r['expected_refusal']]
    assert len(rejected) == 11 and all(r['returncode'] == 1 for r in rejected)
    result['all_refusals_normal_error_stop_1'] = True
    result['runtime'] = 'UNCHANGED_DEFAULT_NUMERICAL_POLICY_COPIED_APP_ENVELOPE'
    result['production_admission'] = False
    (folder/'DEFAULT_RESULT.json').write_text(json.dumps(result, indent=2)+'\n')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for n in ('parent', 'output', 'compiler', 'inputs'): p.add_argument('--'+n, type=Path, required=True)
    a = p.parse_args(); out = a.output.resolve(); out.mkdir()
    exe = build(a.parent.resolve(), out/'build', a.compiler.resolve())
    qualify(exe, a.inputs.resolve(), out/'measurement')
    check_refusals(out/'measurement')
