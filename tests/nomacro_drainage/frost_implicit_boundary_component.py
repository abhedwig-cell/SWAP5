"""Actual original ponded no-runoff Frost boundary Jacobian; no admission."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work', 'build-root', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    p.add_argument('--optimization', choices=('O0', 'O2'), required=True)
    a = p.parse_args(); a.output.mkdir(); a.build_root.mkdir(exist_ok=True)
    sys.path.insert(0, str(ROOT / 'app/hybrid_water'))
    import user_prepare
    import implicit_conductivity_jacobian
    import original_pond_budget
    import history_top_state
    import implicit_pond_availability
    import ordinary_implicit_pond_switch
    import ordinary_implicit_pond_tangent
    from daily_host import NO_MACRO_FP_FLAGS, no_macro_fp_profile
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
    q = dict(status='RUNNING', source=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
             optimization=a.optimization, floating_point_profile=no_macro_fp_profile(), compiler=[], model_periods=0,
             implicit_frost_public_admitted=False, scope='dry flux, no-runoff pond, linear/nonlinear/instantaneous runoff; fitted/examined Ksat; bottom6; three cells')
    def save(): (a.output / 'RESULT.json').write_text(json.dumps(q, indent=2) + '\n', encoding='utf-8')
    def run(cmd): return subprocess.run(cmd, cwd=a.build_root, capture_output=True, text=True, timeout=90)
    save()
    try:
        user_prepare.validate(a.reference_work)
        ref = a.reference_work / 'build'; objects = ref / 'swap-obj'
        files = sorted(p for p in objects.glob('*.o') if p.name != 'swap_main.o')
        def symbols(flag):
            result = run(['nm', '-g', flag, '--format=posix', *map(str, files)])
            result.check_returncode(); table = {}; current = None
            for line in result.stdout.splitlines():
                if line.endswith(':'): current = Path(line[:-1]); table[current] = set(); continue
                if current is not None and line.strip(): table[current].add(line.split()[0])
            assert set(table) == set(files)
            return table
        defined, undefined = symbols('--defined-only'), symbols('--undefined-only'); lookup = {}
        for path, values in defined.items():
            for value in values: lookup.setdefault(value, path)
        selected = {objects / 'headcalc.o'}
        while True:
            before = set(selected)
            for path in before: selected.update(lookup[s] for s in undefined[path] if s in lookup)
            if before == selected: break
        original = (ref / 'swap-selected/headcalc.f90').read_text(encoding='cp1252')
        probe = Path(__file__).with_name('frost_implicit_boundary_probe.f90').read_text(encoding='utf-8')
        entry = '   call frost_boundary_probe()\n   return\n'
        anchor = '!  reset some variables at the start of a new day'
        assert original.count(anchor) == 1 and original.count('contains') == 1
        q.update(actual_original_source_sha256=sha(ref / 'swap-selected/headcalc.f90'),
                 probe_sha256=sha(Path(__file__).with_name('frost_implicit_boundary_probe.f90')),
                 actual_original_object_closure=[dict(name=p.name, sha256=sha(p)) for p in sorted(selected)], variants={})
        old = ordinary_implicit_pond_tangent.headcalc(implicit_conductivity_jacobian.source(original))
        start = original.index('subroutine vector_F('); end = original.index('end subroutine vector_F')
        assert original[start:end] in old
        fixed = old
        for conductivity in ('katm', 'ksatfit(1)'):
            before = 'k(1),' + conductivity + ',dz(1)'
            surface_conductivity = 'merge(ksatexm(1),ksatfit(1),fluseksatexm(1))' if conductivity == 'ksatfit(1)' else conductivity
            after = 'k(1),' + surface_conductivity + '*rfcp(1)+hconode_vsmall*(1d0-rfcp(1)),dz(1)'
            assert fixed.count(before) == 2
            fixed = fixed.replace(before, after)
        import_anchor = '   use MOD_top,only:katm'
        assert fixed.count(import_anchor) == 1
        fixed = fixed.replace(import_anchor, '   use MOD_MvG,only:hconode_vsmall\n   use variables,only:ksatexm,fluseksatexm\n' + import_anchor, 1)
        assert fixed != old
        assert original[start:end] in fixed
        # Reuse the exact accepted history/availability/pond providers, including
        # their strict whole-source identity checks. Do not reconstruct a tangent.
        top_original = (ref / 'swap-selected/boundtop.f90').read_text(encoding='cp1252')
        before_pond = implicit_pond_availability.top_source(history_top_state.render(original_pond_budget.render(top_original)))
        assert hashlib.sha256(before_pond.encode('cp1252')).hexdigest() == ordinary_implicit_pond_switch.ORIGINAL_TOP[True]
        top_source = ordinary_implicit_pond_tangent.top(ordinary_implicit_pond_switch.source(before_pond))
        ordinary_implicit_pond_switch.actual_source(top_source.encode('cp1252'), True)
        top_path = a.build_root / 'actual-qualified-history-boundtop.f90'
        top_path.write_text(top_source, encoding='cp1252')
        q.update(actual_qualified_top_sha256=sha(top_path), actual_qualified_top_parent_sha256=hashlib.sha256(before_pond.encode('cp1252')).hexdigest(),
                 inherited_original_pond_tangent_sha256=sha(Path(ordinary_implicit_pond_tangent.__file__)),
                 original_residual_preserved=True, physical_top_changed_from_qualified_ordinary=False)
        driver = a.build_root / 'driver.f90'
        driver.write_text('program actual_boundary\ncall headcalc\nend program\n', encoding='ascii')
        flags = ['gfortran', '-' + a.optimization, '-ffree-line-length-none', '-fcheck=all', '-fimplicit-none',
                 '-finit-local-zero', '-ffpe-trap=invalid,zero,overflow', *NO_MACRO_FP_FLAGS,
                 '-I' + str(a.build_root), '-I' + str(objects), '-I' + str(ref / 'ttutil-obj'), '-J' + str(a.build_root)]
        top_obj = a.build_root / 'actual_qualified_top.o'
        command = [*flags, '-c', str(top_path), '-o', str(top_obj)]
        start = time.perf_counter(); result = run(command)
        q['compiler'].append(dict(command=command, returncode=result.returncode, seconds=time.perf_counter()-start,
                                  stdout=result.stdout, stderr=result.stderr)); save(); result.check_returncode()
        (a.output / top_path.name).write_bytes(top_path.read_bytes())
        for name, text in [('actual_qualified_ordinary_implicit_composition', old), ('diagnostic_frost_surface_conductivity', fixed)]:
            source = a.build_root / (name + '.f90')
            injected = text.replace(anchor, entry + anchor, 1).replace('contains', 'contains\n' + probe, 1)
            assert injected.replace(entry, '', 1).replace('\n' + probe, '', 1) == text
            source.write_text(injected, encoding='cp1252')
            obj = a.build_root / (name + '.o'); exe = a.build_root / (name + ('.exe' if os.name == 'nt' else ''))
            for command in [[*flags, '-c', str(source), '-o', str(obj)],
                            [*flags, str(driver), str(obj), str(top_obj), *map(str, sorted(selected - {objects / 'headcalc.o', objects / 'boundtop.o'})),
                             str(ref / 'ttutil-obj/libttutil.a'), '-o', str(exe)]]:
                start = time.perf_counter(); result = run(command)
                q['compiler'].append(dict(command=command, returncode=result.returncode, seconds=time.perf_counter()-start,
                                          stdout=result.stdout, stderr=result.stderr)); save(); result.check_returncode()
            result = run([str(exe)])
            observation = dict(returncode=result.returncode, stdout=result.stdout, stderr=result.stderr,
                               executable_sha256=sha(exe), injected_source_sha256=sha(source))
            q['variants'][name] = observation; save(); result.check_returncode()
            assert not result.stderr
            rows = [line.split() for line in result.stdout.splitlines() if line.startswith('ACTUAL_FROST_BOUNDARY ')]
            assert len(rows) == 1440 and all(len(row) == 14 for row in rows)
            values = [[float(v) for v in row[7:]] for row in rows]
            assert all(math.isfinite(v) for row in values for v in row)
            observation.update(cases=len(rows), failures=sum(row[-1] > 2e-6 for row in values),
                               max_relative_error=max(row[-1] for row in values))
            matrix_rows = [line.split() for line in result.stdout.splitlines() if line.startswith('ACTUAL_FROST_MATRIX ')]
            assert len(matrix_rows) == 12960 and all(len(row) == 9 for row in matrix_rows)
            matrix_values = [[float(v) for v in row[4:]] for row in matrix_rows]
            assert all(math.isfinite(v) for row in matrix_values for v in row)
            observation.update(matrix_entries=len(matrix_rows),
                matrix_failures=sum(row[-1] > 2e-6 for row in matrix_values),
                matrix_max_relative_error=max(row[-1] for row in matrix_values))
            for path in (source, exe): (a.output / path.name).write_bytes(path.read_bytes())
            save()
        assert q['variants']['diagnostic_frost_surface_conductivity']['failures'] == 0
        assert q['variants']['diagnostic_frost_surface_conductivity']['matrix_failures'] == 0
        assert q['variants']['actual_qualified_ordinary_implicit_composition']['failures'] > 0
        q['status'] = 'ACTUAL_QUALIFIED_POND_COMPOSITION_FROST_SURFACE_1440_STATES_12960_ENTRIES_PASS_NO_PUBLIC_ADMISSION'
        print(q['status'], len(selected), flush=True)
    except Exception as error:
        q.update(status='FAILED', error=repr(error)); raise
    finally: save()


if __name__ == '__main__': main()
