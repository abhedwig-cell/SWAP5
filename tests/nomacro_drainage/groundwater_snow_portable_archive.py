"""Decode original portable interval/drainage artifacts without model execution."""
import argparse
import json
from pathlib import Path

from ordinary_pond_evidence import read,digest,require
from groundwater_clock_archive import unpack
from groundwater_snow_forensics import audit
from groundwater_snow_custody import audit as custody
from groundwater_snow_control_forensics import native_controls,source_controls


def audit_root(root):
    root=Path(root);projection=read(root/'COMPILED_PROJECTION_V1.json')
    def bundle(q):
        item=projection[q['build_root']];path=root/item['archive_prefix']
        require(digest(path/'BUILD.json')==item['actual_BUILD_sha256'],'Actual interval compiled projection differs')
        return path
    cohort=root/'groundwater-snow';q=read(cohort/'RESULT.json')
    require(q['status']=='ACTUAL_SEVEN_EXPLICIT_SNOW_GROUNDWATER_CDE_CONTEXTS_PASS' and len(q['cases'])==7,
            'Actual portable eight-case composition incomplete')
    shorts={};builds={}
    for name in q['cases']:
        profile=cohort/name;builds[name]=bundle(read(profile/'RESULT.json'))
        shorts[name]=audit(profile,builds[name],profile/'input')
    full=root/'groundwater-snow-full'
    full_observed=audit(full,bundle(read(full/'RESULT.json')),cohort/'h2-snow-clock-periodic/input')
    controls=read(root/'control-cohort/RESULT.json')
    require(controls['status']=='ACTUAL_FOUR_NATIVE_THREE_SOURCE_SNOW_GROUNDWATER_CONTEXTS_PASS' and
            len(controls['native'])==4 and len(controls['source_controls'])==3,'Actual portable control cohort incomplete')
    native={};source={}
    for name,item in controls['native'].items():
        native[name]=native_controls(root/Path(item['actual_root']).name,cohort/name,builds[name])
    for name,item in controls['source_controls'].items():
        source[name]=source_controls(root/Path(item['actual_root']).name,builds[name])
    origins=custody(root)
    require(sum(v['actual_refusals'] for v in native.values())==430 and
            sum(v['actual_refusals'] for v in source.values())==86,'Actual portable refusal denominator differs')
    return dict(status='INDEPENDENT_ORIGINAL_PORTABLE_SNOW_GROUNDWATER_SCIENCE_CONTROLS_PASS',
                short=shorts,full=full_observed,native=native,source_controls=source,source_custody=origins,
                actual_short_contexts=7,actual_short_cold_windows=sum(v['actual_cold_windows'] for v in shorts.values()),
                actual_full_periods=1,actual_full_cold_windows=9,actual_native_refusals=430,
                actual_source_policy_refusals=86,actual_transaction_contexts=4,fresh_model_executions=0)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('archive','artifacts','extract','output','run'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--artifact-id',type=int,required=True);args=p.parse_args()
    record=next(v for v in read(args.artifacts)['artifacts'] if v['id']==args.artifact_id)
    require(not args.output.exists(),'Refuse overwriting original portable observation')
    root,members=unpack(args.archive,record,args.extract);observed=audit_root(root)
    run=read(args.run);require(run['conclusion']=='success' and observed['source_custody']['producer_source']==run['head_sha'],'Actual portable source/run not successful')
    out=dict(**observed,origin_run=run['id'],origin_source=run['head_sha'],
             original_archive=args.archive.name,sha256=digest(args.archive),artifact=record,members=members,
             whole_job_conclusion='SUCCESS',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    with args.output.open('x',encoding='utf-8') as f:json.dump(out,f,indent=2)
    print(out['status'])


if __name__=='__main__':main()
