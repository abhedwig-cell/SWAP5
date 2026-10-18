#!/usr/bin/env python3
"""Collect raw official DTM PixelValue at cell centres and filter locations.

This point service does not supply cell-mean terrain or current survey levels.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import csv
import hashlib
import json
import math
from pathlib import Path
import threading
import time

from pyproj import Transformer
import requests

ENDPOINT = 'https://geo.api.vlaanderen.be/DHMV/wms'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    out = args.output
    out.mkdir(parents=True, exist_ok=True)
    previous_manifest = out/'terrain_manifest.json'
    previous_hashes = json.loads(previous_manifest.read_text()).get('point_cache_sha256',{}) if previous_manifest.exists() else {}
    transform = Transformer.from_crs(32631,31370,always_xy=True)
    grid_path = args.root / 'export/grid_500m.csv'
    points = []
    for cell in csv.DictReader(grid_path.open()):
        x,y = transform.transform(float(cell['easting']),float(cell['northing']))
        points.append({'id':cell['cell_id'],'kind':'cell_centre','x_mL72':x,'y_mL72':y})
    source = args.root / 'results/swap431_groundwater/groundwater_collection.json'
    exports = json.loads(source.read_text())['exports']
    for export in exports:
        p = export['metadata']
        points.append({'id':p['filterfiche'].rsplit('/',1)[-1],'kind':'filter_location',
                       'x_mL72':p['X_mL72'],'y_mL72':p['Y_mL72'],'filter_url':p['filterfiche']})
    state = threading.local()

    def collect(point):
        path = out / (point['kind']+'_'+point['id']+'.json')
        try:
            x,y = point['x_mL72'],point['y_mL72']
            assert math.isfinite(x) and math.isfinite(y)
            params = {'service':'WMS','request':'GetFeatureInfo','version':'1.3.0','crs':'EPSG:31370',
                      'layers':'DHMVII_DTM_1m','query_layers':'DHMVII_DTM_1m',
                      'bbox':f'{x-5.5},{y-5.5},{x+5.5},{y+5.5}','width':11,'height':11,
                      'i':5,'j':5,'info_format':'application/geo+json','feature_count':1}
            if path.exists():
                if path.name in previous_hashes:
                    assert hashlib.sha256(path.read_bytes()).hexdigest()==previous_hashes[path.name], 'Terrain source cache identity changed'
                cached = json.loads(path.read_text())
                assert cached['point'] == point
                return cached
            if not hasattr(state,'client'):
                state.client = requests.Session()
            for attempt in range(3):
                response = state.client.get(ENDPOINT,params=params,timeout=60)
                if response.status_code in [429,503]:
                    delay = int(response.headers.get('Retry-After','30'))
                    while delay:
                        pause = min(delay,60)
                        time.sleep(pause)
                        delay -= pause
                    continue
                response.raise_for_status()
                break
            response.raise_for_status()
            payload = response.json()
            features = payload['features']
            raw_value = features[0]['properties']['PixelValue'] if features else None
            value = None
            if raw_value not in [None,'NoData','NODATA','']:
                value = float(raw_value)
                assert math.isfinite(value)
                if value == -9999:
                    value = None
            result = {'point':point,'request_url':response.url,'response':payload,
                      'response_sha256':hashlib.sha256(response.content).hexdigest(),
                      'elevation_mTAW':value,'status':'OK' if value is not None else 'NO_DATA'}
            temporary = path.with_suffix('.json.tmp')
            temporary.write_text(json.dumps(result,indent=2)+'\n')
            temporary.replace(path)
            return result
        except Exception as error:
            return {'point':point,'status':'ERROR','error':str(error)}

    records = []
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(collect,point) for point in points]
        for future in as_completed(futures):
            records.append(future.result())
            if len(records)%100==0:
                print('Terrain points',len(records),'of',len(points),flush=True)
    records.sort(key=lambda r:(r['point']['kind'],r['point']['id']))
    with (out/'terrain_points.csv').open('w') as handle:
        writer = csv.DictWriter(handle,fieldnames=['id','kind','x_mL72','y_mL72','elevation_mTAW','status'])
        writer.writeheader()
        for r in records:
            writer.writerow({**{k:r['point'][k] for k in ['id','kind','x_mL72','y_mL72']},
                             'elevation_mTAW':r.get('elevation_mTAW'),'status':r['status']})
    errors = [r for r in records if r['status']=='ERROR']
    by_filter = {r['point']['id']:r for r in records if r['point']['kind']=='filter_location' and r['status']=='OK'}
    comparisons = []
    for export in exports:
        p = export['metadata']
        identity = p['filterfiche'].rsplit('/',1)[-1]
        heads = [m['head_mTAW'] for m in export.get('measurements',[]) if '2024-01-01' <= m['date'][:10] <= '2026-10-01']
        if identity not in by_filter or not heads:
            continue
        elevation = by_filter[identity]['elevation_mTAW']
        ref = p.get('Z_mTAW')
        comparisons.append({'filter_url':p['filterfiche'],'name':p.get('GW_ID'),'dtm_elevation_mTAW':elevation,
                            'metadata_reference_mTAW':ref,'reference_minus_dtm_m':None if ref is None else ref-elevation,
                            'period_measurements':len(heads),'head_min_mTAW':min(heads),'head_max_mTAW':max(heads),
                            'dtm_minus_head_min_m':elevation-max(heads),'dtm_minus_head_max_m':elevation-min(heads),
                            'heads_above_dtm_count':sum(h>elevation for h in heads),
                            'qualified_lower_boundary':False})
    if comparisons:
        with (out/'filter_terrain_head_comparison.csv').open('w') as handle:
            writer = csv.DictWriter(handle,fieldnames=list(comparisons[0]))
            writer.writeheader()
            writer.writerows(comparisons)
    manifest = {'grid_sha256':hashlib.sha256(grid_path.read_bytes()).hexdigest(),
                'groundwater_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                'points':len(records),'cell_centres':1024,'filter_locations':len(points)-1024,
                'status_counts':{s:sum(r['status']==s for r in records) for s in ['OK','NO_DATA','ERROR']},
                'errors':errors,'endpoint':ENDPOINT,'layer':'DHMVII_DTM_1m',
                'filter_head_comparisons':len(comparisons),
                'point_cache_sha256':{(r['point']['kind']+'_'+r['point']['id']+'.json'):
                    hashlib.sha256((out/(r['point']['kind']+'_'+r['point']['id']+'.json')).read_bytes()).hexdigest()
                    for r in records if r['status']!='ERROR'},
                'policy':['Raw PixelValue, never rendered StretchedValue or map colours.',
                          'Terrain product heights in metres TAW; nominal acquisition2013-2015, individual flight dates not checked.',
                          'One original1m DTM query at each point; not a500m cell average.',
                          'NoData remains missing, including any Dutch part of the domain.',
                          'DTM-minus-head is an approximate co-located comparison, not observed groundwater depth at the model cell.',
                          'Negative DTM-minus-head is retained: ponding, reference and topography differences require review.',
                          'No automatic lower-boundary prescription or reference-height substitution.']}
    (out/'terrain_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest['status_counts']))
    if errors:
        raise SystemExit('Terrain requests remain incomplete; rerun to resume cached points.')


if __name__ == '__main__':
    main()
