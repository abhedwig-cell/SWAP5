"""Corrected NoHeat RIA native/reader owner; preserve actual thermal admission."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from ria12_corrected_source import R as ROOT,CORE,git
from ria12_corrected_source_custody import source,inherited_evidence
from ria12_corrected_central_science import audit,thermal_preservation,reference_correction,original_outputs,short_proofs
import ria12_thermal_verify as previous

PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='8264c29e9e8f5b21d9c81ff62751295d690d21b3'
ADMITTED='1e48f182a1415a3ef5224de39559a0ecff0c4c7c'
ADMISSION_SHA='1cb8c57a69dc89028ae8d62ce263600703af7683a0758c93f99d936f75d4bbab'
RAW_NAMES=('RIA12_CORRECTED_WINDOWS_RAW_V1','RIA12_CORRECTED_KSAT_INPUTS_V1','RIA12_CORRECTED_UBUNTU_O0_ORIGINAL_V1','RIA12_CORRECTED_UBUNTU_O2_ORIGINAL_V1')

def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    assert raw==git('show',SEALED+':'+path),'Changed corrected NoHeat scientific declaration '+name
    return json.loads(raw)

def parent_admission():
    with ExitStack() as stack:
        store=Archive(PROOF,'RIA12_THERMAL_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for member in store.names:store.get(member)
        label='RIA12_THERMAL_ACTUAL_CANONICAL_PUBLIC_V1';q=json.loads(store.get(label+'.json'));old=json.loads(store.get(label+'.stdout.txt'))
        assert q['before']==q['after'] and q['before']['head']==ADMITTED and q['returncode']==0 and not store.get(label+'.stderr.txt')
        assert len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
        label='RIA12_THERMAL_ACTUAL_CANONICAL_PUBLICATION_V1';q=json.loads(store.get(label+'.json'))
        assert q['before']==q['after'] and q['before']['head']==ADMITTED and q['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
        assert q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
        stats=old['coadmission'];assert (stats['contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(416,2918,1252,359)
    receipt=json.loads((PROOF/'RIA12_THERMAL_MERGE_RECEIPT_V1.json').read_text());assert receipt['actual_merge']==ADMITTED and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('rev-parse',ADMITTED+'^{tree}').decode().strip()==receipt['whole_qualified_tree']==git('rev-parse',CORE+'^{tree}').decode().strip()
    assert git('show','-s','--format=%P',ADMITTED).decode().split()==receipt['ordered_parents']
    return receipt,old

def raw_custody():
    result=[]
    with ExitStack() as stack:
        for name in RAW_NAMES:
            declaration=frozen(name);store=Archive(PROOF,name,stack)
            for member in store.names:store.get(member)
            result.append(dict(archive=name,sha256=declaration['sha256'],bytes=declaration['bytes'],members=len(declaration['members'])))
    return result

def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True

def strip_current_evidence(text):return previous.strip_current_evidence(text)

def publication_dependencies_unchanged():
    guard_previous_source();return True

def verify():
    current=source(SEALED);inherited=inherited_evidence();parent,old=parent_admission();raw=raw_custody()
    # These readers retain the real historical records. They receive no changed
    # HEAD, filesystem, producer metadata, module namespace or publication view.
    previous.raw_custody();previous.previous.raw_custody();previous.previous.previous.raw_custody()
    thermal={};legacy={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            key=platform.upper()+'_'+opt
            value=previous.audit(platform,opt);assert value==previous.frozen('RIA12_THERMAL_'+key+'_CENTRAL_V1');thermal[key]=value
            primary=previous.previous.previous.audit(platform,opt);assert primary==previous.previous.previous.frozen('RIA12_'+key+'_CENTRAL_V1')
            boundary=previous.previous.audit(platform,opt);assert boundary==previous.previous.frozen('RIA12_BOUNDARY_'+key+'_CENTRAL_V1')
            legacy[key]=dict(primary=primary,boundary=boundary,current_corrected_native_compatibility_claimed=False)
    assert previous.reference_correction()==previous.frozen('RIA12_THERMAL_KSAT_CORRECTION_CENTRAL_V1')
    assert previous.original_outputs()==previous.frozen('RIA12_THERMAL_ORIGINAL_OUTPUT_ALL16_CENTRAL_V1')
    assert previous.short_proofs()==previous.frozen('RIA12_THERMAL_SHORT_ALL4_CENTRAL_V1')
    science={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            name='RIA12_CORRECTED_'+platform.upper()+'_'+opt+'_CENTRAL_V1';value=audit(platform,opt);assert value==frozen(name);science[name]=value
    preserved=thermal_preservation();assert preserved==frozen('RIA12_CORRECTED_THERMAL_PRESERVATION_ALL8_CENTRAL_V1')
    correction=reference_correction();assert correction==frozen('RIA12_CORRECTED_KSAT_CORRECTION_ALL16_CENTRAL_V1')
    outputs=original_outputs();assert outputs==frozen('RIA12_CORRECTED_ORIGINAL_OUTPUT_ALL16_CENTRAL_V1')
    short=short_proofs();assert short==frozen('RIA12_CORRECTED_SHORT_AND_FAILURES_CENTRAL_V1')
    assert short['qualified_original_short_contexts']==14 and short['extra_wet_primary_global_refusals']==2
    contexts=[c for report in science.values() for c in report['contexts']]
    assert len(contexts)==16 and sum(c['native_controls']['native_refusals'] for c in contexts)==688
    assert sum(c['native_controls']['private_input_refusals'] for c in contexts)==48 and all(c['external']['exact_external_transaction'] for c in contexts)
    return dict(status='BOUNDED_CORRECTED_ORIGINAL_NOHEAT_RIA_KSAT_NATIVE16_THERMAL16_PRESERVED_REAL_SOURCE_AND_GLOBAL_SCIENCE_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_actual_admission=parent,parent_original_publication=old,unchanged_thermal_science=thermal,historical_legacy_NoHeat_records=legacy,corrected16_original_science=science,current_thermal_compiled_preservation=preserved,original_reference_correction=correction,original_user_output=outputs,original_short_and_explicit_numerical_refusals=short,actual_new_raw_custody=raw,coadmission=dict(contexts=416,short35_contexts=414,year367_contexts=2,corrected_ria_NoHeat_replacement_contexts=16,unchanged_ria_thermal_contexts=16,native_calendar_samples=2918,exact_cold_windows=1252,compiled_initialization_postimages=359,previous_canonical=ADMITTED),legacy_negative_Ksat_native_silently_adopted=False,extra_wet_primary_stress_admitted=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
