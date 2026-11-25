"""Current real-source plate convergence and boundary/state/calendar authority."""
from contextlib import ExitStack
import json
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_state_calendar_source_custody import ROOT,source,git
from frost_boundary_state_calendar_inherited_custody import inherited_evidence
from frost_boundary_state_calendar_parent_admission import parent_admission
from frost_boundary_state_calendar_central import audit
from frost_boundary_state_calendar_postimage_custody import audit as postimage_audit
from frost_boundary_central import audit as historical_boundary_audit
from frost_calendar_state_central import audit as parent_calendar_audit
from frost_boundary_convergence import require_convergence
import frost_boundary_verify as previous

SEALED='0000000000000000000000000000000000000000'
PREFIX='integration/f-ci/nomacro-complete01/'


def frozen(name):
    path=PREFIX+name+'.json'
    from frost_boundary_state_calendar_metadata import raw as metadata_raw
    raw=metadata_raw(name+'.json')
    assert raw==git('show',SEALED+':'+path)
    return json.loads(raw)


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def raw_custody():
    observed=[];data=data_source()
    files=git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines()
    for path in files:
        name=Path(path).name
        if not name.startswith('FROST_BOUNDARY_STATE_CALENDAR04_') or not name.endswith('.json'):continue
        declaration=frozen(name[:-5])
        if not {'archive','sha256','members','parts'}<=declaration.keys():continue
        with ExitStack() as stack:
            store=Archive(data,name[:-5],stack);assert store.record==declaration
            for member in store.names:store.get(member)
            dependencies={}
            for dependency,claim in declaration.get('exact_original_byte_dependencies',{}).items():
                original=Archive(data,dependency,stack);assert original.record['sha256']==claim.get('sha256',claim.get('archive_sha256'))
                dependencies[dependency]=original
            for item in declaration.get('physical_inventory',{}).values() if isinstance(declaration.get('physical_inventory'),dict) else ():
                if 'member' in item:raw=store.get(item['member'])
                else:
                    reference=item['inherited_exact_original_bytes'];key=reference.get('archive',reference.get('original_archive'))
                    raw=dependencies[key].get(reference['member'])
                assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
            observed.append(dict(archive=name[:-5],sha256=declaration['sha256'],bytes=declaration['bytes'],members=len(store.names)))
    assert len(observed)>=30
    return observed


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();raw=raw_custody();data=data_source()
    calendar=parent_calendar_audit(data)
    assert calendar==previous.frozen('FROST_CALENDAR_STATE02_COMPLETE_SELECTED_COHORT_CENTRAL_V1')
    historical=historical_boundary_audit(data)
    assert historical==previous.frozen('FROST_BOUNDARY03_COMPLETE24_CENTRAL_V1')
    unchanged=[x for x in historical['contexts_original'] if x['case']['bottom']==5]
    assert len(unchanged)==16
    with ExitStack() as stack:
        stores={}
        for item in unchanged:
            platform=item['platform'].upper();opt=item['optimization'];case=item['case']['name']
            version=4 if case=='cde-bottom5-implicit1-hys2-initial2' else 3
            name=f'FROST_BOUNDARY03_{platform}_{opt}_ORIGINAL_V{version}'
            if name not in stores:stores[name]=Archive(data,name,stack)
            require_convergence(ReadView(stores[name],'current/'+case+'/science'))
    science=audit(data);assert science==frozen('FROST_BOUNDARY_STATE_CALENDAR04_COMPLETE52_CENTRAL_V1')
    postimages=postimage_audit(data);assert postimages==frozen('FROST_BOUNDARY_STATE_CALENDAR04_CURRENT16_POSTIMAGE_CENTRAL_V1')
    assert science['reopened_parent_context_count']==8 and science['reopened_parent_primary_days']==280
    return dict(status='BOUNDED_ORIGINAL_FROST_BOUNDARY_STATE_CALENDAR_SOURCE_ACTUAL_TRIAL_FLUX_CONVERGENCE_NATIVE_COLD_AND_UNCHANGED_POSTIMAGES_PASS',
        actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,
        inherited_original_calendar_science=calendar,unchanged_parent_bottom5_contexts=unchanged,
        old_parent_plate_convergence_inherited=False,reopened_parent_plate_current_science= science['reopened_parent_contexts'],
        new_original_science=science,current_bottom5_postimages=postimages,actual_new_raw_custody=raw,
        coadmission=dict(contexts=568,short35_contexts=546,year367_contexts=2,new_short_calendar_contexts=12,
            new_frost_calendar_state_contexts=28,new_frost_boundary_contexts=24,new_frost_boundary_state_calendar_contexts=44,
            reopened_parent_plate_contexts=8,native_calendar_samples=3886,exact_cold_windows=1672,
            compiled_initialization_postimages=375,current_unselected_dense_compiled_postimages=4,
            current_bottom5_generated_compiled_postimages=16,current_bottom5_object_comparisons=432,
            previous_canonical='9936bcda75eb920d67aa74e47018baf39ab18f78'),
        original_scientific_water_limit_cm='1e-10',original_accumulated_water_drift_is_diagnostic_not_equivalence=True,
        original_implicit8_zero_day_and_implicit5_hys2_calendar_day5_failures_preserved=True,
        implicit8_publicly_admitted=False,new_implicit_hys2_calendars_publicly_admitted=False,
        new_physical_state=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
