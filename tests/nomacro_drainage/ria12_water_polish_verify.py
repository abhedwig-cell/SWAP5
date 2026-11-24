"""Explicit stricter RIA numerical policy; real current source and original science."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from ria12_water_polish_source import R as ROOT,BASE,ADMITTED,git
from ria12_water_polish_source_custody import source,inherited_evidence
from ria12_water_polish_central import audit,defaults
import ria12_corrected_verify as previous
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='b7606c629c492c6a3f0245117f552bf76d7cc3f4'
ADMISSION_SHA='5bc4b938e019a0eb3b8b7e69a343fadcb25b514c12a067304d6f603426972529'
RAW_NAMES=('RIA12_WATER_POLISH_WINDOWS_RAW_V1','RIA12_WATER_POLISH_UBUNTU_O0_ORIGINAL_V1','RIA12_WATER_POLISH_UBUNTU_O2_ORIGINAL_V1')

def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show',SEALED+':'+path)
    return json.loads(raw)

def parent_admission():
    with ExitStack() as stack:
        store=Archive(PROOF,'RIA12_CORRECTED_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for member in store.names:store.get(member)
        label='RIA12_CORRECTED_ACTUAL_CANONICAL_PUBLIC_V1';q=json.loads(store.get(label+'.json'));old=json.loads(store.get(label+'.stdout.txt'))
        assert q['before']==q['after'] and q['before']['head']==ADMITTED and q['returncode']==0 and not store.get(label+'.stderr.txt')
        assert len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
        label='RIA12_CORRECTED_ACTUAL_CANONICAL_PUBLICATION_V1';q=json.loads(store.get(label+'.json'))
        assert q['before']==q['after'] and q['before']['head']==ADMITTED and q['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
        assert q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
        stats=old['coadmission'];assert (stats['contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(416,2918,1252,359)
    receipt=json.loads((PROOF/'RIA12_CORRECTED_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==ADMITTED and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('rev-parse',ADMITTED+'^{tree}').decode().strip()==receipt['whole_qualified_tree']==git('rev-parse',BASE+'^{tree}').decode().strip()
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

def strip_current_evidence(text):
    line='            /integration/f-ci/nomacro-complete01/RIA12_*\n'
    if line in text:
        assert text.count(line)==1,'Ambiguous RIA evidence checkout addition'
        text=text.replace(line,'',1)
    return previous.strip_current_evidence(text)

def publication_dependencies_unchanged():
    guard_previous_source();return True

def verify():
    current=source(SEALED);inherited=inherited_evidence();parent,old=parent_admission();raw=raw_custody()
    previous.raw_custody();previous.previous.raw_custody();previous.previous.previous.raw_custody();previous.previous.previous.previous.raw_custody()
    thermal={};legacy={};corrected={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            key=platform.upper()+'_'+opt
            value=previous.previous.audit(platform,opt);assert value==previous.previous.frozen('RIA12_THERMAL_'+key+'_CENTRAL_V1');thermal[key]=value
            primary=previous.previous.previous.previous.audit(platform,opt);assert primary==previous.previous.previous.previous.frozen('RIA12_'+key+'_CENTRAL_V1')
            boundary=previous.previous.previous.audit(platform,opt);assert boundary==previous.previous.previous.frozen('RIA12_BOUNDARY_'+key+'_CENTRAL_V1')
            legacy[key]=dict(primary=primary,boundary=boundary,current_corrected_native_compatibility_claimed=False)
            name='RIA12_CORRECTED_'+key+'_CENTRAL_V1';value=previous.audit(platform,opt);assert value==previous.frozen(name);corrected[key]=value
    for func,name in [(previous.previous.reference_correction,'RIA12_THERMAL_KSAT_CORRECTION_CENTRAL_V1'),(previous.previous.original_outputs,'RIA12_THERMAL_ORIGINAL_OUTPUT_ALL16_CENTRAL_V1'),(previous.previous.short_proofs,'RIA12_THERMAL_SHORT_ALL4_CENTRAL_V1')]:assert func()==previous.previous.frozen(name)
    for func,name in [(previous.thermal_preservation,'RIA12_CORRECTED_THERMAL_PRESERVATION_ALL8_CENTRAL_V1'),(previous.reference_correction,'RIA12_CORRECTED_KSAT_CORRECTION_ALL16_CENTRAL_V1'),(previous.original_outputs,'RIA12_CORRECTED_ORIGINAL_OUTPUT_ALL16_CENTRAL_V1'),(previous.short_proofs,'RIA12_CORRECTED_SHORT_AND_FAILURES_CENTRAL_V1')]:assert func()==previous.frozen(name)
    science={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            name='RIA12_WATER_POLISH_'+platform.upper()+'_'+opt+'_CENTRAL_V1';value=audit(platform,opt);assert value==frozen(name);science[name]=value
    preserved=defaults();assert preserved==frozen('RIA12_WATER_POLISH_DEFAULTS_CENTRAL_V1')
    return dict(status='BOUNDED_EXPLICIT_RIA_WATER_POLISH_ORIGINAL_GLOBAL_NATIVE_COLD_POLICY_AND_DEFAULT_PRESERVATION_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_actual_admission=parent,parent_original_publication=old,unchanged_corrected_NoHeat_science=corrected,unchanged_thermal_science=thermal,historical_legacy_records=legacy,new_numerical_policy_science=science,current_default_compiled_preservation=preserved,actual_new_raw_custody=raw,coadmission=dict(contexts=424,short35_contexts=422,year367_contexts=2,new_explicit_water_polish_contexts=8,new_dry_short_preservation_contexts=8,native_calendar_samples=2974,exact_cold_windows=1276,compiled_initialization_postimages=359,previous_canonical=ADMITTED),original_failed_default_wet_primary_relabeled=False,original_scientific_water_limit_cm='1e-10',new_physical_state=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
