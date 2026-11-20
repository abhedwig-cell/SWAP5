"""Independently inspect original successful controls-only portable artifacts."""
import argparse
import json
from pathlib import Path

from ordinary_pond_evidence import read,digest,require
from groundwater_clock_archive import unpack
from groundwater_clock_control_forensics import native_controls,source_controls,postimages
from groundwater_clock_custody import audit as custody


def audit_root(root,original):
    root=Path(root);original=Path(original)
    projection=read(root/'COMPILED_PROJECTION_V1.json');profiles={};bundles={}
    origin=read(root/'ORIGINAL_DEPENDENCY_V1.json')
    require(origin['original_run']==44682712004 and origin['original_source']=='5c0e2b34358940e02ae6f486f04e0f262df1c040' and
            origin['original_receipts_rebound'] is False and origin['fresh_model_periods']==0,'Original control dependency rebound')
    for name,item in origin['restored'].items():
        profile=original/'groundwater-clock'/name;q=read(profile/'RESULT.json');compiled=projection[q['build_root']]
        bundle=root/compiled['archive_prefix']
        require(digest(bundle/'BUILD.json')==compiled['actual_BUILD_sha256']==item['actual_BUILD_sha256'] and
                digest(profile/'RESULT.json')==item['actual_profile_receipt_sha256'],'Original actual bundle/receipt differs')
        profiles[name]=profile;bundles[name]=bundle
    results={}
    for name in ('h2-periodic','h1-step-explicit','h0-step-periodic'):
        results[name]=native_controls(root/'controls'/name,profiles[name],bundles[name])
    for name in ('h2-periodic','h0-step-periodic','h1-explicit-monthly'):
        results['source-'+name]=source_controls(root/'source-controls'/name,bundles[name])
    current=postimages(root/'postimages',profiles,bundles);require(current['actual_cold_windows']==4,'Actual current portable postimage denominator differs')
    sources=custody(root,4)
    return dict(controls=results,postimages=current,source_custody=sources,original_dependency=origin)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('archive','artifacts','extract','original-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--artifact-id',type=int,required=True);a=p.parse_args()
    require(not a.output.exists(),'Refuse overwriting actual control archive observation')
    record=next(v for v in read(a.artifacts)['artifacts'] if v['id']==a.artifact_id)
    root,members=unpack(a.archive,record,a.extract)
    original=a.original_root
    if __import__('os').name=='nt':original=Path('\\\\?\\'+str(original.resolve()))
    observed=audit_root(root,original)
    out=dict(status='ORIGINAL_PORTABLE_CURRENT_GROUNDWATER_CLOCK_CONTROLS_INDEPENDENT_PASS',
        origin_run=44686532162,origin_source='f964e80a1db329c0d3440e894fe2810c4208064b',
        original_archive=a.archive.name,sha256=digest(a.archive),artifact=record,members=members,
        **observed,
        whole_job_conclusion='success',repeated_model_periods=0,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    a.output.write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(out['status'])


if __name__=='__main__':main()
