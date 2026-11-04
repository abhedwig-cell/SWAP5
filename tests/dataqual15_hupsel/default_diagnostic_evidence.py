"""Replay default-runtime native proof against immutable default object ancestry."""
import argparse, csv, hashlib, json, math, re, shutil, struct, subprocess, tarfile, tempfile, zipfile, zlib
from pathlib import Path
from pressure_diagnostic_candidate import ROOT, REL, candidate

BASE = ROOT/'integration/dataqual15_hupsel'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def rows(path):
    with path.open(newline='') as f: return list(csv.DictReader(f))


def audit(root):
    parent_manifest = json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text())
    default_manifest = json.loads((BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json').read_text())
    inputs = json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
    for name in ('budget.csv', 'crop.csv'):
        assert sha(root/('parent-'+name)) == default_manifest['files_sha256']['case/'+name]
    parent_budget = rows(root/'parent-budget.csv'); parent_crop = rows(root/'parent-crop.csv')
    for opt in ('O0', 'O2'):
        leg = root/opt; b = json.loads((leg/'BUILD.json').read_text())
        raw = (leg/'PARENT_BUILD.json').read_bytes()
        assert hashlib.sha256(raw).hexdigest() == parent_manifest['files_sha256']['build-'+opt+'/BUILD.json']
        assert b['baseline'] == json.loads(raw)['baseline']
        assert b['parent_build_sha256'] == hashlib.sha256(raw).hexdigest()
        assert len(b['baseline']['source_sha256']) == len(b['linked_objects_sha256']) == 236
        expected = dict(b['baseline']['object_sha256'])
        replaced = list(expected)[225]; del expected[replaced]
        actual = b['linked_objects_sha256']
        assert all(actual.get(p) == digest for p, digest in expected.items()), 'non-default object or missing provider'
        extras = set(actual)-set(expected); assert len(extras) == 1
        assert actual[next(iter(extras))] == sha(leg/'rotation.o') == b['compiled_object_sha256']
        assert sha(leg/'hupsel_rotation_restart.f90') == b['source_sha256']
        assert b['source_sha256'] == hashlib.sha256(candidate((ROOT/REL).read_text()).encode()).hexdigest()
        assert sha(leg/'mod_hupsel_rotation_restart.mod') == b['unchanged_public_interface_sha256']
        assert sha(leg/'default-diagnostic.exe') == b['executable_sha256']
        run = leg/'measurement'; result = json.loads((run/'DEFAULT_RESULT.json').read_text())
        assert result['runtime'] == 'UNCHANGED_DEFAULT_NUMERICAL_POLICY_COPIED_APP_ENVELOPE'
        assert result['production_admission'] is False and result['all_refusals_normal_error_stop_1']
        assert result['executable_sha256'] == b['executable_sha256']
        whole = run/'uninterrupted525'; restart = run/'restart525'; sentinel = run/'finite_sentinel'
        for name, digest in inputs['files_sha256'].items(): assert sha(whole/name) == digest
        ends = [float(v) for v in re.search(r'^ends_day=(.*)$', (whole/'input.nml').read_text(), re.M)[1].split(',') if v.strip()]
        selected = [v for v in ends if v <= 525]
        actual_budget = rows(whole/'budget.csv'); actual_crop = rows(whole/'crop.csv')
        assert [float(r['t1_day']) for r in actual_budget] == selected
        expected_crop = [r for r in parent_crop if float(r['day']) <= 525]
        assert [float(r['day']) for r in actual_crop] == [float(r['day']) for r in expected_crop]
        if opt == 'O2':
            assert actual_budget == [r for r in parent_budget if float(r['t1_day']) <= 525], 'default physical prefix changed'
            assert actual_crop == expected_crop, 'uninterrupted crop observation changed'
        assert (whole/'checkpoint.bin').read_bytes() == (restart/'checkpoint.bin').read_bytes()
        for case in (whole, restart, sentinel):
            endpoint = (case/'checkpoint.bin').read_bytes()
            assert endpoint[:8] == b'S5HR0004' and struct.unpack_from('=d', endpoint, 8)[0] == 525
            assert zlib.crc32(endpoint[:-4]) == struct.unpack('=I', endpoint[-4:])[0]
            assert all(math.isfinite(x) for x in struct.unpack_from('=2d', endpoint, len(endpoint)-20))
        for name in ('budget.csv', 'crop.csv'):
            a, full = rows(restart/name), rows(whole/name)
            assert len(a) == 1
            key = next(iter(a[0])); original = {r[key]: r for r in full}
            assert all(r == original[r[key]] for r in a)
        raw = (whole/'checkpoint-524.bin').read_bytes()
        assert raw[:8] == b'S5HR0004' and struct.unpack_from('=d', raw, 8)[0] == 524
        assert zlib.crc32(raw[:-4]) == struct.unpack('=I', raw[-4:])[0]
        pressures = struct.unpack_from('=2d', raw, len(raw)-20)
        assert all(math.isfinite(x) for x in pressures) and pressures[0] != 0
        assert list(pressures) == result['pressures_at524']
        sr = (sentinel/'checkpoint.bin').read_bytes(); wr = (whole/'checkpoint.bin').read_bytes()
        assert sr[:-20] == wr[:-20] and sr[-12:-4] == wr[-12:-4]
        assert (sentinel/'budget.csv').read_bytes() == (restart/'budget.csv').read_bytes()
        assert all(float(r['pressure_average_cm']) == -123.456789 for r in rows(sentinel/'crop.csv'))
        refusals = [e for e in result['events'] if e['expected_refusal']]
        assert len(refusals) == 11 and all(e['returncode'] == 1 for e in refusals)
        for event in refusals:
            case = run/event['case']
            output = (case/'stdout').read_text(errors='replace')+(case/'stderr').read_text(errors='replace')
            assert 'source rotation envelope rejected before publication' in output
            assert not any((case/n).exists() for n in ('budget.csv', 'crop.csv', 'checkpoint.bin'))
    return 'DEFAULT_O0_O2_EXACT_NUMERICAL_POLICY_AND_DIAGNOSTIC_RESTART_PASS_NOT_PRODUCTION_ADMISSION'


def controls(root):
    """Resealed data/ancestry defects must not inherit an actual runtime PASS."""
    with tempfile.TemporaryDirectory() as temp:
        copy = Path(temp)/'packet'; shutil.copytree(root, copy)
        def json_change(fn):
            def change(raw):
                data = json.loads(raw); fn(data); return (json.dumps(data)+'\n').encode()
            return change
        def foreign_object(data):
            key = list(data['baseline']['object_sha256'])[0]
            data['linked_objects_sha256'][key] = '0'*64
        def forged_parent(data): data['baseline']['compiler'] = 'unqualified compiler'
        def nan_pressure(raw):
            data = bytearray(raw); struct.pack_into('=d', data, len(data)-20, float('nan'))
            struct.pack_into('=I', data, len(data)-4, zlib.crc32(data[:-4])); return bytes(data)
        prefix = 'O0/measurement/uninterrupted525/'
        cases = [
            ('foreign_numerical_object', 'O0/BUILD.json', json_change(foreign_object)),
            ('forged_default_ancestry', 'O0/BUILD.json', json_change(forged_parent)),
            ('copied_source_postimage', 'O0/hupsel_rotation_restart.f90', lambda b:b+b'! unqualified\n'),
            ('missing_accepted_window', prefix+'budget.csv', lambda b:b'\n'.join(b.splitlines()[:-1])+b'\n'),
            ('missing_crop_observation', prefix+'crop.csv', lambda b:b'\n'.join(b.splitlines()[:-1])+b'\n'),
            ('resealed_nonfinite_observation', prefix+'checkpoint-524.bin', nan_pressure),
            ('physical_endpoint_corruption', prefix+'checkpoint.bin', lambda b:b[:-1]+bytes([b[-1]^1]))]
        for name, relative, mutate in cases:
            path = copy/relative; original = path.read_bytes(); path.write_bytes(mutate(original))
            try:
                try: audit(copy)
                except (AssertionError, ValueError, KeyError): pass
                else: raise AssertionError('accepted defect: '+name)
            finally: path.write_bytes(original)
        print('SEVEN_DEFAULT_ANCESTRY_AND_RESEALED_DATA_REFUSALS_PASS')


def posix():
    """Validate completed native command receipts; never relabel workflow state."""
    record = json.loads((BASE/'DEFAULT_DIAGNOSTIC_POSIX_20261104.json').read_text())
    archive = BASE/'DEFAULT_DIAGNOSTIC_POSIX_20261104.zip'
    assert sha(archive) == record['artifact_zip_sha256']
    assert record['production_admission'] is False
    for area, tree in record['production_and_input_recipe_trees'].items():
        assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT,text=True).strip() == tree
    expected_source = hashlib.sha256(candidate((ROOT/REL).read_text()).encode()).hexdigest()
    micro = 'src/process/mod_root_micro_de_willigen_process.f90'
    expected_micro = hashlib.sha256(subprocess.check_output(['git', 'show', 'HEAD:'+micro], cwd=ROOT)).hexdigest()
    with tempfile.TemporaryDirectory() as temp:
        root = Path(temp)
        with zipfile.ZipFile(archive) as z:
            assert all(not n.startswith('/') and '..' not in Path(n).parts for n in z.namelist())
            z.extractall(root)
        for opt in ('O0', 'O2'):
            build = json.loads((root/('build-'+opt)/'BUILD.json').read_text())
            assert len(build['source_sha256']) == 236
            for name, digest in build['source_sha256'].items():
                relative = next((area+'/'+name.split('/'+area+'/',1)[1] for area in ('src','app') if '/'+area+'/' in name), None)
                if relative:
                    expected = expected_source if relative == REL else hashlib.sha256(subprocess.check_output(['git','show','HEAD:'+relative],cwd=ROOT)).hexdigest()
                    assert digest == expected, relative
            assert [v for k,v in build['source_sha256'].items() if k.endswith('/'+REL)] == [expected_source]
            assert [v for k,v in build['source_sha256'].items() if k.endswith('/'+micro)] == [expected_micro]
            run = root/('measurement-'+opt); r = json.loads((run/'DEFAULT_RESULT.json').read_text())
            assert r['executable_sha256'] == build['executable_sha256']
            assert r['all_refusals_normal_error_stop_1'] and r['refusal_count'] == 11
            assert r['runtime'] == 'UNCHANGED_DEFAULT_NUMERICAL_POLICY_COPIED_APP_ENVELOPE'
            assert r['production_admission'] is False
            whole, restart, sentinel = [run/n for n in ('uninterrupted525', 'restart525', 'finite_sentinel')]
            assert (whole/'checkpoint.bin').read_bytes() == (restart/'checkpoint.bin').read_bytes()
            for name in ('budget.csv', 'crop.csv'):
                a, full = rows(restart/name), rows(whole/name); assert len(a) == 1
                key = next(iter(a[0])); original = {row[key]: row for row in full}
                assert all(row == original[row[key]] for row in a)
            for case in (whole, restart, sentinel):
                raw = (case/'checkpoint.bin').read_bytes()
                assert raw[:8] == b'S5HR0004' and struct.unpack_from('=d',raw,8)[0] == 525
                assert zlib.crc32(raw[:-4]) == struct.unpack('=I',raw[-4:])[0]
            raw = (whole/'checkpoint-524.bin').read_bytes()
            assert zlib.crc32(raw[:-4]) == struct.unpack('=I',raw[-4:])[0]
            assert list(struct.unpack_from('=2d',raw,len(raw)-20)) == r['pressures_at524']
            for event in r['events']:
                if event['expected_refusal']:
                    case = run/event['case']; assert event['returncode'] == 1
                    assert 'source rotation envelope rejected before publication' in (case/'stdout').read_text()
                    assert not any((case/n).exists() for n in ('budget.csv','crop.csv','checkpoint.bin'))
            sr = (sentinel/'checkpoint.bin').read_bytes(); wr = (whole/'checkpoint.bin').read_bytes()
            assert sr[:-20] == wr[:-20] and sr[-12:-4] == wr[-12:-4]
            assert (sentinel/'budget.csv').read_bytes() == (restart/'budget.csv').read_bytes()
            assert all(float(row['pressure_average_cm']) == -123.456789 for row in rows(sentinel/'crop.csv'))
    print('ACTUAL_POSIX_DEFAULT_COMMAND_RECEIPTS_PASS_WORKFLOW_STATUS_SEPARATE')


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--root', type=Path); a = p.parse_args()
    if a.root:
        print(audit(a.root.resolve())); controls(a.root.resolve())
    else:
        manifest = json.loads((BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.json').read_text())
        archive = BASE/'DEFAULT_DIAGNOSTIC_EVIDENCE_20261104.tar.xz'
        assert sha(archive) == manifest['archive_sha256']
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with tarfile.open(archive) as tar:
                assert all(m.isfile() for m in tar.getmembers())
                assert sorted(tar.getnames()) == sorted(manifest['files_sha256'])
                tar.extractall(root, filter='data')
            for name, digest in manifest['files_sha256'].items(): assert sha(root/name) == digest
            print(audit(root)); controls(root)
    posix()
