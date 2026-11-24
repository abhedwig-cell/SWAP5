"""Read-only actual compiler identity and independently recomputed daily balances."""
import argparse
from decimal import Decimal, localcontext
import hashlib
import io
import json
from pathlib import Path
import struct
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]


def audit(profile_path, reference, *, locations=None, provider_catalog=None):
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    profile = json.loads((profile_path / 'RESULT.json').read_text(encoding='utf-8'))
    assert 'PASS_NOT_ADMITTED' in profile['status'] and not profile['canonical_admission']
    kind, opt, phase = profile['kind'], profile['optimization'], profile['phase']
    build = locations['bundle'] if locations else Path(profile['build_root'])
    inputs = locations['inputs'] if locations else Path(profile['input_root'])
    import re,math
    text=(inputs/'swap.swp').read_text(encoding='cp1252')
    def mode(key):
        values=re.findall(r'(?mi)^\s*'+key+r'\s*=\s*([01])\s*(?:!.*)?$',text)
        assert len(values)==1
        return int(values[0])
    selected_hysteresis=mode('SWHYST');implicit=mode('SWKIMPL')
    meta = json.loads((build / 'BUILD.json').read_text()); identity = meta['identity']
    assert sha(build / 'BUILD.json') == profile['trajectory']['build_sha256']
    for name, digest in profile['inventory'].items(): assert sha(inputs / name) == digest
    for name, digest in identity['donor_generated'].items(): assert sha(build / name) == digest
    for name, digest in identity['donor_objects'].items():
        actual = provider_catalog['build/swap-obj/' + name] if provider_catalog else sha(reference / 'build/swap-obj' / name)
        assert actual == digest
    assert '-' + opt in identity['donor_flags'] and '-' + opt in identity['kernel_flags']
    assert '-ffp-contract=off' in identity['donor_flags'] and '-ffp-contract=off' in identity['kernel_flags']
    for role, digest in meta['executable_sha256'].items():
        candidates = [build / ('day_' + role), build / ('day_' + role + '.exe')]
        paths = [p for p in candidates if p.is_file()]; assert len(paths) == 1 and sha(paths[0]) == digest
    # Bind the complete selected Divdra source to the original, through exactly
    # one removed incorrect overwrite. No producer transformation is imported.
    original = (reference / 'build/swap-selected/divdra.f90').read_text(encoding='cp1252')
    actual = (build / 'divdra.f90').read_text(encoding='cp1252')
    old = '               if (icpbotdislay(idr) == icpwlev) dzcpbotdislay(idr) = dzcpwlevsat'
    new = '               ! FROST-DIVDRA-OVERLAP-01: retain the actual Lev2Comp above-bottom extent.'
    assert actual.count(new) == 1 and actual.replace(new, old, 1) == original
    guarded = ROOT / 'reference/swap-4.3.1/frost-corrections/FROST-GEOMETRY-01/frozencond.f90'
    assert (build / 'frozencond.f90').read_bytes() == guarded.read_bytes()
    warm = locations['warm'] if locations else profile_path / 'trajectory'
    rows = [json.loads(s, parse_float=Decimal) for s in (warm / 'daily.jsonl').read_text().splitlines()]
    days = 35 if phase == 'short' else 1096; assert len(rows) == days
    water_max = Decimal(0); chemical_max = Decimal(0); chemical_prefix_max = Decimal(0)
    chemical_flows = [Decimal(0)]*6
    with localcontext() as ctx:
        ctx.prec = 80
        for day, row in enumerate(rows, 1):
            assert row['day'] == day and row['committed'] is True
            before, after, flow = row['stock_start_cm'], row['stock_end_cm'], row['external_flux_cm']
            residual = sum(before) - sum(after) + sum(flow[:7]) - sum(flow[7:])
            water_max = max(water_max, abs(residual))
            assert abs(residual) <= Decimal('1e-10') and abs(row['kernel_residual_cm']) <= Decimal('1e-10')
            if kind == 'cde':
                ledger = row['solute_ledger_mg_cm2']; start = row['solute_start_mg_cm2']; end = row['solute_end_mg_cm2']
                budget = end - start - sum(ledger[2:5]) + sum(ledger[5:8])
                chemical_max = max(chemical_max, abs(budget))
                assert abs(budget) <= Decimal('1e-10')
                assert abs(end - ledger[0]) <= Decimal('1e-10')
                chemical_flows = [a+b for a, b in zip(chemical_flows, ledger[2:8])]
                prefix = end-rows[0]['solute_start_mg_cm2']-sum(chemical_flows[:3])+sum(chemical_flows[3:])
                chemical_prefix_max = max(chemical_prefix_max, abs(prefix))
                assert abs(prefix) <= Decimal('1e-10')
    witness = [list(map(float, line.split()[1:])) for line in (warm / 'original/donor.stdout').read_text().splitlines()
               if line.startswith('HYBRID_FROST_WITNESS ')]
    assert len(witness) == days + 1 and all(v[-1] == 1 for v in witness[1:])
    partial = [day for day, v in enumerate(witness[1:], 1) if 0 < v[0] < 1]
    assert partial and 20 in partial
    if kind == 'cde': assert any(rows[day-1]['solute_ledger_mg_cm2'][5] != 0 for day in partial)
    for own in profile['own']:
        assert own['exact_physical'] and own['exact_complete_native'] and own['origin_unchanged']
        start, end = own['start'], own['end']
        cold = locations['cold'](start) if locations else profile_path / ('own-' + str(start))
        continuation = [json.loads(s) for s in (cold / 'daily.jsonl').read_text().splitlines()]
        # These are the scientific fields used by the existing physical projection.
        fields = ('stock_start_cm', 'stock_end_cm', 'external_flux_cm', 'pressure_head_cm', 'groundwater_cm',
                  'drainage_outward_cm', 'bottom_outward_cm')
        original_rows = [json.loads(s) for s in (warm / 'daily.jsonl').read_text().splitlines()]
        assert len(continuation) == end-start
        for a, b in zip(continuation, original_rows[start:end]):
            assert all(a[k] == b[k] for k in fields)
        with zipfile.ZipFile(io.BytesIO((warm / f'accepted-column-1-day-{end}.zip').read_bytes())) as a, \
             zipfile.ZipFile(io.BytesIO((cold / f'accepted-column-1-day-{end}.zip').read_bytes())) as b:
            for name in ('macro.bin', 'result.end'): assert a.read(name) == b.read(name)
            native = a.read('macro.bin')
            expected_magic=(b'S5FIC002' if kind=='cde' else b'S5FIW002') if implicit else (b'S5FDC001' if kind=='cde' else b'S5FDW001')
            assert native[:8]==expected_magic
            header = struct.pack('<10i', 1, meta['project']['nodes'], 0, int(kind == 'cde'), selected_hysteresis, 1, 1, 1, 1, 2)
            assert native.count(header + header) == 1
            if implicit:
                expected=(4,meta['project']['nodes'],int(kind=='cde'),1,selected_hysteresis,6,1,0)
                assert struct.unpack('<16i',native[-96:-32])==expected+expected
                values=struct.unpack('<4d',native[-32:])
                assert values[:2]==values[2:] and all(map(math.isfinite,values))
    return dict(status='INDEPENDENT_COMPLETE_COMPILER_SOURCES_DAILY_BUDGETS_COLD_NATIVE_PASS',
        producer=profile['source'], result_sha256=sha(profile_path / 'RESULT.json'), kind=kind,
        optimization=opt, days=days, cold_windows=len(profile['own']), partial_frost_days=len(partial),
        actual_frost_day20=True, water_max_decimal=str(water_max), chemical_max_decimal=str(chemical_max),
        chemical_prefix_max_decimal=str(chemical_prefix_max),
        model_executions=0, compiler_executions=0, canonical_admission=False)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('profile', 'reference-work', 'output'): p.add_argument('--' + name, type=Path, required=True)
    args = p.parse_args(); assert not args.output.exists()
    q = audit(args.profile, args.reference_work)
    q['auditor_source'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    args.output.write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8'); print(q['status'])


if __name__ == '__main__': main()
