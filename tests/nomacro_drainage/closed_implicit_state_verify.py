"""Own actual closed implicit science and preserve genuine canonical948 admission."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_implicit_state_source_custody import ROOT,source,git,BASE,PREFIX
from closed_implicit_state_parent_admission import parent_admission
from closed_implicit_state_portable_science import audit as portable
from closed_implicit_state_local_archive_science import audit as local
from closed_implicit_state_preservation_science import audit as preservation
from closed_implicit_state_ci_custody import audit as ci_custody
import closed_gardner_state_verify as previous
SEALED='9d4aaa23c3f21c80ac74062054b87d0ed3de97df'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())
def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('CLOSED_IMPLICIT_STATE13_') or not name.endswith('.json'):continue
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
    assert len(observed)==17
    return observed


def guard_previous_source():
    source(SEALED);parent_admission();raw_custody();ci_custody(data_source());return True
def strip_current_evidence(text):return previous.strip_current_evidence(text)
def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);parent=parent_admission();data=data_source();raw=raw_custody();ci=ci_custody(data);assert ci==frozen('CLOSED_IMPLICIT_STATE13_PORTABLE_ORIGINAL_CI_INDEPENDENT_V1');results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            actual=portable(data,platform,opt);assert actual==frozen('CLOSED_IMPLICIT_STATE13_FIRST_'+platform.upper()+'_'+opt+'_INDEPENDENT_V1');results.append(actual)
    actual_local=local(data);assert actual_local==frozen('CLOSED_IMPLICIT_STATE13_REPAIRED_LOCAL_ARCHIVE_INDEPENDENT_V1')
    actual_preservation=preservation(data);assert actual_preservation==frozen('CLOSED_IMPLICIT_STATE13_FORTY_NATIVE_PRESERVATION_INDEPENDENT_V1')
    assert tuple(sum(v[k] for v in results) for k in ['context_count','primary_days','native_samples','exact_cold_windows','compiled_native_refusals','external_transaction_contexts'])==(56,1960,392,176,1608,56)
    plan=frozen('CLOSED_IMPLICIT_STATE13_FINITE_CASE_PLAN_V1');assert len(plan['independent_qualification_cases'])==14 and plan['deferred_numerical_cases']==[]
    inherited_name='CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3.json';inherited_raw=(data/inherited_name).read_bytes();assert inherited_raw==git('show',BASE+':'+PREFIX+inherited_name)
    deferred=json.loads(inherited_raw)['deferred_numerical_cases'];assert len(deferred)==2
    assert all(v['classification']=='NUMERICAL_DEFECT' and v['still_functional_migration_gap'] for v in deferred)
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==948
    coadmission.update(contexts=1004,short35_contexts=coadmission['short35_contexts']+56,native_calendar_samples=coadmission['native_calendar_samples']+392,exact_cold_windows=coadmission['exact_cold_windows']+176,new_closed_implicit_state_contexts=56,new_closed_implicit_state_primary_days=1960,new_closed_implicit_state_compiled_refusals=1608,new_closed_implicit_state_external_transactions=56,previous_canonical=BASE)
    return dict(status='BOUNDED_CLOSED_IMPLICIT_ORDINARY_SNOW_FROST_ORIGINAL_INPUT_NATIVE_COLD_YEAR_TRANSACTIONS_AND_SOURCE_PASS',actual_current_source=current,parent_historical_admission=parent,actual_raw_custody=raw,actual_original_portable_CI_custody=ci,new_original_portable_science=results,additional_actual_local_science=actual_local,actual_old_numerical_and_native_preservation=actual_preservation,coadmission=coadmission,deferred_numerical_cases=deferred,current_finite_batch_deferred_numerical_cases=plan['deferred_numerical_cases'],scientific_change_class='EXISTING_PROCESS_COMPOSITION_WITH_SOURCE_PROVED_CONDITIONAL_NUMERICAL_ITERATE_POLICY',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,new_numerical_policy=True,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
