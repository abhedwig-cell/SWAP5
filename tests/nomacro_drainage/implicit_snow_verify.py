"""Bounded implicit Snow source, sealed science and inherited admission owner."""
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import implicit_snow_science as science

PARENT='f870eed5dca27b17bb24b27833dc9b3c7f85aea0'
RUNTIME='b726d1009eee14442d20e450bdb5d0105eb6f31c'
READERS='108661c8d8964fcc8513290f82ea625e3a58f6c8'
SEALED='e73315c919f7fbd43fbb72e09c739d9f669b9151'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/IMPLICIT_SNOW_COMPOSITION_QUALIFICATION.json'
OLD='tests/nomacro_drainage/groundwater_snow_verify.py'
GUARD_HOOK='    import implicit_snow_verify as implicit_snow\n    return implicit_snow.guard_previous_source()\n'
VERIFY_HOOK='    import implicit_snow_verify as implicit_snow\n    return implicit_snow.verify()\n'
PROJECTION_HOOK='    import implicit_snow_verify as implicit_snow\n    text=implicit_snow.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/IMPLICIT_SNOW_COMPOSITION_*\n'
PARSERS=('implicit_snow_science.py','implicit_snow_forensics.py','implicit_snow_custody.py',
    'implicit_snow_control_forensics.py','implicit_snow_recovery_forensics.py',
    'implicit_snow_postimage_forensics.py','implicit_snow_parent_bridge.json')
COUNTS=dict(actual_full_periods=12,actual_days_per_full_period=1096,actual_full_cold_windows=108,
    actual_short_contexts=36,actual_short_cold_windows=108,actual_fresh_compiled_refusals=200,
    actual_fresh_source_refusals=144,actual_transaction_contexts=16,
    actual_unselected_contexts=12,actual_unselected_cold_windows=12)


def strip_current_evidence(text):
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous implicit Snow proof checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual implicit Snow compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('implicit_snow_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign implicit Snow parent bridge')
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected={line.split('\t')[1]:line.split('\t')[0] for line in changes}
    require(set(expected)==set(bridge['changes'])|set(bridge['added']) and
        all(expected[p]=='M' for p in bridge['changes']) and all(expected[p]=='A' for p in bridge['added']),
        'Incomplete exact implicit Snow source bridge')
    for path,items in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(items):
            index=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[index:index+len(after)]==after,'Actual implicit Snow source bridge differs')
            lines[index:index+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Original qualified implicit Snow parent changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen implicit Snow observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous implicit Snow owner delegation');old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier explicit Snow scientific owner changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD},'Earlier actual observer changed beyond implicit Snow delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),
            'Registered CI changed beyond implicit Snow proof checkout')
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral implicit Snow qualification changed')
    q=json.loads(raw)
    require(q['status']=='NEUTRAL_IMPLICIT_SNOW_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
        (q['runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,PARENT,READERS),'Foreign implicit Snow qualification')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
        q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and
        q['AGE_admitted'] is False and q['implicit_snow_admitted'] is False and q['new_physical_state'] is False and
        q['water_snow_groundwater_admitted'] is False,'Whole historical, AGE or unsupported groundwater authority promoted')
    require(all(q[k]==v for k,v in COUNTS.items()) and len(q['archives'])==12,'Neutral implicit Snow denominator differs')
    require(all(q[k]==1e-10 for k in ('daily_water_guard_cm','integrated_water_guard_cm',
        'daily_CDE_guard_mg_cm2','integrated_CDE_guard_mg_cm2')),'Scientific conservation guard changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    import groundwater_snow_verify as previous
    for label,item in q['archives'].items():previous.archive_identity(item,label)
    previous.source()
    return True


def inherited():
    import groundwater_snow_verify as previous
    retained=previous.inherited();path=PROOF/'GROUNDWATER_SNOW_CDE_ADMISSION_RAW_V1.zip';record=read(path.with_suffix('.json'))
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256']==
        'a27415038383848ecf7ff69b71021e125d2d7a45efa7938ffdd176ec4b9aee13','Inherited explicit Snow admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(record['members']),'Inherited explicit Snow admission inventory differs')
        for n,item in record['members'].items():
            raw=z.read(n);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Inherited explicit Snow evidence changed')
        receipt=json.loads(z.read('GROUNDWATER_SNOW_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed=json.loads(z.read('GROUNDWATER_SNOW_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and receipt['before']['status']=='' and
            len(receipt['before']['sparse'])==26 and receipt['returncode']==receipt['model_executions']==0 and
            observed['status']=='BOUNDED_EXPLICIT_SNOW_GROUNDWATER_CDE_SOURCE_RAW_ADMISSION_PASS',
            'Actual inherited explicit Snow canonical public observation differs')
    return dict(status='UNCHANGED_ADMITTED_EXPLICIT_SNOW_AND_EARLIER_OBSERVATIONS_REUSED',prior_actual_canonical=PARENT,
        inherited_earlier_owners=retained,fresh_unaffected_full_periods=0,
        inherited_native_refusals=1720,inherited_native_refusals_counted_fresh=False)


def verify():
    source();retained=inherited();win=science.windows(PROOF);portable={o:science.ubuntu(PROOF,o) for o in ('O0','O2')}
    for key in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts','actual_short_cold_windows',
        'actual_fresh_compiled_refusals','actual_fresh_source_refusals','actual_transaction_contexts'):
        require(sum(r[key] for r in [win,*portable.values()])==COUNTS[key],'Actual implicit Snow denominator differs: '+key)
    require(win['actual_unselected_contexts']==12 and win['actual_unselected_cold_windows']==12,'Actual postimage denominator differs')
    return dict(status='BOUNDED_IMPLICIT_SNOW_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**COUNTS,
        Windows=win,Ubuntu=portable,inherited_unchanged_owners=retained,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False,AGE_admitted=False,water_snow_groundwater_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
