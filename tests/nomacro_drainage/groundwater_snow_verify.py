"""Bounded explicit Snow groundwater CDE source and original raw admission owner."""
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import groundwater_snow_science as science

PARENT='3baf8a05786af8635e60b4df8518c77ff3f8eeb2'
RUNTIME='8b8536033f1f260ff13d76f3b66cc1f4ccf7c4b0'
NUMERIC=RUNTIME
READERS='35f85e8efd49d18e7575f71f3d41725012dc7b87'
SEALED='eeb8720b3f3e821e57e5842deb6f3a52d8e24a21'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/GROUNDWATER_SNOW_CDE_QUALIFICATION.json'
OLD='tests/nomacro_drainage/groundwater_interval_verify.py'
GUARD_HOOK='    import groundwater_snow_verify as groundwater_snow\n    return groundwater_snow.guard_previous_source()\n'
VERIFY_HOOK='    import groundwater_snow_verify as groundwater_snow\n    return groundwater_snow.verify()\n'
PROJECTION_HOOK='    import groundwater_snow_verify as groundwater_snow\n    text=groundwater_snow.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/GROUNDWATER_SNOW_CDE_*\n'
PARSERS=('groundwater_snow_science.py','groundwater_snow_forensics.py',
         'groundwater_snow_custody.py','groundwater_snow_control_forensics.py',
         'groundwater_snow_portable_archive.py','groundwater_snow_archive_storage.py','groundwater_snow_parent_bridge.json')
COUNTS=dict(actual_full_periods=4,actual_days_per_full_period=1096,actual_full_cold_windows=36,
            actual_short_contexts=28,actual_short_cold_windows=88,actual_native_refusals=1720,
            actual_compiled_refusals=1716,actual_accepted_receipt_refusals=4,
            actual_transaction_contexts=16,actual_source_policy_refusals=344,
            actual_nonselected_CDE_contexts=6,actual_nonselected_CDE_cold_windows=6)


def strip_current_evidence(text):
    import implicit_snow_verify as implicit_snow
    text=implicit_snow.strip_current_evidence(text)
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous explicit Snow groundwater scientific checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    import implicit_snow_verify as implicit_snow
    return implicit_snow.guard_previous_source()
    require(not git('diff',RUNTIME,'--',*SURFACES),
            'Actual explicit Snow groundwater compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('groundwater_snow_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign groundwater source bridge')
    expected=['app/hybrid_water/'+name for name in ('cde_clock_output.py','cde_interval_output.py',
        'daily_coupling.py','groundwater_cde_clock.py','groundwater_cde_interval.py','groundwater_snow_cde.py',
        'groundwater_snow_cde_source_guard.py','groundwater_snow_clock.py','groundwater_snow_retry.py')]
    require(git('diff','--name-only',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()==expected,
            'Unexpected Snow groundwater physical/state dependency changed')
    added={'app/hybrid_water/'+name for name in ('groundwater_snow_cde.py','groundwater_snow_cde_source_guard.py',
                                                'groundwater_snow_clock.py','groundwater_snow_retry.py')}
    require(set(bridge['changes'])==set(expected)-added and set(bridge['added'])==added,'Incomplete exact Snow parent bridge')
    for path,changes in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(changes):
            index=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[index:index+len(after)]==after,'Actual Snow source bridge differs')
            lines[index:index+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Original parent source body changed')
    for name in ('age_groundwater_output.py','groundwater_native_state.f90','groundwater_history_native_state.f90',
        'cde_interval_output_state.f90','thermal_output_clock.py','thermal_output_step.py',
        'implicit_conductivity_retry.py','implicit_pond_event.py','implicit_pond_event_state.f90',
        'implicit_pond_availability.py','implicit_pond_availability.f90'):
        path='app/hybrid_water/'+name
        require(blob(PARENT,path)==blob(RUNTIME,path),'Original qualified physical/numerical/native provider changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen groundwater observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous groundwater owner delegation')
        old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier groundwater clock scientific/source body changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines()) & existing
    require(changed=={OLD},'Earlier actual scientific/source observer changed beyond exact delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),
                'Registered CI commands/source/limits changed beyond groundwater proof checkout')
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral groundwater qualification changed')
    q=json.loads(raw)
    require(q['status']=='NEUTRAL_GROUNDWATER_SNOW_CDE_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
            (q['runtime'],q['numeric_runtime'],q['predecessor'],q['independent_readers'])==
            (RUNTIME,NUMERIC,PARENT,READERS),'Foreign neutral groundwater authority')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
            q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and
            q['AGE_admitted'] is False and q['groundwater_snow_admitted'] is False and
            q['new_physical_state'] is False,'Whole historical/AGE/release authority promoted')
    require(all(q[k]==v for k,v in COUNTS.items()) and len(q['archives'])==7,'Neutral groundwater denominator differs')
    require(q['daily_water_guard_cm']==q['integrated_water_guard_cm']==q['daily_CDE_guard_mg_cm2']==q['integrated_CDE_guard_mg_cm2']==1e-10,
            'Scientific balance guard changed')
    return q


def archive_identity(item,label):
    import hashlib
    raw=(PROOF/item['record']).read_bytes()
    require(sha(norm(raw))==item['record_lf_sha256'],'Original Snow archive provenance changed: '+label)
    record=json.loads(raw);combined=hashlib.sha256();total=0
    parts=record.get('parts') or [dict(file=record['archive'],bytes=record['bytes'],sha256=record['sha256'])]
    for index,part in enumerate(parts,1):
        expected=record['archive'] if len(parts)==1 else record['archive']+f'.part{index:03d}'
        require(part['file']==expected and Path(expected).name==expected,'Foreign original archive part: '+label)
        path=PROOF/expected;part_hash=hashlib.sha256();size=0
        require(path.is_file(),'Missing actual original Snow raw: '+label)
        with path.open('rb') as source:
            while raw:=source.read(1024*1024):combined.update(raw);part_hash.update(raw);size+=len(raw)
        require(size==part['bytes'] and part_hash.hexdigest()==part['sha256'],'Changed actual original Snow raw: '+label)
        total+=size
    require(total==record['bytes'] and combined.hexdigest()==record['sha256'],'Changed actual original Snow ZIP bytes: '+label)


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    for label,item in q['archives'].items():archive_identity(item,label)
    require(sha(norm((PROOF/'GROUNDWATER_SNOW_CDE_NONSELECTED_BASELINES_V1.json').read_bytes()))==q['baseline_lf_sha256'],
            'Actual Snow unselected baseline changed')
    import groundwater_interval_verify as previous
    previous.source()
    return True


def inherited():
    import groundwater_interval_verify as prior
    retained=prior.inherited()
    path=PROOF/'GROUNDWATER_CDE_INTERVAL_ADMISSION_RAW_V1.zip';manifest=read(path.with_suffix('.json'))
    require(path.stat().st_size==manifest['bytes'] and digest(path)==manifest['sha256']==
            '874519cf85f99e8e7ab8f1c3c1146f38ab19d14aa46d2dc42ea56872490f54e4',
            'Actual inherited groundwater interval canonical admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(manifest['members']),'Original groundwater interval admission inventory differs')
        for name,item in manifest['members'].items():
            raw=z.read(name);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],
                                     'Original groundwater interval admission bytes differ')
        receipt=json.loads(z.read('GROUNDWATER_INTERVAL_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed=json.loads(z.read('GROUNDWATER_INTERVAL_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and
                receipt['before']['status']=='' and len(receipt['before']['sparse'])==25 and
                receipt['returncode']==0 and receipt['model_executions']==0 and
                observed['status']=='BOUNDED_GROUNDWATER_CDE_INTERVAL_SOURCE_RAW_ADMISSION_PASS',
                'Actual unchanged groundwater interval canonical observation invalid')
    return dict(status='UNCHANGED_GROUNDWATER_INTERVAL_AND_EARLIER_CANONICAL_OBSERVATIONS_REUSED',
                prior_actual_canonical=PARENT,actual_public_seconds=receipt['elapsed_seconds'],
                inherited_earlier_owners=retained,fresh_unaffected_full_periods=0,
                groundwater_interval_observations_role='UNCHANGED_ADMITTED_INTERVALS_REUSED_AFTER_EXACT_CURRENT_POSTIMAGES')


def verify():
    import implicit_snow_verify as implicit_snow
    return implicit_snow.verify()
    source();retained=inherited();win=science.windows(PROOF)
    portable={opt:science.ubuntu(PROOF,opt) for opt in ('O0','O2')}
    observations=[win,*portable.values()]
    for field in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts',
                  'actual_short_cold_windows','actual_native_refusals','actual_source_policy_refusals'):
        require(sum(v[field] for v in observations)==COUNTS[field],'Actual groundwater science denominator differs: '+field)
    require(sum(v['actual_transaction_contexts'] for v in observations)==16,'Actual groundwater transaction denominator differs')
    native=[v for opt in win['metrics'].values() for v in opt['native'].values()]+[v for opt in portable.values() for v in opt['native'].values()]
    require(sum(v['compiled_refusals'] for v in native)==COUNTS['actual_compiled_refusals'] and
            sum(v['accepted_receipt_refusals'] for v in native)==COUNTS['actual_accepted_receipt_refusals'],
            'Actual compiled/public native refusal authorities differ')
    require(win['actual_unselected_CDE_contexts']==COUNTS['actual_nonselected_CDE_contexts'] and
            win['actual_unselected_CDE_cold_windows']==COUNTS['actual_nonselected_CDE_cold_windows'],
            'Actual unchanged integrated postimage denominator differs')

    return dict(status='BOUNDED_EXPLICIT_SNOW_GROUNDWATER_CDE_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,
                **COUNTS,Windows=win,Ubuntu=portable,inherited_unchanged_owners=retained,
                model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
                global_family_and_gap_counts='UNKNOWN',RC3_changed=False,AGE_admitted=False,
                implicit_snow_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
