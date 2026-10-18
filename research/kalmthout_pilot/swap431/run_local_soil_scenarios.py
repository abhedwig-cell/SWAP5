#!/usr/bin/env python3
"""Run original SWAP431 using complete local mineral-texture donor profiles.

Exploratory bare-soil responses, not vegetation-qualified cell predictions.
No extrapolated horizons. Cell donors must share the mapped dominant soil code.
"""
import argparse
from collections import defaultdict
import csv
import datetime
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import time
from types import SimpleNamespace
import xml.etree.ElementTree as ET

from rosetta import rosetta
from shapely import STRtree
from shapely.geometry import shape


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def update(text, name, value):
    result, count = re.subn(r'(?m)^\s*' + name + r'\s*=.*$', f'  {name} = {value}', text)
    assert count == 1, name
    return result


def summarize_water(case):
    with (case / 'result_output.csv').open() as handle:
        rows = list(csv.DictReader(line for line in handle if not line.startswith('*')))
    assert len(rows) == 1006
    first = datetime.date(2023, 12, 31)
    assert all(datetime.date.fromisoformat(row['DATE']) == first + datetime.timedelta(days=i)
               for i, row in enumerate(rows))
    def value(row, key):
        result = float(row.get(key, 0))
        assert math.isfinite(result)
        return result
    start_storage = value(rows[0], 'WTOT') + value(rows[0], 'PD_VOL')
    end_storage = value(rows[-1], 'WTOT') + value(rows[-1], 'PD_VOL')
    totals = {key: math.fsum(value(row, key) for row in rows[1:])
              for key in ['RAIN', 'IRRIG', 'SSDI', 'BOT', 'RUNOFF', 'EACT', 'EPD', 'TACT', 'EIC', 'DRN']}
    assert abs(totals['RAIN'] - 221.66) < 0.00001
    incoming, outgoing = ['RAIN', 'IRRIG', 'SSDI', 'BOT'], ['RUNOFF', 'EACT', 'EPD', 'TACT', 'EIC', 'DRN']
    closure = [math.fsum(value(row, key) for key in incoming)
               - math.fsum(value(row, key) for key in outgoing) - value(row, 'DSTOR') for row in rows[1:]]
    max_native = max(abs(value(row, 'BALDEV')) for row in rows[1:])
    # This bound checks rounded output, not model acceptance criteria.
    assert max(abs(v) for v in closure) <= max_native + (len(incoming) + len(outgoing) + 1) * 0.0000051
    return {'days': 1005, 'water_unit': 'cm', 'totals': totals,
            'initial_storage': start_storage, 'final_storage': end_storage,
            'storage_change': end_storage - start_storage,
            'max_native_daily_baldev_cm': max_native,
            'max_daily_closure_from_printed_components_cm': max(abs(v) for v in closure),
            'whole_period_closure_from_printed_components_cm':
                sum(totals[k] for k in incoming) - sum(totals[k] for k in outgoing) - end_storage + start_storage}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data_root', type=Path, help='parent containing results/ and export/')
    parser.add_argument('output', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('--all-cells', action='store_true')
    args = parser.parse_args()
    data = args.data_root.resolve() / 'results'
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    executable = args.executable.resolve()
    observations = json.loads((data / 'swap431_soil_data/observations.json').read_text())
    properties = [f['properties'] for f in observations]
    carbon = defaultdict(list)
    for p in properties:
        if p['Parameter'] == 'Organische C - percentage' and p['Eenheid'] == '%':
            carbon[p['Parentfiche'].rsplit('/', 1)[-1]].append(p['Waarde'])
    locations = {f['properties']['Bodemlocatiefiche'].rsplit('/', 1)[-1]: f
                 for f in json.loads((data / 'dov_profiles_domain.geojson').read_text())['features']}
    classifications = defaultdict(set)
    for feature in json.loads((data / 'dov_soil_classifications.geojson').read_text())['features']:
        p = feature['properties']
        if p['Classificatietype'] == 'Algemene Belgische classificatie':
            classifications[p['Bodemlocatiefiche'].rsplit('/', 1)[-1]].add(p['Bodemtype'])
    soils = json.loads((data / 'dov_soil_domain.geojson').read_text())['features']
    geometries = [shape(f['geometry']) for f in soils]
    tree = STRtree(geometries)
    horizons, excluded = defaultdict(list), []
    for p in properties:
        if p['Parameter'] != 'Textuurfracties':
            continue
        file = data / 'swap431_soil_data/texture_xml' / (p['Bodemobservatie'] + '.xml')
        try:
            source = ET.parse(file)
            bins = sorted((float(m.findtext('ondergrens')), float(m.findtext('bovengrens')),
                           float(m.findtext('waarde'))) for m in source.findall('.//waarde_fractiemeting/meting'))
            assert bins and bins[0][0] == 0 and bins[-1][1] == 2000, 'particle-size range'
            assert all(a[1] == b[0] for a, b in zip(bins, bins[1:])), 'non-contiguous fractions'
            fractions = [0.0, 0.0, 0.0]  # sand50..2000, silt2..50, clay0..2 um
            for low, high, value in bins:
                assert value >= 0 and high > low
                index = 2 if high <= 2 else 1 if low >= 2 and high <= 50 else 0 if low >= 50 else None
                assert index is not None, 'bin crosses USDA size boundary'
                fractions[index] += value
            total = sum(fractions)
            assert abs(total - 100) <= 0.5, 'mass percentages do not sum to 100 within rounding'
            values = carbon[p['Parentfiche'].rsplit('/', 1)[-1]]
            assert len(set(values)) == 1, 'missing or ambiguous organic carbon'
            organic_carbon = float(values[0])
            assert 0 <= organic_carbon <= 12, 'outside initial mineral-soil screening domain'
            top, bottom = float(p['Diepte_van']), float(p['Diepte_tot'])
            assert 0 <= top < bottom
            normalized = [value * 100 / total for value in fractions]
            mean, spread, codes = rosetta(3, [normalized], estimate_type='geo')
            theta_r, theta_s, alpha, n, ksat, k0, lexp = map(float, mean[0])
            assert 0 <= theta_r < theta_s < 1 and 1.001 <= n <= 9 and .0001 <= alpha <= 100
            assert 1e-5 <= ksat <= 1e5
            horizons[p['Bodemlocatie']].append({
                'top_cm': top, 'bottom_cm': bottom, 'observation': p['Bodemobservatiefiche'],
                'observation_phenomenon_time': source.findtext('.//observatie/fenomeentijd'),
                'observation_result_time': source.findtext('.//observatie/resultaattijd'),
                'entry_time_not_observation_date': p.get('eerste_invoer'),
                'xml_sha256': sha(file), 'sand_silt_clay_percent_raw': fractions,
                'texture_sum_raw': total, 'rounding_normalization_factor': 100 / total,
                'organic_carbon_percent': organic_carbon,
                'rosetta_version': 3, 'rosetta_model': int(codes[0]), 'estimate_type': 'geo',
                'rosetta_mean': list(map(float, mean[0])), 'rosetta_spread_raw': list(map(float, spread[0])),
                'swap_mvg': [theta_r, theta_s, alpha, alpha, n, 0.5, ksat, ksat, 0, 1500],
            })
        except (AssertionError, ValueError, TypeError, FileNotFoundError, ET.ParseError) as error:
            excluded.append({'observation': p['Bodemobservatiefiche'], 'reason': str(error)})
    profiles, classification_conflicts = [], []
    for identity, layers in horizons.items():
        layers.sort(key=lambda h: h['top_cm'])
        if identity not in locations or layers[0]['top_cm'] != 0:
            continue
        if not all(a['bottom_cm'] == b['top_cm'] for a, b in zip(layers, layers[1:])):
            continue
        depth = min(layers[-1]['bottom_cm'], 200.0)
        if depth < 80:
            continue
        selected = [dict(h, bottom_cm=min(h['bottom_cm'], depth)) for h in layers if h['top_cm'] < depth]
        point = shape(locations[identity]['geometry'])
        mapped_types = {soils[int(i)]['properties']['Bodemtype'] for i in tree.query(point, predicate='intersects')}
        if len(mapped_types) != 1:
            continue
        mapped_type = mapped_types.pop()
        if mapped_type.startswith('O'):
            continue  # Artificial-ground codes do not define a transferable soil profile.
        if classifications[identity] and classifications[identity] != {mapped_type}:
            classification_conflicts.append({'profile': identity, 'mapped_point_type': mapped_type,
                                              'profile_classifications': sorted(classifications[identity])})
            continue
        profiles.append({'id': identity, 'location_url': locations[identity]['properties']['Bodemlocatiefiche'],
                         'mapped_soil_type': mapped_type, 'coordinates': list(point.coords)[0][:2],
                         'direct_classifications': sorted(classifications[identity]),
                         'depth_cm': depth, 'layers': selected})
    (args.output / 'profile_catalog.json').write_text(json.dumps({'profiles': profiles,
                 'classification_conflicts': classification_conflicts, 'excluded_observations': excluded}, indent=2) + '\n')
    candidates = json.loads((data / 'cell_sources_final/candidate_cells.json').read_text())['candidate_cells']
    grid = {r['cell_id']: r for r in csv.DictReader((args.data_root / 'export/grid_500m.csv').open())}
    by_cell = defaultdict(lambda: defaultdict(float))
    landuse = defaultdict(lambda: defaultdict(float))
    for row in csv.DictReader((data / 'cell_sources_final/cell_source_fractions.csv').open()):
        if row['layer'] == 'soil':
            by_cell[row['cell_id']][json.loads(row['source_codes_json'])[0]] += float(row['cell_fraction'])
        elif row['layer'] == 'landuse2025':
            landuse[row['cell_id']][json.loads(row['source_codes_json'])[0]] += float(row['cell_fraction'])
    if args.all_cells:
        present = {c['cell_id'] for c in candidates}
        natural_codes = {'12', '13', '14', '15', '16', '18', '19'}
        for cell in sorted(grid):
            if cell in present:
                continue
            dominant = max(landuse[cell], key=landuse[cell].get) if landuse[cell] else None
            candidates.append({'cell_id': cell, 'group': 'no_source_coverage' if dominant is None else
                               'landuse2025_' + str(dominant) if dominant in natural_codes else 'separate_surface_contract'})
    base = args.output / 'forcing'
    subprocess.run(['python3', str(Path(__file__).with_name('prepare_reference_forcing.py')),
                    str(data / 'weather_aligned.csv'), str(base)], check=True, stdout=subprocess.DEVNULL)
    template = (base / 'swap.swp').read_text()
    runs, unassigned, assignments, reused = [], [], [], {}
    previous_file = args.output / 'batch_results.json'
    previous_runs = {r['case']: r for r in json.loads(previous_file.read_text())['runs']} if previous_file.exists() else {}
    for candidate in candidates:
        cell = candidate['cell_id']
        if candidate['group'] == 'no_source_coverage' or not by_cell[cell]:
            unassigned.append({'cell': cell, 'reason': 'no soil or land-use source coverage'})
            continue
        if candidate['group'] in ['open_water', 'houses_gardens', 'separate_surface_contract']:
            unassigned.append({'cell': cell, 'reason': 'separate surface/vegetation contract required'})
            continue
        soil_type, soil_fraction = max(by_cell[cell].items(), key=lambda r: r[1])
        eligible = [p for p in profiles if p['mapped_soil_type'] == soil_type]
        x, y = float(grid[cell]['easting']), float(grid[cell]['northing'])
        eligible.sort(key=lambda p: math.dist(p['coordinates'], [x, y]))
        if not eligible or math.dist(eligible[0]['coordinates'], [x, y]) > 5000:
            unassigned.append({'cell': cell, 'soil_type': soil_type, 'reason': 'no complete exact-map-code donor within 5km'})
            continue
        profile = eligible[0]
        for bottom_mode in [6, 7]:
            case_key = (profile['id'], bottom_mode)
            assignment = {'cell': cell, 'bottom_mode': bottom_mode, 'soil_type': soil_type,
                          'dominant_soil_fraction': soil_fraction, 'profile_id': profile['id'],
                          'donor_distance_m': math.dist(profile['coordinates'], [x, y]),
                          'status': 'EXPLORATORY_DOMINANT_SOIL_RESPONSE_ONLY'}
            if case_key in reused:
                assignments.append(dict(assignment, case=reused[case_key], reused_identical_input=True))
                continue
            case = args.output / f'{cell}_soil_response_bot{bottom_mode}'
            case.mkdir(exist_ok=True)
            for name in ['kalmthout.met', 'kalmthout.rain']:
                shutil.copyfile(base / name, case / name)
            text = update(template, 'PROJECT', "'" + cell + "_soil_response'")
            for key, value in [('SWBOTB', str(bottom_mode)), ('SWCSV', '1'), ('SWMONTH', '0'),
                               ('SWSOLU', '0'), ('SWHEA', '0'),
                               ('SWEND', '1'), ('RDS', str(profile['depth_cm'])),
                               ('INLIST_CSV', "'WATBAL,ETTERMS,GWL'")]:
                text = update(text, key, value)
            if profile['depth_cm'] <= 100:
                text = update(text, 'TZ_Z1_Z2', '0.0 0.0')
            grid_rows, hydraulic_rows = [], []
            for i, horizon in enumerate(profile['layers'], 1):
                thickness = horizon['bottom_cm'] - horizon['top_cm']
                compartments = math.ceil(thickness / (1 if horizon['top_cm'] < 10 else 5))
                grid_rows.append(f'{i} {i} {thickness:.8f} {compartments}')
                # TTUTIL infers a column's type from its literals, including BDENS/H_ENPR.
                hydraulic_rows.append(' '.join(f'{v:.12e}' for v in horizon['swap_mvg']))
            text = re.sub(r'( ISUBLAY ISOILLAY HSUBLAY NCOMP\n).*?(\* End of table)',
                          lambda m: m[1] + '\n'.join(grid_rows) + '\n' + m[2], text, flags=re.S)
            text = re.sub(r'( ORES\s+OSAT[^\n]*\n).*?(\* End of table)',
                          lambda m: m[1] + '\n'.join(hydraulic_rows) + '\n' + m[2], text, flags=re.S)
            text = re.sub(r'(?m)^ -200\.0 -75\.0$', f" {-profile['depth_cm']} -75.0", text)
            (case / 'swap.swp').write_text(text)
            contract = {'cell': cell, 'group': candidate['group'], 'soil_type': soil_type,
                        'dominant_soil_fraction': soil_fraction, 'donor_distance_m': math.dist(profile['coordinates'], [x, y]),
                        'profile': profile, 'bottom_mode': bottom_mode, 'executable_sha256': sha(executable),
                        'status': 'EXPLORATORY_LOCAL_SOIL_RESPONSE_NOT_CELL_WATER_BALANCE',
                        'assumptions': ['bare soil; no local vegetation represented', 'shared existing ERA5 representative forcing',
                                        'uniform initial head -75cm; no local initialization',
                                        'zero flux and free drainage are scenarios, not observed boundaries',
                                        'Rosetta3 SSC-only geometric parameter estimates; mineral soils only',
                                        'standard Mualem lambda0.5; predicted Ksat for both conductivity fields',
                                        'BDENS1500 is unused with heat and solute disabled; not a measured density',
                                        'only dominant mapped soil represented; no complete cell aggregation']}
            contract_path = case / 'case_manifest.json'
            previous_contract = json.loads(contract_path.read_text()) if contract_path.exists() else {}
            contract_path.write_text(json.dumps(contract, indent=2) + '\n')
            previous = previous_runs.get(case.name)
            if previous and previous['native_success'] and previous_contract.get('executable_sha256') == sha(executable) and all(
                previous['files'].get(name) == sha(case / name)
                for name in ['swap.swp', 'kalmthout.met', 'kalmthout.rain', 'result_output.csv', 'swap.log']
            ):
                previous['water_balance'] = summarize_water(case)
                previous['files']['case_manifest.json'] = sha(contract_path)
                previous['reused_verified_native_output'] = True
                runs.append(previous)
                reused[case_key] = case.name
                assignments.append(dict(assignment, case=case.name, reused_identical_input=False))
                print(cell, bottom_mode, 'REUSED_VERIFIED_NATIVE_SUCCESS', flush=True)
                continue
            start = time.perf_counter()
            with (case / 'stdout.log').open('w') as stdout, (case / 'stderr.log').open('w') as stderr:
                try:
                    execution = subprocess.run([str(executable)], cwd=case, stdout=stdout, stderr=stderr, timeout=120)
                except subprocess.TimeoutExpired:
                    execution = SimpleNamespace(returncode=-124)
                    stderr.write('Native execution censored after120 wall seconds; not a numerical failure classification.\n')
            log = (case / 'swap.log').read_text() if (case / 'swap.log').exists() else ''
            passed = execution.returncode == 100 and 'Swap simulation okay!' in log
            record = {'cell': cell, 'bottom_mode': bottom_mode, 'case': case.name, 'returncode': execution.returncode,
                      'wall_seconds': time.perf_counter() - start, 'native_success': passed,
                      'files': {p.name: sha(p) for p in case.iterdir() if p.is_file()}}
            if passed:
                record['water_balance'] = summarize_water(case)
            runs.append(record)
            reused[case_key] = case.name
            assignments.append(dict(assignment, case=case.name, reused_identical_input=False))
            (args.output / 'batch_results.json').write_text(json.dumps({'runs': runs, 'unassigned': unassigned}, indent=2) + '\n')
            print(cell, bottom_mode, 'NATIVE_SUCCESS' if passed else 'FAILED', flush=True)
    (args.output / 'batch_results.json').write_text(json.dumps({'runs': runs, 'unassigned': unassigned,
                           'complete_donor_profiles': len(profiles), 'candidate_cells': len(candidates),
                           'assigned_cells': len({r['cell'] for r in assignments}),
                           'assignments': assignments, 'final': True}, indent=2) + '\n')
    print('RUNS', len(runs), 'UNASSIGNED', len(unassigned), 'PROFILES', len(profiles))


if __name__ == '__main__':
    main()
