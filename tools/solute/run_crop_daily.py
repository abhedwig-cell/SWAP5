#!/usr/bin/env python3
"""Run explicit native simple crop/root/Reference-water/solute daily composition."""
import argparse
import base64
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def check_reader(reader):
    meta = json.loads((reader.parent / 'build-complete.json').read_text())
    if meta.get('status') != 'BUILT' or meta.get('executable_sha256') != sha(reader.read_bytes()):
        raise ValueError('native reader identity mismatch')
    for path, expected in meta['input_sha256'].items():
        if sha((ROOT / path).read_bytes()) != expected:
            raise ValueError('native reader source mismatch: ' + path)
    return meta


def prepare(crop_reader, root_reader, swp, crop, met, column):
    readers = [check_reader(p) for p in [crop_reader, root_reader]]
    sources = [('original_swp', swp.read_bytes()), ('original_crop', crop.read_bytes()), ('original_met', met.read_bytes())]
    if crop.suffix.lower() != '.crp' or met.suffix.lower() != '.met':
        raise ValueError('explicit single .CRP and .MET required')
    with tempfile.TemporaryDirectory(prefix='swap5-crop-') as tmp:
        stage = Path(tmp)
        names = ['input.swp', crop.name.lower(), met.name.lower()]
        if len(set(names)) != 3:
            raise ValueError('source basename collision')
        for name, (_, raw) in zip(names, sources):
            (stage / name).write_bytes(raw)
        for reader, marker in [(crop_reader, b'SWP_NATIVE_SIMPLE_CROP_PREPARED'), (root_reader, b'SWP_NATIVE_ROOT_IMPORTED')]:
            result = subprocess.run([str(reader), *names], cwd=stage, input=b'', capture_output=True, timeout=60)
            if result.returncode or marker not in result.stdout:
                raise ValueError('native crop/root import failed:\n' + result.stdout.decode(errors='replace') +
                                 result.stderr.decode(errors='replace'))
        rows = list(csv.DictReader(io.StringIO((stage / 'crop_daily.csv').read_text())))
        rainfall = list(csv.DictReader(io.StringIO((stage / 'rain.csv').read_text())))
        if not rows or len(rows) != len(rainfall) or any(float(a['t1900']) != float(b['t1900'])
                                                      for a, b in zip(rows, rainfall)):
            raise ValueError('foreign rain/crop calendar')
        root_group = (stage / 'root.nml').read_text()
    comments = ['! SWAP5 explicit native daily crop/root/solute route v1',
                '! generator_sha256=' + sha(Path(__file__).read_bytes())]
    for name, meta in zip(['crop', 'root'], readers):
        comments.append('! ' + name + '_reader_executable_sha256=' + meta['executable_sha256'])
    for name, raw in sources:
        comments.append('! ' + name + '_sha256=' + sha(raw))
        encoded = base64.b64encode(raw).decode()
        comments += ['! ' + name + '_base64=' + encoded[i:i+76] for i in range(0, len(encoded), 76)]
    lines = comments + ['&column', ' schema=2,nodes=0,swp_water_bootstrap=.true.']
    for name, value in column.items():
        if not math.isfinite(value):raise ValueError('nonfinite column option')
        lines.append(f' {name}={value:.17e}')
    lines += ['/', '&surface', ' windows=' + str(len(rows)),
              ' ends_day=' + ','.join(str(i+1) for i in range(len(rows))),
              ' rain_cm_day=' + ','.join(r['rain_cm_day'] for r in rainfall),
              ' soil_evaporation_cm_day=' + ','.join(r['soil_evaporation_cm_day'] for r in rows),
              ' evaporation_cm_day=' + ','.join(r['pond_evaporation_cm_day'] for r in rows), '/']
    if root_group.count('/') != 1 or not root_group.rstrip().endswith('/'):
        raise ValueError('native root namelist shape')
    root_group = root_group.rstrip()[:-1]
    lines += [root_group,
              ' crop_active=' + ','.join('.true.' if float(r['active']) == 1. else '.false.' for r in rows),
              ' potential_transpiration_cm_day=' + ','.join(r['transpiration_cm_day'] for r in rows),
              ' root_depth_cm=' + ','.join(r['root_depth_cm'] for r in rows), '/']
    return '\n'.join(lines) + '\n', sources[0][1]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ['crop-reader', 'root-reader', 'exe', 'swp', 'crop', 'met', 'output']:
        ap.add_argument('--' + name, type=Path, required=True)
    ap.add_argument('--restart', type=Path)
    ap.add_argument('--stop-after', type=int, default=2048)
    ap.add_argument('--temporal-tolerance', type=float, default=1e-4)
    ap.add_argument('--initial-pond-cm', type=float, default=0.)
    ap.add_argument('--bottom-up-cm-day', type=float, default=0.)
    ap.add_argument('--substep-root-stress', action='store_true',
                    help='Opt into trial-beginning Feddes feedback; daily geometry and demand remain prescribed')
    args = ap.parse_args()
    if args.output.exists():raise FileExistsError(args.output)
    options = {name: getattr(args, name) for name in ['temporal_tolerance', 'initial_pond_cm', 'bottom_up_cm_day']}
    document, snapshot = prepare(args.crop_reader.resolve(), args.root_reader.resolve(), args.swp.resolve(),
                                 args.crop.resolve(), args.met.resolve(), options)
    if args.substep_root_stress:
        end = document.rfind('/')
        document = document[:end] + ' substep_root_stress=.true.\n' + document[end:]
    with tempfile.TemporaryDirectory(prefix='swap5-crop-run-') as tmp:
        stage = Path(tmp);(stage / 'input.nml').write_text(document);(stage / 'input.swp').write_bytes(snapshot)
        cmd = [sys.executable, str(ROOT / 'tools/solute/run_column.py'), '--exe', str(args.exe.resolve()),
               '--input', str(stage / 'input.nml'), '--swp', str(stage / 'input.swp'),
               '--output', str(args.output.resolve()), '--stop-after', str(args.stop_after)]
        if args.restart:cmd += ['--restart', str(args.restart.resolve())]
        subprocess.run(cmd, check=True)


if __name__ == '__main__':
    main()
