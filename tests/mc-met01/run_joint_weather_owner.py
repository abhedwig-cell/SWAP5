#!/usr/bin/env python3
"""Retain all incumbent weather cases and add legacy/typed physical equivalence.

The existing controlled owning build is reused for four distinct drivers; no
provider is compiled twice per optimization. Frozen assertions remain verbatim.
"""
from pathlib import Path
import ast
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/modularity'))
from joint_admission_authority import verify_source


def legacy_driver(output):
    path = ROOT / 'tests/mc-met01/run_raintb_legacy_pilot.py'
    tree = ast.parse(path.read_text())
    function = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'integration')
    index = next(i for i, n in enumerate(function.body) if isinstance(n, ast.Assign)
                 and any(isinstance(t, ast.Name) and t.id == 'runner' for t in n.targets))
    function.body = function.body[:index] + [ast.Return(value=ast.Name(id='driver', ctx=ast.Load()))]
    module = ast.fix_missing_locations(ast.Module(body=[function], type_ignores=[]))
    namespace = {'ROOT': ROOT, 'hashlib': hashlib}
    exec(compile(module, str(path), 'exec'), namespace)
    return namespace['integration'](output)


def main():
    verify_source()
    path = ROOT / 'tests/mc-met01/run_raintb_legacy_owner_preservation.py'
    source = path.read_text()
    old = "drivers={'weather':ROOT/'tests/fmig431/test_crop_file_weather_production.f90'}"
    assert source.count(old) == 1
    source = source.replace(old, old + "\n    drivers['legacy']=legacy_driver(output)")
    source = source.replace("moistures=['neutral','dry','hydraulic'] if name=='weather' else ['neutral']",
        "moistures=['typed','legacy'] if name=='legacy' else ['neutral','dry','hydraulic'] if name=='weather' else ['neutral']")
    old = "mode,moisture],build,f'native-{name}-{moisture}-{mode}')"
    assert source.count(old) == 1
    source = source.replace(old, "mode,*(['neutral',moisture] if name=='legacy' else [moisture])],build,f'native-{name}-{moisture}-{mode}')")
    old = "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]"
    assert source.count(old) == 1
    source = source.replace(old, "'raintb':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS','legacy':b'MC_MET01_AUTHENTIC_PULSE_OFF_NEXT_DAY_RESTART_MASS=PASS'}[name]")
    old = '    for key,digest in output_hashes.items():'
    assert source.count(old) == 1
    source = source.replace(old, "    for opt in (0,2):\n        for mode in ['continuous','restart']:\n            assert output_hashes[(opt,'legacy','typed',mode)]==output_hashes[(opt,'legacy','legacy',mode)],'physical legacy/typed drift'\n" + old)
    # Keep the executed instrumentation and both original controller identities.
    old = '    results=[];output_hashes={}'
    source = source.replace(old, "    write(output/'JOINT_RECIPE.json',{'source_tree':verify_source()['source_tree'],'owner_controller_sha256':owner_digest,'legacy_controller_sha256':legacy_digest,'executed_controller_sha256':hashlib.sha256(executed_source.encode()).hexdigest(),'original_cases':20,'legacy_cases':8,'expected_compile_units':466,'links':8})\n    (output/'executed_controller.py').write_text(executed_source)\n" + old)
    namespace = {'__file__': str(path), '__name__': '__main__', 'legacy_driver': legacy_driver,
                 'verify_source': verify_source, 'executed_source': source,
                 'owner_digest': hashlib.sha256(path.read_bytes()).hexdigest(),
                 'legacy_digest': hashlib.sha256((ROOT / 'tests/mc-met01/run_raintb_legacy_pilot.py').read_bytes()).hexdigest()}
    exec(compile(source, str(path), 'exec'), namespace)
    verify_source()


if __name__ == '__main__':
    main()
