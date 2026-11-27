"""Own real closed default calendar science and genuine canonical1004 admission."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_default_calendar_source_custody import ROOT,source,git,BASE,PREFIX
from closed_default_calendar_parent_admission import parent_admission
from closed_default_calendar_portable_science import audit as portable
from closed_default_calendar_local_archive_science import audit as local
from closed_default_calendar_preservation_science import audit as preservation
from closed_default_calendar_inherited_domains import audit as inherited_domains
from closed_default_calendar_ci_custody import audit as ci_custody
import closed_implicit_state_verify as previous
SEALED='9f5f428f4dc40ed6b52512e751369113d9313ec4'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('CLOSED_DEFAULT_CALENDAR_STATE14_') or not name.endswith('.json'):continue
        q=frozen(name[:-5])
        if not isinstance(q,dict) or not {'archive','bytes','sha256'}<=q.keys():continue
        pieces=[]
        for part in q.get('parts',[dict(file=q['archive'],bytes=q['bytes'],sha256=q['sha256'])]):
            raw=(data/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];pieces.append(raw)
        raw=b''.join(pieces);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            assert len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(q['members'])
            for key,item in q['members'].items():
                value=z.read(key);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
            count=len(z.namelist())
        observed.append(dict(archive=q['archive'],bytes=q['bytes'],sha256=q['sha256'],members=count))
    assert len(observed)==9
    return observed


def guard_previous_source():
    source(SEALED);parent_admission();raw_custody();ci_custody(data_source());return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);parent=parent_admission();data=data_source();raw=raw_custody();ci=ci_custody(data)
    assert ci==frozen('CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_CI_INDEPENDENT_V1')
    results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            value=portable(data,platform,opt);assert value==frozen('CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_'+platform.upper()+'_'+opt+'_INDEPENDENT_V1');results.append(value)
    actual_local=local(data);assert actual_local==frozen('CLOSED_DEFAULT_CALENDAR_STATE14_TEN_LOCAL_ARCHIVE_INDEPENDENT_V2')
    actual_preservation=preservation(data);assert actual_preservation==frozen('CLOSED_DEFAULT_CALENDAR_STATE14_FORTY_OLD_OBJECT_PRESERVATION_INDEPENDENT_V1')
    actual_inherited=inherited_domains();assert actual_inherited==frozen('CLOSED_DEFAULT_CALENDAR_STATE14_FIFTYSIX_INHERITED_DOMAINS_INDEPENDENT_V1')
    assert tuple(sum(value[key] for value in results) for key in ['context_count','primary_days','native_samples','exact_cold_windows','compiled_native_refusals','external_transaction_contexts'])==(20,700,140,60,584,20)
    plan=frozen('CLOSED_DEFAULT_CALENDAR_STATE14_FINITE_CASE_PLAN_V1');assert len(plan['independent_qualification_cases'])==len(plan['cases'])==5
    deferred_name='CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3.json';inherited_raw=(data/deferred_name).read_bytes();assert inherited_raw==git('show',BASE+':'+PREFIX+deferred_name)
    deferred=json.loads(inherited_raw)['deferred_numerical_cases'];assert len(deferred)==2
    assert all(value['classification']=='NUMERICAL_DEFECT' and value['still_functional_migration_gap'] for value in deferred)
    mcsol=frozen('CLOSED_DEFAULT_CALENDAR_STATE14_MCSOL_UNCHANGED_DEPENDENCY_SELECTION_V1')
    assert mcsol['actual_accepted_parent']==BASE and mcsol['unchanged_tracked_files']==1063 and mcsol['new_model_periods']==0 and mcsol['new_PASS_claimed'] is False
    assert not git('diff',BASE,'HEAD','--',*mcsol['unchanged_dependency_paths'])
    inventory=git('ls-tree','-r','HEAD','--',*mcsol['unchanged_dependency_paths']);assert SHA(inventory)==mcsol['actual_Git_inventory_sha256'] and len(inventory.splitlines())==1063
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==1004
    coadmission.update(contexts=1024,short35_contexts=coadmission['short35_contexts']+20,native_calendar_samples=coadmission['native_calendar_samples']+140,exact_cold_windows=coadmission['exact_cold_windows']+60,
        new_closed_default_calendar_contexts=20,new_closed_default_calendar_primary_days=700,new_closed_default_calendar_compiled_refusals=584,new_closed_default_calendar_external_transactions=20,previous_canonical=BASE)
    return dict(status='BOUNDED_ORIGINAL_CLOSED_DEFAULT_MODEL1_PRESSURE_CALENDAR_NATIVE_COLD_AND_TRANSACTIONS_SOURCE_PASS',actual_current_source=current,parent_historical_admission=parent,
        actual_raw_custody=raw,actual_original_portable_CI_custody=ci,new_original_portable_science=results,additional_actual_local_science=actual_local,
        actual_old_numerical_and_native_preservation=actual_preservation,actual_non1_closed_domains_preserved=actual_inherited,unchanged_MCSOL_selection=mcsol,coadmission=coadmission,
        deferred_numerical_cases=deferred,current_finite_batch_deferred_numerical_cases=[],scientific_change_class='EXISTING_DEFAULT_HYDRAULIC_PROCESS_STATE_AND_OUTPUT_COMPOSITION',
        additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',
        new_physical_state=False,physical_equations_changed=False,new_numerical_policy=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,
        compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
