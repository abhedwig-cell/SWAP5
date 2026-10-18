#!/usr/bin/env python3
"""Download official WorldCover tiles and retain a native regional crop."""
import argparse
import json
import math
from pathlib import Path

import requests
import rasterio
from rasterio.merge import merge
from pyproj import Transformer
from collect_european_baseline import sha


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('domain',type=Path);p.add_argument('output',type=Path)
    args=p.parse_args();out=args.output;out.mkdir(parents=True,exist_ok=True)
    domain=json.loads(args.domain.read_text());e=domain['minimal_extent']
    b=Transformer.from_crs(domain['crs'],4326,always_xy=True).transform_bounds(
        *[e[k] for k in ('xmin','ymin','xmax','ymax')],densify_pts=41)
    cache=out/'tiles';cache.mkdir(exist_ok=True)
    records=[];paths=[]
    for lat in range(3*math.floor(b[1]/3),3*math.floor(b[3]/3)+1,3):
        for lon in range(3*math.floor(b[0]/3),3*math.floor(b[2]/3)+1,3):
            tile=f'{"N" if lat>=0 else "S"}{abs(lat):02d}{"E" if lon>=0 else "W"}{abs(lon):03d}'
            filename=f'ESA_WorldCover_10m_2021_v200_{tile}_Map.tif'
            url='https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/'+filename
            target=cache/filename;receipt=target.with_suffix('.request.json')
            old=json.loads(receipt.read_text()) if receipt.exists() else {}
            if not target.exists() or old.get('sha256')!=sha(target) or old.get('url')!=url:
                temp=target.with_suffix('.partial')
                with requests.get(url,stream=True,timeout=(15,120)) as r:
                    r.raise_for_status();assert r.status_code==200, 'Expected complete source tile'
                    with temp.open('wb') as f:
                        for block in r.iter_content(1048576):f.write(block)
                    old=dict(url=url,etag=r.headers.get('ETag'),last_modified=r.headers.get('Last-Modified'))
                with rasterio.open(temp) as src:assert src.crs.to_epsg()==4326
                temp.replace(target)
                old.update(sha256=sha(target),bytes=target.stat().st_size)
                receipt.write_text(json.dumps(old,indent=2)+'\n')
            records.append(old);paths.append(target)
    sources=[rasterio.open(path) for path in paths]
    try:
        # Retain a one-native-pixel margin to cover later nearest-neighbour warp.
        res=sources[0].res
        bounds=(b[0]-res[0],b[1]-res[1],b[2]+res[0],b[3]+res[1])
        values,transform=merge(sources,bounds=bounds)
        profile=sources[0].profile
        profile.update(height=values.shape[1],width=values.shape[2],transform=transform,compress='deflate')
        target=out/'worldcover2021_region.tif'
        with rasterio.open(target,'w',**profile) as dst:dst.write(values)
    finally:
        for src in sources:src.close()
    manifest=dict(dataset='ESA WorldCover2021v200',nominal_resolution_m=10,
                  source_year=2021,domain_sha256=sha(args.domain),tiles=records,
                  regional_sha256=sha(target),native_crop_bounds_lonlat=bounds,
                  landing='https://esa-worldcover.org/en/data-access',
                  interpretation='Land cover, not crop species, land management, or current2024-2026 observations.')
    (out/'worldcover_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))


if __name__=='__main__':main()
