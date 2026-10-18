#!/usr/bin/env python3
"""Obtain real CORINE vector classes as common-European improvement context.

No rendered map colours are interpreted as data and no running models are edited.
"""
import argparse
import csv
import json
from pathlib import Path

import requests
from pyproj import Transformer
from shapely import STRtree,box,make_valid,union_all
from shapely.geometry import shape
from shapely.ops import transform
from collect_european_baseline import sha

URL='https://image.discomap.eea.europa.eu/arcgis/rest/services/Corine/CLC2018_LAEA/MapServer/0'


def retrieve(parameters,path):
    receipt=path.with_suffix('.request.json')
    if receipt.exists() and path.exists():
        r=json.loads(receipt.read_text())
        if r['parameters']==parameters and r['sha256']==sha(path):return json.loads(path.read_text())
    response=requests.get(URL+'/query',params=parameters,timeout=(15,90));response.raise_for_status()
    data=response.json();assert 'error' not in data,data
    path.write_bytes(response.content)
    receipt.write_text(json.dumps(dict(url=URL+'/query',parameters=parameters,response_url=response.url,sha256=sha(path)),indent=2)+'\n')
    return data


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('baseline',type=Path);p.add_argument('output',type=Path)
    args=p.parse_args();out=args.output;out.mkdir(parents=True,exist_ok=True)
    grid=list(csv.DictReader((args.baseline/'cell_register.csv').open()))
    b=[min(float(r['xmin']) for r in grid),min(float(r['ymin']) for r in grid),max(float(r['xmax']) for r in grid),max(float(r['ymax']) for r in grid)]
    params=dict(f='json',where='1=1',geometry=','.join(map(str,b)),geometryType='esriGeometryEnvelope',inSR=32631,
                spatialRel='esriSpatialRelIntersects',returnIdsOnly='true')
    ids=sorted(retrieve(params,out/'regional_object_ids.json')['objectIds']);assert len(ids)==len(set(ids))
    convert=Transformer.from_crs(4326,32631,always_xy=True).transform;features=[];seen=set();source_files=[]
    for i in range(0,len(ids),200):
        target=ids[i:i+200];path=out/f'vectors_{i//200:03d}.geojson'
        parameters=dict(f='geojson',objectIds=','.join(map(str,target)),outFields='OBJECTID,Code_18,ID,Remark,Area_Ha',
                        returnGeometry='true',outSR=4326)
        d=retrieve(parameters,path)
        actual={int(f['properties']['OBJECTID']) for f in d['features']};assert actual==set(target)
        for f in d['features']:
            key=int(f['properties']['OBJECTID']);assert key not in seen;seen.add(key)
            geometry=transform(convert,shape(f['geometry']));geometry=make_valid(geometry) if not geometry.is_valid else geometry
            code=str(f['properties']['Code_18']);assert len(code)==3 and code.isdigit()
            features.append((geometry,key,code))
        source_files.append(dict(file=path.name,sha256=sha(path),features=len(actual)))
    assert seen==set(ids)
    tree=STRtree([r[0] for r in features]);rows=[]
    for cell in grid:
        geom=box(*[float(cell[k]) for k in ('xmin','ymin','xmax','ymax')]);areas={};pieces=[]
        for k in tree.query(geom,predicate='intersects'):
            g,identity,code=features[k];part=g.intersection(geom);a=part.area
            if a>1e-6:areas[code]=areas.get(code,0.)+a;pieces.append(part)
        coverage=union_all(pieces).area/geom.area if pieces else 0.
        rows.append(dict(cell_id=cell['cell_id'],worldcover_class=cell['dominant_land_class'],
                         corine_dominant_class=max(areas,key=areas.get) if areas else '',
                         corine_coverage_fraction=coverage,
                         corine_overlap_fraction=sum(areas.values())/geom.area-coverage,
                         corine_heath322_fraction=areas.get('322',0.)/geom.area,
                         corine_broadleaf311_fraction=areas.get('311',0.)/geom.area,
                         corine_conifer312_fraction=areas.get('312',0.)/geom.area,
                         corine_mixedforest313_fraction=areas.get('313',0.)/geom.area))
    with (out/'corine_cell_context.csv').open('w',newline='') as handle:
        w=csv.DictWriter(handle,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    manifest=dict(dataset='CORINE Land Cover2018 vector',source_url=URL,polygons=len(features),source_files=source_files,
                  grid_cells=len(rows),majority_heath322_cells=sum(r['corine_heath322_fraction']>=.5 for r in rows),
                  majority_conifer312_cells=sum(r['corine_conifer312_fraction']>=.5 for r in rows),
                  cells_95pct_coverage=sum(r['corine_coverage_fraction']>=.95 for r in rows),
                  minimum_mapping_unit_ha=25,nominal_minimum_width_m=100,
                  interpretation='Older common-European categorical context; not a2024-2026 land-use observation, not a250m independent survey.',
                  native_model_inputs_edited=False,source_landing='https://land.copernicus.eu/en/products/corine-land-cover/clc2018')
    (out/'corine_context_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))


if __name__=='__main__':main()
