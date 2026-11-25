"""Actual-source HYS2 boundary/calendar owner; admission requires frozen64 proof."""
from contextlib import ExitStack
from pathlib import Path
import io,json,zipfile
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from frost_implicit_hys2_source_custody import ROOT,source,git,BASE
from frost_implicit_hys2_inherited_custody import inherited_evidence
from frost_implicit_hys2_parent_admission import parent_admission
from frost_implicit_hys2_central import audit
from frost_implicit_plate_central import audit as parent_science
from frost_boundary_state_calendar_central import audit as prior_calendar_science
from frost_boundary_state_calendar_postimage_custody import audit as prior_postimages
import frost_implicit_plate_verify as previous
import frost_boundary_state_calendar_verify as calendar_previous
SEALED='0000000000000000000000000000000000000000'
PREFIX='integration/f-ci/nomacro-complete01/'
PRIOR_CALENDAR='087fc67db3e1e58d45215522eb284e89cb6c12f1'


def frozen(name):
    from frost_implicit_hys2_metadata import raw
    value=raw(name+'.json');assert value==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(value)


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def raw_custody():
    data=data_source();observed=[]
    for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
        name=Path(path).name
        if not name.startswith('FROST_IMPLICIT_HYS2_YEAR06_') or not name.endswith('.json'):continue
        item=frozen(name[:-5])
        if not {'archive','sha256','members','parts'}<=item.keys():continue
        with ExitStack() as stack:
            store=Archive(data,name[:-5],stack);assert store.record==item
            for member in store.names:store.get(member)
            observed.append(dict(archive=name[:-5],sha256=item['sha256'],bytes=item['bytes'],members=len(store.names)))
    item=frozen('FROST_IMPLICIT_HYS2_YEAR06_ORIGINAL_CAUSAL_RAW_V1');raw=(data/item['archive']).read_bytes()
    assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        manifest=json.loads(z.read('MEMBER_MANIFEST_V1.json'))
        assert set(z.namelist())==set(manifest)|{'MEMBER_MANIFEST_V1.json'} and len(z.namelist())==item['members']
        for name,entry in manifest.items():
            value=z.read(name);assert len(value)==entry['bytes'] and SHA(value)==entry['sha256']
    observed.append(dict(archive=item['archive'],sha256=item['sha256'],bytes=item['bytes'],members=item['members'],mixed_compiler_causal_diagnostic_not_qualification=True))
    assert len(observed)>=6
    return observed


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();raw=raw_custody();data=data_source()
    # Explicit real historical data revisions retain the scope of their original
    # observations. Changed implicit5 contexts are independently requalified below.
    historical=prior_calendar_science(GitArchiveSource(ROOT,PRIOR_CALENDAR))
    assert historical==calendar_previous.frozen('FROST_BOUNDARY_STATE_CALENDAR04_COMPLETE52_CENTRAL_V1')
    historical_objects=prior_postimages(GitArchiveSource(ROOT,PRIOR_CALENDAR),comparison_revision=PRIOR_CALENDAR)
    assert historical_objects==calendar_previous.frozen('FROST_BOUNDARY_STATE_CALENDAR04_CURRENT16_POSTIMAGE_CENTRAL_V1')
    plates=parent_science(GitArchiveSource(ROOT,BASE))
    assert plates==previous.frozen('FROST_IMPLICIT_PLATE05_COMPLETE32_CENTRAL_V1')
    science=audit(data);assert science==frozen('FROST_IMPLICIT_HYS2_YEAR06_COMPLETE64_CENTRAL_V1')
    additions=[x for x in science['actual_contexts'] if not x['case']['requalified_parent']]
    renewed=[x for x in science['actual_contexts'] if x['case']['requalified_parent']]
    assert len(additions)==48 and len(renewed)==16 and all(x['case']['days']==35 for x in renewed)
    coadmission=dict(parent['receipt']['coadmission'])
    coadmission.update(contexts=coadmission['contexts']+len(additions),
        short35_contexts=coadmission['short35_contexts']+sum(x['case']['days']==35 for x in additions),
        native_calendar_samples=coadmission['native_calendar_samples']+sum(x['native_samples'] for x in additions),
        exact_cold_windows=coadmission['exact_cold_windows']+sum(x['exact_cold_windows'] for x in additions),
        new_frost_implicit_hys2_contexts=48,requalified_implicit5_contexts=16,
        new_frost_implicit_hys2_current_postimages=32,
        new_frost_implicit_hys2_object_comparisons=sum(x['whole_object_count'] for x in science['actual_current_inherited_compiled_postimages']),
        previous_canonical=BASE)
    assert coadmission['contexts']==648
    return dict(status='BOUNDED_ORIGINAL_IMPLICIT_FROST_HYS2_BOUNDARY_ACTUAL_TRIAL_FLUX_NATIVE_COLD_CONTROLS_AND_UNCHANGED_WHOLE_OBJECTS_PASS',
        actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,
        inherited_original_calendar_science=historical,historical_original_bottom5_postimages=historical_objects,
        inherited_original_plate_science=plates,new_original_science=science,actual_new_raw_custody=raw,coadmission=coadmission,
        historical_bottom5_postimages_claimed_unchanged_on_current_source=False,
        changed_implicit5_requalified_contexts=16,original_scientific_water_limit_cm='1e-10',
        original_accumulated_water_drift_is_diagnostic_not_equivalence=True,
        original_day5_clock_failure_preserved=True,original_mixed_compiler_diagnostics_used_as_qualification=False,
        selected_implicit_hys2_calendars_implemented_and_qualified=True,
        new_physical_state=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,
        automatic_fallback=False,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
