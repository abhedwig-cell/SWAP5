"""Read original portable Snow bytes through explicit location projections."""
from pathlib import Path

from ordinary_pond_evidence import read,digest,require
from snow_undrained_forensics import audit
from snow_undrained_custody import audit as custody
from snow_undrained_component_forensics import audit as component
from snow_undrained_control_forensics import audit as native_controls,source_controls,transactions

SOURCE='2934c78b9e5ae5893cf8cdd42e040a5496cb538e'


def audit_root(root):
    root=Path(root);cohort=root/'snow-undrained';result=read(cohort/'RESULT.json')
    require(result['status']=='ACTUAL_PORTABLE_NINE_SNOW_UNDRAINED_CONFIGURATIONS_AND_BOUNDED_CDE_COMPONENT_PASS' and
        result['source']==SOURCE and all(v['status']=='PASS' for v in result['steps']),
        'Original portable Snow qualification incomplete')
    projection=read(root/'COMPILED_PROJECTION_V1.json');require(len(projection)==9,'Actual compiler projection denominator differs')
    def mapped(path):
        normalized=str(path).replace('\\','/');require('/proof/' in normalized,'Foreign portable evidence location')
        relative=normalized.split('/proof/',1)[1]
        require('..' not in Path(relative).parts and not Path(relative).is_absolute(),'Foreign portable relative location')
        return root/relative
    def locations(profile):
        q=read(profile/'RESULT.json');entry=projection[q['build_root']];bundle=root/entry['archive_prefix']
        require(digest(bundle/'BUILD.json')==entry['actual_BUILD_sha256'],'Original portable BUILD projection differs')
        return bundle,mapped(q['input_root']),mapped(q['trajectory_root']),[mapped(p) for p in q['cold_actual_roots']]
    short={};full={};builds=[];shortpaths={}
    cases=read(cohort/'source-forms/RESULT.json')['cases'];require(len(cases)==9,'Original portable source case denominator differs')
    for label in cases:
        profile=cohort/'short'/label;b,i,w,c=locations(profile)
        short[label]=audit(profile,b,i,w,c);builds.append(b);shortpaths[label]=(profile,b,i,w)
    representatives=('water-explicit-flux-daily','water-implicit-head-clock','cde-explicit-flux-interval','cde-implicit-head-clock-positive')
    for label in representatives:
        profile=cohort/'full'/label;b,i,w,c=locations(profile);full[label]=audit(profile,b,i,w,c)
    cap=read(root/'source/RESULT.json');external=cap['members']['app/hybrid_water/daily_coupling.py']['sha256']
    native={};forged={};trans={}
    for label in ('water-explicit-flux-daily','cde-implicit-head-clock-positive'):
        profile,b,i,w=shortpaths[label]
        native[label]=native_controls(cohort/('native-controls-'+label),profile,b,i,w)
        forged[label]=source_controls(cohort/('source-controls-'+label),b)
        trans[label]=transactions(cohort/('transactions-'+label),profile,b,i,external,w)
    source=custody(root,builds);small=component(cohort/'cde-component',read(root/'provider-PREPARED.json'))
    require(all(v['actual_days']==35 and v['actual_cold_windows']==3 for v in short.values()) and
        all(v['actual_days']==1096 and v['actual_cold_windows']==9 for v in full.values()),'Actual portable period denominator differs')
    return dict(status='INDEPENDENT_ORIGINAL_PORTABLE_NINE_SNOW_UNDRAINED_CONFIGURATIONS_PASS',short=short,full=full,
        native=native,source_controls=forged,transactions=trans,source_custody=source,original_cde_component=small,
        actual_short_contexts=9,actual_short_cold_windows=27,actual_full_periods=4,actual_full_cold_windows=36,
        actual_compiled_refusals=50,actual_source_refusals=36,actual_transaction_contexts=2,model_executions=0,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
