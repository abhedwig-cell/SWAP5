"""Reuse real Frost native/transaction controls for the bounded implicit domain."""
import argparse
import ast
import contextlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tests/nomacro_drainage'))
import frost_cde_drainage_controls as previous


def main():
    p = argparse.ArgumentParser(add_help=False)
    for key in ('reference-work', 'profile', 'scratch', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    a = p.parse_args()
    path = 'tests/nomacro_drainage/frost_cde_drainage_controls.py'
    raw = subprocess.check_output(['git', 'show', 'b285147254b208643423adea88a4fb5f1158b464:' + path], cwd=ROOT)
    if (ROOT/path).read_bytes().replace(b'\r\n', b'\n') != raw:
        raise ValueError('Inherited actual Frost controls changed')
    functions = [n for n in ast.parse(raw.decode()).body if isinstance(n, ast.FunctionDef) and n.name == 'main']
    if len(functions) != 1: raise ValueError('Missing inherited actual controls')

    class Scope(ast.NodeTransformer):
        tuples = 0
        sources = 0
        constants = 0
        divd0 = 0
        def visit_If(self, node):
            self.generic_visit(node)
            if (ast.unparse(node.test) == 'project.solute' and
                    'input-original-invalid-divd0' in ast.unparse(node)):
                self.divd0 += 1
                node.test = ast.Constant(True)
            return node
        def visit_Tuple(self, node):
            self.generic_visit(node)
            if [n.value if isinstance(n, ast.Constant) else None for n in node.elts] == ['implicit', 'SWKIMPL', 1]:
                self.tuples += 1
                node.elts = [ast.Constant('unsupported-implicit-selector'), ast.Constant('SWKIMPL'), ast.Constant(2)]
            return node
        def visit_List(self, node):
            self.generic_visit(node)
            if [n.value if isinstance(n, ast.Constant) else None for n in node.elts] == ['divdra.f90', 'frozencond.f90', 'timecontrol.f90', 'integral.f90']:
                self.sources += 1
                node.elts += [ast.Constant('headcalc.f90'), ast.Constant('boundtop.f90')]
            return node
        def visit_Constant(self, node):
            replacements = {'SWDIVD0': 'SWDIVD1', 'original-invalid-divd0': 'implicit-divd0-refused',
                'ACTUAL_FROST_SWDIVD1_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS':
                'ACTUAL_IMPLICIT_FROST_COMPILED_NATIVE_ACTIVE_TRANSACTIONS_SCOPE_SOURCE_CONTROLS_PASS'}
            if isinstance(node.value, str) and node.value in replacements:
                self.constants += 1
                return ast.copy_location(ast.Constant(replacements[node.value]), node)
            return node

    adaptation = Scope(); function = adaptation.visit(functions[0])
    if (adaptation.tuples, adaptation.sources, adaptation.constants, adaptation.divd0) != (1, 1, 3, 1):
        raise ValueError('Ambiguous bounded implicit control adaptation')
    # Preserve every inherited compiled attack. Its CDE-tail shape assertion
    # owns the old prefix; the distinct revision2 root tail follows it.
    native_path = 'tests/nomacro_scheduled_subsurface/output_thermal_controls.py'
    native_raw = subprocess.check_output(['git','show','b285147254b208643423adea88a4fb5f1158b464:'+native_path],cwd=ROOT)
    if (ROOT/native_path).read_bytes().replace(b'\r\n',b'\n') != native_raw:
        raise ValueError('Inherited compiled thermal controls changed')
    native_functions = [node for node in ast.parse(native_raw.decode()).body
                        if isinstance(node,ast.FunctionDef) and node.name=='native']
    if len(native_functions)!=1: raise ValueError('Missing literal native controls')
    class RootTail(ast.NodeTransformer):
        changes = 0
        def visit_Compare(self,node):
            self.generic_visit(node)
            if ast.unparse(node)=='c + 24 + 16 * n == len(raw)':
                self.changes += 1
                node.comparators[0] = ast.BinOp(left=node.comparators[0],op=ast.Sub(),right=ast.Constant(96))
            return node
    tail = RootTail(); native_function = tail.visit(native_functions[0])
    if tail.changes!=1: raise ValueError('Ambiguous separate root-tail shape adaptation')
    native_namespace = dict(vars(previous.inherited))
    exec(compile(ast.fix_missing_locations(ast.Module(body=[native_function],type_ignores=[])),native_path,'exec'),native_namespace)
    previous.inherited.native = native_namespace['native']
    namespace = dict(vars(previous))
    module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    exec(compile(module, path, 'exec'), namespace)
    namespace['main']()

    m = previous.inherited.m
    q = json.loads((a.profile/'RESULT.json').read_text(encoding='utf-8'))
    build = Path(q['build_root']); inputs = Path(q['input_root'])
    project = m.e.load(inputs, original_output=True, time_step_policy='original-adaptive-event-closure-v1')
    meta, case = m.validate_bundle(build, a.reference_work, project)
    source = a.profile/'trajectory/accepted-column-1-day-4.zip'; digest = m.sha(source)
    target = a.output/'explicit-parent-native-codec'; target.mkdir()
    origin = target/'origin'; receipt = m.h.verify_checkpoint(source, 4, meta['binding'], origin)
    native = origin/'macro.bin'; original = native.read_bytes()
    assert original[:8] == (b'S5FIC002' if project.solute else b'S5FIW002')
    native.write_bytes((b'S5FDC001' if project.solute else b'S5FDW001') + original[8:])
    try:
        with contextlib.ExitStack() as stack:
            m.h.DailyHost(stack, m.h.executable(build, 'day_donor'), m.h.executable(build, 'day_kernel'),
                case, target, [m.h.ColumnStart('original', 4, origin, receipt)], runtime=True,
                checkpoint_enabled=True, binding=meta['binding'], model=project.model, project=project)
    except (ValueError, RuntimeError) as error:
        diagnostic = '\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
        assert 'ERROR STOP' in diagnostic and not list(target.glob('accepted-*.zip'))
        result = dict(attack='actual-explicit-Frost-parent-codec', status='REFUSED',
                      error=str(error), diagnostic=diagnostic, original_checkpoint_unchanged=m.sha(source)==digest)
    else:
        raise AssertionError('Explicit Frost native accepted as implicit state')
    (a.output/'EXPLICIT_PARENT_CODEC_NEGATIVE.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    from implicit_frost_source_guard import validate_source
    checks = []
    for helper in ('headcalc.f90', 'boundtop.f90'):
        bad = a.scratch/('source-'+helper)
        try: validate_source(bad, project, meta['identity'], a.reference_work)
        except ValueError as error: checks.append(dict(provider=helper, status='REFUSED', error=str(error)))
        else: raise AssertionError('Foreign complete independent implicit source parent accepted')
    (a.output/'INDEPENDENT_SOURCE_PARENT_NEGATIVES.json').write_text(json.dumps(checks, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__': main()
