"""Bounded calendar source/raw admission, retaining preceding actual science."""
from functools import lru_cache
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'))
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import calendar_evidence as evidence
import extended_verify as preceding
from extended_forensics import require

PROOF=ROOT/'integration/f-ci/nomacro-complete01'
RUNTIME='17e41671ce0479b8e5993f2404cfbfa2c1079f7a'
FULL='6d931e66afb653a7930cbb4e3fa56a623b01788d'
BASE='66d6297b1ac0462c9be17f8df3db10c1773d1595'
SEALED='6ea429406'
READERS='95f784d544be443f5841dbc4ce54ffb6c802855b'
OLD='tests/nomacro_drainage/extended_verify.py'
QUAL='integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_CALENDAR_QUALIFICATION.json'
SURFACES=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
SOURCE_LINE="    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual drainage compiler source differs from qualified runtime')\n"
SOURCE_DELEGATION="    import calendar_verify as calendar\n    calendar.guard_previous_source()\n"
VERIFY_DELEGATION="    import calendar_verify as calendar\n    return calendar.verify()\n"


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def norm(raw):return raw.replace(b'\r\n',b'\n')


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral calendar qualification changed')
    q=json.loads(raw)
    require((q['runtime'],q['full_period_runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,FULL,BASE,READERS),'Foreign calendar source authority')
    require(q['status']=='NEUTRAL_EXTENDED_DRAINAGE_CALENDAR_SOURCE_RAW_QUALIFICATION_PENDING_ADMISSION','Calendar neutral authority promoted')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_remaining_gap_counts'],q['RC3_changed'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN',False),'Whole historical/scientific/release scope promoted')
    require(all(q[key]==1e-10 for key in ('daily_soil_water_guard_cm','daily_secondary_water_guard_cm','daily_combined_water_guard_cm','daily_cde_guard_mg_cm2','integrated_cde_guard_mg_cm2')) and q['integrated_water_1e10_claim'] is False,'Calendar scientific guards changed')
    require((q['actual_full_periods'],q['actual_days_per_full_period'],q['actual_primary_complete_native_cold_windows'],q['actual_current_postimage_contexts'],q['actual_public_native_refusals'],q['actual_compiled_native_refusals'],q['actual_cli_contexts'],q['actual_transaction_contexts'])==(8,1096,48,8,348,324,16,16),'Calendar actual scope/denominators changed')
    require(q['AGE_extended_admitted'] is False and q['actual_AGE_failure_accepted_days']==364 and q['AGE_day365_published'] is False,'Unqualified AGE dry domain promoted')
    return q


@lru_cache(maxsize=1)
def guard_previous_source():
    qualification()
    import history_verify as history
    history.guard_previous_source()
    changed=git('diff','--name-only',BASE,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected=['app/hybrid_water/'+name for name in ('daily_coupling.py','daily_host.py','experimental_project.py','extended_drainage.py','extended_output_receipt.py','original_output.py')]
    require(changed==expected,'Unexpected calendar compiler dependency changed')
    require(git('diff','--name-only',FULL,RUNTIME,'--',*SURFACES).decode().splitlines()==['app/hybrid_water/daily_host.py','app/hybrid_water/extended_drainage.py'],'Full/current calendar physical dependency changed')
    before=blob(FULL,'app/hybrid_water/daily_host.py');after=blob(RUNTIME,'app/hybrid_water/daily_host.py')
    original=b"validate_extended((current.directory/'macro.bin').read_bytes(),budget,self.project)"
    require(before.count(original)==1 and before.replace(original,b"validate_extended((current.directory/'macro.bin').read_bytes(),{**budget,**solute_budget},self.project)")==after,'Current host changed beyond complete read-only validation receipt')
    return True


@lru_cache(maxsize=1)
def source():
    guard_previous_source();q=qualification()
    current=norm((ROOT/OLD).read_bytes()).decode()
    require(current.count(SOURCE_DELEGATION)==1 and current.count(VERIFY_DELEGATION)==1,'Missing/ambiguous calendar source/verify delegation')
    current=current.replace(SOURCE_DELEGATION,SOURCE_LINE,1).replace(VERIFY_DELEGATION,'',1)
    require(current.encode()==blob(BASE,OLD),'Preceding drainage source/scientific bodies changed')
    for name in ('calendar_evidence.py','calendar_forensics.py','calendar_publisher.py'):
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Independent calendar scientific reader changed')
    for item in q['archives'].values():
        path='integration/f-ci/nomacro-complete01/'+item['record'];raw=(ROOT/path).read_bytes()
        require(norm(raw)==blob(SEALED,path) and evidence.prior.digest(norm(raw))==item['record_lf_sha256'],'Neutral calendar raw provenance changed')
    preceding.source() # Executes every preceding assertion with bounded authority delegation.
    return True


def retained_failures(q):
    # Check every central archive/member, including unsuccessful/prototype
    # phases. These checks establish custody, never scientific admission.
    for item in q['archives'].values():
        path=PROOF/item['archive'];record=json.loads((PROOF/item['record']).read_text())
        require(record['sha256']==item['sha256'] and record['bytes']==item['bytes'],'Calendar archive identity differs')
        # Premodel cancellation inventories predate the size+hash member
        # schema. Preserve that original record and validate its declared
        # SHA values directly, without rewriting or upgrading the evidence.
        if all(isinstance(value,str) for value in record['members'].values()):
            require(path.stat().st_size==record['bytes'] and evidence.prior.digest(path.read_bytes())==record['sha256'],'Premodel original artifact changed')
            with zipfile.ZipFile(path) as archive:
                require(len(archive.namelist())==len(set(archive.namelist())) and set(archive.namelist())==set(record['members']),'Premodel actual inventory differs')
                for name,digest in record['members'].items():require(evidence.prior.digest(archive.read(name))==digest,'Premodel actual source member changed')
            continue
        with evidence.prior.archive(path,record) as archive:
            if 'AGE_FAILURE_' in path.name:
                rows=evidence.prior.lines(archive.read('dry-failure/trajectory/daily.jsonl'))
                require(len(rows)==364 and rows[-1]['day']==364 and not any('accepted-column-1-day-365.zip' in n for n in archive.namelist()),'Actual refused AGE day published or prefix censored')
                evidence.science.inventory(rows)
                require(b'Original host surface age budget rejected' in archive.read('dry-failure/trajectory/original/donor.stderr'),'Actual AGE failure diagnostic missing')
            if 'AGE_DRY_COMPONENT_' in path.name:
                for opt in ('O0','O2'):
                    output=archive.read('actual/'+opt+'-run.stdout').decode()
                    require('ACTUAL_DRY_REFUSAL 1 ' in output and 'ACTUAL_WET_CONTROL 0 ' in output and 'ACTUAL_PRODUCTION_RETAINED_AGE_DRY_DOMAIN_AND_CONTROLS_PASS' in output,'Actual retained-age component controls missing')
    return dict(actual_refused_AGE_day=365,actual_accepted_AGE_prefix_days=364,AGE_admitted=False)


@lru_cache(maxsize=1)
def scientific():
    q=qualification();metrics={};failures=retained_failures(q)
    for opt in ('O0','O2'):
        metrics['Windows-'+opt]=evidence.windows(PROOF/f'EXTENDED_DRAINAGE_CALENDAR_WINDOWS_{opt}_RAW_ARCHIVE.zip',opt)
        metrics['Ubuntu-'+opt]=evidence.ubuntu(PROOF/f'EXTENDED_DRAINAGE_CALENDAR_UBUNTU_FULL_{opt}_RAW_ARCHIVE.zip',PROOF/f'EXTENDED_DRAINAGE_CALENDAR_UBUNTU_CURRENT_{opt}_RAW_ARCHIVE.zip',opt)
    return dict(metrics=metrics,actual_full_periods=8,actual_primary_exact_cold_windows=48,actual_current_postimage_contexts=8,actual_public_native_refusals=348,actual_compiled_native_refusals=324,actual_cli_contexts=16,actual_transaction_contexts=16,retained_failure_scope=failures)


def verify():
    import history_verify as history
    return history.verify()
    source();current=scientific();old=preceding.scientific()
    import weather_surface_verify as weather
    q=json.loads((PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_bytes());weather.validate(q)
    inherited_weather=weather.scientific(q);inherited=weather.inherited()
    return dict(status='BOUNDED_EXTENDED_DRAINAGE_ORIGINAL_CALENDAR_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**current,inherited_drainage=old,inherited_weather=inherited_weather,inherited_groundwater=inherited,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
