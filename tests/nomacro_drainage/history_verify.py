"""Bounded hydraulic-history source/raw admission retaining preceding science."""
from functools import lru_cache
import json
from pathlib import Path
import subprocess
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'))
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import history_evidence as evidence
import calendar_verify as previous
from extended_forensics import require

PROOF=ROOT/'integration/f-ci/nomacro-complete01'
BASE='6a31bc718ed01480e573f5853bf3f5510ff40908'
RUNTIME='60ebf4adc'
FULL='8fc2f88f0'
SEALED='bdff0f9e5'
READERS='1e23b1b9f745faacb52752b813772998cc4c12a2'
QUAL='integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_HISTORY_QUALIFICATION.json'
OLD='tests/nomacro_drainage/calendar_verify.py'
SURFACES=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
SOURCE_LINE="    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual calendar compiler source differs from qualified runtime')\n"
SOURCE_HOOK="    import history_verify as history\n    history.guard_previous_source()\n"
VERIFY_HOOK="    import history_verify as history\n    return history.verify()\n"


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def norm(raw):return raw.replace(b'\r\n',b'\n')


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral hydraulic-history qualification changed')
    q=json.loads(raw)
    require((q['runtime'],q['full_period_runtime'],q['predecessor'],q['independent_readers'])==(git('rev-parse',RUNTIME).decode().strip(),git('rev-parse',FULL).decode().strip(),BASE,READERS),'Foreign hydraulic-history source authority')
    require(q['status']=='NEUTRAL_EXTENDED_HYDRAULIC_HISTORY_SOURCE_RAW_QUALIFICATION_PENDING_ADMISSION','History neutral authority promoted')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_remaining_gap_counts'],q['RC3_changed'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN',False),'Whole historical/scientific/release scope promoted')
    require(all(q[key]==1e-10 for key in ('daily_soil_water_guard_cm','daily_secondary_water_guard_cm','daily_combined_water_guard_cm','daily_cde_guard_mg_cm2','integrated_cde_guard_mg_cm2')) and q['integrated_water_1e10_claim'] is False,'History scientific guards changed')
    require((q['actual_full_periods'],q['actual_days_per_full_period'],q['actual_primary_complete_native_cold_windows'],q['actual_short_contexts'],q['actual_output_interaction_contexts'],q['actual_history_off_contexts'],q['actual_current_Windows_contexts'],q['actual_public_native_refusals'],q['actual_compiled_native_refusals'],q['actual_cli_contexts'],q['actual_transaction_contexts'],q['actual_public_scope_refusals'])==(8,1096,48,8,4,4,4,435,405,14,14,4),'History actual scope/denominators changed')
    require(q['AGE_extended_admitted'] is q['implicit_extended_admitted'] is False and q['fresh_unaffected_full_periods']==0,'Unqualified AGE/implicit domain promoted or unaffected full periods repeated')
    return q


@lru_cache(maxsize=1)
def guard_previous_source():
    qualification()
    import implicit_verify as implicit
    implicit.guard_previous_source()
    expected=['app/hybrid_water/'+name for name in ('experimental_project.py','extended_drainage.py','extended_output_receipt.py','original_output.py','original_output_hysteresis.py')]
    require(git('diff','--name-only',BASE,RUNTIME,'--',*SURFACES).decode().splitlines()==expected,'Unexpected history physical compiler dependency changed')
    path='app/hybrid_water/experimental_project.py'
    require(git('diff','--name-only',FULL,RUNTIME,'--',*SURFACES).decode().splitlines()==[path],'History full/current numerical dependency changed')
    anchor=b'    report = inspect(directory,original_output=original_output)\n'
    added=b"    if report.get('extended_drainage',{}).get('swhyst') and not original_output:\n        raise ValueError('Extended drainage hydraulic history requires explicit original-output state')\n"
    before=blob(FULL,path);require(before.count(anchor)==1 and before.replace(anchor,anchor+added)==blob(RUNTIME,path),'History input guard changed beyond exact inert explicit-output predicate')
    # Nonextended old hysteresis renderers remain literal, with only the
    # explicitly selected SWDRA2 admission exception in their selector.
    path='app/hybrid_water/original_output_hysteresis.py'
    added=b"        if key=='SWDRA' and one(key)==2:\n            from extended_drainage import enabled as extended_drainage_enabled\n            if extended_drainage_enabled(project):continue\n"
    after=blob(RUNTIME,path);require(after.count(added)==1 and after.replace(added,b'',1)==blob(BASE,path),'Old hydraulic-history scientific provider changed')
    return True


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification();text=norm((ROOT/OLD).read_bytes()).decode()
    require(text.count(SOURCE_HOOK)==1 and text.count(VERIFY_HOOK)==1,'Missing/ambiguous history owner delegation')
    text=text.replace(SOURCE_HOOK,SOURCE_LINE,1).replace(VERIFY_HOOK,'',1)
    require(text.encode()==blob(BASE,OLD),'Preceding calendar scientific/source bodies changed')
    for name in ('history_evidence.py','history_forensics.py'):
        path='tests/nomacro_drainage/'+name;require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Independent history scientific reader changed')
    for item in q['archives'].values():
        path='integration/f-ci/nomacro-complete01/'+item['record'];raw=(ROOT/path).read_bytes()
        require(norm(raw)==blob(SEALED,path) and evidence.prior.digest(norm(raw))==item['record_lf_sha256'],'Neutral history raw archive provenance changed')
    previous.source() # Retains and executes all preceding source assertions.
    return True


def scope(q):
    path=PROOF/'EXTENDED_DRAINAGE_HISTORY_SCOPE_AND_PROTOTYPE_RAW.zip';record=json.loads(path.with_suffix('.json').read_text())
    with evidence.prior.archive(path,record) as z:
        current=json.loads(z.read('scope-current/RESULT.json'));require(len(current['controls'])==4 and current['accepted_origin_unchanged'] is True,'Actual excluded history scope denominator changed')
        require({item['label'] for item in current['controls']}=={'compatibility','AGE','history3','implicit'},'Excluded history composition omitted')
        for item in current['controls']:
            prefix='scope-current/'+item['label']+'/'
            require(item['returncode']==2 and item['expected_refusal'] in z.read(prefix+'actual.stderr').decode(),'Actual excluded history CLI did not refuse at its intended guard')
            for name,digest in item['input_sha256'].items():require(evidence.prior.digest(z.read(prefix+'input/'+name.replace('\\','/')))==digest,'Actual excluded scope input changed')
            require(not any(name.startswith(prefix) and ('accepted-' in name or name.endswith('donor.stdout') or name.endswith('.exe')) for name in z.namelist()),'Excluded history CLI published or executed worker')
    return dict(actual_public_scope_refusals=4,AGE_admitted=False,implicit_admitted=False,prototypes_and_failed_attempts='RETAINED_NO_ADMISSION')


@lru_cache(maxsize=1)
def scientific():
    q=qualification();metrics={}
    for platform,call in [('Windows',evidence.windows),('Ubuntu',evidence.ubuntu)]:
        for opt in ('O0','O2'):metrics[platform+'-'+opt]=call(PROOF/f'EXTENDED_DRAINAGE_HISTORY_{platform.upper()}_{opt}_RAW_ARCHIVE.zip',opt)
    # Validate source-capsule custody too; windows() separately binds every
    # actual compiler identity against each actual source epoch.
    path=PROOF/'EXTENDED_DRAINAGE_HISTORY_WINDOWS_SOURCE_RAW_ARCHIVE.zip'
    with evidence.prior.archive(path,json.loads(path.with_suffix('.json').read_text())):pass
    return dict(metrics=metrics,scope=scope(q),actual_full_periods=8,actual_primary_exact_cold_windows=48,actual_public_native_refusals=435,actual_compiled_native_refusals=405,actual_cli_contexts=14,actual_transaction_contexts=14)


def verify():
    import implicit_verify as implicit
    return implicit.verify()
    source();current=scientific();calendar=previous.scientific();drainage=previous.preceding.scientific()
    import weather_surface_verify as weather
    q=json.loads((PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_bytes());weather.validate(q)
    inherited_weather=weather.scientific(q);inherited=weather.inherited()
    return dict(status='BOUNDED_EXTENDED_HYDRAULIC_HISTORY_SOURCE_RAW_ADMISSION_PASS',runtime=git('rev-parse',RUNTIME).decode().strip(),**current,inherited_calendar=calendar,inherited_drainage=drainage,inherited_weather=inherited_weather,inherited_groundwater=inherited,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
