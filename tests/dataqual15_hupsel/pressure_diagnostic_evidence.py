"""Replay retained real Windows research evidence; no production admission."""
import argparse, csv, hashlib, json, math, struct, tarfile, tempfile, zlib
from pathlib import Path
from pressure_diagnostic_candidate import ROOT, REL, candidate

BASE = ROOT/'integration/dataqual15_hupsel'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def rows(path):
    with path.open(newline='') as f: return list(csv.DictReader(f))


def audit(root):
    authority = json.loads((BASE/'MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104.json').read_text())
    inputs = json.loads((BASE/'PRESSURE_DIAGNOSTIC_INPUTS_20261104.json').read_text())
    assert sha(root/'parent-budget.csv') == authority['files_sha256']['full-O2/budget.csv']
    parent = rows(root/'parent-budget.csv')
    for opt in ('O0', 'O2'):
        build = json.loads((root/opt/'BUILD.json').read_text())
        assert build['parent_build_sha256'] == authority['files_sha256']['build-'+opt+'/BUILD.json']
        assert sha(root/opt/'hupsel_rotation_restart.f90') == hashlib.sha256(candidate((ROOT/REL).read_text()).encode()).hexdigest()
        assert sha(root/opt/'diagnostic-candidate.exe') == build['executable_sha256']
        run = root/opt/'measurement'; result = json.loads((run/'RESULT.json').read_text())
        assert result['production_admission'] is False and result['refusal_count'] == 11
        assert result['finite_sentinel_restored'] and result['physical_sentinel_noninterference']
        assert result['executable_sha256'] == build['executable_sha256']
        whole = run/'uninterrupted525'; restart = run/'restart525'; sentinel = run/'finite_sentinel'
        for name, digest in inputs['files_sha256'].items(): assert sha(whole/name) == digest, name
        assert (whole/'checkpoint.bin').read_bytes() == (restart/'checkpoint.bin').read_bytes()
        for name in ('budget.csv', 'crop.csv'):
            a, b = rows(restart/name), rows(whole/name)
            key = next(iter(a[0])); by_time = {r[key]: r for r in b}
            assert len(a) == result['exact_suffix_rows'][name]
            assert all(r == by_time[r[key]] for r in a)
        if opt == 'O2':
            actual = rows(whole/'budget.csv')
            assert actual == parent[:len(actual)], 'candidate changed physical prefix'
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
        refused = [e for e in result['events'] if e['expected_refusal']]
        assert len(refused) == 11
        for event in refused:
            case = run/event['case']
            output = (case/'stdout').read_text(errors='replace')+(case/'stderr').read_text(errors='replace')
            assert event['returncode'] != 0 and 'source rotation envelope rejected before publication' in output
            assert not any((case/n).exists() for n in ('budget.csv', 'crop.csv', 'checkpoint.bin'))
    return 'WINDOWS_O0_O2_DIAGNOSTIC_CANDIDATE_REPLAY_PASS_NOT_ADMISSION'


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('--root', type=Path)
    a = p.parse_args()
    if a.root: print(audit(a.root.resolve()))
    else:
        manifest = json.loads((BASE/'PRESSURE_DIAGNOSTIC_EVIDENCE_20261104.json').read_text())
        archive = BASE/'PRESSURE_DIAGNOSTIC_EVIDENCE_20261104.tar.xz'
        assert sha(archive) == manifest['archive_sha256']
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with tarfile.open(archive) as tar:
                assert all(m.isfile() for m in tar.getmembers())
                assert sorted(tar.getnames()) == sorted(manifest['files_sha256'])
                tar.extractall(root, filter='data')
            for name, digest in manifest['files_sha256'].items(): assert sha(root/name) == digest
            print(audit(root))
