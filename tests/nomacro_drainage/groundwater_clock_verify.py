"""Bounded existing groundwater state/CDE clock source and original raw owner."""
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import groundwater_clock_science as science

PARENT='c22d6ec1c5ede56b93d7f38635e38e4c277b3f51'
RUNTIME='63edf690ef7b48ffef420f9ac7bf1f098c007bef'
NUMERIC='e80d8cf7aa6f815081ce852bb558165c1b7d301b'
READERS='cabf065abb073034e80841c40094939ae85c6938'
SEALED='0bd32b4b4'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/GROUNDWATER_CDE_CLOCK_QUALIFICATION.json'
OLD='tests/nomacro_drainage/ordinary_pond_verify.py'
GUARD_HOOK='    import groundwater_clock_verify as groundwater_clock\n    return groundwater_clock.guard_previous_source()\n'
VERIFY_HOOK='    import groundwater_clock_verify as groundwater_clock\n    return groundwater_clock.verify()\n'
PROJECTION_HOOK='    import groundwater_clock_verify as groundwater_clock\n    text=groundwater_clock.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/GROUNDWATER_CDE_CLOCK_*\n'
PARSERS=('groundwater_clock_science.py','groundwater_clock_forensics.py',
         'groundwater_clock_custody.py','groundwater_clock_archive.py',
         'groundwater_clock_control_forensics.py','groundwater_clock_portable_archive.py',
         'groundwater_clock_controls_archive.py','groundwater_clock_parent_bridge.json')
COUNTS=dict(actual_full_periods=4,actual_days_per_full_period=1096,actual_full_cold_windows=32,
            actual_short_contexts=24,actual_short_cold_windows=76,actual_native_refusals=980,
            actual_compiled_refusals=976,actual_accepted_receipt_refusals=4,
            actual_transaction_contexts=12,actual_source_policy_refusals=108,
            actual_current_native_postimages=20,actual_nonselected_CDE_contexts=6,
            actual_nonselected_water_cached_cold=2)


def strip_current_evidence(text):
    import groundwater_interval_verify as groundwater_interval
    text=groundwater_interval.strip_current_evidence(text)
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous groundwater clock scientific checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    import groundwater_interval_verify as groundwater_interval
    return groundwater_interval.guard_previous_source()
    require(not git('diff',RUNTIME,'--',*SURFACES),
            'Actual groundwater clock compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('groundwater_clock_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign groundwater source bridge')
    expected=['app/hybrid_water/'+name for name in ('cde_clock_output.py','daily_coupling.py',
              'groundwater_cde_clock.py','groundwater_cde_clock_source_guard.py',
              'groundwater_history_native.py','groundwater_native.py','ordinary_pond_source_guard.py')]
    require(git('diff','--name-only',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()==expected,
            'Unexpected groundwater physical/state dependency changed')
    require(set(bridge['changes'])==set(expected)-{'app/hybrid_water/groundwater_cde_clock.py',
            'app/hybrid_water/groundwater_cde_clock_source_guard.py'},'Incomplete literal parent bridge')
    for path,changes in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(changes):
            index=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[index:index+len(after)]==after,'Actual selected source bridge differs')
            lines[index:index+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Original parent source body changed')
    # The only new trial provider delegates the literal existing groundwater
    # reaction renderer; all prior physical Fortran/template files are unchanged.
    provider='app/hybrid_water/age_groundwater_output.py'
    require(blob(PARENT,provider)==blob(RUNTIME,provider),'Original groundwater trial provider changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen groundwater observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous groundwater owner delegation')
        old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier ordinary scientific/source body changed')
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
    require(q['status']=='NEUTRAL_GROUNDWATER_CDE_CLOCK_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
            (q['runtime'],q['numeric_runtime'],q['predecessor'],q['independent_readers'])==
            (RUNTIME,NUMERIC,PARENT,READERS),'Foreign neutral groundwater authority')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
            q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and
            q['AGE_admitted'] is False and q['groundwater_clock_admitted'] is False and
            q['new_physical_state'] is False,'Whole historical/AGE/release authority promoted')
    require(all(q[k]==v for k,v in COUNTS.items()) and len(q['archives'])==7,'Neutral groundwater denominator differs')
    require(q['daily_water_guard_cm']==q['integrated_water_guard_cm']==q['daily_CDE_guard_mg_cm2']==q['integrated_CDE_guard_mg_cm2']==1e-10,
            'Scientific balance guard changed')
    return q


def archive_identity(item,label):
    raw=(PROOF/item['record']).read_bytes()
    require(sha(norm(raw))==item['record_lf_sha256'],'Original archive provenance changed: '+label)
    record=json.loads(raw);path=PROOF/record['archive']
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256'],
            'Changed actual original raw archive: '+label)


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    for label,item in q['archives'].items():archive_identity(item,label)
    require(sha(norm((PROOF/'GROUNDWATER_CDE_CLOCK_NONSELECTED_BASELINES_V1.json').read_bytes()))==q['baseline_lf_sha256'],
            'Actual groundwater unselected baseline changed')
    import ordinary_pond_verify as prior
    old=prior.qualification()
    for label,item in old['archives'].items():archive_identity(item,label)
    require(sha(norm((PROOF/'ORDINARY_NONSELECTED_ACTUAL_BASELINE_BINDINGS_V1.json').read_bytes()))==old['baseline_lf_sha256'],
            'Original ordinary nonselected baseline changed')
    return True


def inherited():
    import ordinary_pond_verify as prior
    retained=prior.inherited()
    path=PROOF/'ORDINARY_IMPLICIT_POND_ADMISSION_RAW_V1.zip';manifest=read(path.with_suffix('.json'))
    require(path.stat().st_size==manifest['bytes'] and digest(path)==manifest['sha256']==
            '24adb3e521e822945e2910686ff43c953a9e6840cf16ae8a16c7399fa4a06db9',
            'Actual inherited ordinary canonical admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(manifest['members']),'Original ordinary admission inventory differs')
        for name,item in manifest['members'].items():
            raw=z.read(name);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],
                                     'Original ordinary admission bytes differ')
        receipt=json.loads(z.read('ORDINARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed=json.loads(z.read('ORDINARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and
                receipt['before']['status']=='' and len(receipt['before']['sparse'])==23 and
                receipt['returncode']==0 and receipt['model_executions']==0 and
                observed['status']=='BOUNDED_ORDINARY_IMPLICIT_POND_SOURCE_RAW_ADMISSION_PASS',
                'Actual unchanged ordinary canonical observation invalid')
    return dict(status='UNCHANGED_ORDINARY_AND_EARLIER_CANONICAL_OBSERVATIONS_REUSED',
                prior_actual_canonical=PARENT,actual_public_seconds=receipt['elapsed_seconds'],
                inherited_earlier_owners=retained,fresh_unaffected_full_periods=0,
                groundwater_clock_observations_role='REPLACED_BY_FRESH_COMPOSITION_SCIENCE')


def verify():
    import groundwater_interval_verify as groundwater_interval
    return groundwater_interval.verify()
    source();retained=inherited();win=science.windows(PROOF)
    portable={opt:science.ubuntu(PROOF,opt) for opt in ('O0','O2')}
    observations=[win,*portable.values()]
    for field in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts',
                  'actual_short_cold_windows','actual_native_refusals','actual_source_policy_refusals',
                  'actual_current_native_postimages'):
        require(sum(v[field] for v in observations)==COUNTS[field],'Actual groundwater science denominator differs: '+field)
    require(sum(v['actual_transactions'] for v in observations)==12,'Actual groundwater transaction denominator differs')
    return dict(status='BOUNDED_GROUNDWATER_CDE_CLOCK_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,
                **COUNTS,Windows=win,Ubuntu=portable,inherited_unchanged_owners=retained,
                model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
                functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
                global_family_and_gap_counts='UNKNOWN',RC3_changed=False,AGE_admitted=False,
                groundwater_nonclock_interval_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
