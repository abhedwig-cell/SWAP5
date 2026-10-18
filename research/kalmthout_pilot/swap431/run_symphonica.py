#!/usr/bin/env python3
"""Local, resumable SYMPHONICA source-to-SWAP431 soil-response pipeline.

No scheduler, SWAP5 build, solver benchmark or GitHub Actions dependency.
All model results retain their exploratory physical assumptions.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('executable', type=Path)
    parser.add_argument('weather', type=Path)
    parser.add_argument('endpoint', type=Path)
    parser.add_argument('grid', type=Path)
    parser.add_argument('--recorded-studies', action='store_true',
                        help='Use archived study identities and repository factual tables without reacquiring undistributed PDFs')
    parser.add_argument('--dutch-sources', action='store_true',
                        help='Collect complementary Dutch modal soil profiles and dated land-cover polygons; does not qualify additional cell runs')
    parser.add_argument('--wet-heath', action='store_true',
                        help='Also collect current LAI/terrain and run explicitly provisional historical wet-heath scenarios')
    args = parser.parse_args()
    root, exe = args.root.resolve(), args.executable.resolve()
    results, export = root / 'results', root / 'export'
    results.mkdir(parents=True, exist_ok=True)
    export.mkdir(exist_ok=True)
    scripts = Path(__file__).resolve().parent
    parent = scripts.parent
    def run(script, *parameters):
        subprocess.run([sys.executable, str(script), *map(str, parameters)], check=True, cwd=root)
    def sha(path):
        return hashlib.sha256(path.read_bytes()).hexdigest()
    target_grid = export / 'grid_500m.csv'
    if args.grid.resolve() != target_grid:
        shutil.copyfile(args.grid, target_grid)
    run(parent / 'align_existing_forcing.py', args.weather.resolve(), args.endpoint.resolve(), results / 'weather_aligned.csv')
    names = ['dov_soil_domain.geojson', 'dov_profiles_domain.geojson', 'dov_ksat_domain.geojson',
             'dov_groundwater_domain.geojson', 'landuse2025_domain.tif', 'landuse2022_verified.tif',
             'dov_soil_classifications.geojson']
    first, second = results / 'bwk_domain_sorted1.geojson', results / 'bwk_domain_keyset_verified.geojson'
    if not all((results / name).exists() for name in names) or not first.exists() or not second.exists():
        raw = results / 'raw_local_sources'
        run(parent / 'fetch_local_sources.py', raw)
        for source, target in [('dov_soil.geojson', names[0]), ('dov_profiles.geojson', names[1]),
                               ('dov_ksat.geojson', names[2]), ('dov_groundwater.geojson', names[3]),
                               ('dov_classifications.geojson', names[6]),
                               ('dov_horizons.geojson', 'bodemdiepteintervallen.geojson'),
                               ('dov_samples.geojson', 'bodemmonsters.geojson'),
                               ('dov_historical_profiles.geojson', 'vw_profiel.geojson'),
                               ('landuse2025.tif', names[4]), ('landuse2022.tif', names[5])]:
            shutil.copyfile(raw / source, results / target)
        shutil.copyfile(raw / 'bwk_page1.geojson', first)
        shutil.copyfile(raw / 'bwk_page2.geojson', second)
    inventory = results / 'cell_sources_final'
    audit = inventory / 'source_overlay_audit.json'
    cached = False
    if audit.exists():
        identities = json.loads(audit.read_text())['input_sha256']
        cached = all((root / p).exists() and sha(root / p) == expected for p, expected in identities.items())
    if not cached:
        run(parent / 'inventory_cell_sources.py', target_grid, results / names[0], inventory,
            '--bwk', first, second, '--landuse', results / names[4], '--landuse2022', results / names[5])
    run(parent / 'summarize_cell_sources.py', inventory)
    soil_data = results / 'swap431_soil_data'
    manifest = soil_data / 'collection_manifest.json'
    cached = False
    if manifest.exists():
        recorded = json.loads(manifest.read_text())
        cached = recorded['errors'] == 0 and all(
            (soil_data / entry['file']).exists() and sha(soil_data / entry['file']) == entry['sha256']
            for entry in recorded['texture_exports'])
    if not cached:
        run(scripts / 'collect_soil_observations.py', soil_data)
    run(scripts / 'collect_groundwater.py', root, results / 'swap431_groundwater', '--all-shallow')
    run(scripts / 'audit_groundwater.py', root, results / 'swap431_groundwater_audit')
    run(scripts / 'collect_site_context.py', root, results / 'swap431_site_context')
    run(scripts / 'collect_local_studies.py', results / 'local_studies',
        *(['--recorded-only'] if args.recorded_studies else []))
    run(scripts / 'fit_historical_retention.py', results / 'local_studies/historical_retention_fits.json')
    run(scripts / 'run_local_soil_scenarios.py', root, results / 'swap431_grid_soil_scenarios', exe, '--all-cells')
    if args.wet_heath:
        run(scripts / 'collect_nhi_ecosystem_priors.py', results / 'nhi_ecosystem_priors')
        run(scripts / 'collect_modis_lai.py', target_grid, results / 'modis_lai')
        run(scripts / 'collect_terrain_points.py', root, results / 'terrain_points')
        run(scripts / 'run_wet_heath_scenarios.py', root, results / 'wet_heath_scenarios', exe)
    if args.dutch_sources:
        run(scripts / 'collect_dutch_sources.py', root, results / 'dutch_sources')
    batch = json.loads((results / 'swap431_grid_soil_scenarios/batch_results.json').read_text())
    status = {'model': 'SWAP4.3.1', 'executable_sha256': sha(exe),
              'study_document_mode': 'RECORDED_IDENTITIES_ONLY' if args.recorded_studies else 'PDF_BYTES_VERIFIED',
              'source_grid_cells': batch['candidate_cells'], 'assigned_soil_response_cells': batch['assigned_cells'],
              'unique_native_runs': len(batch['runs']), 'native_successes': sum(r['native_success'] for r in batch['runs']),
              'unassigned_cells': len(batch['unassigned']),
              'status': 'EXPLORATORY_SOIL_RESPONSE_RESULTS; LOCAL_VEGETATION_AND_BOUNDARY_PARAMETERIZATION_OPEN'}
    if args.wet_heath:
        heath = json.loads((results/'wet_heath_scenarios/batch_results.json').read_text())['runs']
        assert len(heath)==16 and all(r['native_success'] for r in heath)
        status.update({'provisional_wet_heath_ecotope_runs':len(heath),
                       'wet_heath_daily_states_checked':sum(r['water_balance']['physical_daily_states_checked'] for r in heath),
                       'wet_heath_current_cell_assignment':False})
    if args.dutch_sources:
        dutch = json.loads((results / 'dutch_sources/dutch_source_manifest.json').read_text())
        status.update({'dutch_modal_soil_centres': dutch['soil_profile_count'],
                       'dutch_landcover_cells_95pct': dutch['landcover_cells_95pct'],
                       'dutch_data_status': 'SOURCE_CONTEXT_ONLY_NO_ADDITIONAL_CELL_QUALIFICATION'})
    (results / 'symphonica_pipeline_status.json').write_text(json.dumps(status, indent=2) + '\n')
    print(json.dumps(status))


if __name__ == '__main__':
    main()
