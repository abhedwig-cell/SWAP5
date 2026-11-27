"""Own actual implicit/history initial1/2 state and genuine admitted canonical1044 parent."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_joint_history_calendar_source_custody import ROOT,PREFIX,BASE,source,git
from closed_joint_history_calendar_parent_admission import parent_admission
from closed_joint_history_calendar_portable_science import audit as portable
from closed_joint_history_calendar_local_archive_science import audit as local
from closed_joint_history_calendar_native_recovery_science import audit as native_recovery
from closed_joint_history_calendar_inherited_selection import audit as admitted40,local_unaffected
from closed_initialization_calendar_inherited_selection import audit as inherited40
from closed_default_calendar_inherited_domains import audit as inherited56
from closed_joint_history_calendar_ci_custody import audit as ci_custody
import closed_initialization_calendar_verify as previous
SEALED='420b142921be6829b51c7af86dc859977d33d3e5'


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def frozen(name):
    raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('CLOSED_JOINT_HISTORY_STATE16_') or not name.endswith('.json'):continue
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
    assert ci==frozen('CLOSED_JOINT_HISTORY_STATE16_ORIGINAL_CI_INDEPENDENT_V1')
    portable_results=[]
    for platform in ['Ubuntu','Windows']:
        for opt in ['O0','O2']:
            value=portable(data,platform,opt);assert value==frozen('CLOSED_JOINT_HISTORY_STATE16_FIRST_'+platform.upper()+'_'+opt+'_INDEPENDENT_V1');portable_results.append(value)
    assert tuple(sum(v[k] for v in portable_results) for k in ['context_count','primary_days','native_samples','exact_cold_windows','compiled_native_refusals','external_transaction_contexts'])==(24,840,168,72,744,24)
    local_science=local(data);assert local_science==frozen('CLOSED_JOINT_HISTORY_STATE16_LOCAL_ARCHIVE_INDEPENDENT_V1')
    assert local_science['context_count']==12 and local_science['primary_days']==420 and local_science['original_native_failure_contexts_not_qualified']==4
    recovery=native_recovery(data);assert recovery==frozen('CLOSED_JOINT_HISTORY_STATE16_CURRENT_NATIVE_RECOVERY_INDEPENDENT_V1')
    assert (recovery['current_compiled_contexts'],recovery['unchanged_whole_objects'],recovery['exact_original_native_positives'],recovery['compiled_native_refusals'])==(4,88,28,112)
    unaffected=local_unaffected(data);original_unaffected=frozen('CLOSED_JOINT_HISTORY_STATE16_EIGHT_LOCAL_UNAFFECTED_SELECTION_V1')
    expected=dict(original_unaffected);expected.pop('actual_current_observer');assert unaffected==expected
    old=inherited40();old_probe=frozen('CLOSED_JOINT_HISTORY_STATE16_FORTY_OLD_SOURCE_SELECTION_V1');assert old==old_probe['original_literal_audit_result'] and old_probe['source_or_HEAD_projected'] is False
    non1=inherited56();non1_probe=frozen('CLOSED_JOINT_HISTORY_STATE16_FIFTYSIX_NON1_SOURCE_SELECTION_V1');assert non1==non1_probe['original_literal_audit_result'] and non1_probe['source_or_HEAD_projected'] is False
    defaults=admitted40();default_probe=frozen('CLOSED_JOINT_HISTORY_STATE16_FORTY_ADMITTED_DEFAULT_POLICY_SELECTION_V1');assert defaults==default_probe['actual_original_policy_selection'] and default_probe['source_or_HEAD_projected'] is False
    plan=frozen('CLOSED_JOINT_HISTORY_STATE16_FINITE_CASE_PLAN_V1');assert len(plan['cases'])==len(plan['independent_qualification_cases'])==6
    assert all(v['initial'] in (1,2) and v['history'] in (1,2) and v['implicit']==1 and v['hydraulic_model']==1 and v['bottom']==6 and v['drainage']==v['snow']==v['frost']==0 for v in plan['cases'])
    name='CLOSED_GARDNER_STATE12_FINITE_CASE_PLAN_V3.json';deferred_raw=(data/name).read_bytes();assert deferred_raw==git('show',BASE+':'+PREFIX+name)
    deferred=json.loads(deferred_raw)['deferred_numerical_cases'];assert len(deferred)==2 and all(v['classification']=='NUMERICAL_DEFECT' and v['still_functional_migration_gap'] for v in deferred)
    mcsol=frozen('CLOSED_JOINT_HISTORY_STATE16_MCSOL_UNCHANGED_SELECTION_V1');assert mcsol['actual_accepted_parent']==BASE and mcsol['unchanged_tracked_files']==1063 and mcsol['new_model_periods']==0 and mcsol['new_scientific_PASS_claimed'] is False
    assert not git('diff',BASE,'HEAD','--',*mcsol['unchanged_dependency_paths']);inventory=git('ls-tree','-r','HEAD','--',*mcsol['unchanged_dependency_paths']);assert SHA(inventory)==mcsol['actual_Git_inventory_sha256'] and len(inventory.splitlines())==1063
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==1044
    coadmission.update(contexts=1068,short35_contexts=coadmission['short35_contexts']+24,native_calendar_samples=coadmission['native_calendar_samples']+168,exact_cold_windows=coadmission['exact_cold_windows']+72,previous_canonical=BASE,new_closed_joint_history_contexts=24,new_closed_joint_history_primary_days=840,new_closed_joint_history_compiled_refusals=744,new_closed_joint_history_external_transactions=24)
    return dict(status='BOUNDED_ORIGINAL_CLOSED_IMPLICIT_HISTORY_INITIAL12_NONDAILY_NATIVE_CALENDAR_COLD_AND_TRANSACTION_SOURCE_PASS',actual_current_source=current,parent_historical_admission=parent,actual_raw_custody=raw,actual_original_portable_CI_custody=ci,new_original_portable_science=portable_results,additional_actual_original_local_science=local_science,actual_current_native_recovery_of_original_local_checkpoints=recovery,unaffected_original_local_source_selection=unaffected,original_unaffected_local_probe=original_unaffected,inherited_old40_unchanged_source_selection=old,original_inherited_old40_probe=old_probe,actual_non1_closed_domains_preserved=non1,original_non1_probe=non1_probe,admitted_default_original_policy_selection=defaults,original_admitted_default_policy_probe=default_probe,unchanged_MCSOL_selection=mcsol,coadmission=coadmission,deferred_numerical_cases=deferred,current_finite_batch_deferred_numerical_cases=[],scientific_change_class='EXISTING_IMPLICIT_HYSTERESIS_INITIAL12_CLOSED_NONDAILY_STATE_COMPOSITION_AND_NATIVE_VALIDATION',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_native_failure_roles_relabelled=False,native_counters_or_dates_normalized=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,new_numerical_policy=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))

