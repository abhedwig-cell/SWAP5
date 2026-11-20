"""Decode original portable interval/drainage artifacts without model execution."""
import argparse
import json
from pathlib import Path

from ordinary_pond_evidence import read,digest,require
from groundwater_clock_archive import unpack
from groundwater_interval_forensics import audit
from groundwater_interval_custody import audit as custody
from groundwater_interval_control_forensics import native_controls,source_controls


def audit_root(root):
    root=Path(root);projection=read(root/'COMPILED_PROJECTION_V1.json')
    def bundle(q):
        item=projection[q['build_root']];path=root/item['archive_prefix']
        require(digest(path/'BUILD.json')==item['actual_BUILD_sha256'],'Actual interval compiled projection differs')
        return path
    cohort=root/'groundwater-interval';q=read(cohort/'RESULT.json')
    require(q['status']=='ACTUAL_GROUNDWATER_CDE_INTERVAL_DRAINAGE_COMPOSITION_COHORT_PASS' and len(q['cases'])==8,
            'Actual portable eight-case composition incomplete')
    shorts={};builds={}
    for name in q['cases']:
        profile=cohort/name;builds[name]=bundle(read(profile/'RESULT.json'))
        shorts[name]=audit(profile,builds[name],profile/'input')
    full=root/'groundwater-interval-full'
    full_observed=audit(full,bundle(read(full/'RESULT.json')),cohort/'h0-interval-monthly-off/input')
    controls=read(root/'control-cohort/RESULT.json')
    require(controls['status']=='ACTUAL_FOUR_NATIVE_THREE_SOURCE_COMPOSITION_CONTEXTS_PASS' and
            len(controls['native'])==4 and len(controls['source_controls'])==3,'Actual portable control cohort incomplete')
    native={};source={}
    for name,item in controls['native'].items():
        native[name]=native_controls(root/Path(item['actual_root']).name,cohort/name,builds[name])
    for name,item in controls['source_controls'].items():
        source[name]=source_controls(root/Path(item['actual_root']).name,builds[name])
    origins=custody(root)
    require(sum(v['actual_refusals'] for v in native.values())==321 and
            sum(v['actual_refusals'] for v in source.values())==28,'Actual portable refusal denominator differs')
    return dict(status='INDEPENDENT_ORIGINAL_PORTABLE_INTERVAL_DRAINAGE_SCIENCE_CONTROLS_PASS',
                short=shorts,full=full_observed,native=native,source_controls=source,source_custody=origins,
                actual_short_contexts=8,actual_short_cold_windows=sum(v['actual_cold_windows'] for v in shorts.values()),
                actual_full_periods=1,actual_full_cold_windows=8,actual_native_refusals=321,
                actual_source_policy_refusals=28,actual_transaction_contexts=4,fresh_model_executions=0)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('archive','artifacts','extract','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--artifact-id',type=int,required=True);args=p.parse_args()
    record=next(v for v in read(args.artifacts)['artifacts'] if v['id']==args.artifact_id)
    require(not args.output.exists(),'Refuse overwriting original portable observation')
    root,members=unpack(args.archive,record,args.extract);observed=audit_root(root)
    out=dict(**observed,origin_run=44692527051,origin_source='a55d62b16b8dfb6581a7e0b50ee774a07d82751e',
             original_archive=args.archive.name,sha256=digest(args.archive),artifact=record,members=members,
             whole_job_conclusion='SUCCESS',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    with args.output.open('x',encoding='utf-8') as f:json.dump(out,f,indent=2)
    print(out['status'])


if __name__=='__main__':main()
