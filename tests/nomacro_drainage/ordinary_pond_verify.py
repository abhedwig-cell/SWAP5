"""Bounded original ordinary implicit pond source/raw admission owner."""
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from extended_forensics import require
import ordinary_science as science

PARENT='d785e2c3c415122b8e391d3979f1fbceb81ce5b5'
RUNTIME='614e1c5a5ce383222d6febb9d183aac14bf4a625'
NUMERIC='b96f69a397615d24f7af4fc1cdf28bf591957a04'
READERS='69f03573043fcd5bf6fe6c9b323bcccb176c485a'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/ORDINARY_IMPLICIT_POND_QUALIFICATION.json'
SURFACES=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
OLD='tests/nomacro_drainage/secondary_pond_verify.py'
GUARD_HOOK='    import ordinary_pond_verify as ordinary\n    return ordinary.guard_previous_source()\n'
VERIFY_HOOK='    import ordinary_pond_verify as ordinary\n    return ordinary.verify()\n'
PARSERS=('ordinary_science.py','ordinary_pond_evidence.py','ordinary_pond_forensics.py',
         'ordinary_chain_forensics.py','ordinary_control_forensics.py','ordinary_source_custody.py')


def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def norm(raw):return raw.replace(b'\r\n',b'\n')
def sha(raw):return hashlib.sha256(raw).hexdigest()


@lru_cache(maxsize=1)
def guard_previous_source():
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual ordinary implicit compiler source differs from qualified runtime')
    expected=['app/hybrid_water/'+n for n in ('daily_coupling.py','daily_host.py','ordinary_implicit_pond_switch.py','ordinary_implicit_pond_tangent.py','ordinary_pond_source_guard.py')]
    require(git('diff','--name-only',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()==expected,'Unexpected ordinary process/state dependency changed')
    host=blob(RUNTIME,'app/hybrid_water/daily_host.py')
    for addition in (
        b'    from ordinary_implicit_pond_switch import apply_build as ordinary_pond_build\n    patched=ordinary_pond_build(output,project,patched)\n',
        b"    from ordinary_implicit_pond_switch import metadata as ordinary_pond_metadata\n    ordinary_pond=ordinary_pond_metadata(project)\n    if ordinary_pond is not None:build_identity['ordinary_implicit_pond_switch']=ordinary_pond\n"):
        require(host.count(addition)==1,'Ambiguous selected ordinary host hook');host=host.replace(addition,b'',1)
    require(host==blob(PARENT,'app/hybrid_water/daily_host.py'),'Prior host physical/default body changed')
    coupling=blob(RUNTIME,'app/hybrid_water/daily_coupling.py')
    addition=b"    from ordinary_implicit_pond_switch import metadata as ordinary_pond_metadata,validate as validate_ordinary_pond\n    if identity.get('ordinary_implicit_pond_switch')!=ordinary_pond_metadata(project):\n        raise ValueError('Foreign ordinary implicit positive-pond reference policy')\n    validate_ordinary_pond(bundle,project)\n    if identity.get('ordinary_implicit_pond_switch'):\n        from ordinary_pond_source_guard import validate as validate_ordinary_pond_source\n        validate_ordinary_pond_source(bundle,project,identity)\n"
    require(coupling.count(addition)==1 and coupling.replace(addition,b'',1)==blob(PARENT,'app/hybrid_water/daily_coupling.py'),'Transaction/native/physical coupler changed beyond read-only validation')
    actual=norm((ROOT/OLD).read_bytes()).decode()
    require(actual.count(GUARD_HOOK)==actual.count(VERIFY_HOOK)==1 and
            actual.replace(GUARD_HOOK,'',1).replace(VERIFY_HOOK,'',1).encode()==blob(PARENT,OLD),'Earlier secondary scientific/source bodies changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen ordinary scientific observer changed: '+name)
    return True


def qualification():
    q=json.loads((ROOT/QUAL).read_text())
    require(q['status']=='NEUTRAL_ORDINARY_IMPLICIT_POND_RAW_SCIENCE_PASS_PENDING_ADMISSION' and
            (q['runtime'],q['numeric_runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,NUMERIC,PARENT,READERS),'Foreign neutral ordinary source authority')
    require(q['functional_completion']=='PARTIAL' and q['whole_scientific_equivalence']=='NOT_QUALIFIED' and
            q['global_family_and_gap_counts']=='UNKNOWN' and q['RC3_changed'] is False and q['AGE_admitted'] is False and
            q['ordinary_implicit_admitted'] is False,'Whole historical/AGE/release authority promoted')
    require(q['daily_water_guard_cm']==q['integrated_water_guard_cm']==q['daily_CDE_guard_mg_cm2']==q['integrated_CDE_guard_mg_cm2']==1e-10,'Scientific guard changed')
    return q


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    for name,item in q['archives'].items():
        raw=(PROOF/item['record']).read_bytes()
        require(sha(norm(raw))==item['record_lf_sha256'],'Neutral ordinary archive provenance changed: '+name)
        record=json.loads(raw);path=PROOF/record['archive']
        require(path.stat().st_size==record['bytes'] and science.digest(path)==record['sha256'],'Changed actual ordinary raw archive: '+name)
    require(sha(norm((PROOF/'ORDINARY_NONSELECTED_ACTUAL_BASELINE_BINDINGS_V1.json').read_bytes()))==q['baseline_lf_sha256'],'Actual nonselected baseline changed')
    import secondary_pond_verify as previous
    previous.source()
    return True


def inherited():
    import secondary_pond_inherited as old
    result=old.verify(ROOT,PROOF)
    # Validate the original nine secondary archives at their exact neutral byte
    # identities; their numerical implementations and all readers are unchanged.
    import secondary_pond_verify as owner
    q=owner.qualification()
    for item in q['archives'].values():
        record=json.loads((PROOF/item['record']).read_text());path=PROOF/record['archive']
        require(path.stat().st_size==record['bytes'] and science.digest(path)==record['sha256'],'Changed inherited actual secondary raw archive')
    path=PROOF/'EXTENDED_DRAINAGE_SECONDARY_POND_ADMISSION_RAW_V1.zip'
    manifest=json.loads(path.with_suffix('.json').read_text())
    require(science.digest(path)==manifest['sha256']=='c0e62a48a585db00a53ee02b7274c5636e82994d9d922150eb32e94e737fcfb6','Actual inherited canonical admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(manifest['members']),'Actual prior canonical raw inventory differs')
        for name,item in manifest['members'].items():
            raw=z.read(name);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Actual prior canonical raw bytes changed')
        receipt=json.loads(z.read('SECONDARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
        require(receipt['before']==receipt['after'] and receipt['before']['head']==PARENT and receipt['returncode']==0 and receipt['model_executions']==0,'Actual prior canonical verification invalid')
        observed=json.loads(z.read('SECONDARY_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
        require(observed['status']=='BOUNDED_SECONDARY_EXTENDED_IMPLICIT_SOURCE_RAW_ADMISSION_PASS','Wrong inherited owner observation')
    return dict(status='UNCHANGED_EXPLICIT_EXTENDED_PREDECESSOR_OBSERVATIONS_REUSED',
                prior_actual_canonical=PARENT,actual_public_seconds=receipt['elapsed_seconds'],
                original_ordinary_postimages_role='HISTORICAL_ONLY_REPLACED_BY_FRESH_ORDINARY_QUALIFICATION',
                unchanged_evidence=result,fresh_unaffected_full_periods=0)


def verify():
    source();old=inherited();win=science.windows(PROOF)
    portable={opt+('-initial' if initial else '-followup'):science.ubuntu(PROOF,opt,initial)
              for opt in ('O0','O2') for initial in (True,False)}
    require(win['actual_full_periods']==4 and win['actual_full_cold_windows']==32 and
            sum(v['component']['actual_points'] for v in portable.values())==208,'Actual ordinary scientific denominator differs')
    return dict(status='BOUNDED_ORDINARY_IMPLICIT_POND_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,
                actual_full_periods=8,actual_days_per_full_period=1096,actual_full_cold_windows=64,
                actual_short_contexts=24,actual_short_cold_windows=72,actual_source_policy_refusals=320,
                actual_current_native_postimages=18,actual_current_transactions=4,actual_nonselected_contexts=6,
                Windows=win,Ubuntu=portable,inherited_unchanged_owners=old,model_executions=0,
                canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',
                whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
                RC3_changed=False,AGE_admitted=False,CDE_groundwater_subdaily_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
