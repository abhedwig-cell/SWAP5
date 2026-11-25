"""Bounded existing Frost calendar composition and actual admitted parent custody."""
from contextlib import ExitStack
import json
from pathlib import Path
from analytical_hydraulic_archives import Archive
from frost_calendar_state_source_custody import ROOT,source,inherited_evidence,git
from frost_calendar_state_parent_admission import parent_admission
from frost_calendar_state_central import audit
import frost_history_state_verify as previous

P=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='c8001b3f45d9a131436ec8719bbd1c6c0fc48e5c'
RAW_NAMES=('FROST_CALENDAR_STATE02_WINDOWS_LOCAL_RAW_V1',
    'FROST_CALENDAR_STATE02_WINDOWS_CI_O0_ORIGINAL_V1','FROST_CALENDAR_STATE02_WINDOWS_CI_O2_ORIGINAL_V1',
    'FROST_CALENDAR_STATE02_UBUNTU_O0_ORIGINAL_V1','FROST_CALENDAR_STATE02_UBUNTU_O2_ORIGINAL_V1')


def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    assert raw==git('show',SEALED+':'+path)
    return json.loads(raw)


def raw_custody():
    result=[]
    with ExitStack() as stack:
        for name in RAW_NAMES:
            declaration=frozen(name);store=Archive(P,name,stack);assert store.record==declaration
            for member in store.names:store.get(member)
            result.append(dict(archive=name,sha256=declaration['sha256'],bytes=declaration['bytes'],members=len(store.names)))
    return result


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission(SEALED);raw_custody();return True


def strip_current_evidence(text):
    line='            /integration/f-ci/nomacro-complete01/FROST_CALENDAR_STATE02_*\n'
    if line in text:
        assert text.count(line)==1,'Ambiguous Frost calendar evidence checkout addition';text=text.replace(line,'',1)
    return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission(SEALED);raw=raw_custody()
    science=audit(P);assert science==frozen('FROST_CALENDAR_STATE02_COMPLETE_SELECTED_COHORT_CENTRAL_V1')
    return dict(status='BOUNDED_EXISTING_FROST_CALENDAR_SOURCE_DAILY_RECEIPT_ORIGINAL_SCIENCE_NATIVE_COLD_AND_DENSE_PRESERVATION_PASS',
        actual_current_source=current,fresh_inherited_evidence=inherited,parent_actual_admission=parent,
        new_original_science=science,actual_new_raw_custody=raw,
        coadmission=dict(contexts=500,short35_contexts=486,year367_contexts=2,new_short_calendar_contexts=12,
            new_frost_calendar_state_contexts=28,native_calendar_samples=3450,exact_cold_windows=1484,
            compiled_initialization_postimages=375,current_unselected_dense_compiled_postimages=4,
            previous_canonical='8dbe3db7c7832dd6a1f86c4275cd43f054552df3'),
        original_scientific_water_limit_cm='1e-10',original_accumulated_water_drift_is_diagnostic_not_equivalence=True,
        new_physical_state=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',
        global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
