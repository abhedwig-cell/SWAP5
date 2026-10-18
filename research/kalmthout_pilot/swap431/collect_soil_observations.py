#!/usr/bin/env python3
"""Cache all regional DOV soil observations and original texture XML exports."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import shutil
import threading
import time
from urllib.parse import urlencode
from urllib.request import urlopen
import xml.etree.ElementTree as ET
import requests


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    parser.add_argument('--seed', nargs='*', type=Path, default=[])
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    xml_dir = args.output / 'texture_xml'
    xml_dir.mkdir(exist_ok=True)
    observations, last, page, expected = [], '', 0, None
    request_log = []
    while True:
        params = {'service': 'WFS', 'version': '2.0.0', 'request': 'GetFeature',
                  'typeNames': 'bodem:bodemobservaties', 'srsName': 'EPSG:32631',
                  'outputFormat': 'application/json', 'count': 10000, 'sortBy': 'Bodemobservatie A',
                  'cql_filter': "BBOX(geom,592980,5683020,608980,5699020,'EPSG:32631')" +
                                (" AND Bodemobservatie>'" + last + "'" if last else '')}
        url = 'https://www.dov.vlaanderen.be/geoserver/wfs?' + urlencode(params)
        target = args.output / f'page{page:02d}.geojson'
        if page < len(args.seed):
            shutil.copyfile(args.seed[page], target)
        elif not target.exists():
            with urlopen(url, timeout=90) as response:
                raw = response.read()
            json.loads(raw)
            target.write_bytes(raw)
        raw = target.read_bytes()
        data = json.loads(raw)
        features = data['features']
        ids = [f['properties']['Bodemobservatie'] for f in features]
        assert all(a < b for a, b in zip([last] + ids, ids))
        if expected is None:
            expected = int(data['totalFeatures'])
        observations.extend(features)
        request_log.append({'path': target.name, 'url': url, 'sha256': hashlib.sha256(raw).hexdigest(),
                         'seed_reused': page < len(args.seed), 'returned': len(features)})
        if len(features) < 10000:
            break
        last, page = ids[-1], page + 1
    assert len(observations) == expected, (len(observations), expected)
    (args.output / 'observations.json').write_text(json.dumps(observations) + '\n')
    textures = [f['properties'] for f in observations if f['properties']['Parameter'] == 'Textuurfracties']

    thread_state = threading.local()

    def retrieve(properties):
        identity = properties['Bodemobservatie']
        url = properties['Bodemobservatiefiche'] + '.xml'
        target = xml_dir / (identity + '.xml')
        for attempt in range(3):
            try:
                if target.exists():
                    raw = target.read_bytes()
                else:
                    if not hasattr(thread_state, 'session'):
                        thread_state.session = requests.Session()
                    response = thread_state.session.get(url, timeout=35)
                    response.raise_for_status()
                    raw = response.content
                    ET.fromstring(raw)
                    target.write_bytes(raw)
                tree = ET.fromstring(raw)
                count = len(tree.findall('.//waarde_fractiemeting/meting'))
                if count == 0:
                    raise ValueError('no texture fraction measurements in export')
                return {'id': identity, 'url': url, 'file': str(target.relative_to(args.output)),
                        'sha256': hashlib.sha256(raw).hexdigest(), 'fractions': count, 'status': 'OK'}
            except Exception as error:
                if attempt == 2:
                    return {'id': identity, 'url': url, 'status': 'ERROR', 'error': str(error)}
                time.sleep(0.5 * (attempt + 1))

    results = []
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = [executor.submit(retrieve, p) for p in textures]
        for future in as_completed(futures):
            results.append(future.result())
            if len(results) % 50 == 0:
                print('TEXTURE_EXPORTS', len(results), '/', len(textures), flush=True)
    report = {'observation_count': len(observations), 'expected': expected,
              'texture_observations': len(textures), 'requests': request_log,
              'texture_exports': sorted(results, key=lambda r: r['id']),
              'errors': sum(r['status'] != 'OK' for r in results)}
    (args.output / 'collection_manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({k: v for k, v in report.items() if k not in ['requests', 'texture_exports']}))


if __name__ == '__main__':
    main()
