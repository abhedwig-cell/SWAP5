"""Own actual initial1/2 composition and the genuine admitted canonical1024 parent."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_initialization_calendar_source_custody import ROOT,PREFIX,BASE,source,git
from closed_initialization_calendar_parent_admission import parent_admission
from closed_initialization_calendar_portable_science import audit as portable
from closed_initialization_calendar_local_archive_science import audit as local
from closed_initialization_calendar_preservation_science import audit as preservation
from closed_initialization_calendar_inherited_selection import audit as inherited40
from closed_default_calendar_inherited_domains import audit as inherited56
from closed_initialization_calendar_ci_custody import audit as ci_custody
import closed_default_calendar_verify as previous
SEALED='349340db4e80f7dff0e01ee6dc450dad75cd6879'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('CLOSED_INITIALIZATION_STATE15_') or not name.endswith('.json'):continue
        record=frozen(name[:-5])
        if not isinstance(record,dict) or not {'archive','bytes','sha256'}<=record.keys():continue
        pieces=[]
        for part in record.get('parts',[dict(file=record['archive'],bytes=record['bytes'],sha256=record['sha256'])]):
            raw=(data/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];pieces.append(raw)
        raw=b''.join(pieces);assert len(raw)==record['bytes'] and SHA(raw)==record['sha256']
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            assert len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(record['members'])
            for member,item in record['members'].items():
                value=z.read(member);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
            count=len(z.namelist())
        observed.append(dict(archive=record['archive'],bytes=record['bytes'],sha256=record['sha256'],members=count))
    assert len(observed)==8
    return observed


def guard_previous_source():
    source(SEALED);parent_admission();raw_custody();ci_custody(data_source());return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);parent=parent_admission();data=data_source();raw=raw_custody();ci=ci_custody(data)
    assert ci==frozen('CLOSED_INITIALIZATION_STATE15_ORIGINAL_CI_INDEPENDENT_V1')
    results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            observed=portable(data,platform,opt);assert observed==frozen('CLOSED_INITIALIZATION_STATE15_FIRST_'+platform.upper()+'_'+opt+'_INDEPENDENT_V1');results.append(observed)
    local_science=local(data);assert local_science==frozen('CLOSED_INITIALIZATION_STATE15_TEN_LOCAL_ARCHIVE_INDEPENDENT_V1')
    old_science=preservation(data);assert old_science==frozen('CLOSED_INITIALIZATION_STATE15_CURRENT_OLD_PRESERVATION_INDEPENDENT_V1')
    inherited=inherited40();original_inherited=frozen('CLOSED_INITIALIZATION_STATE15_FORTY_INHERITED_SOURCE_SELECTION_V1')
    # Preserve the original probe's actual observer; do not relabel it as HEAD.
    expected=dict(original_inherited);expected.pop('actual_current_observer');assert inherited==expected
    actual_non1=inherited56();original_non1=frozen('CLOSED_INITIALIZATION_STATE15_FIFTYSIX_INHERITED_DOMAINS_V1')
    assert actual_non1==original_non1['current_new_initialization_branch_exclusions']
    assert tuple(sum(v[k] for v in results) for k in ['context_count','primary_days','native_samples','exact_cold_windows','compiled_native_refusals','external_transaction_contexts'])==(20,700,140,60,584,20)
    plan=frozen('CLOSED_INITIALIZATION_STATE15_FINITE_CASE_PLAN_V1');assert len(plan['cases'])==len(plan['independent_qualification_cases'])==5
    assert all(v['initial']==2 and v['bottom']==6 and v['drainage']==0 and v['hydraulic_model']==1 for v in plan['cases'])
    original_deferred='CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3.json';deferred_raw=(data/original_deferred).read_bytes();assert deferred_raw==git('show',BASE+':'+PREFIX+original_deferred)
    deferred=json.loads(deferred_raw)['deferred_numerical_cases'];assert len(deferred)==2 and all(v['classification']=='NUMERICAL_DEFECT' and v['still_functional_migration_gap'] for v in deferred)
    mcsol=frozen('CLOSED_INITIALIZATION_STATE15_MCSOL_UNCHANGED_SELECTION_V1');assert mcsol['actual_accepted_parent']==BASE and mcsol['unchanged_tracked_files']==1063 and mcsol['new_model_periods']==0 and mcsol['new_scientific_PASS_claimed'] is False
    assert not git('diff',BASE,'HEAD','--',*mcsol['unchanged_dependency_paths']);inventory=git('ls-tree','-r','HEAD','--',*mcsol['unchanged_dependency_paths']);assert SHA(inventory)==mcsol['actual_Git_inventory_sha256'] and len(inventory.splitlines())==1063
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==1024
    coadmission.update(contexts=1044,short35_contexts=coadmission['short35_contexts']+20,native_calendar_samples=coadmission['native_calendar_samples']+140,exact_cold_windows=coadmission['exact_cold_windows']+60,previous_canonical=BASE,
        new_closed_initialization_contexts=20,new_closed_initialization_primary_days=700,new_closed_initialization_compiled_refusals=584,new_closed_initialization_external_transactions=20)
    return dict(status='BOUNDED_ORIGINAL_CLOSED_DEFAULT_GROUNDWATER_INITIALIZATION_CALENDAR_NATIVE_COLD_AND_TRANSACTIONS_SOURCE_PASS',actual_current_source=current,parent_historical_admission=parent,actual_raw_custody=raw,actual_original_portable_CI_custody=ci,
        new_original_portable_science=results,additional_actual_local_science=local_science,actual_old_initial1_numerical_and_canonical_native_preservation=old_science,
        inherited_old40_unchanged_source_selection=inherited,original_inherited_old40_probe=original_inherited,actual_non1_closed_domains_preserved=actual_non1,original_non1_probe=original_non1,unchanged_MCSOL_selection=mcsol,coadmission=coadmission,
        deferred_numerical_cases=deferred,current_finite_batch_deferred_numerical_cases=[],scientific_change_class='EXISTING_DEFAULT_GROUNDWATER_INITIALIZATION_AND_CLOSED_OUTPUT_STATE_COMPOSITION',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,
        original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,new_numerical_policy=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,
        compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
