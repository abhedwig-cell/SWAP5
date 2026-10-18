#!/usr/bin/env python3
"""Prepare an explicit local vegetation-only delta on the common v0.1 model.

Soil, initial condition, meteorology, lower boundary and numerics remain identical.
Only mapped majority-heath cells receive the already documented NHI heath prior.
The parent full grid plus these overrides defines the candidate next version.
"""
import argparse
import csv
import json
from pathlib import Path
import shutil

from collect_european_baseline import sha
from run_wet_heath_scenarios import crop


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline',type=Path);p.add_argument('refinement',type=Path)
    p.add_argument('previous_root',type=Path);p.add_argument('output',type=Path)
    p.add_argument('--corine',type=Path,help='Add common-European CLC322 majority-heath candidates, without deleting the local source attribution')
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    candidates={r['cell_id']:r for r in csv.DictReader((args.refinement/'heath_refinement_register.csv').open())
                if r['proposed_vegetation_refinement']=='NHI_HEATH_ANALOGUE'}
    local_ids=set(candidates);common_ids=set();common_rows={}
    if args.corine:
        for r in csv.DictReader((args.corine/'corine_cell_context.csv').open()):
            if float(r['corine_heath322_fraction'])>=.5:
                common_ids.add(r['cell_id'])
                common_rows[r['cell_id']]=r
                if r['cell_id'] not in candidates:candidates[r['cell_id']]=dict(r,source='CORINE2018 common-European class322')
    grid=list(csv.DictReader((args.baseline/'cell_register.csv').open()))
    selected=[r for r in grid if r['cell_id'] in candidates]
    fact=args.previous_root/'results/nhi_ecosystem_priors/selected/Basisdata/msw_templates/fact_svat.inp'
    values=[float(row[3]) for line in fact.read_text().splitlines() if (row:=line.split()) and row[0]=='14']
    assert len(values)==366
    texts={year:crop(values,year,50.,.05).replace('* Historical wet-heath scenario; documented local observations and NHI priors.',
                  '* Mapped-heath vegetation analogue; soil and boundary inherited from the common parent, no local calibration.') for year in (2024,2025,2026)}
    forcing=args.output/'forcing';forcing.mkdir(exist_ok=True)
    for name in ('hourly.met','kalmthout.rain'):shutil.copyfile(args.baseline/'forcing'/name,forcing/name)
    result=[]
    for cell in selected:
        identity=cell['cell_id'];source=args.baseline/'cells'/identity;target=args.output/'cells'/identity
        target.mkdir(parents=True,exist_ok=True)
        contract=json.loads((source/'cell_manifest.json').read_text())
        shutil.copyfile(source/'swap.swp',target/'swap.swp')
        for year,text in texts.items():(target/f'heath{year}.crp').write_text(text)
        for name in ('hourly.met','kalmthout.rain'):
            link=target/name
            if not link.exists():link.symlink_to(Path('../../forcing')/name)
        contract['parent_model_version']='BASELINE250-v01'
        contract['parent_cell_manifest_sha256']=sha(source/'cell_manifest.json')
        contract['parent_native_swp_sha256']=sha(source/'swap.swp')
        contract['original_worldcover_class']=contract['dominant_land_class']
        contract['dominant_land_class']=20
        contract['vegetation']=dict(name='local_mapped_heath_NHI_analogue',nhi_index=14,root_cm=50.,height_cm=40.,rsc=288.84,albedo=.3)
        contract['lai_approximation']=dict(method='Original NHI366-day heath curve with native compression within0.05m2/m2; no13-anchor smoothing')
        contract['refinement_source']=candidates[identity]
        contract['refinement_membership']=dict(corine_common_heath=identity in common_ids,bwk_local_heath=identity in local_ids)
        contract['corine_source_context']=common_rows.get(identity)
        contract['refinement_contract']='Vegetation-only candidate. Wet-heath flags do not automatically change groundwater. Underlying soil and all boundaries remain parent v01.'
        contract['flags'].append('LOCAL_HABITAT_VEGETATION_REFINEMENT_UNCALIBRATED')
        contract['input_sha256']={p.name:sha(p) for p in target.iterdir() if p.suffix in ('.swp','.crp','.met','.rain')}
        assert contract['input_sha256']['swap.swp']==contract['parent_native_swp_sha256']
        (target/'cell_manifest.json').write_text(json.dumps(contract,indent=2)+'\n')
        r=dict(cell);r['dominant_land_class']='20';r['status']='PREPARED_INITIAL_V01';r['flags']+=';LOCAL_HABITAT_VEGETATION_REFINEMENT_UNCALIBRATED'
        result.append(r)
    with (args.output/'cell_register.csv').open('w',newline='') as handle:
        w=csv.DictWriter(handle,fieldnames=list(result[0]));w.writeheader();w.writerows(result)
    receipt=dict(version='BASELINE250-v02-VEGETATION-CANDIDATE',parent_grid_cells=len(grid),
                 vegetation_override_cells=len(result),unchanged_parent_cells=len(grid)-len(result),
                 common_corine_heath_cells=len(common_ids),local_bwk_heath_cells=len(local_ids),
                 overlap_cells=len(common_ids&local_ids),local_additional_cells=len(local_ids-common_ids),
                 native_runs_completed=0,change='Only LAI, height, stomatal resistance, albedo androot depth are replaced by documented NHI heath priors in mapped majority-heath cells.',
                 unchanged='All parent native SWP bytes, soil, forcing, lower boundaries, initial states and numerical settings.',
                 lai_source_sha256=sha(fact),refinement_register_sha256=sha(args.refinement/'heath_refinement_register.csv'),
                 corine_manifest_sha256=sha(args.corine/'corine_context_manifest.json') if args.corine else None,
                 groundwater='62 mapped majority-wet-heath cells remain a separate review task; no fake measured water-table boundary.',
                 scope='Local improvement candidate, not calibrated or observed flux validation.')
    (args.output/'vegetation_variant_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))


if __name__=='__main__':main()
