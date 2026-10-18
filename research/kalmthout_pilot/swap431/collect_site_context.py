#!/usr/bin/env python3
"""Collect dated root, vegetation, land-use and water-table field observations."""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import json
import math
from pathlib import Path
import threading
import xml.etree.ElementTree as ET

import requests

PARAMETERS = {'Beworteling diepte', 'Vegetatie', 'vegetatie', 'Bodemgebruik Aardewerk',
              'Bodemgebruik', 'Diepte (grond)watertafel t.o.v. maaiveld'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    source = args.root / 'results/swap431_soil_data/observations.json'
    observations = [f for f in json.loads(source.read_text()) if f['properties']['Parameter'] in PARAMETERS]
    args.output.mkdir(parents=True, exist_ok=True)
    state = threading.local()
    previous_path = args.output / 'site_context.json'
    previous_hashes = {r['file']: r['sha256'] for r in json.loads(previous_path.read_text())['records']
                       if r['status'] == 'OK'} if previous_path.exists() else {}

    def collect(feature):
        p = feature['properties']
        path = args.output / (p['Bodemobservatie'] + '.xml')
        url = p['Bodemobservatiefiche'] + '.xml'
        try:
            if path.exists() and path.name in previous_hashes:
                assert hashlib.sha256(path.read_bytes()).hexdigest() == previous_hashes[path.name], 'Cached source identity changed'
            if path.exists() and path.name not in previous_hashes:
                try:
                    ET.parse(path)
                except ET.ParseError:
                    path.unlink()  # Incomplete uncommitted download, recover automatically.
            if not path.exists():
                if not hasattr(state, 'client'):
                    state.client = requests.Session()
                response = state.client.get(url, timeout=60)
                response.raise_for_status()
                ET.fromstring(response.content)
                temporary = path.with_suffix('.xml.tmp')
                temporary.write_bytes(response.content)
                temporary.replace(path)
            raw = path.read_bytes()
            obs = ET.fromstring(raw).find('observatie')
            assert obs is not None
            assert obs.findtext('identificator/identificator') == p['Bodemobservatie']
            value_fields = {child.tag: child.text for child in obs if child.tag.startswith('waarde_')}
            phenomenon = obs.findtext('fenomeentijd')
            # Entry timestamps and identifier years are not observation dates.
            period = 'UNKNOWN_DATE' if not phenomenon else 'WITHIN_MODEL_PERIOD' if (
                '2024-01-01' <= phenomenon[:10] <= '2026-10-01') else 'OUTSIDE_MODEL_PERIOD'
            return {'observation_url': p['Bodemobservatiefiche'], 'xml_url': url,
                    'file': path.name, 'sha256': hashlib.sha256(raw).hexdigest(),
                    'location_url': p['Bodemlocatiefiche'], 'coordinates_epsg32631': feature['geometry']['coordinates'][:2],
                    'parameter': p['Parameter'], 'xml_parameter': obs.findtext('parameter'),
                    'wfs_value': p['Waarde'], 'xml_values': value_fields, 'unit': obs.findtext('eenheid'),
                    'phenomenon_time': phenomenon, 'result_time': obs.findtext('resultaattijd'),
                    'entry_time_not_measurement_date': p.get('eerste_invoer'),
                    'reliability_concept': obs.findtext('betrouwbaarheid'),
                    'depth_from_m': obs.findtext('diepte_van'), 'depth_to_m': obs.findtext('diepte_tot'),
                    'period_status': period, 'status': 'OK', 'automatic_crop_parameter_assignment': False}
        except Exception as error:
            return {'observation_url': p['Bodemobservatiefiche'], 'parameter': p['Parameter'],
                    'status': 'ERROR', 'error': str(error)}

    with ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(collect, observations))
    report = {'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'records': records,
              'parameter_counts': dict(Counter(r['parameter'] for r in records)),
              'status_counts': dict(Counter(r['status'] for r in records)),
              'period_counts': dict(Counter(r.get('period_status', 'ERROR') for r in records)),
              'policy': ['Original typed XML values retained; categorical codes are not inferred as physical parameters.',
                         'Root depth observations are not root density, maximum uptake depth or Feddes thresholds.',
                         'Groundwater snapshot depth is not a time-varying lower boundary.',
                         'Historical vegetation and land use are not assigned to 2024-2026 cells.']}
    groups = defaultdict(list)
    for record in records:
        if record['status'] == 'OK':
            groups[record['parameter']].append(record)
    grid_path = args.root / 'export/grid_500m.csv'
    grid = list(csv.DictReader(grid_path.open()))
    links = []
    for cell in grid:
        xy = [float(cell['easting']), float(cell['northing'])]
        for parameter, candidates in sorted(groups.items()):
            ordered = sorted(candidates, key=lambda r: (math.dist(xy, r['coordinates_epsg32631']), r['observation_url']))
            for rank, record in enumerate(ordered[:3], 1):
                links.append({'cell_id': cell['cell_id'], 'parameter': parameter, 'rank_by_distance': rank,
                              'distance_m': math.dist(xy, record['coordinates_epsg32631']),
                              'observation_url': record['observation_url'], 'location_url': record['location_url'],
                              'phenomenon_time': record['phenomenon_time'], 'period_status': record['period_status'],
                              'xml_values_json': json.dumps(record['xml_values'], ensure_ascii=False, sort_keys=True),
                              'unit': record['unit'], 'automatic_crop_parameter_assignment': False})
    with (args.output / 'cell_nearby_field_context.csv').open('w') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(links[0]))
        writer.writeheader()
        writer.writerows(links)
    report['grid_sha256'] = hashlib.sha256(grid_path.read_bytes()).hexdigest()
    report['grid_cells'] = len(grid)
    report['nearby_links'] = len(links)
    report['parameter_year_counts'] = {parameter: dict(sorted(Counter(
        (r['phenomenon_time'] or 'unknown')[:4] for r in candidates).items())) for parameter, candidates in sorted(groups.items())}
    report['nearby_link_policy'] = 'Nearest three per source parameter; no representativity or crop contract implied.'
    (args.output / 'site_context.json').write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({k: report[k] for k in ['parameter_counts', 'status_counts', 'period_counts']}))
    if report['status_counts'].get('ERROR'):
        raise SystemExit('Source errors remain; rerun to resume the cached collection.')


if __name__ == '__main__':
    main()
