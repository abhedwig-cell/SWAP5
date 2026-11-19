"""Real public/native corruption, CLI replay and transaction controls for weather."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import time
import zipfile

import implicit_conductivity_runtime as prior
from age_groundwater_controls import transactions
from daily_coupling import CoupledDailyColumn
import weather_root_state as state

m = prior.m
ROOT = prior.ROOT


def attacks(raw):
    start = len(raw)-state.SIZE
    result = {}

    def integer(name, offset, value, mirror=None):
        b = bytearray(raw)
        struct.pack_into('<i', b, offset, value)
        if mirror is not None:
            struct.pack_into('<i', b, mirror, value)
        result[name] = (bytes(b), True)

    for i, value in enumerate(struct.unpack_from('<8i', raw, start)):
        integer('domain-'+str(i), start+4*i, value+1, start+32+4*i)
    integer('domain-copy', start, 99)
    integer('trailer', len(raw)-4, 1)
    b = bytearray(raw);struct.pack_into('<d', b, start+64, -1.)
    result['clock'] = (bytes(b), True)
    for i in range(2):
        for name, value in [('nan', float('nan')), ('negative', -1.), ('above-one', 2.)]:
            b = bytearray(raw);struct.pack_into('<d', b, start+72+8*i, value)
            result[name+'-'+str(i)] = (bytes(b), True)
        b = bytearray(raw);value = 0. if struct.unpack_from('<d', raw, start+72+8*i)[0] else 1.
        struct.pack_into('<d', b, start+72+8*i, value);struct.pack_into('<d', b, start+88+8*i, value)
        result['receipt-'+str(i)] = (bytes(b), False)
    result['old-codec'] = (b'S5HUP012'+raw[8:], True)
    result['truncated'] = (raw[:-1], True)
    result['trailing'] = (raw+b'x', True)
    return result


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'profile-root', 'output'):
        p.add_argument('--'+name, type=Path, required=True)
    a = p.parse_args();a.output.mkdir()
    cohort = json.loads((a.profile_root/'RESULT.json').read_text())
    project = m.e.load(Path(cohort['input_root']));build = Path(cohort['build_root'])
    meta, case = m.validate_bundle(build, a.reference_work, project)
    source = a.profile_root/'trajectory/accepted-column-1-day-531.zip';digest = m.sha(source)
    q = dict(status='RUNNING', source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
             build_sha256=m.sha(build/'BUILD.json'), public_refusals=[], native_refusals=[])

    def save():
        (a.output/'RESULT.json').write_text(json.dumps(q, indent=2)+'\n', encoding='utf8')

    def native(label, origin, receipt, directory):
        directory.parent.mkdir(exist_ok=True)
        m.h.prepare_column(case, directory, m.h.ColumnStart('original', 531, origin, receipt), True, True, project)
        started = time.monotonic()
        r = subprocess.run([str(m.h.executable(build, 'day_donor')), './swap.swp'], cwd=directory,
                           input='0 -1\n', capture_output=True, text=True, timeout=30)
        (directory/'actual.stdout').write_text(r.stdout, encoding='utf8')
        (directory/'actual.stderr').write_text(r.stderr, encoding='utf8')
        return dict(label=label, returncode=r.returncode, seconds=time.monotonic()-started,
                    no_day_return='HYBRID_DAY_RETURN' not in r.stdout,
                    stderr=r.stderr[:1000])

    save()
    try:
        with zipfile.ZipFile(source) as z:
            members = {n:z.read(n) for n in z.namelist()}
        accepted = json.loads(members['checkpoint.json'])
        state.validate_candidate(members['macro.bin'], accepted['receipt'], project)
        origin = a.output/'valid-origin'
        receipt = m.h.verify_checkpoint(source, 531, meta['binding'], origin)
        q['positive_native'] = native('positive', origin, receipt, a.output/'native-positive/column')
        assert q['positive_native']['returncode'] == 100
        save()
        for label, (raw, compiled_refusal) in attacks(members['macro.bin']).items():
            directory = a.output/label;directory.mkdir()
            forged = dict(members);forged['macro.bin'] = raw
            manifest = copy.deepcopy(accepted)
            manifest['files']['macro.bin'] = hashlib.sha256(raw).hexdigest()
            forged['checkpoint.json'] = json.dumps(manifest).encode()
            package = directory/'deliberately-forged.zip'
            with zipfile.ZipFile(package, 'w') as z:
                for name, value in forged.items():z.writestr(name, value)
            try:
                column = CoupledDailyColumn(build, a.reference_work, directory/'public', project,
                                            'weather-controls', origin=package, day=531, adopt_native=True)
                column.prepare()
            except ValueError as error:
                assert 'root stress' in str(error).lower(), str(error)
                assert not list((directory/'public').rglob('accepted-*.zip'))
                assert not list((directory/'public').rglob('donor.stdout'))
                q['public_refusals'].append(dict(label=label, error=str(error), before_physical_worker=True, no_publication=True))
            else:
                raise AssertionError('Public route accepted forged '+label)
            if compiled_refusal:
                unpacked = directory/'origin'
                copied_receipt = m.h.verify_checkpoint(package, 531, meta['binding'], unpacked)
                actual = native(label, unpacked, copied_receipt, directory/'native/column')
                assert actual['returncode'] != 100 and actual['no_day_return'], actual
                assert any(t in actual['stderr'].lower() for t in ('root stress', 'nonmacro checkpoint')), actual
                q['native_refusals'].append(actual)
            assert m.sha(source) == digest
            save()
        q['transactions'] = transactions(build, a.reference_work, project, a.profile_root/'trajectory', a.output/'transactions')
        # Reuse the exact compiled bundle through the actual public CLI.
        command = [sys.executable, '-B', str(ROOT/'tools/solute/run_water.py'), '--model', project.model,
                   '--experimental-project', project.input_directory, '--reference-work', str(a.reference_work),
                   '--build-bundle', str(build), '--days', '532', '--checkpoint-at', '532',
                   '--restart', str(source), '--restart-day', '531', '--output', str(a.output/'public-cli')]
        r = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=90)
        (a.output/'public-cli.stdout').write_text(r.stdout, encoding='utf8')
        (a.output/'public-cli.stderr').write_text(r.stderr, encoding='utf8')
        q['public_cli'] = dict(command=command, returncode=r.returncode)
        assert r.returncode == 0, r.stderr
        assert m.physical(m.rows(a.output/'public-cli')) == m.physical(m.rows(a.profile_root/'trajectory')[531:532])
        with zipfile.ZipFile(a.output/'public-cli/accepted-column-1-day-532.zip') as cold, zipfile.ZipFile(a.profile_root/'trajectory/accepted-column-1-day-532.zip') as warm:
            assert all(cold.read(n) == warm.read(n) for n in ('result.end', 'macro.bin'))
        q['public_cli'].update(exact_physical=True, exact_complete_native=True)
        assert m.sha(source) == digest
        q.update(status='ACTUAL_WEATHER_ROOT_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS', origin_unchanged=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error));raise
    finally:
        save()
    print(q['status'], len(q['public_refusals']), len(q['native_refusals']), flush=True)


if __name__ == '__main__':
    main()
