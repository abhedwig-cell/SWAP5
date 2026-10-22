"""Bind a weather experiment to its input bytes and declared total rainfall.

Keep the original sealed observation runner unchanged. All remaining arguments
are forwarded to it, including duration, temporal budget and restart selection.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--build', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--expected-rain-mm', type=float, required=True)
args, remaining = parser.parse_known_args()
if not math.isfinite(args.expected_rain_mm) or args.expected_rain_mm < 0:
    parser.error('--expected-rain-mm must be finite and nonnegative')
build = args.build.resolve()
manifest = json.loads((build / 'BUILD.json').read_text())
weather_hash = hashlib.sha256((build / 'weather.999').read_bytes()).hexdigest()
if weather_hash != manifest['weather_sha256']:
    parser.error('weather input differs from build manifest')
runner = Path(__file__).with_name('run_perf01_weather.py')
subprocess.run([sys.executable, str(runner), '--build', str(build),
                '--output', str(args.output.resolve()), *remaining], check=True,
               stdout=subprocess.DEVNULL)
record_path = args.output.resolve() / 'RESULT.json'
record = json.loads(record_path.read_text())
record.update(weather_sha256=weather_hash, expected_rain_mm=args.expected_rain_mm)
if record['status'] == 'COMPLETE_NATIVE_OBSERVATION':
    import csv
    with (args.output / 'daily.csv').open() as stream:
        rain = sum(float(row['rain_mm']) for row in csv.DictReader(stream))
    record['total_rain_mm'] = rain
    if not math.isfinite(rain) or abs(rain - args.expected_rain_mm) > 1e-8:
        record['status'] = 'FORCING_MISMATCH'
record_path.write_text(json.dumps(record, indent=2) + '\n')
print(json.dumps(record), flush=True)
sys.exit(0 if record['status'] == 'COMPLETE_NATIVE_OBSERVATION' else 1)
