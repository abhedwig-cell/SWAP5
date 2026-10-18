#!/usr/bin/env python3
"""Original SWAP431 hourly bare-soil responses for WUR modal point profiles.

Explicit Staring2018 class priors and zero/free boundary sensitivities.
These runs do not represent current vegetation or whole-cell water balances.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time

from run_local_soil_scenarios import sha, summarize_water, update


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--first-only', action='store_true')
    args = parser.parse_args()
    root, out, exe = args.root.resolve(), args.output.resolve(), args.executable.resolve()
    out.mkdir(parents=True, exist_ok=True)
    source = root / 'results/dutch_sources/soil_point_profiles.json'
    points = json.loads(source.read_text())
    manifest_path = root / 'results/dutch_sources/dutch_source_manifest.json'
    sources = json.loads(manifest_path.read_text())
    assert sources['soil_errors'] == 0
    for name, digest in sources['file_sha256'].items():
        assert sha(manifest_path.parent / name) == digest, name
    parameter_file = Path(__file__).resolve().parent.parent / 'local_sources/staring2018_parameters.csv'
    staring = {r['code']: r for r in csv.DictReader(parameter_file.open())}
    profiles = {}
    for point in points:
        if point['status'] != 'DERIVED_MODAL_PROFILE':
            continue
        profile = point['profile']
        identity = hashlib.sha256(json.dumps(profile, sort_keys=True).encode()).hexdigest()[:16]
        entry = profiles.setdefault(identity, {'profile': profile, 'point_cells': []})
        assert entry['profile'] == profile
        entry['point_cells'].append(point['cell_id'])
    daily = root / 'results/swap431_grid_soil_scenarios/forcing'
    template = (daily / 'swap.swp').read_text()
    hourly = root / 'results/wet_heath_scenarios/forcing/hourly.met'
    assert hourly.exists(), 'Prepare the existing hourly forcing with --wet-heath first'
    results, assignments = [], []
    for identity, entry in sorted(profiles.items()):
        profile = entry['profile']
        layers = []
        for h in profile['horizon']:
            # Explicit choice of 2018 parameters for the named texture class;
            # this is not a claim that the WUR point API supplies hydraulic fits.
            code = h['spu'][0] + f'{int(h["spu"][1:]):02d}'
            p = staring[code]
            alpha, k = float(p['alpha_per_cm']), float(p['Ksat_fit_cm_day'])
            values = [float(p['theta_r']), float(p['theta_s']), alpha, alpha,
                      float(p['n']), float(p['lambda']), k, k, 0., 1500.]
            layers.append({'top_cm': h['top'], 'bottom_cm': h['bottom'],
                           'source_horizon': h, 'staring2018_class': code, 'swap_mvg': values})
        depth = layers[-1]['bottom_cm']
        assert depth >= 80
        for bottom in [6, 7]:
            name = f'nlmodal_{identity}_bot{bottom}'
            case = out / name
            case.mkdir(exist_ok=True)
            shutil.copyfile(hourly, case / 'hourly.met')
            text = template
            for key, value in [('PROJECT', "'"+name+"'"), ('SWCROP', '0'), ('SWBOTB', str(bottom)),
                               ('SWCSV', '1'), ('SWMONTH', '0'), ('SWEND', '1'), ('RDS', str(float(depth))),
                               ('SWSOLU', '0'), ('SWHEA', '0'), ('SWMETDETAIL', '1'),
                               ('METFIL', "'hourly.met'"), ('ALTW', '10.0'), ('ALTH', '2.0'),
                               ('SWETR', '0'), ('SWDIVIDE', '1'), ('SWRAIN', '0'),
                               ('INLIST_CSV', "'WATBAL,ETTERMS,GWL'")]:
                text = update(text, key, value)
            grids, hydraulics = [], []
            for i, h in enumerate(layers, 1):
                thick = h['bottom_cm'] - h['top_cm']
                grids.append(f'{i} {i} {thick:.8f} {math.ceil(thick/(1 if h["top_cm"]<10 else 5))}')
                hydraulics.append(' '.join(f'{v:.12e}' for v in h['swap_mvg']))
            text = re.sub(r'( ISUBLAY ISOILLAY HSUBLAY NCOMP\n).*?(\* End of table)',
                          lambda m: m[1]+'\n'.join(grids)+'\n'+m[2], text, flags=re.S)
            text = re.sub(r'( ORES\s+OSAT[^\n]*\n).*?(\* End of table)',
                          lambda m: m[1]+'\n'.join(hydraulics)+'\n'+m[2], text, flags=re.S)
            text, count = re.subn(r'(?m)^ -200\.0 -75\.0$', f' {-float(depth):.8f} -75.0', text)
            assert count == 1
            (case / 'swap.swp').write_text(text)
            contract = {'case': name, 'profile': profile, 'layers': layers,
                        'bottom_mode': bottom, 'point_cells': entry['point_cells'],
                        'profile_source_sha256': sha(source), 'staring2018_sha256': sha(parameter_file),
                        'status': 'EXPLORATORY_MODAL_POINT_PROFILE_SOIL_RESPONSE_NOT_CELL_WATER_BALANCE',
                        'assumptions': ['Derived modal profile, not a site core or area-mean soil.',
                                        'Staring2018 class priors, including fitted Ksat and lambda; no local hydraulic calibration.',
                                        'Bare soil, no vegetation; shared actual hourly ERA5 and original SWAP Penman-Monteith.',
                                        'Uniform initial h=-75cm; zero/free lower boundaries are sensitivities.',
                                        'Profile ends at reported depth; no invented deeper horizons.',
                                        'BDENS1500 unused with heat/solute/oxygen disabled; no measured density claim.']}
            (case / 'case_manifest.json').write_text(json.dumps(contract, indent=2)+'\n')
            inputs = {p.name: sha(p) for p in case.iterdir() if p.name in ['swap.swp', 'hourly.met', 'case_manifest.json']}
            receipt = case / 'run_receipt.json'
            old = json.loads(receipt.read_text()) if receipt.exists() else {}
            reused = (old.get('native_success') and old.get('input_sha256') == inputs
                      and old.get('executable_sha256') == sha(exe)
                      and all((case/p).exists() and sha(case/p)==v for p,v in old['output_sha256'].items()))
            if reused:
                record = dict(old, reused=True)
            else:
                start = time.perf_counter()
                with (case/'stdout.log').open('w') as stdout, (case/'stderr.log').open('w') as stderr:
                    try:
                        code = subprocess.run([str(exe)], cwd=case, stdout=stdout, stderr=stderr, timeout=120).returncode
                    except subprocess.TimeoutExpired:
                        code = -124
                log = (case/'swap.log').read_text() if (case/'swap.log').exists() else ''
                record = {'case': name, 'native_success': code==100 and 'Swap simulation okay!' in log,
                          'returncode': code, 'wall_seconds': time.perf_counter()-start, 'reused': False,
                          'input_sha256': inputs, 'executable_sha256': sha(exe),
                          'output_sha256': {p.name: sha(p) for p in case.iterdir()
                                            if p.name in ['result_output.csv', 'swap.log', 'stdout.log', 'stderr.log']}}
            if record['native_success']:
                record['physical_validation_status'] = 'PENDING'
                receipt.write_text(json.dumps(record, indent=2)+'\n')
                record['water_balance'] = summarize_water(case)
                lower = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][0] for h in layers)
                upper = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][1] for h in layers)
                with (case/'result_output.csv').open() as handle:
                    rows = list(csv.DictReader(l for l in handle if not l.startswith('*')))
                assert re.search(r'(?m)^\s*SWCROP\s*=\s*0\b', text)
                required = {'DATE', 'WTOT', 'PD_VOL', 'RAIN', 'EACT', 'EPD', 'DSTOR', 'BALDEV'}
                if bottom == 7:
                    required.add('BOT')
                assert required <= rows[0].keys(), 'Missing active native output'
                for row in rows:
                    assert lower-1e-4 <= float(row['WTOT']) <= upper+1e-4
                    assert float(row['PD_VOL']) >= 0
                    # These inactive crop terms are omitted by the native writer.
                    assert float(row.get('TACT', 0)) == 0 and float(row.get('EIC', 0)) == 0
                record['physical_daily_states_checked'] = len(rows)-1
                record['physical_validation_status'] = 'PASS'
                receipt.write_text(json.dumps(record, indent=2)+'\n')
            results.append(record)
            assignments += [{'cell': cell, 'case': name, 'sampling': 'CENTRE_POINT_RESPONSE_ONLY'}
                            for cell in entry['point_cells']]
            (out/'batch_results.json').write_text(json.dumps({'runs': results, 'assignments': assignments,
                'unique_profiles': len(profiles), 'soil_point_cells': sum(len(p['point_cells']) for p in profiles.values()),
                'whole_cell_predictions': False}, indent=2)+'\n')
            print(name, record['native_success'], 'REUSED' if reused else record['wall_seconds'], flush=True)
            assert record['native_success'], 'Inspect retained failed native run'
            if args.first_only:
                return


if __name__ == '__main__':
    main()
