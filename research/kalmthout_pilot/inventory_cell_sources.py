#!/usr/bin/env python3
"""Intersect original EPSG:32631 WFS polygons with the official pilot grid.

Requires shapely >=2. Keeps source features and compound vegetation codes;
does not turn map codes into hydraulic or vegetation model parameters.
"""
import argparse
import csv
import hashlib
import json
from collections import defaultdict
from pathlib import Path

import shapely
from shapely import STRtree, box, make_valid, union_all
from shapely.geometry import shape


def load_pages(paths, fields):
    features, hashes, seen, repaired = [], {}, set(), 0
    for path in paths:
        raw = path.read_bytes()
        hashes[str(path)] = hashlib.sha256(raw).hexdigest()
        data = json.loads(raw)
        assert data['crs']['properties']['name'].endswith('32631'), path
        for feature in data['features']:
            identity = feature['id']
            if identity in seen:
                raise ValueError(f'duplicate paginated feature {identity}')
            seen.add(identity)
            geometry = shape(feature['geometry'])
            if not geometry.is_valid:
                geometry = make_valid(geometry)
                repaired += 1
            properties = feature['properties']
            key = tuple(str(properties.get(name) or '') for name in fields)
            features.append((geometry, identity, key))
    return features, hashes, repaired


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('grid', type=Path)
    parser.add_argument('soil', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--bwk', nargs='+', type=Path, required=True)
    parser.add_argument('--landuse', type=Path)
    parser.add_argument('--landuse2022', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    soil, soil_hashes, soil_repairs = load_pages([args.soil], ['Bodemtype'])
    bwk_fields = ['BWKLABEL', 'HAB1', 'PHAB1', 'HAB2', 'PHAB2', 'HAB3', 'PHAB3', 'HAB4', 'PHAB4', 'HAB5', 'PHAB5']
    bwk, bwk_hashes, bwk_repairs = load_pages(args.bwk, bwk_fields)
    collections = {'soil': soil, 'bwk': bwk}
    raster_hashes = {}
    for year, raster_path in [(2025, args.landuse), (2022, args.landuse2022)]:
        if raster_path is None:
            continue
        import rasterio
        from rasterio.features import shapes
        from pyproj import Transformer
        from shapely.ops import transform
        with rasterio.open(raster_path) as raster:
            assert raster.crs.to_epsg() == 31370
            assert raster.res == (10.0, 10.0)
            values = raster.read(1)
            convert = Transformer.from_crs(raster.crs, 32631, always_xy=True).transform
            collections[f'landuse{year}'] = [
                (transform(convert, shape(geom)), f'raster_region_{i}', (str(int(value)),))
                for i, (geom, value) in enumerate(shapes(values, mask=values != raster.nodata, transform=raster.transform))
            ]
        raster_hashes[str(raster_path)] = hashlib.sha256(raster_path.read_bytes()).hexdigest()
    trees = {layer: STRtree([f[0] for f in collection]) for layer, collection in collections.items()}
    grid = list(csv.DictReader(args.grid.open()))
    assert len(grid) == 1024
    summary, fractions, joint = [], [], []
    for row in grid:
        cell = box(*(float(row[k]) for k in ['xmin', 'ymin', 'xmax', 'ymax']))
        assert cell.area == 250000
        clipped = []
        result = {'cell_id': row['cell_id']}
        for layer, collection in collections.items():
            tree = trees[layer]
            parts = []
            for index in tree.query(cell, predicate='intersects'):
                geometry, identity, key = collection[index]
                part = geometry.intersection(cell)
                if part.area <= 1e-6:
                    continue
                parts.append((part, identity, key))
                fractions.append([row['cell_id'], layer, identity, json.dumps(key), part.area, part.area / cell.area])
            covered = union_all([p[0] for p in parts]).area if parts else 0.0
            result[layer + '_coverage_fraction'] = covered / cell.area
            result[layer + '_overlap_fraction'] = (sum(p[0].area for p in parts) - covered) / cell.area
            result[layer + '_feature_count'] = len(parts)
            clipped.append(parts)
        pair_areas = defaultdict(float)
        for sg, si, sk in clipped[0]:
            for bg, bi, bk in clipped[1]:
                area = sg.intersection(bg).area
                if area > 1e-6:
                    pair_areas[(sk[0], bk)] += area
        for (soil_type, vegetation), area in sorted(pair_areas.items()):
            joint.append([row['cell_id'], soil_type, json.dumps(vegetation), area, area / cell.area])
        result['joint_fraction_sum'] = sum(pair_areas.values()) / cell.area
        result['ready_for_simulation'] = False
        summary.append(result)
    for filename, fields, rows in [
        ('cell_source_coverage.csv', list(summary[0]), [list(r.values()) for r in summary]),
        ('cell_source_fractions.csv', ['cell_id', 'layer', 'source_id', 'source_codes_json', 'area_m2', 'cell_fraction'], fractions),
        ('cell_joint_units.csv', ['cell_id', 'soil_type', 'bwk_habitat_codes_json', 'area_m2', 'cell_fraction'], joint),
    ]:
        with (args.output / filename).open('w', newline='') as handle:
            writer = csv.writer(handle)
            writer.writerow(fields)
            writer.writerows(rows)
    audit = {
        'crs': 'EPSG:32631', 'cells': len(grid), 'cell_area_m2': 250000,
        'shapely_version': shapely.__version__, 'soil_features': len(soil), 'bwk_features': len(bwk),
        'repaired_geometries': {'soil': soil_repairs, 'bwk': bwk_repairs},
        'input_sha256': {**soil_hashes, **bwk_hashes, **raster_hashes, str(args.grid): hashlib.sha256(args.grid.read_bytes()).hexdigest()},
        'bwk_tuple_fields': bwk_fields,
        'coverage': {layer: {
            'equivalent_full_cells': sum(r[layer + '_coverage_fraction'] for r in summary),
            'fully_covered_cells': sum(r[layer + '_coverage_fraction'] >= 1 - 1e-7 for r in summary),
            'zero_coverage_cells': sum(r[layer + '_coverage_fraction'] <= 1e-7 for r in summary),
            'max_overlap_fraction': max(r[layer + '_overlap_fraction'] for r in summary),
        } for layer in collections},
        'representative_cell': next(r for r in summary if r['cell_id'] == 'KAL_0496'),
        'joint_rows': len(joint),
        'status': 'SOURCE_INVENTORY_ONLY; no hydraulic, root, canopy or lower-boundary parameters assigned',
        'limitations': ['Habitat proportions are retained within each source polygon; geometry is not split by habitat percentage.',
                       'Joint units retain mapped heterogeneity, not subpolygon geography.',
                       'Missing area is explicit; do not renormalize it into covered classes.',
                       'Overlaps require reconciliation before area-weighted simulation.'],
    }
    (args.output / 'source_overlay_audit.json').write_text(json.dumps(audit, indent=2) + '\n')
    print(json.dumps(audit, indent=2))


if __name__ == '__main__':
    main()
