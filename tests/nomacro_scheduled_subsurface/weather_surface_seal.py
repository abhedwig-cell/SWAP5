"""Preserve actual Windows weather bytes and original unmodified CI ZIPs once.

This records neutral raw provenance. Scientific admission belongs to the
independent source/raw owner, not this archive writer or producer PASS tags.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import zipfile


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def archive(output, name, directories, files, builds=()):
    target = output/(name+'.zip');require = lambda b: b or (_ for _ in ()).throw(ValueError(name))
    require(not target.exists());members = {}
    with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        def add(key, path):
            require(path.is_file() and not path.is_symlink() and key not in members)
            raw = path.read_bytes();z.writestr(key, raw)
            members[key] = dict(bytes=len(raw), sha256=sha(raw))
        for prefix, root in directories:
            require(root.is_dir())
            for path in sorted(root.rglob('*')):
                if path.is_file():add(prefix+'/'+path.relative_to(root).as_posix(), path)
        for prefix, root in builds:
            require(root.is_dir())
            for path in sorted(root.iterdir()):
                if path.is_file() and (path.name == 'BUILD.json' or path.suffix.lower() in ('.f90', '.exe', '.dll', '.so')):
                    add(prefix+'/'+path.name, path)
        for key, path in files:add(key, path)
    with zipfile.ZipFile(target) as z:
        require(z.testzip() is None and set(z.namelist()) == set(members))
        for key, value in members.items():require(sha(z.read(key)) == value['sha256'])
    record = dict(status='NEUTRAL_ACTUAL_WINDOWS_RAW_ARCHIVE_NO_ADMISSION_CLAIM', archive=target.name,
                  bytes=target.stat().st_size, sha256=sha(target.read_bytes()), members=members,
                  compiled_objects_excluded='Reproducible original provider; actual emitted source, executable/library and BUILD bytes retained')
    require(record['bytes'] < 100*1024*1024)
    (output/(name+'.json')).write_text(json.dumps(record, indent=2)+'\n', encoding='utf8')
    return record


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('evidence-root', 'work-root', 'output'):
        p.add_argument('--'+name, type=Path, required=True)
    a = p.parse_args();a.output.mkdir(exist_ok=True)
    ev, work, out = a.evidence_root, a.work_root, a.output
    records = {}
    common = ['WEATHER_LITERAL_SOURCE_PROJECTION.json', 'WEATHER_CURRENT_SOURCE_NATIVE_PROJECTIONS.json',
              'WEATHER_H_ACCEPTANCE_AUTHORITY.json', 'WEATHER_INCOMING_CANONICAL_1FC_ACTUAL_OWNER.json',
              'WEATHER_ROOT_NATIVE_WARM532_PROJECTION.json', 'WEATHER_PORTABLE_CARRIER.json',
              'WEATHER_UNIFORM_PORTABLE_CARRIER.json', 'WEATHER_FINAL_V8_BUILD_PROVENANCE.json',
              'WEATHER_COMPOSED_V9_BUILD_PROVENANCE.json', 'WEATHER_UNIFORM_V10_BUILD_PROVENANCE.json']
    for opt, base in [('O0', 'weather-terminal-O0-v3'), ('O2', 'weather-terminal-O2-v4')]:
        directories = [(prefix, ev/root) for prefix, root in [
            ('pulsed', f'weather-terminal-pulsed-{opt}-full-v4'),
            ('hourly', f'weather-final-hourly-{opt}-v8'),
            ('uniform', f'weather-uniform-{opt}-v10'),
            ('controls', f'weather-final-controls-{opt}-v8'),
            ('pulsed-preservation', f'weather-final-pulsed-{opt}-v8'),
            ('composed-hourly', f'weather-composed-hourly-{opt}-v9'),
            ('named-seam', f'weather-composed-named-{opt}-v9')]]
        builds = [(prefix, work/root) for prefix, root in [
            ('pulsed-build', f'weather-terminal-{opt}-v4/pulsed'),
            ('hourly-build', base+'/final-v8/hourly'),
            ('uniform-build', base+'/uniform-v10/uniform'),
            ('pulsed-preservation-build', base+'/final-v8/pulsed'),
            ('composed-hourly-build', base+'/composed-v9/hourly'),
            ('named-build', base+'/composed-v9/named')]]
        if opt == 'O0':
            directories += [(prefix, ev/root) for prefix, root in [
                ('source-prior', 'weather-source-capsule-windows-v4'),
                ('source-primary', 'weather-final-source-capsule-windows-v8'),
                ('source-composed', 'weather-composed-source-capsule-windows-v9')]]
        files = [('common/'+name, ev/name) for name in common] if opt == 'O0' else []
        # This controller did not change between its actual uniform run and
        # capture. Its Git identity stays758378f2f, distinct from prior caps.
        if opt == 'O0':files.append(('uniform-controller/weather_surface_runtime.py', Path(__file__).with_name('weather_surface_runtime.py')))
        name = 'WEATHER_TERMINAL_WINDOWS_'+opt+'_RAW_ARCHIVE'
        records[name] = archive(out, name, directories, files, builds)
    failed = [name for name in (
        'weather-current-pulsed-O0-v1', 'weather-current-hourly-O0-v1',
        'weather-current-pulsed-O0-v2', 'weather-current-hourly-O0-v2',
        'weather-terminal-pulsed-O0-v1', 'weather-terminal-hourly-O0-v1',
        'weather-terminal-pulsed-O0-v2', 'weather-terminal-pulsed-O0-v3', 'weather-terminal-hourly-O0-v3',
        'weather-terminal-hourly-O0-full-v4', 'weather-terminal-hourly-O2-full-v4',
        'weather-hourly-day531-native-probe-v4', 'weather-root-native-hourly-O0-v5',
        'weather-root-native-hourly-O0-v6', 'weather-root-native-hourly-O0-v7') if (ev/name).is_dir()]
    builds = [(name.replace('/', '-'), work/name) for name in (
        'weather-terminal-O0-v3/pulsed', 'weather-terminal-O0-v3/hourly',
        'weather-terminal-O0-v3/root-native-v5/hourly',
        'weather-terminal-O0-v3/root-native-v6/hourly',
        'weather-terminal-O0-v3/root-native-v7/hourly',
        'weather-terminal-O0-v4/hourly', 'weather-terminal-O2-v4/hourly')]
    name = 'WEATHER_TERMINAL_RETAINED_FAILURES_RAW_ARCHIVE'
    files = [(n, ev/n) for n in ('WEATHER_PRELIMINARY_BUILD_CAPSULES.zip', 'WEATHER_PRELIMINARY_BUILD_CAPSULES.json')]
    records[name] = archive(out, name, [(n, ev/n) for n in failed], files, builds)
    for family in ('WEATHER_TERMINAL_UBUNTU_', 'WEATHER_UNIFORM_UBUNTU_'):
        for opt in ('O0', 'O2'):
            name = family+opt+'_RAW_ARCHIVE';record = json.loads((ev/(name+'.json')).read_text())
            require = lambda b: b or (_ for _ in ()).throw(ValueError(name))
            original = ev/(name+'.zip');require(sha(original.read_bytes()) == record['sha256'])
            require(not (out/original.name).exists());shutil.copyfile(original, out/original.name)
            shutil.copyfile(ev/(name+'.json'), out/(name+'.json'))
            require(sha((out/original.name).read_bytes()) == record['sha256'] and record['repacked'] is False)
            records[name] = record
    print(json.dumps({k:dict(bytes=v['bytes'], members=len(v['members']), sha256=v['sha256']) for k, v in records.items()}, indent=2))


if __name__ == '__main__':
    main()
