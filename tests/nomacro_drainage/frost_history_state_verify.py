"""Bounded existing Frost hysteresis/state composition and actual inherited admission."""
from contextlib import ExitStack
import hashlib,json
from frost_history_state_archives import P,BASE,Archive,SHA
from frost_history_state_source_custody import ROOT,source,inherited_evidence,git
from frost_history_state_central import audit
from frost_history_state_preservation import audit as preservation
from frost_history_state_portable_custody import source as portable_source
import ria12_water_polish_verify as previous
SEALED='69a17b5690387577c8fcec82016f1f93c84eb911'
ADMISSION_SHA='5bd3a60cc8dcdf5d4598df6dad1bb1168ff20418d76b15dffc0f2ec3c23b0caa'
RAW_NAMES=('FROST_HYSTERESIS_STATE01_WINDOWS_RAW_V1','FROST_HYSTERESIS_STATE01_UBUNTU_O0_ORIGINAL_V1','FROST_HYSTERESIS_STATE01_UBUNTU_O2_ORIGINAL_V1')


def frozen(name):
    path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    assert raw==git('show',SEALED+':'+path)
    return json.loads(raw)


def parent_admission():
    receipt=frozen('RIA12_WATER_POLISH_MERGE_RECEIPT_V1')
    assert receipt['actual_merge']==BASE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==ADMISSION_SHA
    assert git('rev-parse',BASE+'^{tree}').decode().strip()==receipt['whole_tree']==git('rev-parse',receipt['qualified_candidate']+'^{tree}').decode().strip()
    assert git('show','-s','--format=%P',BASE).decode().split()==receipt['ordered_parents']
    with ExitStack() as stack:
        store=Archive(P,'RIA12_WATER_POLISH_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA
        for member in store.names:store.get(member)
        raw=store.get('RIA12_WATER_POLISH_PR1799_GENUINE_GIT_OBJECT_'+BASE+'.bin')
        assert raw==git('cat-file','commit',BASE) and hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==BASE
        label='RIA12_WATER_POLISH_ACTUAL_MERGE_PUBLIC_V1';q=json.loads(store.get(label+'.json'));public=json.loads(store.get(label+'.stdout.txt'))
        assert q['before']==q['after'] and q['before']['head']==BASE and q['returncode']==0 and not store.get(label+'.stderr.txt')
        assert len(q['before']['sparse'])==14 and len(q['before']['original_project_files'])==56
        stats=public['coadmission'];assert (stats['contexts'],stats['native_calendar_samples'],stats['exact_cold_windows'],stats['compiled_initialization_postimages'])==(424,2974,1276,359)
        label='RIA12_WATER_POLISH_ACTUAL_MERGE_PUBLICATION_V1';q=json.loads(store.get(label+'.json'))
        assert q['before']==q['after'] and q['before']['head']==BASE and q['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
        assert q['ordinary_python_default_dont_write_bytecode'] is False and q['child_bytecode_environment_variables_absent']
        ci=json.loads(store.get('RIA12_WATER_POLISH_FINAL_PR1799_ALL_CI_API_V1.json'))
        runs=ci['runs']['workflow_runs'];assert len(runs)==17 and all(x['status']=='completed' and x['conclusion']=='success' and x['head_sha']==receipt['qualified_candidate'] for x in runs)
        negatives=json.loads(store.get('RIA12_WATER_POLISH_BOTHCI_FINAL_NEGATIVES_V1.json'))
        assert negatives['candidate']==receipt['qualified_candidate'] and len(negatives['controls'])==4
        assert {x['role'] for x in negatives['controls']}=={'SOURCE','RAW','INHERITED','PUBLICATION'}
        assert all(x['actual_refusal'] and x['actual_one_file_delta'] and x['exact_parent']==receipt['qualified_candidate'] for x in negatives['controls'])
    return dict(receipt=receipt,actual_admitted_coadmission=stats,scientific_evidence_reuse='ACTUAL_ADMITTED_424_CONTEXT_CLOSURE_WITH_FRESH_COMPLETE_INHERITED_BYTE_CUSTODY_AND_LITERAL_NONSELECTED_SOURCE_DEFAULT_COMPILED_PRESERVATION',old_model_periods_reexecuted=0,old_scientific_math_reexecution_claimed=False)


def raw_custody():
    result=[]
    with ExitStack() as stack:
        for name in RAW_NAMES:
            declaration=frozen(name);store=Archive(P,name,stack)
            assert store.record==declaration
            for member in store.names:store.get(member)
            item=dict(archive=name,sha256=declaration['sha256'],bytes=declaration['bytes'],members=len(store.names))
            if 'UBUNTU' in name:item['original_source_custody']=portable_source(store,stack)[1]
            result.append(item)
    return result


def guard_previous_source():
    source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):
    line='            /integration/f-ci/nomacro-complete01/FROST_HYSTERESIS_STATE01_*\n'
    if line in text:
        assert text.count(line)==1,'Ambiguous Frost evidence checkout addition';text=text.replace(line,'',1)
    return previous.strip_current_evidence(text)


def publication_dependencies_unchanged():
    guard_previous_source();return True


def verify():
    current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();raw=raw_custody();science={}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            name='FROST_HYSTERESIS_STATE01_'+platform.upper()+'_'+opt+'_CENTRAL_V1';value=audit(platform,opt);assert value==frozen(name);science[name]=value
    preserved=preservation();assert preserved==frozen('FROST_HYSTERESIS_STATE01_PRESERVATION_CENTRAL_V1')
    return dict(status='BOUNDED_EXISTING_FROST_HYSTERESIS01_INITIAL12_EXPLICIT_IMPLICIT_SOURCE_ORIGINAL_SCIENCE_NATIVE_COLD_AND_DEFAULT_PRESERVATION_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_actual_admission=parent,new_original_science=science,current_preservation=preserved,actual_new_raw_custody=raw,coadmission=dict(contexts=472,short35_contexts=470,year367_contexts=2,new_frost_hysteresis_state_contexts=48,native_calendar_samples=3310,exact_cold_windows=1420,compiled_initialization_postimages=375,previous_canonical=BASE),original_scientific_water_limit_cm='1e-10',original_accumulated_water_drift_is_diagnostic_not_equivalence=True,new_physical_state=False,inventory_or_flux_correction=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
