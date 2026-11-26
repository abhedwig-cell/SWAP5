"""Current checkout protocol and exact inherited scientific dependency authority."""
from pathlib import Path
import json
from frost_boundary_git_archive import GitArchiveSource
from ci_checkout_scope07_source_custody import ROOT,source,git,BASE
from ci_checkout_scope07_inherited_custody import inherited_evidence
from ci_checkout_scope07_parent_admission import parent_admission
from ci_checkout_scope07 import audit as protocol_audit
import frost_implicit_hys2_verify as previous
SEALED='c344878cd50f3e8893f9ee6b7d459041db869157'
PREFIX='integration/f-ci/nomacro-complete01/'


def frozen(name):
    from ci_checkout_scope07_metadata import raw
    value=raw(name+'.json');assert value==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(value)


def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())


def inherited_science(data):
    # The new owner changes only checkout transport, a metadata witness and four
    # explicit joint-owner calls. Its source custody checks every old scientific
    # program and engine byte; fresh evidence custody checks every inherited blob.
    # Do not re-run models or re-label their producer for an unchanged surface.
    name='FROST_IMPLICIT_HYS2_YEAR06_COMPLETE64_CENTRAL_V1'
    raw=(data/(name+'.json')).read_bytes()
    assert raw==git('show',BASE+':'+PREFIX+name+'.json')
    science=json.loads(raw);assert science==previous.frozen(name)
    assert (science['contexts'],science['primary_days'],science['native_samples'],science['exact_cold_windows'],science['actual_compiled_refusals'],science['transaction_contexts'])==(64,1872,368,160,4672,96)
    assert len(science['actual_current_inherited_compiled_postimages'])==32 and sum(x['whole_object_count'] for x in science['actual_current_inherited_compiled_postimages'])==916
    return dict(status='EXACT_GENUINE648_ENGINE_PROGRAMS_EVIDENCE_AND_ACCEPTED_SCIENCE_INHERITED_NO_NEW_SCIENTIFIC_PASS_CLAIM',actual_qualified_canonical=BASE,original_scientific_producer='a4f24f74f3b5b82b2673f2695d15fe7ba3990fd6',original_independent_observer='9b4efb16a4c29bc5713e6861d10de41e130742eb',original_summary=name+'.json',inherited_contexts=64,inherited_current_object_postimages=32,inherited_whole_object_comparisons=916,new_scientific_contexts=0,model_periods_replayed=0,scientific_result_reparsed_or_recomputed=False,scientific_producer_rebound=False)


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();inherited_science(data_source());return True


def strip_current_evidence(text):return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();science=inherited_science(data_source());protocol=protocol_audit()
    contract=frozen('CI_CHECKOUT_SCOPE07_CONTRACT_V1')
    assert contract['actual_canonical_dependency']==BASE and contract['parent_admission_archive_sha256']==parent['receipt']['admission_archive_sha256']
    assert contract['dependency_canonical_admission_pending'] is False
    assert protocol['checkout_steps']==43 and protocol['fci_canonical_keeps_complete_versioned_evidence'] and not protocol['engine_source_changed']
    coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==648
    return dict(status='CURRENT_CHECKOUT_ONLY_PROTOCOL_COMPLETE_FROZEN_FCI_EVIDENCE_AND_EXACT_UNCHANGED_SCIENTIFIC_SURFACE_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,inherited_original_scientific_authority=science,current_checkout_protocol=protocol,coadmission=coadmission,
        scientific_change_class='D_READ_ONLY_BUILD_AND_EVIDENCE_TRANSPORT',new_scientific_contexts=0,
        original_model_engine_and_inputs_unchanged=True,all_old_scientific_programs_preserved=True,
        original_scientific_producer_rebound=False,source_or_working_directory_identity_projected=False,
        original_physical_equations_state_or_tolerances_changed=False,automatic_fallback=False,
        compiler_executions=0,model_executions=0,performance_speedup_claimed=False,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
