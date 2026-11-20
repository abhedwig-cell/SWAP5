"""Reuse frozen independent Frost science with only the new native codec constants."""
import argparse
import ast
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
READERS = 'b285147254b208643423adea88a4fb5f1158b464'
PARENT_READER = 'tests/nomacro_drainage/frost_cde_drainage_model_forensics.py'


def audit(profile, reference):
    sys.path[:0] = [str(ROOT/'tests/nomacro_drainage'), str(ROOT/'app/hybrid_water')]
    import frost_cde_drainage_model_forensics as frozen
    raw = subprocess.check_output(['git', 'show', READERS + ':' + PARENT_READER], cwd=ROOT)
    if (ROOT/PARENT_READER).read_bytes().replace(b'\r\n', b'\n') != raw:
        raise ValueError('Frozen independent Frost model reader changed')
    functions = [n for n in ast.parse(raw.decode('utf-8')).body
                 if isinstance(n, ast.FunctionDef) and n.name == 'audit']
    if len(functions) != 1: raise ValueError('Missing frozen scientific audit')

    class NativeCodec(ast.NodeTransformer):
        count = 0
        def visit_Constant(self, node):
            replacements = {b'S5FDW001': b'S5FIW002', b'S5FDC001': b'S5FIC002'}
            if isinstance(node.value, bytes) and node.value in replacements:
                self.count += 1
                return ast.copy_location(ast.Constant(value=replacements[node.value]), node)
            return node

    selector = NativeCodec(); function = selector.visit(functions[0])
    if selector.count != 2: raise ValueError('Ambiguous distinct native codec adaptation')
    namespace = dict(vars(frozen))
    module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    exec(compile(module, PARENT_READER, 'exec'), namespace)
    result = namespace['audit'](profile, reference)

    q = json.loads((profile/'RESULT.json').read_text(encoding='utf-8'))
    rows = [json.loads(line, parse_float=Decimal)
            for line in (profile/'trajectory/daily.jsonl').read_text(encoding='utf-8').splitlines()]
    with localcontext() as context:
        context.prec = 80
        initial = sum(rows[0]['stock_start_cm'])
        accumulated = [Decimal(0)] * len(rows[0]['external_flux_cm'])
        maximum = Decimal(0)
        for row in rows:
            accumulated = [a+b for a, b in zip(accumulated, row['external_flux_cm'])]
            residual = initial-sum(row['stock_end_cm'])+sum(accumulated[:7])-sum(accumulated[7:])
            maximum = max(maximum, abs(residual))
    result['water_prefix_max_decimal'] = str(maximum)
    # This additional whole-trajectory absolute metric is retained explicitly.
    # The inherited owning gates remain absolute daily/terminal 1e-10 cm,
    # internal cumulative-step 1e-10 times its elapsed window, and absolute
    # every-prefix CDE 1e-10 mg/cm2. Do not invent a new fixed global water
    # criterion or silently describe its diagnostic as passing.
    result['additional_absolute_global_water_prefix_within_1e10'] = maximum <= Decimal('1e-10')
    result['absolute_global_water_prefix_is_owning_acceptance_gate'] = False
    result['owning_water_guards'] = 'absolute daily/terminal 1e-10 cm and original cumulative hydraulic-step window rule'
    build = Path(q['build_root']); inputs = Path(q['input_root'])
    meta = json.loads((build/'BUILD.json').read_text(encoding='utf-8'))
    if (meta['identity'].get('implicit_conductivity') or {}).get('implicit_frost_composition') is not True:
        raise ValueError('Actual input/build does not select implicit Frost')
    import experimental_project
    from implicit_frost_source_guard import validate_source
    project = experimental_project.load(inputs, original_output=True,
                                       time_step_policy='original-adaptive-event-closure-v1')
    validate_source(build, project, meta['identity'], reference)
    return dict(**result, implicit_frost_source_parents_verified=True,
        frozen_scientific_reader=READERS, frozen_reader_sha256=hashlib.sha256(raw).hexdigest(),
        inherited_scientific_body_executed=True, changed_reader_constants=selector.count,
        reader_adaptation='only distinct S5FIW002/S5FIC002 native codec constants; no scientific statement changed',
        fresh_model_executions=0, fresh_compiler_executions=0)


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('profile', 'reference-work', 'output'):
        p.add_argument('--' + key, type=Path, required=True)
    a = p.parse_args()
    if a.output.exists(): raise ValueError('Never overwrite an original independent observation')
    result = audit(a.profile, a.reference_work)
    a.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    print(result['status'], result['kind'], result['optimization'], result['days'])
