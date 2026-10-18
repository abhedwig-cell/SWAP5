#!/usr/bin/env python3
"""Compare common land cover to exact 250m intersections of received BWK habitat.

This prepares a local improvement register; it never edits running v0.1 models.
Mapped percentages are assumed uniform inside a polygon for this first overlay.
Unresolved compound fields retain lower/upper heath fractions, not fake precision.
"""
import argparse
import csv
import json
from pathlib import Path
import re

from shapely import STRtree, box, make_valid, union_all
from shapely.geometry import shape
from collect_european_baseline import sha

HEATH={'2310','4010','4030'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('baseline',type=Path);p.add_argument('output',type=Path)
    p.add_argument('bwk',nargs='+',type=Path)
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    features=[];seen=set()
    for path in args.bwk:
        data=json.loads(path.read_text());assert data['crs']['properties']['name'].endswith('32631')
        for f in data['features']:
            assert f['id'] not in seen;seen.add(f['id'])
            props=f['properties'];lower=upper=wet=0.;slots=[];total=0.
            for i in range(1,6):
                text=str(props.get(f'HAB{i}') or '').strip();fraction=float(props.get(f'PHAB{i}') or 0)/100
                assert 0<=fraction<=1
                total+=fraction
                if not text or fraction==0:continue
                tokens=[t.strip() for t in re.split('[,+/]',text) if t.strip()]
                codes=[re.match(r'^(2310|4010|4030)[a-zA-Z_]*$',t) for t in tokens]
                certain=bool(tokens) and all(codes)
                possible=bool(re.search(r'(?<!\d)(2310|4010|4030)(?!\d)',text))
                if possible:upper+=fraction
                if certain:
                    lower+=fraction
                    if all(m.group(1)=='4010' for m in codes):wet+=fraction
                slots.append(dict(field=f'HAB{i}',value=text,percentage=100*fraction,
                                  exclusively_heath=certain,possibly_heath=possible))
            # An internally inconsistent attribute allocation is not promoted.
            invalid=total>1+1e-9
            if invalid:lower=wet=0.;upper=min(upper,1.)
            geom=shape(f['geometry']);geom=make_valid(geom) if not geom.is_valid else geom
            features.append((geom,f['id'],lower,upper,wet,slots,invalid))
    tree=STRtree([f[0] for f in features]);rows=[];evidence=[]
    for cell in csv.DictReader((args.baseline/'cell_register.csv').open()):
        geom=box(*[float(cell[k]) for k in ['xmin','ymin','xmax','ymax']]);pieces=[]
        lower=upper=wet=area_sum=0.;references=[]
        for k in tree.query(geom,predicate='intersects'):
            g,identity,lo,hi,w,slots,invalid=features[k]
            part=g.intersection(geom);a=part.area
            if a<=1e-6:continue
            pieces.append(part);area_sum+=a
            lower+=a*lo;upper+=a*hi;wet+=a*w
            if hi:
                references.append(identity)
                evidence.append(dict(cell_id=cell['cell_id'],source_feature_id=identity,intersection_area_m2=a,
                                     habitat_slots=slots,inconsistent_percentage_sum=invalid))
        coverage=union_all(pieces).area/geom.area if pieces else 0.
        overlap=area_sum/geom.area-coverage
        lo,hi,w=lower/geom.area,upper/geom.area,wet/geom.area
        candidate=lo>=.5 and overlap<=.001 and lo<=1.001
        rows.append(dict(cell_id=cell['cell_id'],baseline_land_class=cell['dominant_land_class'],
                         bwk_coverage_fraction=coverage,bwk_overlap_fraction=overlap,
                         heath_fraction_lower=lo,heath_fraction_upper=hi,wet_heath_fraction_lower=w,
                         proposed_vegetation_refinement='NHI_HEATH_ANALOGUE' if candidate else 'KEEP_BASELINE',
                         proposed_boundary_action='SHALLOW_GROUNDWATER_REVIEW' if w>=.5 else 'KEEP_BASELINE_BOUNDARY',
                         source_ids=';'.join(references)))
    with (args.output/'heath_refinement_register.csv').open('w',newline='') as h:
        writer=csv.DictWriter(h,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    (args.output/'heath_overlay_evidence.json').write_text(json.dumps(evidence,indent=2)+'\n')
    summary=dict(total_baseline_cells=len(rows),
                 majority_heath_candidates=sum(r['proposed_vegetation_refinement']=='NHI_HEATH_ANALOGUE' for r in rows),
                 majority_wet_heath_review_cells=sum(r['wet_heath_fraction_lower']>=.5 for r in rows),
                 source_polygons=len(features),source_sha256={p.name:sha(p) for p in args.bwk},
                 source_interpretation='2310 duinheide,4010 vochtige/natte heide,4030 droge heide; known compound non-heath mixtures retain bounds.',
                 percentage_contract='Mapped habitat percentages assumed uniform inside polygons; bounds represent unresolved class mixtures, not probabilistic uncertainty.',
                 source_landing='https://natura2000.vlaanderen.be/gebied/kalmthoutse-heide',
                 baseline_inputs_edited=False,local_refined_native_runs=0)
    (args.output/'heath_refinement_receipt.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))


if __name__=='__main__':main()
