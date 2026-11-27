"""Own actual closed/Gardner science and preserve the genuine canonical880 authority."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_gardner_state_source_custody import ROOT,source,git,BASE,PREFIX
from closed_gardner_state_parent_admission import parent_admission
from closed_gardner_state_portable_science import audit as portable
from closed_gardner_state_local_archive_science import audit as local
import implicit_hydraulic_state_verify as previous
SEALED='b2ac1ce22bf248ac9cca7717945c86c9cec03550'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())
def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('CLOSED_GARDNER_STATE12_') or not name.endswith('.json'):continue
        q=frozen(name[:-5])
        if not isinstance(q,dict) or not {'archive','bytes','sha256'}<=q.keys():continue
        pieces=[]
        for part in q.get('parts',[dict(file=q['archive'],bytes=q['bytes'],sha256=q['sha256'])]):
            raw=(data/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];pieces.append(raw)
        raw=b''.join(pieces);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            assert len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(q['members'])
            for n,item in q['members'].items():
                value=z.read(n);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
            count=len(z.namelist())
        observed.append(dict(archive=q['archive'],bytes=q['bytes'],sha256=q['sha256'],members=count))
    assert len(observed)>=7
    return observed


def guard_previous_source():
    source(SEALED);parent_admission();raw_custody();return True
def strip_current_evidence(text):return previous.strip_current_evidence(text)
def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);parent=parent_admission();data=data_source();raw=raw_custody();results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            actual=portable(data,platform,opt);assert actual==frozen('CLOSED_GARDNER_STATE12_FIRST_'+platform.upper()+'_'+opt+'_INDEPENDENT_V1');results.append(actual)
    actual_local=local(data);assert actual_local==frozen('CLOSED_GARDNER_STATE12_REPAIRED_LOCAL_ARCHIVE_INDEPENDENT_V1')
    assert tuple(sum(v[k] for v in results) for k in ['context_count','primary_days','native_samples','exact_cold_windows','compiled_native_refusals','external_transaction_contexts'])==(68,2380,476,240,1140,68)
    plan=frozen('CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3');assert len(plan['independent_qualification_cases'])==17 and len(plan['deferred_numerical_cases'])==2
    assert all(v['classification']=='NUMERICAL_DEFECT' and v['still_functional_migration_gap'] for v in plan['deferred_numerical_cases'])
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==880
    coadmission.update(contexts=948,short35_contexts=coadmission['short35_contexts']+68,native_calendar_samples=coadmission['native_calendar_samples']+476,exact_cold_windows=coadmission['exact_cold_windows']+240,new_closed_gardner_state_contexts=68,new_closed_gardner_state_primary_days=2380,new_closed_gardner_state_compiled_refusals=1140,new_closed_gardner_state_external_transactions=68,previous_canonical=BASE)
    return dict(status='BOUNDED_CLOSED_AND_GARDNER_ORDINARY_SNOW_FROST_ORIGINAL_INPUT_NATIVE_COLD_YEAR_TRANSACTIONS_AND_SOURCE_PASS',actual_current_source=current,parent_historical_admission=parent,actual_raw_custody=raw,new_original_portable_science=results,additional_actual_local_and_whole_object_science=actual_local,coadmission=coadmission,deferred_numerical_cases=plan['deferred_numerical_cases'],scientific_change_class='EXISTING_PHYSICAL_PROCESS_STATE_AND_INPUT_DOMAIN_COMPOSITION',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,new_numerical_policy=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
