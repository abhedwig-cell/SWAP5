#!/usr/bin/env python3
"""Cache a bounded local groundwater selection without extending observations."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import json
import math
from pathlib import Path
import threading
import xml.etree.ElementTree as ET

import requests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('data_root', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--all-shallow', action='store_true')
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    data = args.data_root / 'results'
    features = json.loads((data / 'dov_groundwater_domain.geojson').read_text())['features']
    shallow = [f for f in features if f['properties'].get('onderkant_filter_m') is not None
               and f['properties']['onderkant_filter_m'] <= 5
               and (f['properties'].get('peilmetingen_tot') or '') >= '2024-01-01']
    grid = {r['cell_id']: r for r in csv.DictReader((args.data_root / 'export/grid_500m.csv').open())}
    candidates = json.loads((data / 'cell_sources_final/candidate_cells.json').read_text())['candidate_cells']
    selected = {}
    for candidate in candidates:
        if 'heath' not in candidate['group']:
            continue
        row = grid[candidate['cell_id']]
        point = [float(row['easting']), float(row['northing'])]
        ordered = sorted(shallow, key=lambda f: math.dist(f['geometry']['coordinates'][:2], point))
        for feature in ordered[:2]:
            selected[feature['properties']['filterfiche']] = feature
    for feature in sorted(shallow, key=lambda f: f['properties']['peilmetingen_tot'], reverse=True)[:6]:
        selected[feature['properties']['filterfiche']] = feature
    if args.all_shallow:
        for feature in features:
            p = feature['properties']
            if p.get('onderkant_filter_m') is not None and p['onderkant_filter_m'] <= 5 and p.get('peilmetingen_van'):
                selected[p['filterfiche']] = feature
    state = threading.local()

    def collect(feature):
        properties = feature['properties']
        url = properties['filterfiche'] + '.xml'
        path = args.output / (properties['filterfiche'].rsplit('/', 1)[-1] + '.xml')
        try:
            if not path.exists():
                if not hasattr(state, 'client'):
                    state.client = requests.Session()
                response = state.client.get(url, timeout=60)
                response.raise_for_status()
                ET.fromstring(response.content)
                path.write_bytes(response.content)
            raw = path.read_bytes()
            tree = ET.fromstring(raw)
            measurements = []
            for measurement in tree.findall('.//filtermeting/peilmeting'):
                date = measurement.findtext('datum')
                value = measurement.findtext('peil_mtaw')
                if date and value:
                    measurements.append({'date': date, 'head_mTAW': float(value),
                                         'reliability': measurement.findtext('betrouwbaarheid'),
                                         'filter_status': measurement.findtext('filterstatus'),
                                         'method': measurement.findtext('methode')})
            return {'metadata': properties, 'url': url, 'sha256': hashlib.sha256(raw).hexdigest(),
                    'measurements': measurements, 'status': 'OK' if measurements else 'NO_HEAD_MEASUREMENTS_IN_EXPORT'}
        except Exception as error:
            return {'url': url, 'metadata': properties, 'status': 'ERROR', 'error': str(error)}
    with ThreadPoolExecutor(max_workers=4) as pool:
        exports = list(pool.map(collect, selected.values()))
    report = {'shallow_recent_candidates': len(shallow), 'selected_exports': len(exports), 'exports': exports,
              'selection': 'All known <=5m screens with head metadata' if args.all_shallow else
                           'Two nearest shallow recent screens per heath candidate, plus six most recent.',
              'full_2024_2026_coverage_from_shallow_metadata': any(
                  (f['properties'].get('peilmetingen_van') or '9999') <= '2024-01-01'
                  and f['properties']['peilmetingen_tot'] >= '2026-10-01' for f in shallow),
              'limitations': ['No interpolation or extrapolation into 2025/2026 is performed.',
                             'Do not equate measurement-reference height with cell ground elevation.',
                             'Do not reuse prescribed head observations as independent validation.']}
    dates = [m['date'][:10] for e in exports for m in e.get('measurements', [])]
    report['actual_last_measurement'] = max(dates) if dates else None
    report['measurements_in_simulation_period'] = sum('2024-01-01' <= date <= '2026-10-01' for date in dates)
    (args.output / 'groundwater_collection.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'selected': len(exports), 'statuses': [r['status'] for r in exports],
                      'measurements': sum(len(r.get('measurements', [])) for r in exports)}))


if __name__ == '__main__':
    main()
