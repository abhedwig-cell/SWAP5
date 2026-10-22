"""Run a source-built weather executable with the original exact 1x/4x inputs."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--build', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
ap.add_argument('--rain', type=int, choices=[1, 4], required=True)
ap.add_argument('--budget', type=float, default=.001)
ap.add_argument('--restart', action='store_true')
args = ap.parse_args()
build, output = args.build.resolve(), args.output.resolve()
meta = json.loads((build / 'BUILD.json').read_text())
assert meta['status'] == 'BUILT'
assert hashlib.sha256((build / 'weather').read_bytes()).hexdigest() == meta['executable_sha256']
output.mkdir(parents=True, exist_ok=False)
view = output / 'input'; view.mkdir()
archive = ROOT / 'benchmarks/performance/PERF01_WET4_REVIEW_20261022_EVIDENCE.tar.xz'
assert hashlib.sha256(archive.read_bytes()).hexdigest() == '804e683e352acf47df28a8561b4447e0c60294154706eb8da99852bf62bdbe78'
if args.rain == 4:
    with tarfile.open(archive, 'r:xz') as tar:
        weather = tar.extractfile('build/fallback-O2/weather.999').read()
else:
    import gzip
    weather = gzip.decompress((ROOT / 'tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz').read_bytes())
weather_hash = hashlib.sha256(weather).hexdigest()
assert weather_hash == {1: 'ba5c1f880f6166842ed292c18fd12a142cfda4158002f9487fd1420e734e7b72',
                        4: 'b69d91f8af402b4783a3b5bbd51026492b93b04de6be90717648e9b806db0fb8'}[args.rain]
(view / 'weather.999').write_bytes(weather)
shutil.copy2(build / 'weather', view / 'weather')
meta['weather_sha256'] = weather_hash
(view / 'BUILD.json').write_text(json.dumps(meta, indent=2) + '\n')
cmd = [sys.executable, str(ROOT / 'benchmarks/performance/run_perf01_weather_bound.py'),
       '--build', str(view), '--output', str(output / 'native'), '--budget', str(args.budget),
       '--expected-rain-mm', str(args.rain * 227), '--timeout', '120']
if args.restart:
    cmd += ['--restart']
subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
report = json.loads((output / 'native/RESULT.json').read_text())
print(json.dumps({k: report[k] for k in ['status', 'completed_days', 'total_rain_mm', 'user_seconds', 'wall_seconds']}))
