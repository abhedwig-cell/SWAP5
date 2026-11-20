"""Bounded ordinary Snow undrained source, sealed science and inherited admission owner."""
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import snow_undrained_science as science

PARENT='b546801eaf24a01ee4dc457eb857ef46e6b61c30'
RUNTIME='b0d4acf8c02ba479c81535d7187675fd88878ee7'
READERS='626c1df96392755de05b3b0caa5bbf7b341efea4'
SEALED='093a3d90dae9aab67a54b9b87e1462eb54bed75f'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/SNOW_UNDRAINED_QUALIFICATION.json'
OLD='tests/nomacro_drainage/water_snow_groundwater_verify.py'
GUARD_HOOK='    import snow_undrained_verify as undrained\n    return undrained.guard_previous_source()\n'
VERIFY_HOOK='    import snow_undrained_verify as undrained\n    return undrained.verify()\n'
PROJECTION_HOOK='    import snow_undrained_verify as undrained\n    text=undrained.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/SNOW_UNDRAINED_*\n'
PARSERS=('snow_undrained_science.py','snow_undrained_forensics.py','snow_undrained_custody.py',
    'snow_undrained_control_forensics.py','snow_undrained_component_forensics.py',
    'snow_undrained_portable_forensics.py','snow_undrained_parent_bridge.json')
COUNTS=dict(actual_full_periods=16,actual_days_per_full_period=1096,actual_full_cold_windows=144,
    actual_short_contexts=36,actual_short_cold_windows=108,actual_compiled_refusals=200,
    actual_source_refusals=144,actual_transaction_contexts=8,
    actual_unselected_contexts=12,actual_unselected_cold_windows=12)


def strip_current_evidence(text):
    import frost_drainage_verify as frost
    text=frost.strip_current_evidence(text)
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous ordinary Snow undrained proof checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    import frost_drainage_verify as frost
    return frost.guard_previous_source()
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual ordinary Snow undrained compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('snow_undrained_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign ordinary Snow undrained parent bridge')
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected={line.split('\t')[1]:line.split('\t')[0] for line in changes}
    require(set(expected)==set(bridge['changes'])|set(bridge['added']) and
        all(expected[p]=='M' for p in bridge['changes']) and all(expected[p]=='A' for p in bridge['added']),
        'Incomplete exact ordinary Snow undrained source bridge')
    for path,items in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(items):
            index=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[index:index+len(after)]==after,'Actual ordinary Snow undrained source bridge differs')
            lines[index:index+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Original qualified ordinary Snow undrained parent changed')
    for path,value in bridge['added'].items():
        require(sha(blob(RUNTIME,path))==value,'Actual added bounded Snow source differs')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen ordinary Snow undrained observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous ordinary Snow undrained owner delegation');old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier water Snow groundwater scientific owner changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD},'Earlier actual observer changed beyond ordinary Snow undrained delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),
            'Registered CI changed beyond ordinary Snow undrained proof checkout')
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral ordinary Snow undrained qualification changed')
    q=json.loads(raw)
    require(q['status']=='NEUTRAL_SNOW_UNDRAINED_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
        (q['runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,PARENT,READERS),'Foreign ordinary Snow undrained qualification')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
        q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and
        q['AGE_admitted'] is False and q['new_physical_state'] is False and
        q['snow_undrained_admitted'] is False,'Whole historical, AGE or unsupported groundwater authority promoted')
    require(all(q[k]==v for k,v in COUNTS.items()) and len(q['archives'])==8,'Neutral ordinary Snow undrained denominator differs')
    require(all(q[k]==1e-10 for k in ('daily_water_guard_cm','integrated_water_guard_cm','daily_CDE_guard_mg_cm2','integrated_CDE_guard_mg_cm2')),'Scientific conservation guard changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    import water_snow_groundwater_verify as previous
    import groundwater_snow_verify as archives
    for label,item in q['archives'].items():archives.archive_identity(item,label)
    previous.source()
    return True


def inherited():
    import water_snow_groundwater_verify as previous
    retained=previous.inherited();path=PROOF/'WATER_SNOW_GROUNDWATER_ADMISSION_RAW_V1.zip';record=read(path.with_suffix('.json'))
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256']==
        '02e3eae6cf817754280fd0a00c5bfe3b4146e3558990c5424d5efa2ac7b0f717','Inherited water Snow groundwater admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(record['members']),'Inherited water Snow groundwater admission inventory differs')
        for n,item in record['members'].items():
            raw=z.read(n);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Inherited water Snow groundwater evidence changed')
        receipt=json.loads(z.read('WATER_SNOW_GROUNDWATER_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed=json.loads(z.read('WATER_SNOW_GROUNDWATER_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and receipt['before']['status']=='' and
            len(receipt['before']['sparse'])==28 and receipt['returncode']==receipt['model_executions']==0 and
            observed['status']=='BOUNDED_WATER_SNOW_GROUNDWATER_SOURCE_RAW_ADMISSION_PASS',
            'Actual inherited water Snow groundwater canonical public observation differs')
    return dict(status='UNCHANGED_ADMITTED_WATER_SNOW_GROUNDWATER_AND_EARLIER_OBSERVATIONS_REUSED',prior_actual_canonical=PARENT,
        inherited_earlier_owners=retained,fresh_unaffected_full_periods=0,
        inherited_observations_counted_fresh=False)


def verify():
    import frost_drainage_verify as frost
    return frost.verify()
    source();retained=inherited();win=science.windows(PROOF);portable={o:science.ubuntu(PROOF,o) for o in ('O0','O2')}
    for key in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts','actual_short_cold_windows',
        'actual_compiled_refusals','actual_source_refusals','actual_transaction_contexts'):
        require(sum(r[key] for r in [win,*portable.values()])==COUNTS[key],'Actual ordinary Snow undrained denominator differs: '+key)
    require(win['actual_unselected_contexts']==12 and win['actual_unselected_cold_windows']==12,'Actual postimage denominator differs')
    return dict(status='BOUNDED_SNOW_UNDRAINED_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**COUNTS,
        Windows=win,Ubuntu=portable,inherited_unchanged_owners=retained,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False,AGE_admitted=False,snow_undrained_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
