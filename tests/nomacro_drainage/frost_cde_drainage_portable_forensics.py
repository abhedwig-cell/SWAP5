"""Read original artifact ZIPs independently, without execution or path rebinding."""
import argparse
from datetime import date, timedelta
from decimal import Decimal, localcontext
import hashlib
import io
import json
from pathlib import Path
import re
import struct
import subprocess
import zipfile
from frost_cde_drainage_sealed_components import audit as components

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = '5534a17df5ecc382cd4b8415c5bbd7d3954a0ea6'
FOLLOWUP = '6e40385c9b871992641f7a601bbf0ec30f5f68d3'
SHA = lambda raw: hashlib.sha256(raw).hexdigest()


def binary(raw):
    labels = [raw.find(v) for v in (b'DATE                    ', b'DATETIME                ')]
    labels = [v for v in labels if v >= 0]; assert len(labels) == 1
    first = labels[0] + re.search(rb'\d{4}-\d{2}-\d{2}', raw[labels[0]:]).start()
    assert (first-labels[0]) % 24 == 0
    columns = (first-labels[0]) // 24 - 1; size = 19 + 4*columns
    assert columns > 0 and (len(raw)-first) % size == 0
    return [raw[v:v+size] for v in range(first, len(raw), size)]


def audit(original, followup, opt):
    def read(z, name): return json.loads(z.read(name))
    q = read(followup, 'frost-cde-drainage-followup/RESULT.json')
    assert q['status'] == 'ACTUAL_PORTABLE_RETAINED_FROST_WATER_AND_MISSING_CDE_CONTROLS_PASS_NOT_ADMITTED'
    assert q['source'] == FOLLOWUP and q['original_source'] == ORIGINAL and q['water_model_periods_replayed'] == 0
    assert len(q['steps']) == 8 and all(v['status'] == 'PASS' for v in q['steps'])
    assert SHA(Path(original.filename).read_bytes()) == q['original_sha256']
    prepared = read(followup, 'provider-PREPARED.json')
    assert prepared['source_archives']['SWAP.ZIP'] == '1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
    with zipfile.ZipFile(io.BytesIO(original.read('source/actual-producer-source.zip'))) as cap, \
         zipfile.ZipFile(io.BytesIO(cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP'))) as source:
        component_result = components(original.read, original.namelist(),
            {name: 'frost-cde-drainage/' + name for name in ('overlap', 'rates', 'cde')},
            {name: source.read('SWAP/' + name + '.f90') for name in ('divdra', 'solute', 'frozencond')}, prepared, opt)
    for archive, head in ((original, ORIGINAL), (followup, FOLLOWUP)):
        manifest = read(archive, 'source/RESULT.json'); assert manifest['producer_head'] == head
        raw = archive.read('source/actual-producer-source.zip'); assert SHA(raw) == manifest['sha256']
        entries = subprocess.check_output(['git', 'ls-tree', '-r', head], cwd=ROOT, text=True)
        expected = {line.split('\t', 1)[1]: line.split('\t', 1)[0].split()[2] for line in entries.splitlines()}
        with zipfile.ZipFile(io.BytesIO(raw)) as source:
            for name in source.namelist():
                value = source.read(name); item = manifest['members'][name]
                assert SHA(value) == item['sha256'] and item['git_blob'] == expected[name]
                normalized = value.replace(b'\r\n', b'\n')
                blob = lambda v: hashlib.sha1(b'blob ' + str(len(v)).encode() + b'\0' + v).hexdigest()
                assert expected[name] in (blob(value), blob(normalized)), name
    projection = read(followup, 'COMPILED_PROJECTION_V1.json'); results = []
    for kind in ('water', 'cde'):
        prefix = 'frost-cde-drainage' if kind == 'water' else 'frost-cde-drainage-followup'
        controls = read(followup, 'frost-cde-drainage-followup/' + kind + '-controls/RESULT.json')
        assert controls['status'].endswith('CONTROLS_PASS')
        assert len(controls['native_refusals']) == (39 if kind == 'water' else 44)
        assert all(v['status'] == 'REFUSED' and 'ERROR STOP' in v['diagnostic'] for v in controls['native_refusals'])
        assert all(v['status'] == 'REFUSED' for v in controls['descriptor_refusals'] + controls['source_refusals'])
        assert all(v is True for k, v in controls['transactions'].items() if k != 'start_day')
        assert controls['transactions']['start_day'] == 19
        for phase in ('short', 'full'):
            root = prefix + '/' + kind + '-' + phase; profile = read(followup, root + '/RESULT.json')
            assert profile['source'] == (ORIGINAL if kind == 'water' else FOLLOWUP) and 'PASS_NOT_ADMITTED' in profile['status']
            entry = projection[profile['build_root']]; bundle = entry['archive_prefix']
            raw = followup.read(bundle + '/BUILD.json'); assert SHA(raw) == entry['actual_BUILD_sha256'] == profile['trajectory']['build_sha256']
            meta = json.loads(raw); identity = meta['identity']
            assert '-' + opt in identity['donor_flags'] and '-' + opt in identity['kernel_flags']
            assert identity['compiler_sha256'] == prepared['toolchain']['gfortran']['sha256']
            for name, digest in identity['donor_generated'].items(): assert SHA(followup.read(bundle + '/' + name)) == digest
            for name, digest in identity['donor_objects'].items(): assert digest == prepared['provider_files']['build/swap-obj/' + name]
            for role, digest in meta['executable_sha256'].items(): assert SHA(followup.read(bundle + '/day_' + role)) == digest
            inputs = profile['input_root'].split('/proof/', 1)[1]
            for name, digest in profile['inventory'].items(): assert SHA(followup.read(inputs + '/' + name)) == digest
            warm = root + '/trajectory'
            rows = [json.loads(s, parse_float=Decimal) for s in followup.read(warm + '/daily.jsonl').decode().splitlines()]
            days = 35 if phase == 'short' else 1096; assert len(rows) == days
            water_max = Decimal(0); chemical_max = Decimal(0); chemical_prefix_max = Decimal(0)
            chemical_flows = [Decimal(0)]*6
            with localcontext() as ctx:
                ctx.prec = 80
                for day, row in enumerate(rows, 1):
                    assert row['day'] == day and row['committed'] is True
                    flux = row['external_flux_cm']
                    residual = sum(row['stock_start_cm']) - sum(row['stock_end_cm']) + sum(flux[:7]) - sum(flux[7:])
                    water_max = max(water_max, abs(residual)); assert abs(residual) <= Decimal('1e-10')
                    if kind == 'cde':
                        ledger = row['solute_ledger_mg_cm2']
                        residual = row['solute_end_mg_cm2'] - row['solute_start_mg_cm2'] - sum(ledger[2:5]) + sum(ledger[5:8])
                        chemical_max = max(chemical_max, abs(residual)); assert abs(residual) <= Decimal('1e-10')
                        chemical_flows = [a+b for a, b in zip(chemical_flows, ledger[2:8])]
                        prefix_residual = row['solute_end_mg_cm2']-rows[0]['solute_start_mg_cm2']-sum(chemical_flows[:3])+sum(chemical_flows[3:])
                        chemical_prefix_max = max(chemical_prefix_max, abs(prefix_residual))
                        assert abs(prefix_residual) <= Decimal('1e-10')
            witness = [list(map(float, s.split()[1:])) for s in followup.read(warm + '/original/donor.stdout').decode().splitlines() if s.startswith('HYBRID_FROST_WITNESS ')]
            assert len(witness) == days+1 and all(v[-1] == 1 for v in witness[1:]) and 0 < witness[20][0] < 1
            expected_windows = 3 if phase == 'short' else 7; assert len(profile['own']) == expected_windows
            warm_output = binary(followup.read(warm + '/original/result_output.bin'))
            for own in profile['own']:
                start, end = own['start'], own['end']; cold = root + '/own-' + str(start)
                with zipfile.ZipFile(io.BytesIO(followup.read(warm + f'/accepted-column-1-day-{end}.zip'))) as a, \
                     zipfile.ZipFile(io.BytesIO(followup.read(cold + f'/accepted-column-1-day-{end}.zip'))) as b:
                    for name in ('macro.bin', 'result.end'): assert a.read(name) == b.read(name)
                    assert a.read('macro.bin')[:8] == (b'S5FDC001' if kind == 'cde' else b'S5FDW001')
                first = date.fromisoformat(meta['project']['start_date'])
                lo, hi = str(first + timedelta(days=start)), str(first + timedelta(days=end))
                expected = [row for row in warm_output[1:] if lo <= row[:19].decode().strip() < hi]
                actual = binary(followup.read(cold + '/original/result_output.bin'))[1:]
                assert actual == expected
            results.append(dict(kind=kind, phase=phase, days=days, cold_windows=expected_windows,
                water_max_decimal=str(water_max), chemical_max_decimal=str(chemical_max),
                chemical_prefix_max_decimal=str(chemical_prefix_max)))
    return dict(status='INDEPENDENT_ORIGINAL_PORTABLE_SOURCE_COMPILER_WARM_COLD_USER_OUTPUT_CONTROLS_PASS',
        optimization=opt, results=results, components=component_result, native_refusals=83, transactions=2, water_model_periods_replayed=0,
        model_executions=0, compiler_executions=0, canonical_admission=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('original-artifact', 'followup-artifact', 'output'): p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); assert not a.output.exists()
    with zipfile.ZipFile(a.original_artifact) as original, zipfile.ZipFile(a.followup_artifact) as followup:
        q = audit(original, followup, a.optimization)
    q['original_sha256'] = SHA(a.original_artifact.read_bytes()); q['followup_sha256'] = SHA(a.followup_artifact.read_bytes())
    q['auditor_source'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    a.output.write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8'); print(q['status'])


if __name__ == '__main__': main()
