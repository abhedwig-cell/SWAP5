#!/usr/bin/env python3
"""Assemble a full grid by explicit references to parent and vegetation deltas."""
import argparse
import csv
import json
from pathlib import Path


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline',type=Path);p.add_argument('variants',type=Path)
    p.add_argument('output',type=Path);p.add_argument('--common-only',action='store_true')
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    base=args.baseline.resolve();variant=args.variants.resolve()
    candidates={}
    for path in (variant/'cells').glob('*/cell_manifest.json'):
        m=json.loads(path.read_text())
        if not args.common_only or m['refinement_membership']['corine_common_heath']:candidates[path.parent.name]=m
    grid=list(csv.DictReader((base/'cell_register.csv').open()))
    features=json.loads((base/'grid_250m.geojson').read_text())
    selected=args.output/'cells';selected.mkdir(exist_ok=True)
    import os
    for row,f in zip(grid,features['features']):
        identity=row['cell_id'];assert f['properties']['cell_id']==identity
        source=(variant if identity in candidates else base)/'cells'/identity
        link=selected/identity
        if not link.exists():link.symlink_to(Path(os.path.relpath(source,selected)),target_is_directory=True)
        f['properties']['model_vegetation_class']=20 if identity in candidates else int(row['dominant_land_class'])
        if identity in candidates:
            membership=candidates[identity]['refinement_membership']
            f['properties']['vegetation_source']='CORINE322' if args.common_only else 'CORINE322+BWK' if membership['corine_common_heath'] and membership['bwk_local_heath'] else 'CORINE322' if membership['corine_common_heath'] else 'BWK_HEATH'
        else:f['properties']['vegetation_source']='WorldCover broad class'
        row['worldcover_original_class']=row['dominant_land_class']
        if identity in candidates:row['dominant_land_class']='20'
    with (args.output/'cell_register.csv').open('w',newline='') as handle:
        w=csv.DictWriter(handle,fieldnames=list(grid[0]));w.writeheader();w.writerows(grid)
    (args.output/'grid_250m.geojson').write_text(json.dumps(features))
    for name in ['grid_250m.csv','landcover_fractions.csv']:
        link=args.output/name
        if not link.exists():link.symlink_to(Path(os.path.relpath(base/name,args.output)))
    forcing=args.output/'forcing'
    if not forcing.exists():forcing.symlink_to(Path(os.path.relpath(base/'forcing',args.output)),target_is_directory=True)
    version=dict(version='EUROPEAN_COMMON_HEATH' if args.common_only else 'EUROPEAN_PLUS_LOCAL_HEATH',
                 total_grid_cells=len(grid),heath_override_cells=len(candidates),
                 unchanged_parent_cells=len(grid)-len(candidates),
                 model_contract='Full grid assembled by explicit parent/delta links; no new native calculation or parameter alteration.',
                 source_priority='European CORINE322 majority-heath only; no local habitat data determine vegetation.' if args.common_only else 'European CORINE322 heath plus positive local BWK majority-heath additions; no negative local habitat inference from absence of a listed Natura2000 habitat.',
                 groundwater='All parent lower boundaries preserved;62 local wet-heath review cells remain separately flagged.')
    (args.output/'model_version.json').write_text(json.dumps(version,indent=2)+'\n');print(json.dumps(version,indent=2))


if __name__=='__main__':main()
