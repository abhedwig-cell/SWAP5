"""Independently check the strict wet4 run before comparing temporal budgets."""
import argparse
import hashlib
import json
from pathlib import Path

from assess_perf01_weather import read, differences

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--strict', type=Path, required=True)
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--comparison', type=Path, action='append', default=[])
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
build = json.loads((args.build / 'BUILD.json').read_text())
assert build['status'] == 'BUILT'
assert sha(args.build / 'weather') == build['executable_sha256']
assert sha(args.build / 'weather.999') == build['weather_sha256'] == \
    'b69d91f8af402b4783a3b5bbd51026492b93b04de6be90717648e9b806db0fb8'
overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
             'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
             'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
for source, expected in build['sources'].items():
    path = args.build / overrides[source] if source in overrides else root / source
    assert sha(path) == expected, source
for source, key in [('src/runtime/mod_fmr_serialized_multiswap_runtime.f90', 'observer_original_sha256'),
                    ('src/runtime/mod_fmr_production_application_bootstrap.f90', 'surface_observer_original_sha256'),
                    ('src/legacy/b1_10_port/headcalc.f90', 'headcalc_sha256')]:
    assert sha(root / source) == build[key], source
strict, rows = read(args.strict)
assert strict['head_budget_cm'] == 1e-6
assert strict['executable_sha256'] == build['executable_sha256']
assert strict['weather_sha256'] == build['weather_sha256']
assert strict['expected_rain_mm'] == 908
assert abs(strict['totals']['rain_mm'] - 908) < 1e-8
assert strict['totals']['runoff_mm'] > 0, 'wet surface discriminator inactive'
comparison = {}
for directory in args.comparison:
    metrics, other = read(directory)
    assert metrics['executable_sha256'] == strict['executable_sha256']
    assert abs(metrics['totals']['rain_mm'] - 908) < 1e-8
    assert sha(Path(metrics['command'][4])) == build['weather_sha256']
    comparison[str(metrics['head_budget_cm'])] = differences(other, rows)
result = dict(status='STRICT_WET4_97DAY_BALANCE_AND_SOURCE_PASS', metrics=strict,
              coarser_minus_strict=comparison, provider_count=len(build['sources']),
              production_postimages={source: sha(root / source) for source in build['sources']
                                    if source not in overrides},
              claim_ceiling='Finite temporal refinement, four-cell30cm illustrative column. '
              'No exact physical truth, uniform saturated-head accuracy or canonical admission.')
args.output.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(dict(status=result['status'], totals=strict['totals'],
                      max_gross_daily_closure_mm=strict['max_gross_daily_closure_mm'],
                      coarser_minus_strict=comparison), indent=2))
