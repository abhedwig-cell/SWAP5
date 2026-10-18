#!/usr/bin/env python3
"""Prepare the complete initial 250m SWAP grid using common European inputs.

Every cell has a declared assignment, including explicit non-soil water cells.
This v0.1 uses mapped means, pedotransfer estimates and declared vegetation priors.
Local data are future refinements, not eligibility conditions for the first model.
"""
import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import re
import shutil

import numpy as np
import rasterio
from rasterio.transform import from_origin
from rasterio.warp import reproject, Resampling
from pyproj import Transformer
from rosetta import rosetta

from collect_european_baseline import DEPTHS, PROPERTIES, sha
from run_local_soil_scenarios import update
from run_wet_heath_scenarios import crop

# Explicit project priors. WorldCover tree cover does not resolve tree species.
# NHI LAI templates are external phenological analogues, not EU-wide calibration.
VEGETATION = {
    10: dict(name='generic_forest', nhi_index=11, root_cm=100., height_cm=1000., rsc=150., albedo=.15),
    20: dict(name='shrub_heath_analogue', nhi_index=14, root_cm=50., height_cm=40., rsc=288.84, albedo=.30),
    30: dict(name='generic_grass', nhi_index=1, root_cm=50., height_cm=20., rsc=100., albedo=.23),
    40: dict(name='generic_cropland_no_wofost', nhi_index=5, root_cm=80., height_cm=70., rsc=100., albedo=.23),
    50: dict(name='built_up_pervious_soil_surrogate', nhi_index=1, root_cm=30., height_cm=10., rsc=150., albedo=.20),
    60: dict(name='bare_soil', nhi_index=None, root_cm=0., height_cm=0., rsc=0., albedo=.20),
    90: dict(name='wetland_herbaceous_analogue', nhi_index=1, root_cm=50., height_cm=70., rsc=100., albedo=.23),
}


def write_csv(path, records):
    with path.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(records[0]))
        writer.writeheader(); writer.writerows(records)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('domain', type=Path)
    parser.add_argument('sources', type=Path)
    parser.add_argument('previous_root', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    domain = json.loads(args.domain.read_text())
    bbox = domain['minimal_extent']; dx = 250.
    nx, ny = [int((bbox[b] - bbox[a]) / dx) for a, b in [('xmin', 'xmax'), ('ymin', 'ymax')]]
    transform = from_origin(bbox['xmin'], bbox['ymax'], dx, dx)
    grid, xy = [], []
    # Preserve southwest row order; 250m IDs cannot collide with earlier 500m IDs.
    for row in range(ny):
        for col in range(nx):
            x, y = bbox['xmin'] + col * dx, bbox['ymin'] + row * dx
            grid.append(dict(cell_id=f'K250_{row*nx+col+1:05d}', col=col+1, row=row+1,
                             xmin=x, ymin=y, xmax=x+dx, ymax=y+dx,
                             easting=x+dx/2, northing=y+dx/2,
                             parent_500m=f'KAL_{(row//2)*(nx//2)+col//2+1:04d}'))
            xy.append((x+dx/2, y+dx/2))
    assert nx == ny == 64 and len(grid) == 4096
    write_csv(args.output / 'grid_250m.csv', grid)
    soils = args.sources / 'soilgrids'
    source_manifest = json.loads((soils / 'soilgrids_manifest.json').read_text())
    assert source_manifest['domain_sha256'] == sha(args.domain)
    observations = {}
    for prop in PROPERTIES:
        for depth in DEPTHS:
            name = f'{prop}_{depth}_mean'
            print('SAMPLE', name, flush=True)
            path = soils / f'{name}.tif'
            recorded = next(r for r in source_manifest['rasters'] if r['coverage'] == name)
            assert sha(path) == recorded['sha256']
            with rasterio.open(path) as src:
                projected = Transformer.from_crs(domain['crs'], src.crs, always_xy=True).transform
                points = [projected(x, y) for x, y in xy]
                values = list(src.sample(points, masked=True))
                observations[prop, depth] = [None if np.ma.is_masked(v[0]) else float(v[0]) for v in values]
    worldcover = args.sources / 'worldcover/worldcover2021_region.tif'
    print('LANDCOVER', flush=True)
    fine = np.zeros((ny*25, nx*25), dtype=np.uint8)
    with rasterio.open(worldcover) as src:
        reproject(src.read(1), fine, src_transform=src.transform, src_crs=src.crs,
                  dst_transform=from_origin(bbox['xmin'], bbox['ymax'], 10., 10.),
                  dst_crs=domain['crs'], resampling=Resampling.nearest, dst_nodata=0)
    assert np.all(np.isin(fine, [10, 20, 30, 40, 50, 60, 80, 90])), 'Unmapped landcover or coverage gap'
    fractions, decisions, raw, features = [], [], [], []
    for i, cell in enumerate(grid):
        r, c = ny-1-(cell['row']-1), cell['col']-1
        values, counts = np.unique(fine[r*25:(r+1)*25, c*25:(c+1)*25], return_counts=True)
        counts = dict(zip(map(int, values), map(int, counts)))
        land = {k: v for k, v in counts.items() if k != 80}
        dominant = max(land, key=land.get) if land else 80
        fraction = {str(k): v/625 for k, v in counts.items()}
        fractions.extend(dict(cell_id=cell['cell_id'], worldcover_class=k, area_fraction=v/625) for k, v in sorted(counts.items()))
        flags = ['INITIAL_V01_NOT_LOCALLY_CALIBRATED', 'DOMINANT_LAND_COVER_NOT_SUBGRID_MIXTURE',
                 'SHARED_ERA5_REPRESENTATIVE_POINT', 'INITIAL_UNIFORM_HEAD_MINUS75CM_NO_SPINUP']
        if len(land) > 1 or 80 in counts:
            flags.append('MIXED_CELL_REFINE_FRACTIONS')
        if dominant in (30, 40):
            flags.append('DRAINAGE_AND_MANAGEMENT_UNKNOWN_REVIEW')
        if dominant == 50:
            flags.append('NO_IMPERVIOUS_URBAN_HYDROLOGY_SOIL_SURROGATE_ONLY')
        boundary = 'FREE_DRAINAGE_DEFAULT'
        if dominant == 90:
            boundary = 'CONSTANT_SHALLOW_HEAD_WETLAND_PRIOR_50CM'
            flags.append('WETLAND_IS_NOT_PROOF_OF_MANAGED_LEVEL')
        decision = dict(cell_id=cell['cell_id'], dominant_land_class=dominant,
                        water_fraction=counts.get(80, 0)/625,
                        dominant_land_fraction=counts.get(dominant, 0)/625,
                        boundary=boundary, flags=flags, landcover_fractions=fraction)
        for j, depth in enumerate(DEPTHS):
            obs = {p: observations[p, depth][i] for p in PROPERTIES}
            original_obs = dict(obs)
            # No-data replacement is an explicit v0.1 fallback, not inferred source data.
            fallback = (any(v is None or not math.isfinite(v) or v < 0 for v in obs.values())
                        or sum(obs[p] or 0 for p in ('sand', 'silt', 'clay')) <= 0)
            if fallback:
                obs = dict(sand=850., silt=100., clay=50., bdod=140., soc=100.)
                flags.append('SOILGAP_GENERIC_SAND_FALLBACK')
            texture = [obs[p]/10 for p in ('sand', 'silt', 'clay')]
            total = sum(texture)
            assert total > 0
            normalized = [v*100/total for v in texture]
            bd = obs['bdod']/100  # cg/cm3 -> g/cm3
            ptf_bd = bd if .5 <= bd <= 2. else 1.4
            if ptf_bd != bd:
                flags.append('PTF_BULK_DENSITY_FALLBACK_1P4')
            if obs['soc']/100 > 12:  # dg/kg -> percent C
                flags.append('HIGH_ORGANIC_C_MINERAL_PTF_EXTRAPOLATION')
            raw.append(dict(cell_id=cell['cell_id'], depth=depth, source_raw=original_obs, used_inputs_raw_units=obs,
                            raw_texture_sum_percent=total, normalization_factor=100/total,
                            source_bulk_density_g_cm3=bd, ptf_bulk_density_g_cm3=ptf_bd,
                            source_soc_percent=obs['soc']/100, explicit_fallback=fallback))
            features.append(normalized + [ptf_bd])
        decisions.append(decision)
    print('PEDOTRANSFER', len(features), flush=True)
    mean, spread, models = rosetta(3, features, estimate_type='geo')
    assert len(mean) == 4096*6
    shared = args.output / 'forcing'; shared.mkdir(exist_ok=True)
    previous = args.previous_root / 'results/wet_heath_scenarios'
    for name in ['hourly.met', 'kalmthout.rain']:
        shutil.copyfile(previous / 'forcing' / name, shared / name)
    template = (previous / 'wetheath_a1_r50_ic05_bot6/swap.swp').read_text()
    lai_file = args.previous_root / 'results/nhi_ecosystem_priors/selected/Basisdata/msw_templates/fact_svat.inp'
    fact_rows = [line.split() for line in lai_file.read_text().splitlines() if line.split()]
    lai = {index: [float(r[3]) for r in fact_rows if r[0] == str(index)] for index in (1, 5, 11, 14)}
    assert all(len(v) == 366 for v in lai.values())
    cases = args.output / 'cells'; cases.mkdir(exist_ok=True)
    geo = []
    for i, (cell, decision) in enumerate(zip(grid, decisions)):
        code = decision['dominant_land_class']
        if code == 80:
            decision.update(status='OPEN_WATER_NO_SOIL_COLUMN', native_model=None)
            continue
        veg = VEGETATION[code]
        path = cases / cell['cell_id']; path.mkdir(exist_ok=True)
        layers, hydraulic, grids = [], [], []
        for j, depth in enumerate(DEPTHS):
            k = 6*i+j
            tr, ts, alpha, n, ks, k0, le = map(float, mean[k])
            assert 0 <= tr < ts < 1 and n > 1 and alpha > 0 and ks > 0, (i, j, mean[k])
            top, bot = map(float, depth[:-2].split('-'))
            values = [tr, ts, alpha, alpha, n, .5, ks, ks, 0., features[k][3]*1000]
            layers.append(dict(**raw[k], top_cm=top, bottom_cm=bot, swap_mvg=values,
                               rosetta_version=3, rosetta_model=int(models[k]),
                               rosetta_geo=list(map(float, mean[k])), rosetta_spread_raw=list(map(float, spread[k]))))
            grids.append(f'{j+1} {j+1} {bot-top:.8f} {math.ceil((bot-top)/(1 if top < 15 else 5))}')
            hydraulic.append(' '.join(f'{v:.12e}' for v in values))
        bottom = 5 if code == 90 else 7
        text = template
        for key, value in [('PROJECT', "'"+cell['cell_id']+"'"), ('SWBOTB', str(bottom)), ('RDS', '200.0'),
                           ('SWCROP', '0' if code == 60 else '1')]:
            text = update(text, key, value)
        text = re.sub(r'( ISUBLAY ISOILLAY HSUBLAY NCOMP\n).*?(\* End of table)', lambda m:m[1]+'\n'.join(grids)+'\n'+m[2], text, flags=re.S)
        text = re.sub(r'( ORES\s+OSAT[^\n]*\n).*?(\* End of table)', lambda m:m[1]+'\n'.join(hydraulic)+'\n'+m[2], text, flags=re.S)
        text = re.sub(r'(?m)^ -106\.0 -75\.0$', ' -200.0 -75.0', text)
        if bottom == 5:
            # Bottom compartment midpoint 197.5cm; hydrostatic head for table 50cm below surface.
            text = re.sub(r'(      DATE5  HBOT5\n).*?(\* End of table)',
                          lambda m:m[1]+' 2024-01-01 147.5\n 2026-10-01 147.5\n'+m[2], text, flags=re.S)
        for year in (2024, 2025, 2026):
            if code == 60:
                continue
            crp = crop(lai[veg['nhi_index']], year, veg['root_cm'], .05)
            crp = crp.replace('* Historical wet-heath scenario; documented local observations and NHI priors.',
                              '* Initial regional land-cover analogue; explicit project priors, no WOFOST.')
            crp = crp.replace('4.000000000000e+01', f'{veg["height_cm"]:.12e}')
            crp = update(update(crp, 'RSC', f'{veg["rsc"]:.12e}'), 'ALBEDO', f'{veg["albedo"]:.12e}')
            (path / f'heath{year}.crp').write_text(crp)
        (path / 'swap.swp').write_text(text)
        for name in ('hourly.met', 'kalmthout.rain'):
            link = path / name
            if not link.exists():
                link.symlink_to(Path('../../forcing') / name)
        manifest = dict(cell=cell, **decision, vegetation=veg, layers=layers,
                        bottom_mode=bottom, status='PREPARED_INITIAL_V01', model='SWAP4.3.1',
                        native_model='SWAP_SIMPLE_CROP_NO_WOFOST',
                        source_manifest_sha256=sha(soils/'soilgrids_manifest.json'),
                        worldcover_region_sha256=sha(worldcover), lai_template_sha256=sha(lai_file),
                        ptf_contract='Rosetta3 model3 texture+bulk density; geometric estimates; Mualem lambda0.5 assumed; Ksat used in both SWAP conductivity fields.',
                        source_sampling='SoilGrids native pixel at target centre; WorldCover fractions from nearest 10m UTM raster. Not new independent measurements.',
                        local_improvements='Existing DOV/BWK, historical retention, groundwater, terrain and MODIS retained separately; not yet assimilated.')
        manifest['input_sha256'] = {p.name:sha(p) for p in path.iterdir() if p.suffix in ('.swp', '.crp', '.met', '.rain')}
        (path/'cell_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        decision.update(status='PREPARED_INITIAL_V01', native_model='SWAP_SIMPLE_CROP_NO_WOFOST')
    for cell, decision in zip(grid, decisions):
        x,y,X,Y = [cell[k] for k in ('xmin','ymin','xmax','ymax')]
        geo.append(dict(type='Feature', geometry=dict(type='Polygon', coordinates=[[[x,y],[X,y],[X,Y],[x,Y],[x,y]]]),
                        properties={**cell, **decision, 'flags': ';'.join(sorted(set(decision['flags']))) }))
    (args.output/'grid_250m.geojson').write_text(json.dumps(dict(type='FeatureCollection', crs=dict(type='name',properties=dict(name='urn:ogc:def:crs:EPSG::32631')), features=geo)))
    write_csv(args.output/'landcover_fractions.csv', fractions)
    write_csv(args.output/'cell_register.csv', [{**g, **{k:v for k,v in d.items() if k not in ('flags','landcover_fractions')},
                                                'flags': ';'.join(sorted(set(d['flags'])))} for g,d in zip(grid,decisions)])
    summary = dict(version='v0.1', grid_cells=len(grid), cell_size_m=250,
                   prepared_soil_columns=sum(d['status']=='PREPARED_INITIAL_V01' for d in decisions),
                   open_water_cells=sum(d['status']=='OPEN_WATER_NO_SOIL_COLUMN' for d in decisions),
                   native_runs_completed=0, domain_sha256=sha(args.domain),
                   soil_manifest_sha256=sha(soils/'soilgrids_manifest.json'),
                   worldcover_sha256=sha(worldcover), assumptions=VEGETATION,
                   classification_counts={str(k): sum(d['dominant_land_class']==k for d in decisions) for k in sorted({d['dominant_land_class'] for d in decisions})},
                   boundary_counts={k:sum(d['boundary']==k for d in decisions) for k in sorted({d['boundary'] for d in decisions})},
                   execution_status='INPUTS_PREPARED_NOT_EXECUTED',
                   boundary_policy='Default free drainage; mapped herbaceous wetlands fixed bottom head at groundwater depth50cm as explicit alternative prior. No managed-polder claim and no lateral surface-water exchange yet.')
    (args.output/'baseline250_receipt.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary,indent=2))


if __name__ == '__main__':
    main()
