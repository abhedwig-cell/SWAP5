#!/usr/bin/env python3
"""Run a rain-only fallow SWP/MET calendar through the admitted solute column.

Original source bytes and adapter identities are embedded as comments in the
generated namelist. The existing atomic launcher binds that complete document
and the SWP to every output/restart generation, with its original inventory.
"""
import argparse
import base64
import csv
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(data):
    return hashlib.sha256(data).hexdigest()


def prepare(reader, swp, met, column, with_etref=False):
    meta = json.loads((reader.parent / 'build-complete.json').read_text())
    if meta.get('status') != 'BUILT' or meta.get('executable_sha256') != sha(reader.read_bytes()):
        raise ValueError('daily reader executable identity mismatch')
    for path, expected in meta['input_sha256'].items():
        if sha((ROOT / path).read_bytes()) != expected:
            raise ValueError('daily reader source identity mismatch: ' + path)
    swp_bytes, met_bytes = swp.read_bytes(), met.read_bytes()
    if met.suffix.lower() != '.met':
        raise ValueError('single .MET file required')
    with tempfile.TemporaryDirectory(prefix='swap5-daily-') as tmp:
        stage = Path(tmp)
        (stage / 'input.swp').write_bytes(swp_bytes)
        (stage / met.name.lower()).write_bytes(met_bytes)
        result = subprocess.run([str(reader), 'input.swp', met.name.lower()] + (['etref'] if with_etref else []), cwd=stage,
                                input=b'', capture_output=True, timeout=60)
        if result.returncode or b'SWP_NATIVE_DAILY_MET_IMPORTED' not in result.stdout:
            raise ValueError('native MET import failed:\n' + result.stdout.decode(errors='replace') +
                             result.stderr.decode(errors='replace'))
        rows = list(csv.DictReader((stage / 'daily.csv').open()))
    comments = ['! SWAP5 native daily rain-only fallow route v1',
                '! generator_sha256=' + sha(Path(__file__).read_bytes()),
                '! reader_executable_sha256=' + meta['executable_sha256']]
    for name, data in [('original_swp', swp_bytes), ('original_met', met_bytes)]:
        comments.append('! ' + name + '_sha256=' + sha(data))
        encoded = base64.b64encode(data).decode()
        comments.extend('! ' + name + '_base64=' + encoded[i:i + 76]
                        for i in range(0, len(encoded), 76))
    lines = comments + ['&column', ' schema=2,nodes=0,swp_water_bootstrap=.true.']
    for name, value in column.items():
        if not math.isfinite(value):
            raise ValueError('nonfinite column option: ' + name)
        lines.append(f' {name}={value:.17e}')
    lines += ['/', '&surface', f' windows={len(rows)}',
              ' ends_day=' + ','.join(r['end_day'] for r in rows),
              ' rain_cm_day=' + ','.join(r['rain_cm_day'] for r in rows), '/']
    if with_etref:
        lines[-1:-1] = [' soil_evaporation_cm_day=' + ','.join(r['soil_demand_cm_day'] for r in rows),
                        ' evaporation_cm_day=' + ','.join(r['pond_demand_cm_day'] for r in rows)]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--etref', action='store_true', help='Explicit SWREDU=0 fallow evaporation composition')
    parser.add_argument('--reader', type=Path, required=True)
    parser.add_argument('--exe', type=Path, required=True)
    parser.add_argument('--swp', type=Path, required=True)
    parser.add_argument('--met', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--restart', type=Path)
    parser.add_argument('--stop-after', type=int, default=2048)
    parser.add_argument('--temporal-tolerance', type=float, help='Existing explicit column temporal policy')
    parser.add_argument('--initial-pond-cm', type=float, default=0.)
    parser.add_argument('--bottom-up-cm-day', type=float, default=0.)
    parser.add_argument('--pond-max-cm', type=float, default=1e6)
    parser.add_argument('--runoff-resistance-day', type=float, default=0.)
    args = parser.parse_args()
    column = {name: getattr(args, name) for name in ['initial_pond_cm', 'bottom_up_cm_day',
                                                   'pond_max_cm', 'runoff_resistance_day']}
    if args.temporal_tolerance is not None:
        column['temporal_tolerance'] = args.temporal_tolerance
    if args.output.exists():
        raise FileExistsError(args.output)
    document = prepare(args.reader.resolve(), args.swp.resolve(), args.met.resolve(), column, args.etref)
    with tempfile.TemporaryDirectory(prefix='swap5-daily-run-') as tmp:
        source = Path(tmp) / 'daily.nml'
        source.write_text(document)
        # Run the exact SWP snapshot embedded above, including under concurrent
        # source edits between preprocessing and the existing launcher's staging.
        snapshot = Path(tmp) / 'input.swp'
        encoded = ''.join(line.split('=', 1)[1] for line in document.splitlines()
                          if line.startswith('! original_swp_base64='))
        snapshot.write_bytes(base64.b64decode(encoded, validate=True))
        command = [sys.executable, str(ROOT / 'tools/solute/run_column.py'),
                   '--exe', str(args.exe.resolve()), '--input', str(source), '--swp', str(snapshot),
                   '--output', str(args.output.resolve()), '--stop-after', str(args.stop_after)]
        if args.restart:
            command += ['--restart', str(args.restart.resolve())]
        subprocess.run(command, check=True)


if __name__ == '__main__':
    main()
