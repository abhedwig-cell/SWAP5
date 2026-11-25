"""Current real-source implicit plate composition and exact calendar authority."""
from contextlib import ExitStack
from pathlib import Path
import io,json,zipfile
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_implicit_plate_source_custody import ROOT,source,git,BASE
from frost_implicit_plate_inherited_custody import inherited_evidence
from frost_implicit_plate_parent_admission import parent_admission
from frost_implicit_plate_central import audit
from frost_boundary_state_calendar_central import audit as previous_science
from frost_boundary_state_calendar_postimage_custody import audit as previous_postimages
import frost_boundary_state_calendar_verify as previous
SEALED='c55c1a212d669758d09634dcb77eeac57864403d'
PREFIX='integration/f-ci/nomacro-complete01/'


def frozen(name):
    from frost_implicit_plate_metadata import raw
    value=raw(name+'.json');assert value==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(value)


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('FROST_IMPLICIT_PLATE05_') or not name.endswith('.json'):continue
        item=frozen(name[:-5])
        if not {'archive','sha256','members','parts'}<=item.keys():continue
        with ExitStack() as stack:
            store=Archive(data,name[:-5],stack);assert store.record==item
            for member in store.names:store.get(member)
            observed.append(dict(archive=name[:-5],sha256=item['sha256'],bytes=item['bytes'],members=len(store.names)))
    item=frozen('FROST_IMPLICIT_PLATE05_ORIGINAL_CAUSAL_DIAGNOSTIC_RAW_V1');raw=(data/item['archive']).read_bytes()
    assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        manifest=json.loads(z.read('MEMBER_MANIFEST_V1.json'));assert set(z.namelist())==set(manifest)|{'MEMBER_MANIFEST_V1.json'} and len(z.namelist())==item['members']
        for name,entry in manifest.items():value=z.read(name);assert len(value)==entry['bytes'] and SHA(value)==entry['sha256']
    observed.append(dict(archive=item['archive'],sha256=item['sha256'],bytes=item['bytes'],members=item['members'],mixed_compiler_causal_diagnostic_not_qualification=True))
    assert len(observed)>=11
    return observed


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();raw=raw_custody();data=data_source()
    historical=previous_science(GitArchiveSource(ROOT,BASE))
    assert historical==previous.frozen('FROST_BOUNDARY_STATE_CALENDAR04_COMPLETE52_CENTRAL_V1')
    old_objects=previous_postimages(GitArchiveSource(ROOT,BASE),comparison_revision=BASE)
    assert old_objects==previous.frozen('FROST_BOUNDARY_STATE_CALENDAR04_CURRENT16_POSTIMAGE_CENTRAL_V1')
    science=audit(data);assert science==frozen('FROST_IMPLICIT_PLATE05_COMPLETE32_CENTRAL_V1')
    coadmission=dict(parent['receipt']['coadmission'])
    coadmission.update(contexts=600,short35_contexts=570,new_frost_implicit_plate_contexts=32,
        new_frost_implicit_plate_current_postimages=16,new_frost_implicit_plate_object_comparisons=sum(x['whole_object_count'] for x in science['actual_current_inherited_compiled_postimages']),
        native_calendar_samples=4070,exact_cold_windows=1752,previous_canonical=BASE)
    return dict(status='BOUNDED_ORIGINAL_IMPLICIT_FROST_PLATE_ACTUAL_TRIAL_FLUX_PENDING_DATE_NATIVE_COLD_CONTROLS_AND_UNCHANGED_WHOLE_OBJECTS_PASS',
        actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,
        inherited_original_boundary_calendar_science=historical,inherited_boundary5_whole_object_postimages=old_objects,
        new_original_science=science,actual_new_raw_custody=raw,coadmission=coadmission,
        original_scientific_water_limit_cm='1e-10',original_accumulated_water_drift_is_diagnostic_not_equivalence=True,
        original_implicit8_zero_day_and_pending_date_cold_failures_preserved=True,
        original_mixed_compiler_causal_diagnostics_used_as_qualification=False,
        selected_implicit8_public_route_implemented_and_qualified=True,new_implicit_hys2_calendars_publicly_admitted=False,
        new_physical_state=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,
        automatic_fallback=False,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
