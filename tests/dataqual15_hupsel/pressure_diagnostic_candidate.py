"""Preregistered copied app-envelope candidate; never modifies production source.

Reject legacy schemas instead of inventing the historical germination sample.
This builder changes only a private implementation and rebuilds every module.
"""
import argparse, hashlib, json, subprocess, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REL = 'app/solute_project/hupsel_rotation_restart.f90'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def candidate(source):
    pairs = [
        ("MAGIC='S5HR0003'", "MAGIC='S5HR0004'"),
        ('  irrigation_copy=irrigation\n',
         '  if(.not.all(ieee_is_finite([potato%last_pressure,grass%last_pressure])))return\n'
         '  irrigation_copy=irrigation\n'),
        ('  if(io==0)call irrigation_native_view(u,.false.,irrigation_copy,io)\n',
         '  if(io==0)call irrigation_native_view(u,.false.,irrigation_copy,io)\n'
         '  if(io==0)write(u,iostat=io)potato%last_pressure,grass%last_pressure\n'),
        (' subroutine decode_envelope(path,clock,blob,v,g,irrigation,status)',
         ' subroutine decode_envelope(path,clock,blob,v,g,irrigation,pressure,status)'),
        ('  real(real64)::origin\n',
         '  real(real64),intent(out)::pressure(2)\n  real(real64)::origin\n'),
        ('  if(io==0)call irrigation_native_view(u,.true.,irrigation,io)\n',
         '  if(io==0)call irrigation_native_view(u,.true.,irrigation,io)\n'
         '  if(io==0)read(u,iostat=io)pressure\n'
         '  if(io==0)then\n   if(.not.all(ieee_is_finite(pressure)))io=1\n  end if\n'),
        ('  call decode_envelope(path,clock,blob,v,g,irrigation,status)',
         '  call decode_envelope(path,clock,blob,v,g,irrigation,pressure,status)'),
        ('  type(original_potato_irrigation_t)::irrigation\n',
         '  type(original_potato_irrigation_t)::irrigation\n  real(real64)::pressure(2)\n'),
        ('  real(real64)::clock,observed\n', '  real(real64)::clock,observed,pressure(2)\n'),
        ('  call decode_envelope(path,clock,blob,v,g,irrigation_next,code)',
         '  call decode_envelope(path,clock,blob,v,g,irrigation_next,pressure,code)'),
        ('  inner=local_stage(path,\'read-stage\');call remove_file(inner)\n',
         '  crop%last_pressure=pressure(1);grass_next%last_pressure=pressure(2)\n'
         '  inner=local_stage(path,\'read-stage\');call remove_file(inner)\n'),
    ]
    for old, new in pairs:
        assert source.count(old) == 1, old
        source = source.replace(old, new)
    return source


def build(bundle, out, fc):
    parent = json.loads((bundle/'BUILD.json').read_text())
    record = parent['baseline']
    opt = next(x[1:] for x in record['flags'] if x in ('-O0', '-O2'))
    authority = json.loads((ROOT/'integration/dataqual15_hupsel/MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text())
    assert sha(bundle/'BUILD.json') == authority['files_sha256']['build-'+opt+'/BUILD.json']
    assert subprocess.check_output([str(fc), '--version'], text=True).splitlines()[0] == record['compiler']
    for name, digest in parent['source_sha256'].items():
        assert sha(Path(name)) == digest, name
    for name, digest in parent['compiled_objects_sha256'].items():
        assert sha(bundle/name) == digest, name
    assert sha(bundle/'pressure-runtime.exe') == parent['executable_sha256']
    provider = record['publication_provider']
    assert sha(Path(provider['object'])) == provider['object_sha256']
    assert sha(Path(provider['source'])) == provider['source_sha256']
    assert sha(Path(record['ttutil_archive'])) == record['archive_sha256']
    out.mkdir()
    source = out/'hupsel_rotation_restart.f90'
    source.write_text(candidate((ROOT/REL).read_text()), encoding='utf-8', newline='\n')
    flags = [x for x in record['flags'] if not x.startswith(('-I', '-J'))]
    flags += ['-I'+str(out), '-J'+str(out)]
    events, objects, sources = [], [], {}
    def run(cmd):
        start = time.monotonic()
        p = subprocess.run(list(map(str, cmd)), cwd=out, capture_output=True, timeout=240)
        i = len(events)
        (out/f'{i}.stdout').write_bytes(p.stdout)
        (out/f'{i}.stderr').write_bytes(p.stderr)
        events.append(dict(command=list(map(str, cmd)), returncode=p.returncode, seconds=time.monotonic()-start))
        (out/'EVENTS.json').write_text(json.dumps(events, indent=2)+'\n')
        assert p.returncode == 0, p.stderr
    changed = []
    for i, name in enumerate(parent['source_sha256']):
        path = Path(name)
        actual = source if path == ROOT/REL else path
        if actual == source: changed.append(REL)
        obj = out/f'{i}.o'
        run([fc, *flags, '-c', actual, '-o', obj])
        objects.append(obj); sources[str(actual)] = sha(actual)
    assert changed == [REL] and len(objects) == 236
    exe = out/'diagnostic-candidate.exe'
    args = ['-fopenmp', '-Wl,--stack,16777216', *map(str, objects), provider['object'], record['ttutil_archive'], '-o', str(exe)]
    response = out/'link.args'
    response.write_text('\n'.join('"'+s.replace('\\', '/')+'"' for s in args)+'\n')
    run([fc, '@'+str(response)])
    result = dict(status='COPIED_SOURCE_BUILT_NOT_ADMITTED', parent_build_sha256=sha(bundle/'BUILD.json'),
                  parent=parent, changed_source=REL, source_sha256=sources,
                  compiled_objects_sha256={p.name: sha(p) for p in objects},
                  executable_sha256=sha(exe), events=events, production_admission=False)
    (out/'BUILD.json').write_text(json.dumps(result, indent=2)+'\n')
    return exe


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for n in ('bundle', 'output', 'compiler'): p.add_argument('--'+n, type=Path, required=True)
    a = p.parse_args()
    print(build(a.bundle.resolve(), a.output.resolve(), a.compiler.resolve()))
