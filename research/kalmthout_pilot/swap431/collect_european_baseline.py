#!/usr/bin/env python3
"""Obtain reusable SoilGrids regional rasters for the complete 250m v0.1 grid.

Native SoilGrids maps retain their own interrupted Goode homolosine grid.
No false claim of independent 250m information or measured local soil properties.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

import requests
import rasterio
from pyproj import CRS, Transformer

DEPTHS = ('0-5cm', '5-15cm', '15-30cm', '30-60cm', '60-100cm', '100-200cm')
PROPERTIES = ('sand', 'silt', 'clay', 'bdod', 'soc')
IGH = CRS.from_proj4('+proj=igh +datum=WGS84 +units=m +no_defs')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('domain', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    domain = json.loads(args.domain.read_text())
    extent = domain['minimal_extent']
    bounds = [extent[k] for k in ('xmin', 'ymin', 'xmax', 'ymax')]
    a = Transformer.from_crs(domain['crs'], IGH, always_xy=True).transform_bounds(*bounds, densify_pts=41)

    def collect(item):
        prop, depth = item
        coverage = f'{prop}_{depth}_mean'
        path = args.output / f'{coverage}.tif'
        receipt = path.with_suffix('.request.json')
        parameters = [('map', f'/map/{prop}.map'), ('SERVICE', 'WCS'), ('VERSION', '2.0.1'),
                      ('REQUEST', 'GetCoverage'), ('COVERAGEID', coverage), ('FORMAT', 'GEOTIFF_INT16'),
                      ('SUBSET', f'X({a[0]-500},{a[2]+500})'), ('SUBSET', f'Y({a[1]-500},{a[3]+500})'),
                      ('SUBSETTINGCRS', 'http://www.opengis.net/def/crs/EPSG/0/152160')]
        request = {'url': 'https://maps.isric.org/mapserv', 'parameters': [list(p) for p in parameters]}
        if receipt.exists() and path.exists():
            old = json.loads(receipt.read_text())
            if old['request'] == request and old['sha256'] == sha(path):
                print('VERIFIED', coverage, flush=True)
                return old
        response = requests.get(request['url'], params=parameters, timeout=(15, 100))
        response.raise_for_status()
        assert response.content[:2] in (b'II', b'MM'), (coverage, response.text[:200])
        temporary = path.with_suffix('.partial.tif')
        temporary.write_bytes(response.content)
        with rasterio.open(temporary) as src:
            assert src.crs is not None and src.count == 1
            metadata = {'crs': src.crs.to_wkt(), 'shape': list(src.shape),
                        'transform': list(src.transform), 'nodata': src.nodata,
                        'resolution': list(src.res)}
        temporary.replace(path)
        result = {'request': request, 'response_url': response.url, 'sha256': sha(path),
                  'bytes': path.stat().st_size, 'coverage': coverage, 'raster': metadata,
                  'source': 'SoilGrids250m 2.0 mean prediction',
                  'units': {'sand': 'g/kg', 'silt': 'g/kg', 'clay': 'g/kg',
                            'bdod': 'cg/cm3', 'soc': 'dg/kg'}[prop]}
        receipt.write_text(json.dumps(result, indent=2) + '\n')
        print('RECEIVED', coverage, result['bytes'], flush=True)
        return result

    with ThreadPoolExecutor(max_workers=3) as pool:
        records = list(pool.map(collect, [(p, d) for p in PROPERTIES for d in DEPTHS]))
    manifest = {'domain_sha256': sha(args.domain), 'extent': extent, 'rasters': records,
                'properties': list(PROPERTIES), 'depth_intervals': list(DEPTHS),
                'method': 'Native regional WCS subsets; target grid sampling is recorded separately.',
                'source_documentation': 'https://docs.isric.org/globaldata/soilgrids/wcs.html'}
    (args.output / 'soilgrids_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('COMPLETE', len(records), flush=True)


if __name__ == '__main__':
    main()
