#!/usr/bin/env python3
"""Package new SWAP431 project evidence; regional GIS base is separately pinned."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('archive', type=Path)
    parser.add_argument('summary', type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    results = root / 'results'
    batch = json.loads((results / 'swap431_grid_soil_scenarios/batch_results.json').read_text())
    assert batch['final'] and batch['candidate_cells'] == 1024
    assert all(r['native_success'] and r['water_balance']['days'] == 1005 for r in batch['runs'])
    soil = json.loads((results / 'swap431_soil_data/collection_manifest.json').read_text())
    assert soil['errors'] == 0 and soil['observation_count'] == soil['expected'] == 20049
    groundwater = json.loads((results / 'swap431_groundwater/groundwater_collection.json').read_text())
    profile = json.loads((results / 'swap431_grid_soil_scenarios/profile_catalog.json').read_text())
    files = [root / p for p in ['export/grid_500m.csv', 'export/weather.csv', 'results/era5_endpoint_20261002.json',
             'results/weather_aligned.csv', 'results/dov_soil_classifications.geojson',
             'results/bodemdiepteintervallen.geojson', 'results/bodemmonsters.geojson', 'results/vw_profiel.geojson',
             'results/symphonica_pipeline_status.json', 'results/symphonica_pipeline_final.log',
             'results/symphonica_resume.log',
             'results/swap431_initial_grid_results.json', 'results/swap431_grid_preclassification_screen.json']]
    files += [p for p in (results / 'swap431_soil_data').rglob('*') if p.is_file()]
    files += [p for p in (results / 'swap431_groundwater').rglob('*') if p.is_file()]
    model = results / 'swap431_grid_soil_scenarios'
    files += [model / 'batch_results.json', model / 'profile_catalog.json']
    files += [p for p in (model / 'forcing').iterdir() if p.is_file()]
    for run in batch['runs']:
        files += [p for p in (model / run['case']).iterdir()
                  if p.is_file() and p.name not in ['kalmthout.met', 'kalmthout.rain'] and not p.name.endswith('.tmp')]
    for path in (results / 'swap431_local_batch').rglob('*'):
        if path.is_file() and path.name in ['swap.err', 'swap.swp', 'case_manifest.json']:
            files.append(path)
    entries = []
    args.archive.parent.mkdir(parents=True, exist_ok=True)
    with tarfile.open(args.archive, 'w:xz') as archive:
        for path in sorted(set(files)):
            raw = path.read_bytes()
            name = str(path.relative_to(root))
            entries.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
            archive.add(path, arcname=name, recursive=False)
    sha = hashlib.sha256(args.archive.read_bytes()).hexdigest()
    summary = {'model': 'SWAP4.3.1', 'candidate_grid_cells': batch['candidate_cells'],
               'assigned_dominant_soil_response_cells': batch['assigned_cells'],
               'unassigned_cells': len(batch['unassigned']), 'complete_eligible_donor_profiles': len(profile['profiles']),
               'excluded_classification_conflicts': len(profile['classification_conflicts']),
               'unique_native_scenarios': len(batch['runs']), 'all_native_runs_success': True,
               'full_run_days': 1005, 'soil_observations': soil['observation_count'],
               'texture_exports': soil['texture_observations'], 'texture_export_errors': soil['errors'],
               'groundwater_filters': len(groundwater['exports']),
               'groundwater_measurements': sum(len(e.get('measurements', [])) for e in groundwater['exports']),
               'groundwater_measurements_in_period': groundwater['measurements_in_simulation_period'],
               'last_groundwater_measurement': groundwater['actual_last_measurement'],
               'max_native_daily_baldev_cm': max(r['water_balance']['max_native_daily_baldev_cm'] for r in batch['runs']),
               'max_absolute_full_period_printed_closure_cm': max(abs(r['water_balance']['whole_period_closure_from_printed_components_cm']) for r in batch['runs']),
               'native_wall_seconds_range': [min(r['wall_seconds'] for r in batch['runs']), max(r['wall_seconds'] for r in batch['runs'])],
               'archive_bytes': args.archive.stat().st_size, 'archive_sha256': sha,
               'status': 'EXPLORATORY_BARE_SOIL_SCENARIOS; NOT_FULL_CELL_BALANCES_OR_VALIDATED_HEATH_SIMULATIONS'}
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(summary, indent=2) + '\n')
    args.summary.with_name('project_evidence_manifest.json').write_text(json.dumps({'summary': summary, 'files': entries}, indent=2) + '\n')
    with args.summary.with_name('scenario_water_balances.csv').open('w', newline='') as handle:
        fields = ['case', 'cell', 'bottom_mode', 'wall_seconds', 'RAIN', 'BOT', 'RUNOFF', 'EACT', 'EPD',
                  'storage_change', 'max_native_daily_baldev_cm', 'whole_period_closure_from_printed_components_cm']
        writer = csv.DictWriter(handle, fields)
        writer.writeheader()
        for run in batch['runs']:
            wb = run['water_balance']
            writer.writerow({**{k: run[k] for k in ['case', 'cell', 'bottom_mode', 'wall_seconds']},
                             **{k: wb['totals'][k] for k in ['RAIN', 'BOT', 'RUNOFF', 'EACT', 'EPD']},
                             **{k: wb[k] for k in ['storage_change', 'max_native_daily_baldev_cm', 'whole_period_closure_from_printed_components_cm']}})
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    main()
