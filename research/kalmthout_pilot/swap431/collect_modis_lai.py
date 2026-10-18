#!/usr/bin/env python3
"""Collect actual MODIS LAI and QA for grid centres, without filling time gaps."""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import hashlib
import json
from pathlib import Path
import threading
import time

import numpy as np
from pyproj import Transformer
import rasterio
from rasterio.io import MemoryFile
from rasterio.windows import Window
import requests

API = 'https://planetarycomputer.microsoft.com/api/stac/v1'
BANDS = ['Lai_500m', 'FparLai_QC', 'FparExtra_QC']


def flags(lai, qc, extra):
    numeric = lai <= 100
    main = numeric & ((qc & 1) == 0) & ((qc >> 5) <= 1)
    strict = main & ((qc & 4) == 0) & (((qc >> 3) & 3) == 0) & ((extra & 127) == 0)
    return numeric, main, strict


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('grid', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    catalog = out / 'catalog.json'
    if not catalog.exists():
        url = API + '/search'
        params = {'collections': 'modis-15A2H-061', 'bbox': '4.3,51.29,4.55,51.44',
                  'datetime': '2024-01-01T00:00:00Z/2026-10-01T23:59:59Z', 'limit': 300}
        pages = []
        while url:
            response = requests.get(url, params=params, timeout=60)
            response.raise_for_status()
            page = response.json()
            pages.append(page)
            url = next((link['href'] for link in page['links'] if link['rel'] == 'next'), None)
            params = None
        catalog.write_text(json.dumps(pages) + '\n')
    pages = json.loads(catalog.read_text())
    items = {f['id']: f for page in pages for f in page['features'] if f['id'].startswith('MCD15A2H.')}
    assert items
    grid = list(csv.DictReader(args.grid.open()))
    x, y = np.array([float(r['easting']) for r in grid]), np.array([float(r['northing']) for r in grid])
    state = threading.local()
    # The official container token serves all assets. Signing every individual
    # band needlessly exhausts the public signing API's request allowance.
    token = None
    for attempt in range(4):
        response = requests.get('https://planetarycomputer.microsoft.com/api/sas/v1/token/modiseuwest/modis-061-cogs', timeout=60)
        if response.status_code == 429:
            delay = int(response.headers.get('Retry-After', '60')) + 1
            print('Source signing allowance, waiting seconds', delay, flush=True)
            while delay > 0:
                wait = min(delay, 60)
                time.sleep(wait)
                delay -= wait
            continue
        response.raise_for_status()
        token = response.json()['token']
        break
    assert token is not None, 'Source signing allowance unavailable after bounded retries'

    def collect(item):
        identity = item['id']
        cache, meta = out / (identity + '.npz'), out / (identity + '.json')
        if cache.exists() and meta.exists():
            result = json.loads(meta.read_text())
            assert hashlib.sha256(cache.read_bytes()).hexdigest() == result['cache_sha256']
            return result
        if not hasattr(state, 'client'):
            state.client = requests.Session()
        records, arrays, spatial = [], {}, None
        for band in BANDS:
            href = item['assets'][band]['href']
            response = state.client.get(href + '?' + token, timeout=60)
            response.raise_for_status()
            raw = response.content
            with MemoryFile(raw) as memory, memory.open() as ds:
                transformer = Transformer.from_crs(32631, ds.crs, always_xy=True)
                sx, sy = transformer.transform(x, y)
                rr, cc = rasterio.transform.rowcol(ds.transform, sx, sy)
                rr, cc = np.array(rr), np.array(cc)
                assert rr.min() >= 0 and cc.min() >= 0 and rr.max() < ds.height and cc.max() < ds.width
                window = Window(int(cc.min()), int(rr.min()), int(cc.max()-cc.min()+1), int(rr.max()-rr.min()+1))
                arrays[band] = ds.read(1, window=window)
                info = {'crs_wkt': ds.crs.to_wkt(), 'transform': list(ds.window_transform(window)),
                        'source_window': list(window.flatten()), 'rows': rr.tolist(), 'columns': cc.tolist()}
                if spatial is None:
                    spatial = info
                    arrays['cell_rows'] = rr - rr.min()
                    arrays['cell_columns'] = cc - cc.min()
                else:
                    assert info == spatial, 'Band grid mismatch'
                records.append({'band': band, 'source_url': href, 'source_bytes': len(raw),
                                'source_sha256': hashlib.sha256(raw).hexdigest(),
                                'scale': ds.scales[0], 'valid_range': ds.tags().get('valid_range')})
        np.savez_compressed(cache, **arrays)
        result = {'id': identity, 'start': item['properties']['start_datetime'],
                  'end': item['properties']['end_datetime'], 'assets': records, 'spatial': spatial,
                  'cache_sha256': hashlib.sha256(cache.read_bytes()).hexdigest()}
        meta.write_text(json.dumps(result, indent=2) + '\n')
        return result

    records, errors = [], []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = {pool.submit(collect, item): identity for identity, item in sorted(items.items())}
        for future in as_completed(futures):
            try:
                records.append(future.result())
            except Exception as error:
                errors.append({'id': futures[future], 'error': str(error)})
            if (len(records)+len(errors)) % 10 == 0:
                print('LAI cached', len(records), 'errors', len(errors), 'of', len(items), flush=True)
    records.sort(key=lambda r: r['start'])
    counts = {'numeric': 0, 'main_algorithm': 0, 'strict': 0}
    with (out / 'cell_lai_observations.csv').open('w') as handle:
        fields = ['cell_id', 'item', 'start', 'end', 'source_row', 'source_column',
                  'lai_raw', 'lai_m2_m2', 'qc_raw', 'extra_qc_raw', 'main_algorithm', 'strict_quality']
        writer = csv.DictWriter(handle, fields)
        writer.writeheader()
        for record in records:
            with np.load(out / (record['id'] + '.npz')) as data:
                r, c = data['cell_rows'], data['cell_columns']
                lai, qc, extra = [data[b][r, c] for b in BANDS]
            numeric, main, strict = flags(lai, qc, extra)
            for key, values in zip(counts, [numeric, main, strict]):
                counts[key] += int(values.sum())
            for i, cell in enumerate(grid):
                writer.writerow({'cell_id': cell['cell_id'], 'item': record['id'], 'start': record['start'],
                                 'end': record['end'], 'source_row': record['spatial']['rows'][i],
                                 'source_column': record['spatial']['columns'][i], 'lai_raw': int(lai[i]),
                                 'lai_m2_m2': float(lai[i]) * .1 if numeric[i] else '',
                                 'qc_raw': int(qc[i]), 'extra_qc_raw': int(extra[i]),
                                 'main_algorithm': bool(main[i]), 'strict_quality': bool(strict[i])})
    manifest = {'model_grid_sha256': hashlib.sha256(args.grid.read_bytes()).hexdigest(),
                'catalog_sha256': hashlib.sha256(catalog.read_bytes()).hexdigest(),
                'items_found': len(items), 'items_collected': len(records), 'errors': errors,
                'cell_count': len(grid), 'counts': counts, 'items': records,
                'quality_reference': 'https://lpdaac.usgs.gov/documents/926/MOD15_User_Guide_V61.pdf, tables 3-5',
                'policy': ['MCD combined Terra/Aqua, version6.1, actual 8-day composites.',
                           'Nearest native MODIS pixel at grid centre; no area average or heath fraction isolation.',
                           'Raw QA retained. Main algorithm includes saturation. Strict excludes cloud/dead-detector/extra flags.',
                           'No interpolation, no gap filling, no LAI applied automatically to SWAP.',
                           'Composite start/end retained, including intervals overlapping the simulation edges.']}
    (out / 'lai_manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({k: manifest[k] for k in ['items_found', 'items_collected', 'cell_count', 'counts']},
                     )[:-1] + ', "error_count": ' + str(len(errors)) + '}')
    if errors:
        raise SystemExit('Some source retrievals failed; rerun to resume verified caches.')


if __name__ == '__main__':
    main()
