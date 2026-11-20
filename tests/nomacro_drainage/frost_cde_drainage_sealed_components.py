"""Independent original defect, geometric correction and literal CDE readers."""
from decimal import Decimal, localcontext
import hashlib
import json
import re

SHA = lambda raw: hashlib.sha256(raw).hexdigest()
OLD = '               if (icpbotdislay(idr) == icpwlev) dzcpbotdislay(idr) = dzcpwlevsat'
NEW = '               ! FROST-DIVDRA-OVERLAP-01: retain the actual Lev2Comp above-bottom extent.'


def audit(get, names, roots, originals, prepared, opt):
    text = lambda raw: raw.decode('cp1252').replace('\r\n', '\n')
    divdra = text(originals['divdra']); solute = text(originals['solute'])
    results = {}
    for label, root in roots.items():
        read = lambda name: get(root + '/' + name)
        q = json.loads(read('RESULT.json')); assert 'PASS' in q['status'] and q['model_periods'] == 0
        assert q['optimization'] == opt and q['canonical_admission'] is False
        closure = q.get('original_object_closure', q.get('actual_original_object_closure'))
        assert len(closure) == 40
        for item in closure:
            assert item['sha256'] == prepared['provider_files']['build/swap-obj/' + item['name']]
        assert q['ttutil_sha256'] == prepared['provider_files']['build/ttutil-obj/libttutil.a']
        def executable(mode, stem):
            path = mode + '-' + stem
            if root + '/' + path + '.exe' in names: path += '.exe'
            return read(path)
        if label == 'overlap':
            assert set(q['cases']) == {'original', 'corrected'} and all(len(v) == 12 for v in q['cases'].values())
            assert text(read('original-reference.f90')) == divdra
            corrected = text(read('corrected-reference.f90'))
            assert corrected.count(NEW) == 1 and corrected.replace(NEW, OLD, 1) == divdra
            wrong = traps = unchanged = 0
            for mode in ('original', 'corrected'):
                logs = json.loads(read(mode + '-compile.json'))
                assert all(v['returncode'] == 0 and '-' + opt in v['command'] for v in logs)
                exe = executable(mode, 'actual-divdra-overlap')
                for key, item in q['cases'][mode].items():
                    assert SHA(exe) == item['executable_sha256'] and SHA(read(mode + '-probe.f90')) == item['actual_source_sha256']
                    rows = [s.split() for s in item['stdout'].splitlines() if s.startswith('ACTUAL_DIVDRA_INFILTRATION_BOOKKEEPING ')]
                    assert len(rows) == 1; row = rows[0]
                    depth, channel, spacing = (item['input'][k] for k in ('water_depth_cm', 'channel_depth_cm', 'spacing_cm'))
                    water, bottom, conductivity = Decimal(row[7]), Decimal(row[8]), Decimal(row[12])
                    total, saturated, unsaturated = map(Decimal, row[13:16])
                    assert water == depth and conductivity == 1 and bottom > water > channel
                    expected = [bottom-Decimal(channel), bottom-water, water-Decimal(channel)]
                    observed = [total, saturated, unsaturated]
                    if mode == 'corrected':
                        assert item['returncode'] == 0 and not item['stderr'] and observed == expected
                        output = next(s.split() for s in item['stdout'].splitlines() if s.startswith('ACTUAL_DIVDRA_OVERLAP_OUTPUT '))
                        values = list(map(Decimal, output[1:])); assert all(v.is_finite() for v in values)
                        assert abs(sum(values[4:])-values[3]) <= Decimal('1e-10')
                        if spacing == 400:
                            assert item['stdout'] == q['cases']['original'][key]['stdout']; unchanged += 1
                    elif spacing == 40:
                        assert observed != expected; wrong += 1
                        if depth == 50:
                            assert item['returncode'] != 0 and 'Floating-point exception' in item['stderr'] and saturated == 0
                            traps += 1
                    else: assert item['returncode'] == 0 and observed == expected
            assert (wrong, traps, unchanged) == (6, 2, 6)
            results[label] = dict(corrected_geometric_cases=12, original_wrong_overlap_cases=wrong, original_FPE_cases=traps, unaffected_exact=unchanged)
            continue
        assert len(q['executions']) == 2
        for execution in q['executions']:
            mode = execution['mode']; assert execution['returncode'] == 0 and not execution['stderr']
            logs = json.loads(read(mode + '-compile.json'))
            assert len(logs) == (4 if label == 'cde' else 3)
            assert all(v['returncode'] == 0 and '-' + opt in v['command'] for v in logs)
            exe = executable(mode, 'actual-frost-cde' if label == 'cde' else 'actual-frost-divdra')
            assert SHA(exe) == execution['executable_sha256']
            corrected = text(read(mode + ('-divdra.f90' if label == 'cde' else '-actual-divdra.f90')))
            assert corrected.count(NEW) == 1 and corrected.replace(NEW, OLD, 1) == divdra
            if mode == 'original': assert read(mode + '-frozencond.f90') == originals['frozencond']
        assert q['executions'][0]['stdout'] == q['executions'][1]['stdout']
        if label == 'rates':
            rows = [s.split() for s in q['executions'][0]['stdout'].splitlines() if s.startswith('ACTUAL_FROZENBOUNDS_DIVDRA_RATES ')]
            assert len(rows) == 84
            for index, row in enumerate(rows, 1):
                assert int(row[1]) == index; levels = int(row[2]); values = list(map(Decimal, row[7:]))
                assert len(values) == 9 + 5*levels and all(v.is_finite() for v in values)
                assert all(0 <= v <= 1 for v in values[:4])
                assert abs(values[8]-sum(values[9:9+levels])) <= Decimal('1e-10')
                for level in range(levels):
                    assert abs(values[9+level]-sum(values[9+levels+level::levels])) <= Decimal('1e-10')
            results[label] = dict(actual_original_and_guarded_rate_cases=84)
            continue
        for execution in q['executions']:
            mode = execution['mode']; actual = text(read(mode + '-solute.f90'))
            declaration = '   real(8),save::frost_cde_probe_exponent=1d0\n   public::frost_cde_probe_exponent\n'
            assert actual.count(declaration) == 1; actual = actual.replace(declaration, '', 1)
            first = actual.index('      case (97)'); last = actual.index('      case (1)', first)
            fixture = actual[first:last]; assert not re.search(r'\b(?:qdra|cdrtot)\b', fixture)
            actual = actual[:first] + actual[last:]
            if mode == 'guarded':
                after = '               if (cmsy(i) <= 0d0) then'; assert actual.count(after) == 1
                actual = actual.replace(after, '               if (cmsy(i) < vsmall) then', 1)
            assert actual == solute
        rows = [s.split() for s in q['executions'][0]['stdout'].splitlines() if s.startswith('ACTUAL_FROST_CDE_TASK2 ')]
        assert len(rows) == 252; worst = Decimal(0)
        with localcontext() as ctx:
            ctx.prec = 80
            for index, row in enumerate(rows, 1):
                assert int(row[1]) == index; levels = int(row[2]); v = list(map(Decimal, row[3:]))
                assert len(v) == 26 + 4*levels and all(x.is_finite() for x in v)
                dt, bottom_rate = v[1:3]; before, concentration, after = v[10:14], v[14:18], v[18:22]
                lateral = [sum(v[26+i*levels+j] * (concentration[i] if v[26+i*levels+j] > 0 else Decimal('.007')) * dt for j in range(levels)) for i in range(4)]
                bottom = bottom_rate * (Decimal('.011') if bottom_rate > 0 else concentration[3]) * dt
                checks = [v[5]-sum(lateral), v[6]-sum(lateral), v[7]-bottom, v[8]-bottom, v[4]-v[3]+sum(lateral)-bottom, v[9]]
                checks += [(after[i]-before[i])*d+lateral[i]-(bottom if i == 3 else 0) for i, d in enumerate((10, 20, 40, 60))]
                worst = max(worst, *map(abs, checks)); assert all(abs(x) <= Decimal('1e-10') for x in checks)
        results[label] = dict(actual_literal_CDE_task2_cases=252, independent_decimal_budget_max_abs=str(worst), complete_original_source_inverse_exact=True)
    return dict(status='SEALED_ACTUAL_ORIGINAL_DEFECT_GEOMETRIC_CORRECTION_FROST_RATES_CDE_TASK2_PASS', components=results,
        model_executions=0, compiler_executions=0, implicit_boundary_jacobian_qualified=False)
