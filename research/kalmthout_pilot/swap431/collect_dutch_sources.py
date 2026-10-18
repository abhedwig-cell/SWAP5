#!/usr/bin/env python3
"""Collect complementary Dutch soil point profiles and actual land-cover polygons.

No conversion of map classes into measured local parameters or validated SWAP input.
Original responses, query locations, source dates and incomplete coverage are retained.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import hashlib
import json
from pathlib import Path

import requests
from pyproj import Transformer
from shapely import make_valid
from shapely.geometry import box, shape
from shapely.ops import transform, unary_union
from shapely.strtree import STRtree

SOIL = 'https://www.soilphysics.wur.nl/soil.php'
LAND = 'https://api.pdok.nl/kadaster/brt-bodemgebruik/ogc/v1/collections/landcoverunit/items'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def retrieve(url, path, parameters=None):
    """Resume only a hash-verified original response with the same request."""
    query = {'url': url, 'parameters': parameters}
    meta = path.with_suffix('.request.json')
    if path.exists() and meta.exists():
        saved = json.loads(meta.read_text())
        if saved['request'] == query and saved['sha256'] == sha(path):
            return json.loads(path.read_bytes())
    response = requests.get(url, params=parameters, timeout=60)
    response.raise_for_status()
    data = response.json()
    path.write_bytes(response.content)
    meta.write_text(json.dumps({'request': query, 'response_url': response.url,
                                'sha256': sha(path), 'bytes': path.stat().st_size}, indent=2) + '\n')
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    root, out = args.root.resolve(), args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    for name in ['soil_points', 'landcover_pages']:
        (out / name).mkdir(exist_ok=True)
    grid = list(csv.DictReader((root / 'export/grid_500m.csv').open()))
    coverage = {r['cell_id']: r for r in csv.DictReader(
        (root / 'results/cell_sources_final/cell_source_coverage.csv').open())}
    targets = [g for g in grid if float(coverage[g['cell_id']]['soil_coverage_fraction']) < .95
               or float(coverage[g['cell_id']]['landuse2025_coverage_fraction']) < .95]
    to_ll = Transformer.from_crs(32631, 4326, always_xy=True)
    to_grid = Transformer.from_crs(4326, 32631, always_xy=True)

    def soil_point(cell):
        lon, lat = to_ll.transform(float(cell['easting']), float(cell['northing']))
        result = {'cell_id': cell['cell_id'], 'longitude': lon, 'latitude': lat,
                  'sampling': 'CELL_CENTRE_POINT_NOT_AREA_PROFILE'}
        try:
            data = retrieve(SOIL, out / 'soil_points' / (cell['cell_id'] + '.json'),
                            {'latitude': lat, 'longitude': lon})
            if data == 'No soil information available for this location.':
                result['status'] = 'NO_SOIL_INFORMATION'
            else:
                assert isinstance(data, dict) and data['smu'] and data['horizon']
                bottom = 0.
                for h in data['horizon']:
                    assert float(h['top']) == bottom < float(h['bottom'])
                    assert abs(sum(float(h[k]) for k in ['sand', 'silt', 'clay']) - 100) < 1e-6
                    assert h['spu'].startswith(('B', 'O'))
                    bottom = float(h['bottom'])
                result.update(status='DERIVED_MODAL_PROFILE', profile=data)
        except (requests.RequestException, ValueError, KeyError, AssertionError) as error:
            result.update(status='ERROR', error_type=type(error).__name__)
        return result

    with ThreadPoolExecutor(max_workers=3) as pool:
        profiles = list(pool.map(soil_point, targets))
    (out / 'soil_point_profiles.json').write_text(json.dumps(profiles, indent=2) + '\n')

    bbox = to_ll.transform_bounds(min(float(g['xmin']) for g in grid),
                                  min(float(g['ymin']) for g in grid),
                                  max(float(g['xmax']) for g in grid),
                                  max(float(g['ymax']) for g in grid), densify_pts=21)
    url, parameters = LAND, {'bbox': ','.join(map(str, bbox)), 'limit': 1000, 'f': 'json'}
    features, ids, visited = [], set(), set()
    page = 0
    while url:
        assert url not in visited, 'Repeated pagination link'
        visited.add(url)
        page += 1
        data = retrieve(url, out / 'landcover_pages' / f'page_{page:03d}.json', parameters)
        assert len(data['features']) == data['numberReturned']
        for feature in data['features']:
            identity = str(feature['id'])
            assert identity not in ids, 'Pagination duplicates a feature'
            ids.add(identity)
            features.append(feature)
        following = [link['href'] for link in data['links'] if link['rel'] == 'next']
        assert len(following) <= 1
        url, parameters = (following[0] if following else None), None
        if url:
            assert url.startswith(LAND + '?'), 'Unexpected source pagination host or endpoint'
    shapes, invalid = [], 0
    for feature in features:
        geom = transform(to_grid.transform, shape(feature['geometry']))
        if not geom.is_valid:
            invalid += 1
            geom = make_valid(geom)
        shapes.append(geom)
    tree = STRtree(shapes)
    rows = []
    for cell in grid:
        geometry = box(*(float(cell[k]) for k in ['xmin', 'ymin', 'xmax', 'ymax']))
        pieces, classes, dates = [], {}, set()
        for index in tree.query(geometry, predicate='intersects'):
            clipped = geometry.intersection(shapes[index])
            if clipped.area <= 0:
                continue
            props = features[index]['properties']
            key = props['land_cover_observation_class']
            classes[key] = classes.get(key, 0.) + clipped.area / geometry.area
            dates.add(props.get('observation_date'))
            pieces.append(clipped)
        area = unary_union(pieces).area if pieces else 0.
        rows.append({'cell_id': cell['cell_id'], 'coverage_fraction': area / geometry.area,
                     'overlap_fraction': (sum(p.area for p in pieces) - area) / geometry.area,
                     'class_area_fractions': classes, 'observation_dates': sorted(d for d in dates if d),
                     'missing_date_features': any(d is None for d in dates)})
    (out / 'cell_landcover.json').write_text(json.dumps(rows, indent=2) + '\n')
    dates = sorted({f['properties'].get('observation_date') for f in features
                    if f['properties'].get('observation_date')})
    manifest = {'grid_cells': len(grid), 'target_soil_centres': len(targets),
                'soil_profile_count': sum(r['status'] == 'DERIVED_MODAL_PROFILE' for r in profiles),
                'soil_no_information': sum(r['status'] == 'NO_SOIL_INFORMATION' for r in profiles),
                'soil_errors': sum(r['status'] == 'ERROR' for r in profiles),
                'landcover_features': len(features), 'landcover_pages': page,
                'landcover_cells_any': sum(r['coverage_fraction'] > 1e-8 for r in rows),
                'landcover_cells_95pct': sum(r['coverage_fraction'] >= .95 for r in rows),
                'landcover_observation_dates': dates,
                'invalid_geometries_repaired_for_overlay': invalid,
                'input_grid_sha256': sha(root / 'export/grid_500m.csv'),
                'input_flemish_coverage_sha256': sha(root / 'results/cell_sources_final/cell_source_coverage.csv'),
                'source_soil': SOIL, 'source_landcover': LAND,
                'limitations': ['WUR supplies derived modal profiles, not local field observations.',
                                'Centre-point profiles cannot establish whole-cell or subunit soil coverage.',
                                'SPU class names are retained; no implicit hydraulic-version mapping.',
                                'BRT classes and observation dates remain separate from Flemish land use/BWK.',
                                'No canopy/root/groundwater parameters or SWAP cell qualification generated.']}
    manifest['file_sha256'] = {str(p.relative_to(out)): sha(p) for p in sorted(out.rglob('*'))
                              if p.is_file() and p.name != 'dutch_source_manifest.json'}
    (out / 'dutch_source_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: v for k, v in manifest.items() if k != 'file_sha256'}))
    assert manifest['soil_errors'] == 0, 'Incomplete source collection; inspect retained errors'


if __name__ == '__main__':
    main()
