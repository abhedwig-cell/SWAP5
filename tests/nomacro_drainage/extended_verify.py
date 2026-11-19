"""Bounded original drainage source/raw owner, retaining all preceding science."""
from functools import lru_cache
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'))
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import extended_evidence as evidence
from extended_forensics import require

PROOF='integration/f-ci/nomacro-complete01/'
BASE='bc9271bcc60478e02c7a7d8a11e21dd8c791c9df'
RUNTIME='ec4cb79a974f86bc248aa10eb037a588a1b2f249'
SEALED='b245bb94d0be2badcb603e575f7914e013827410'
FORENSICS='0a43c447c'
WEATHER='tests/nomacro_scheduled_subsurface/weather_surface_verify.py'
SELF='tests/nomacro_drainage/extended_verify.py'
MC=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
CHECKOUT='            /integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_*\n'
SURFACES=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
OLD_APP=('app/hybrid_water/daily_coupling.py','app/hybrid_water/daily_host.py','app/hybrid_water/experimental_project.py')
NEW_APP=tuple('app/hybrid_water/'+name for name in ('extended_drainage.py','extended_drainage_state.f90','extended_interception.py','extended_pond.py','extended_trial_receipt.py'))
PARSERS=tuple('tests/nomacro_drainage/'+name for name in ('extended_evidence.py','extended_forensics.py','forensic_negative_controls.py'))
HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('extended_drain_admission',ROOT/'tests/nomacro_drainage/extended_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.verify()
"""
SOURCE_HOOK="""    import importlib.util
    spec=importlib.util.spec_from_file_location('extended_drain_preservation',ROOT/'tests/nomacro_drainage/extended_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    return owner.guard_weather(q)
"""
STRIP_HOOK="""    spec=importlib.util.spec_from_file_location('extended_drain_checkout_projection',ROOT/'tests/nomacro_drainage/extended_verify.py')
    owner=importlib.util.module_from_spec(spec);spec.loader.exec_module(owner)
    text=owner.strip_current_evidence(text)
"""

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def normalized(raw):return raw.replace(b'\r\n',b'\n')

def strip_current_evidence(text):
    if CHECKOUT in text:
        require(text.count(CHECKOUT)==1,'Ambiguous drainage scientific checkout')
        text=text.replace(CHECKOUT,'',1)
    return text

def qualification():
    path=PROOF+'EXTENDED_DRAINAGE_QUALIFICATION.json';raw=(ROOT/path).read_bytes()
    require(normalized(raw)==blob(SEALED,path),'Neutral original drainage qualification changed')
    q=json.loads(raw)
    require(q['runtime']==RUNTIME and q['predecessor']==BASE and q['status']=='NEUTRAL_ORIGINAL_EXTENDED_DRAINAGE_SOURCE_RAW_QUALIFICATION_PENDING_ADMISSION','Foreign original drainage qualification')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_remaining_gap_counts'],q['RC3_changed'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN',False),'Whole historical/scientific/release scope promoted')
    require(q['daily_soil_water_guard_cm']==q['daily_secondary_water_guard_cm']==q['daily_combined_water_guard_cm']==q['daily_cde_guard_mg_cm2']==q['integrated_cde_guard_mg_cm2']==1e-10 and q['integrated_water_1e10_claim'] is False,'Original owning scientific guards changed')
    require((q['actual_full_periods'],q['actual_days_per_full_period'],q['actual_primary_complete_native_cold_windows'],q['actual_short_table_periods'],q['actual_short_table_complete_native_cold_windows'],q['actual_public_native_refusals'],q['actual_compiled_native_refusals'],q['actual_cli_contexts'],q['actual_transaction_contexts'])==(16,1096,112,4,16,312,288,12,12),'Actual drainage scope/denominators changed')
    return q

@lru_cache(maxsize=1)
def source():
    q=qualification()
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual drainage compiler source differs from qualified runtime')
    changed=git('diff','--name-only',BASE,RUNTIME,'--',*SURFACES).decode().splitlines()
    require(changed==sorted([*OLD_APP,*NEW_APP]),'Unexpected original physical compiler surface changed')
    for path in OLD_APP:
        patch=git('diff','--unified=0',BASE,RUNTIME,'--',path).decode()
        require(not any(line.startswith('-') and not line.startswith('---') for line in patch.splitlines()),'Original host/reader/coupler body changed')
    for path in PARSERS:
        require(normalized((ROOT/path).read_bytes())==blob(FORENSICS,path),'Independent original drainage scientific reader changed')
    for name,item in q['archives'].items():
        path=PROOF+item['record'];raw=(ROOT/path).read_bytes()
        require(normalized(raw)==blob(SEALED,path) and evidence.digest(normalized(raw))==item['record_lf_sha256'],'Neutral raw archive provenance changed: '+name)
    for path in (PROOF+'EXTENDED_DRAINAGE_STATE_OWNERSHIP.json',PROOF+'WEATHER_TERMINAL_QUALIFICATION.json'):
        require(normalized((ROOT/path).read_bytes())==blob(SEALED,path),'Original state ownership or inherited weather authority changed')
    current=normalized((ROOT/WEATHER).read_bytes()).decode()
    for hook in (HOOK,SOURCE_HOOK,STRIP_HOOK):
        require(current.count(hook)==1,'Missing/ambiguous drainage owner delegation');current=current.replace(hook,'',1)
    require(current.encode()==blob(BASE,WEATHER),'Preceding weather scientific/source bodies changed')
    for path in MC:
        text=normalized((ROOT/path).read_bytes()).decode();require(text.count(CHECKOUT)==1,'Required drainage scientific checkout missing')
        require(strip_current_evidence(text).encode()==blob(BASE,path),'Old MC command/limit/source/checkouts changed')
    # All previous scientific readers remain exactly at the admitted image.
    previous=git('diff','--name-only',BASE,'--','tests/nomacro_scheduled_subsurface','tests/saltfarm_newton','tests/hupsel51').decode().splitlines()
    require(previous==[WEATHER],'Preceding actual scientific reader changed beyond literal delegation')
    return True

def guard_weather(q):
    import weather_surface_verify as old
    old.validate(q);source()
    return True

def preservation():
    source();return 'LITERAL_NONSELECTED_HOST_COUPLER_CLI_AND_OLD_SCIENTIFIC_CHECKS_PRESERVED'

def nonselected(z,opt):
    for case in ('pulsed','hourly'):
        p='nonselected-'+case+'/';r=json.loads(z.read(p+'PRESERVATION.json'))
        require(r['actual_days']==5 and r['fresh_unaffected_full_periods']==0 and all(r[key] is True for key in ('exact_inputs','exact_generated_fortran','exact_kernel_sources','exact_physical_prefix')),'Actual nonselected weather preservation omitted')
        archive=ROOT/PROOF/r['old_archive'];require(evidence.digest(archive.read_bytes())==r['old_archive_sha256'],'Inherited actual weather authority changed')
        with zipfile.ZipFile(archive) as old:
            prefix=case+'-build/';current='nonselected-'+case+'-build/'
            expected={name[len(prefix):]:old.read(name) for name in old.namelist() if name.startswith(prefix) and '/' not in name[len(prefix):] and name.endswith('.f90')}
            actual={name[len(current):]:z.read(name) for name in z.namelist() if name.startswith(current) and '/' not in name[len(current):] and name.endswith('.f90')}
            require(expected==actual,'Actual nonselected original generated Fortran changed')
            warm=evidence.lines(z.read(p+'trajectory/daily.jsonl'));before=evidence.lines(old.read(case+'/trajectory/daily.jsonl'))[:5]
            require(evidence.physical(warm)==evidence.physical(before),'Actual nonselected weather physical prefix changed')
            for day in (2,4):
                now=evidence.package(z.read(p+f'trajectory/accepted-column-1-day-{day}.zip'))[1];prior=evidence.package(old.read(case+f'/trajectory/accepted-column-1-day-{day}.zip'))[1]
                require(now==prior,'Actual nonselected complete original native changed')
    r=json.loads(z.read('named-seam/RESULT.json'));require(r['actual_days']==2 and r['full_periods_repeated']==0 and all(r[key] is True for key in ('exact_generated_fortran','exact_inputs','exact_prior_physical','exact_complete_native_replay','origin_unchanged')),'Actual named original transport seam omitted')
    a=evidence.package(z.read('named-seam/cold/accepted-column-1-day-2.zip'))[1];b=evidence.package(z.read('named-seam/warm-endpoint/accepted-column-1-day-2.zip'))[1]
    require(a==b,'Actual named transport complete native changed')
    return dict(weather_five_day_contexts=2,named_two_day_contexts=1)

@lru_cache(maxsize=1)
def scientific():
    q=qualification();metrics={};preserved={}
    for platform,call in [('Windows',evidence.windows),('Ubuntu',evidence.ubuntu)]:
        for opt in ('O0','O2'):
            name='EXTENDED_DRAINAGE_'+platform.upper()+'_'+opt+'_RAW_ARCHIVE';path=ROOT/PROOF/q['archives'][name]['archive']
            metrics[platform+'-'+opt]=call(path,opt)
            if platform=='Windows':
                with zipfile.ZipFile(path) as z:preserved[opt]=nonselected(z,opt)
    return dict(metrics=metrics,actual_full_periods=16,actual_primary_exact_cold_windows=112,actual_table_exact_cold_windows=16,actual_public_native_refusals=312,actual_compiled_native_refusals=288,actual_cli_contexts=12,actual_transaction_contexts=12,nonselected=preserved)

def verify():
    source();current=scientific()
    import weather_surface_verify as old
    q=json.loads((ROOT/PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_bytes());old.validate(q)
    previous=old.scientific(q);inherited=old.inherited()
    return dict(status='BOUNDED_ORIGINAL_EXTENDED_DRAINAGE_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**current,inherited_weather=previous,inherited_groundwater=inherited,inherited_canonical_transport='ACTUAL_LITERAL_SOURCE_AND_RAW_CHECKS_PASS_WITHOUT_NEW_MODEL_OR_PERFORMANCE_RUNS',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
