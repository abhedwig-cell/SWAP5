"""Read-only independent original source, compiler and chemical receipt audit."""
import argparse
import hashlib
import json
import math
import re
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work', 'evidence', 'output'):
        p.add_argument('--' + name, type=Path, required=True)
    args = p.parse_args(); assert not args.output.exists()
    sha = lambda raw: hashlib.sha256(raw).hexdigest()
    ref = args.reference_work / 'build'
    original = (ref / 'swap-selected/solute.f90').read_text(encoding='cp1252')
    divdra = (ref / 'swap-selected/divdra.f90').read_text(encoding='cp1252')
    observations = []
    for opt in ('O0', 'O2'):
        folder = args.evidence / ('frost-cde-drainage-cde-' + opt + '-v2')
        raw = (folder / 'RESULT.json').read_bytes(); q = json.loads(raw)
        assert q['status'] == 'ACTUAL_FROST_CORRECTED_DIVDRA_CDE_TASK2_252_CASES_PASS_NOT_MODEL_QUALIFIED'
        assert q['model_periods'] == 0 and not q['canonical_admission']
        for item in q['original_object_closure']:
            assert sha((ref / 'swap-obj' / item['name']).read_bytes()) == item['sha256']
        for mode in ('original', 'guarded'):
            execution = next(v for v in q['executions'] if v['mode'] == mode)
            actual = (folder / (mode + '-solute.f90')).read_text(encoding='cp1252')
            declaration = ('   real(8),save::frost_cde_probe_exponent=1d0\n'
                           '   public::frost_cde_probe_exponent\n')
            assert actual.count(declaration) == 1
            actual = actual.replace(declaration, '', 1)
            start = actual.index('      case (97)'); end = actual.index('      case (1)', start)
            fixture = actual[start:end]
            assert not re.search(r'\b(?:qdra|cdrtot)\b', fixture) and 'case (2)' not in fixture
            actual = actual[:start] + actual[end:]
            if mode == 'guarded':
                old, new = '               if (cmsy(i) < vsmall) then', '               if (cmsy(i) <= 0d0) then'
                assert actual.count(new) == 1; actual = actual.replace(new, old, 1)
            assert actual == original, 'Complete original CDE source inverse differs'
            corrected = (folder / (mode + '-divdra.f90')).read_text(encoding='cp1252')
            before = '               if (icpbotdislay(idr) == icpwlev) dzcpbotdislay(idr) = dzcpwlevsat'
            after = '               ! FROST-DIVDRA-OVERLAP-01: retain the actual Lev2Comp above-bottom extent.'
            assert corrected.count(after) == 1 and corrected.replace(after, before, 1) == divdra
            logs = json.loads((folder / (mode + '-compile.json')).read_text(encoding='utf-8'))
            assert len(logs) == 4 and all(v['returncode'] == 0 and '-' + opt in v['command'] for v in logs)
            link = logs[-1]['command']
            oldobjects = [Path(v).name for v in link if Path(v).parent == ref / 'swap-obj']
            expected = {v['name'] for v in q['original_object_closure']} - {'frozencond.o', 'divdra.o', 'solute.o'}
            assert set(oldobjects) == expected and len(oldobjects) == len(expected)
            exe = folder / (mode + '-actual-frost-cde.exe')
            assert sha(exe.read_bytes()) == execution['executable_sha256']
            assert execution['returncode'] == 0 and not execution['stderr']
            rows = [s.split() for s in execution['stdout'].splitlines() if s.startswith('ACTUAL_FROST_CDE_TASK2 ')]
            assert len(rows) == 252
            worst = 0.0
            for row in rows:
                levels = int(row[2]); v = list(map(float, row[3:]))
                assert len(v) == 26 + 4 * levels and all(map(math.isfinite, v))
                dt, bot = v[1], v[2]; initial, final = v[3:5]
                mass0, c0, mass1 = v[10:14], v[14:18], v[18:22]
                lateral = []
                for i in range(4):
                    flows = v[26 + i * levels:26 + (i + 1) * levels]
                    leaving = math.fsum(max(x, 0) for x in flows) * c0[i]
                    entering = math.fsum(min(x, 0) for x in flows) * .007
                    lateral.append(dt * (leaving + entering))
                bottom = dt * bot * (.011 if bot > 0 else c0[3])
                checks = [v[5] - math.fsum(lateral), v[6] - math.fsum(lateral),
                    v[7] - bottom, v[8] - bottom, final - initial + math.fsum(lateral) - bottom, v[9]]
                checks += [(mass1[i] - mass0[i]) * d + lateral[i] - (bottom if i == 3 else 0)
                           for i, d in enumerate((10, 20, 40, 60))]
                worst = max(worst, *map(abs, checks))
                assert max(map(abs, checks)) <= 1e-10
            observations.append(dict(optimization=opt, mode=mode, producer=q['source'], result_sha256=sha(raw),
                full_original_CDE_inverse_exact=True, full_original_Divdra_single_edit_inverse_exact=True,
                original_objects=len(expected), actual_recompiled_modules=3, cases=len(rows),
                independently_summed_budget_max_abs=worst))
    result = dict(status='INDEPENDENT_COMPLETE_SOURCE_COMPILER_CDE_RECEIPT_PASS_NOT_MODEL_QUALIFIED',
        auditor_source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        observations=observations, compiler_executions=0, model_executions=0, canonical_admission=False)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(result['status'], max(v['independently_summed_budget_max_abs'] for v in observations))


if __name__ == '__main__':
    main()
