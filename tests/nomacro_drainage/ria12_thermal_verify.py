"""Actual canonical400 and bounded RIA numerical heat/Snow source and science."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
from ria12_thermal_source import R as ROOT,CORE,git
from ria12_thermal_source_custody import source,inherited_evidence
from ria12_thermal_central_science import audit,preservation,reference_correction,original_outputs,short_proofs
import ria12_boundary_verify as previous

PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='fc1b69349bbce18b4f78a435ca3751b2375974d3'
ADMISSION_SHA='db830e813d9edcde4d30bb0de367195f79cb001891b43eae1118032a31636585'
RAW_NAMES=('RIA12_THERMAL_WINDOWS_RAW_V1','RIA12_THERMAL_SNOW_INPUTS_V1','RIA12_THERMAL_UBUNTU_O0_ORIGINAL_V1','RIA12_THERMAL_UBUNTU_O2_ORIGINAL_V1','RIA12_THERMAL_UBUNTU_O0_CONTROLS_V1','RIA12_THERMAL_UBUNTU_O2_CONTROLS_V1')


def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    assert raw==git('show',SEALED+':'+path),'Changed RIA thermal scientific declaration '+name
    return json.loads(raw)


def parent_admission():
    with ExitStack() as stack:
        store=Archive(PROOF,'RIA12_BOUNDARY_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for member in store.names:store.get(member)
        label='RIA12_BOUNDARY_ACTUAL_CANONICAL_PUBLIC_V1';receipt=json.loads(store.get(label+'.json'));old=json.loads(store.get(label+'.stdout.txt'))
        assert receipt['before']==receipt['after'] and receipt['before']['head']==CORE and receipt['returncode']==0 and not store.get(label+'.stderr.txt')
        assert len(receipt['before']['sparse'])==14 and len(receipt['before']['original_project_files'])==56
        label='RIA12_BOUNDARY_ACTUAL_CANONICAL_PUBLICATION_V1';scope=json.loads(store.get(label+'.json'))
        assert scope['before']==scope['after'] and scope['before']['head']==CORE and scope['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
        stats=old['coadmission'];assert (stats['contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(400,2806,1204,343)
    receipt=json.loads((PROOF/'RIA12_BOUNDARY_MERGE_RECEIPT_V1.json').read_text())
    assert receipt['actual_merge']==CORE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('rev-parse',CORE+'^{tree}').decode().strip()==receipt['whole_qualified_tree']
    assert git('show','-s','--format=%P',CORE).decode().split()==receipt['ordered_parents']
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
    # Read the canonical400 scientific evidence without giving its old owner
    # another HEAD, namespace, working tree or altered producer metadata.
    previous.raw_custody();previous.previous.raw_custody();inherited_science={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            key=platform.upper()+'_'+opt
            primary=previous.previous.audit(platform,opt);assert primary==previous.previous.frozen('RIA12_'+key+'_CENTRAL_V1')
            boundary=previous.audit(platform,opt);assert boundary==previous.frozen('RIA12_BOUNDARY_'+key+'_CENTRAL_V1')
            inherited_science[key]=dict(primary=primary,boundary=boundary)
    assert previous.short_proofs()==previous.frozen('RIA12_BOUNDARY_SHORT_ALL12_CENTRAL_V1')
    for opt in ('O0','O2'):
        assert previous.preservation(opt)==previous.frozen('RIA12_BOUNDARY_'+opt+'_MODEL1_PRESERVATION_CENTRAL_V1')
        assert previous.previous.preservation(opt)==previous.previous.frozen('RIA12_'+opt+'_MODEL1_PRESERVATION_CENTRAL_V1')
    for kind,opt in (('water','O0'),('cde','O2')):
        assert previous.primary_preservation(kind,opt)==previous.frozen('RIA12_BOUNDARY_'+kind.upper()+'_'+opt+'_PRIMARY_PRESERVATION_CENTRAL_V1')
    science={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            name='RIA12_THERMAL_'+platform.upper()+'_'+opt+'_CENTRAL_V1';value=audit(platform,opt);assert value==frozen(name);science[name]=value
    preserved=preservation();assert preserved==frozen('RIA12_THERMAL_PRESERVATION_ALL8_CENTRAL_V1')
    correction=reference_correction();assert correction==frozen('RIA12_THERMAL_KSAT_CORRECTION_CENTRAL_V1')
    outputs=original_outputs();assert outputs==frozen('RIA12_THERMAL_ORIGINAL_OUTPUT_ALL16_CENTRAL_V1')
    short=short_proofs();assert short==frozen('RIA12_THERMAL_SHORT_ALL4_CENTRAL_V1')
    contexts=[c for report in science.values() for c in report['contexts']]
    assert len(contexts)==16 and sum(c['native'] for c in contexts)==112 and sum(c['cold'] for c in contexts)==48
    assert sum(c['native_controls']['native_refusals'] for c in contexts)==736
    assert sum(c['native_controls']['private_input_refusals'] for c in contexts)==48 and sum(c['external'] is not None for c in contexts)==12
    return dict(status='BOUNDED_ORIGINAL_RIA_THERMAL_SNOW_PARENT400_NEW16_REAL_SOURCE_ORIGINAL_STOCK_KSAT_NATIVE_COLD_AND_EXTERNAL_PASS',
                actual_current_source=current,fresh_parent400_evidence=inherited,parent_actual_admission=parent,inherited400_original_science=old,
                inherited_primary_and_boundary_science=inherited_science,new16_original_science=science,unchanged_old_compiled=preserved,
                original_reference_correction=correction,original_user_output=outputs,original_four_short=short,actual_new_raw_custody=raw,
                coadmission=dict(contexts=416,short35_contexts=414,year367_contexts=2,new_ria_thermal_contexts=16,native_calendar_samples=2918,exact_cold_windows=1252,compiled_initialization_postimages=359,previous_canonical=CORE),
                compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
