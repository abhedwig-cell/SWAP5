"""Read original failed and successful repair artifacts without rebinding."""
import hashlib
import json
from pathlib import Path

from ordinary_pond_evidence import read,digest,require,rows
from water_snow_groundwater_forensics import audit
from water_snow_groundwater_custody import audit as custody
from water_snow_groundwater_control_forensics import audit as native_controls,source_controls,transactions

AFFECTED={'explicit-h0-daily','explicit-h1-interval-off','implicit-h0-interval-off','implicit-h2-daily'}


def audit_root(original,current):
    original,current=Path(original),Path(current);initial=original/'water-snow-groundwater';cohort=current/'recovery'
    failed=read(initial/'RESULT.json');result=read(cohort/'RESULT.json')
    require(failed['status']=='FAILED_OR_CENSORED' and failed['source']=='53f9ede58285c77f5fe34d4120dbfab709b41488' and
        len(failed['steps'])==2 and failed['steps'][0]['status']=='PASS' and failed['steps'][1]['label']=='short-explicit-h0-daily' and
        result['status']=='ACTUAL_WATER_SNOW_GROUNDWATER_DAY_TAIL_REPAIR_PORTABLE_PASS' and
        result['original_failed_producer_sha256']==digest(initial/'RESULT.json') and result['original_failed_jobs_preserved'] is True,
        'Actual original failed producer or repair role differs')
    rejected=rows(initial/'short-explicit-h0-daily/trajectory')
    require(len(rejected)==25 and all(r['committed'] for r in rejected[:24]) and rejected[-1]['day']==25 and
        rejected[-1]['committed'] is False and abs(rejected[-1]['kernel_residual_cm'])>1e-10,
        'Actual original day25 numerical refusal missing')
    require(set(result['affected_day_tail_contexts'])==AFFECTED and result['fresh_unaffected_compilations']==result['fresh_unaffected_full_replays']==0,
        'Actual targeted repair dependency denominator differs')
    old_projection=read(original/'COMPILED_PROJECTION_V1.json');projection=read(current/'COMPILED_PROJECTION_V1.json')
    require(len(old_projection)==9 and len(projection)==13,'Actual original/current compiler projection denominator differs')
    for actual,entry in old_projection.items():
        old=original/entry['archive_prefix'];preserved=current/projection[actual]['archive_prefix']
        require(digest(old/'BUILD.json')==entry['actual_BUILD_sha256']==digest(preserved/'BUILD.json'),'Original BUILD rebound during repair')
        for p in old.iterdir():
            if p.is_file():require((preserved/p.name).is_file() and digest(p)==digest(preserved/p.name),'Original actual compiled bytes changed')
    def mapped(path):
        normalized=str(path).replace('\\','/')
        for marker,root in (('/proof-current/',current),('/proof/',original)):
            if marker in normalized:return root/normalized.split(marker,1)[1]
        raise ValueError('Foreign portable original evidence location')
    def locations(profile):
        r=read(profile/'RESULT.json');entry=projection[r['build_root']];b=current/entry['archive_prefix']
        require(digest(b/'BUILD.json')==entry['actual_BUILD_sha256'],'Actual portable selected BUILD projection differs')
        return b,mapped(r['input_root']),mapped(r['trajectory_root']),[mapped(p) for p in r['cold_actual_roots']]
    shorts={};fulls={};builds=[];shortpaths={}
    require(len(result['actual_short_profiles'])==9 and all(s['status']=='PASS' for s in result['steps']),
        'Actual coherent repair qualification incomplete')
    for label,path in result['actual_short_profiles'].items():
        profile=mapped(path);b,i,w,c=locations(profile);shorts[label]=audit(profile,b,i,w,c);builds.append(b);shortpaths[label]=(profile,b,i,w)
    for label in ('explicit-h2-clock','implicit-h1-step-reset','explicit-h0-daily'):
        profile=cohort/('full-'+label);b,i,w,c=locations(profile);fulls[label]=audit(profile,b,i,w,c)
    source=custody(current,builds);cap=read(current/'source/RESULT.json')
    external=cap['members']['app/hybrid_water/daily_coupling.py']['sha256'];native={};forged={};trans={}
    for label in ('explicit-h0-daily','implicit-h1-step-reset'):
        profile,b,i,w=shortpaths[label]
        native[label]=native_controls(cohort/('native-controls-'+label),profile,b,i,w)
        forged[label]=source_controls(cohort/('source-controls-'+label),b)
        trans[label]=transactions(cohort/('transactions-'+label),profile,b,i,external,w)
    require(all(v['actual_days']==35 and v['actual_cold_windows']==3 for v in shorts.values()) and
        all(v['actual_days']==1096 and v['actual_cold_windows']==9 for v in fulls.values()),'Actual portable science denominator differs')
    repaired=rows(cohort/'short-explicit-h0-daily/trajectory')[24]
    require(repaired['committed'] and abs(repaired['kernel_residual_cm'])<=1e-10 and abs(repaired['independent_residual_cm'])<=1e-10,
        'Actual original day25 problem not repaired')
    return dict(status='INDEPENDENT_ORIGINAL_PORTABLE_WATER_SNOW_GROUNDWATER_REPAIR_PASS',short=shorts,full=fulls,
        native=native,source_controls=forged,transactions=trans,source_custody=source,
        actual_short_contexts=9,actual_short_cold_windows=27,actual_full_periods=3,actual_full_cold_windows=27,
        actual_compiled_refusals=130,actual_source_refusals=32,actual_transaction_contexts=2,
        original_day25_refusal_preserved=True,repaired_day25_kernel_residual_cm=repaired['kernel_residual_cm'],
        original_failed_producers_preserved=True,fresh_unaffected_compilations=0,model_executions=0,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
