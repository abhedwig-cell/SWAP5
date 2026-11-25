"""Bounded canonical500 plus original Frost boundary24 source/raw authority."""
from contextlib import ExitStack
import json
from pathlib import Path
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
from frost_boundary_source_custody import ROOT,source,git
from frost_boundary_inherited_custody import inherited_evidence
from frost_boundary_parent_admission import parent_admission
from frost_boundary_central import audit
from frost_calendar_state_central import audit as parent_calendar_audit
import frost_calendar_state_verify as previous

SEALED='61f099f4c5ea2a496e6da5d6d55ca57d93192fea'
RAW_NAMES=('FROST_BOUNDARY03_DISCOVERY_RAW_V1',)+tuple('FROST_BOUNDARY03_'+platform+'_'+opt+'_ORIGINAL_V'+str(version)
    for platform in ('WINDOWS','UBUNTU') for opt in ('O0','O2') for version in (1,2,3,4))


def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json'
    raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show',SEALED+':'+path)
    return json.loads(raw)


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def raw_custody():
    observed=[];data=data_source()
    with ExitStack() as stack:
        for name in RAW_NAMES:
            declaration=frozen(name);store=Archive(data,name,stack);assert store.record==declaration
            for member in store.names:store.get(member)
            observed.append(dict(archive=name,sha256=declaration['sha256'],bytes=declaration['bytes'],members=len(store.names)))
    return observed


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):
    line='            /integration/f-ci/nomacro-complete01/FROST_BOUNDARY03_*.json\n'
    assert text.count(line)==1
    return previous.strip_current_evidence(text.replace(line,'',1))


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();raw=raw_custody();data=data_source()
    old=parent_calendar_audit(data);assert old==frozen('FROST_CALENDAR_STATE02_COMPLETE_SELECTED_COHORT_CENTRAL_V1')
    science=audit(data);assert science==frozen('FROST_BOUNDARY03_COMPLETE24_CENTRAL_V1')
    return dict(status='BOUNDED_ORIGINAL_FROST_BOUNDARY_SOURCE_DAILY_BUDGETS_NATIVE_COLD_AND_EXACT_PARENT_POSTIMAGES_PASS',
        actual_current_source=current,fresh_inherited_evidence=inherited,parent_actual_admission=parent,
        inherited_original_calendar_science=old,new_original_science=science,actual_new_raw_custody=raw,
        coadmission=dict(contexts=524,short35_contexts=510,year367_contexts=2,new_short_calendar_contexts=12,
            new_frost_calendar_state_contexts=28,new_frost_boundary_contexts=24,
            native_calendar_samples=3618,exact_cold_windows=1556,compiled_initialization_postimages=375,
            current_unselected_dense_compiled_postimages=4,current_selected_boundary_generated_compiled_postimages=20,
            previous_canonical='1c3b8725548c836c9a73570c2579dd6cdc683217'),
        original_scientific_water_limit_cm='1e-10',original_accumulated_water_drift_is_diagnostic_not_equivalence=True,
        original_implicit8_zero_day_clock_resolution_failures_preserved=True,implicit8_publicly_admitted=False,
        new_physical_state=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
