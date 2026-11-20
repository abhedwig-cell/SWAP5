"""Bounded water/Snow groundwater source, sealed science and inherited admission owner."""
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import water_snow_groundwater_science as science

PARENT='9c447f419d11743efe7464d3c8542ac1bc8fea4a'
RUNTIME='26ea91cf981126212fc71291426849f52d574cee'
READERS='7d71f3421d0cda273a005aba61b0612834761171'
SEALED='cc4588e4d358f8ca66a50d2e3da3e456a7ba3134'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/WATER_SNOW_GROUNDWATER_QUALIFICATION.json'
OLD='tests/nomacro_drainage/implicit_snow_verify.py'
GUARD_HOOK='    import water_snow_groundwater_verify as water_snow\n    return water_snow.guard_previous_source()\n'
VERIFY_HOOK='    import water_snow_groundwater_verify as water_snow\n    return water_snow.verify()\n'
PROJECTION_HOOK='    import water_snow_groundwater_verify as water_snow\n    text=water_snow.strip_current_evidence(text)\n'
PATTERN='            /integration/f-ci/nomacro-complete01/WATER_SNOW_GROUNDWATER_*\n'
PARSERS=('water_snow_groundwater_science.py','water_snow_groundwater_forensics.py',
    'water_snow_groundwater_custody.py','water_snow_groundwater_control_forensics.py',
    'water_snow_groundwater_portable_forensics.py','water_snow_groundwater_parent_bridge.json')
COUNTS=dict(actual_full_periods=12,actual_days_per_full_period=1096,actual_full_cold_windows=108,
    actual_short_contexts=36,actual_short_cold_windows=108,actual_compiled_refusals=390,
    actual_source_refusals=96,actual_transaction_contexts=6,
    actual_unselected_contexts=10,actual_unselected_cold_windows=10)


def strip_current_evidence(text):
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous water Snow groundwater proof checkout')
        text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual water Snow groundwater compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('water_snow_groundwater_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign water Snow groundwater parent bridge')
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected={line.split('\t')[1]:line.split('\t')[0] for line in changes}
    require(set(expected)==set(bridge['changes'])|set(bridge['added']) and
        all(expected[p]=='M' for p in bridge['changes']) and all(expected[p]=='A' for p in bridge['added']),
        'Incomplete exact water Snow groundwater source bridge')
    for path,items in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(items):
            index=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[index:index+len(after)]==after,'Actual water Snow groundwater source bridge differs')
            lines[index:index+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Original qualified water Snow groundwater parent changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen water Snow groundwater observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous water Snow groundwater owner delegation');old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier implicit Snow scientific owner changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD},'Earlier actual observer changed beyond water Snow groundwater delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),
            'Registered CI changed beyond water Snow groundwater proof checkout')
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral water Snow groundwater qualification changed')
    q=json.loads(raw)
    require(q['status']=='NEUTRAL_WATER_SNOW_GROUNDWATER_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
        (q['runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,PARENT,READERS),'Foreign water Snow groundwater qualification')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
        q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and
        q['AGE_admitted'] is False and q['new_physical_state'] is False and
        q['water_snow_groundwater_admitted'] is False,'Whole historical, AGE or unsupported groundwater authority promoted')
    require(all(q[k]==v for k,v in COUNTS.items()) and len(q['archives'])==10,'Neutral water Snow groundwater denominator differs')
    require(all(q[k]==1e-10 for k in ('daily_water_guard_cm','integrated_water_guard_cm')),'Scientific conservation guard changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    import implicit_snow_verify as previous
    import groundwater_snow_verify as archives
    for label,item in q['archives'].items():archives.archive_identity(item,label)
    previous.source()
    return True


def inherited():
    import implicit_snow_verify as previous
    retained=previous.inherited();path=PROOF/'IMPLICIT_SNOW_COMPOSITION_ADMISSION_RAW_V1.zip';record=read(path.with_suffix('.json'))
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256']==
        'db8955a6c08c9ac8ccd22aca3ed9de100a67856b79d3d3835f818c78f1d29c77','Inherited implicit Snow admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(record['members']),'Inherited implicit Snow admission inventory differs')
        for n,item in record['members'].items():
            raw=z.read(n);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Inherited implicit Snow evidence changed')
        receipt=json.loads(z.read('IMPLICIT_SNOW_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        observed=json.loads(z.read('IMPLICIT_SNOW_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and receipt['before']['status']=='' and
            len(receipt['before']['sparse'])==27 and receipt['returncode']==receipt['model_executions']==0 and
            observed['status']=='BOUNDED_IMPLICIT_SNOW_SOURCE_RAW_ADMISSION_PASS',
            'Actual inherited implicit Snow canonical public observation differs')
    return dict(status='UNCHANGED_ADMITTED_IMPLICIT_SNOW_AND_EARLIER_OBSERVATIONS_REUSED',prior_actual_canonical=PARENT,
        inherited_earlier_owners=retained,fresh_unaffected_full_periods=0,
        inherited_observations_counted_fresh=False)


def verify():
    source();retained=inherited();win=science.windows(PROOF);portable={o:science.ubuntu(PROOF,o) for o in ('O0','O2')}
    for key in ('actual_full_periods','actual_full_cold_windows','actual_short_contexts','actual_short_cold_windows',
        'actual_compiled_refusals','actual_source_refusals','actual_transaction_contexts'):
        require(sum(r[key] for r in [win,*portable.values()])==COUNTS[key],'Actual water Snow groundwater denominator differs: '+key)
    require(win['actual_unselected_contexts']==10 and win['actual_unselected_cold_windows']==10,'Actual postimage denominator differs')
    return dict(status='BOUNDED_WATER_SNOW_GROUNDWATER_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**COUNTS,
        Windows=win,Ubuntu=portable,inherited_unchanged_owners=retained,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',
        whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False,AGE_admitted=False,water_snow_groundwater_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
