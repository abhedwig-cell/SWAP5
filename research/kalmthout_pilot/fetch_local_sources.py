#!/usr/bin/env python3
"""Retrieve public regional source subsets, not ready-to-run model parameters.

BWK uses monotonically increasing UIDN keysets: offset pagination was observed
to duplicate/skip features. Every raw response and its exact request are saved.
"""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

BBOX = '592980,5683020,608980,5699020,EPSG:32631'
DOV = 'https://www.dov.vlaanderen.be/geoserver/wfs'
BWK = 'https://geo.api.vlaanderen.be/BWK/wfs'
MERCATOR = 'https://www.mercator.vlaanderen.be/raadpleegdienstenmercatorpubliek/ows'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    manifest = {}

    def fetch(base, parameters, name):
        url = base + '?' + urlencode(parameters)
        with urlopen(url, timeout=90) as response:
            raw = response.read()
        (args.output / name).write_bytes(raw)
        manifest[name] = {'url': url, 'sha256': hashlib.sha256(raw).hexdigest(), 'bytes': len(raw)}
        (args.output / 'requests.json').write_text(json.dumps(manifest, indent=2) + '\n')
        return raw

    common = {'service': 'WFS', 'version': '2.0.0', 'request': 'GetFeature',
              'srsName': 'EPSG:32631', 'outputFormat': 'application/json', 'count': 10000}
    for name, layer in [('soil', 'bodemkaart:bodemtypes'), ('profiles', 'bodem:bodemlocaties'),
                        ('ksat', 'bodem:infiltratiemetingen'),
                        ('classifications', 'bodem:bodemclassificaties'),
                        ('horizons', 'bodem:bodemdiepteintervallen'),
                        ('samples', 'bodem:bodemmonsters'),
                        ('historical_profiles', 'dov-pub-aardewerk:vw_profiel'),
                        ('groundwater', 'gw_meetnetten:grondwaterlocaties_met_metingen')]:
        data = json.loads(fetch(DOV, {**common, 'typeNames': layer, 'bbox': BBOX}, 'dov_' + name + '.geojson'))
        assert int(data['totalFeatures']) == len(data['features']) < 10000
    last = -1
    page = 1
    while True:
        params = {**common, 'typeNames': 'BWK:Bwkhab', 'sortBy': 'UIDN A',
                  'cql_filter': "BBOX(SHAPE,592980,5683020,608980,5699020,'EPSG:32631') AND UIDN>" + str(last)}
        data = json.loads(fetch(BWK, params, f'bwk_page{page}.geojson'))
        ids = [feature['properties']['UIDN'] for feature in data['features']]
        assert all(a < b for a, b in zip([last] + ids, ids))
        if len(ids) < 10000:
            break
        last = ids[-1]
        page += 1
    for year in [2022, 2025]:
        params = [('service', 'WCS'), ('version', '2.0.1'), ('request', 'GetCoverage'),
                  ('coverageId', f'lu__lu_landgebruik_vlaa_{year}_v3'),
                  ('subset', 'X(147530,163850)'), ('subset', 'Y(219810,236130)'), ('format', 'image/tiff')]
        fetch(MERCATOR, params, f'landuse{year}.tif')
    fetch(MERCATOR, {'service': 'WMS', 'version': '1.1.1', 'request': 'GetStyles',
                     'layers': 'lu:lu_landgebruik_vlaa_2025_v3'}, 'landuse2025_style.sld')
    print(json.dumps({'files': len(manifest), 'manifest': str(args.output / 'requests.json')}))


if __name__ == '__main__':
    main()
