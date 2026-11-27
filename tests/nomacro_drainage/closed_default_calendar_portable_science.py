"""Read actual portable artifacts and genuine producer bytes; never rerun a model."""
from contextlib import ExitStack
from pathlib import Path
import hashlib,io,json,tarfile,zipfile
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from closed_default_calendar_feedback import R,P,git
from closed_default_calendar_science import observe,OriginalInputs
from implicit_hydraulic_state_portable_source import sdk
PRODUCER='94c86c2918278ffd9595b9960eb8e1522652277a'
PHYSICAL='0a43d8a48cfc5ed98164b1873a3e6a6aa93fb744'
RUNS={'Ubuntu':46044072466,'Windows':46044072519}
blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()


def source(store,platform):
    assert not git('diff',PHYSICAL,PRODUCER,'--','app','src','tools','reference')
    tree={row.split(b'\t',1)[1].decode():row.split()[2].decode() for row in git('ls-tree','-r',PRODUCER).splitlines()}
    def check(name,raw,item):
        assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==tree[name]
        assert tree[name] in (blob(raw),blob(raw.replace(b'\r\n',b'\n')))
    q=json.loads(store.get('source/RESULT.json'));raw=store.get('source/actual-producer-source.zip')
    assert q['producer_head']==PRODUCER and len(raw)==q['bytes'] and SHA(raw)==q['sha256']
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        absent={n for n,v in q['members'].items() if v.get('checkout')=='ABSENT'}
        assert all(n.startswith('reference/swap-4.3.1/') for n in absent)
        assert len(z.namelist())==len(set(z.namelist()))==len(q['members'])-len(absent) and set(z.namelist())==set(q['members'])-absent
        for name,item in q['members'].items():
            if name in absent:assert item==dict(git_blob=tree[name],checkout='ABSENT')
            else:check(name,z.read(name),item)
        original=z.read('reference/swap-4.3.1/source-archives/SWAP.ZIP')
    controller=json.loads(store.get('controller-source.json'));raw=store.get('controller-source.tar')
    assert controller['producer_head']==PRODUCER and len(raw)==controller['bytes'] and SHA(raw)==controller['sha256']
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        assert len(t.getmembers())==len({v.name for v in t.getmembers()})==len(controller['members']) and {v.name for v in t.getmembers()}==set(controller['members'])
        for name,item in controller['members'].items():check(name,t.extractfile(name).read(),item)
    workflow='.github/workflows/nomacro-closed-default-calendar-state14-'+platform.lower()+'.yml'
    assert store.get('actual-workflow.yml')==git('show',PRODUCER+':'+workflow)
    assert store.get('actual-workflow-git-blob.txt').decode().strip()==tree[workflow]
    contract=json.loads(store.get('actual-source-contract.json'))
    assert contract['actual_source']==PRODUCER and contract['actual_canonical_parent']=='ae54d7d621a07e54dd8f9fdb758585b2a2cc754d' and contract['source_contract']['complete_literal_inverses']==8
    assert contract['compiler_executions']==contract['model_executions']==0
    assert not contract['physical_equations_changed'] and not contract['new_physical_state'] and contract['new_numerical_policy'] is False
    selection=json.loads(store.get('actual-test-selection.json'));status=json.loads(git('show',PRODUCER+':'+P+'STATUS.json'))
    assert selection['status']=='SELECTED_NOT_QUALIFIED' and selection['group']=='closed_default_calendar_feedback' and selection['candidate']==status['test_selection']['candidate'] and len(selection['candidate'])==40
    assert selection['decision']==status['test_selection']['groups']['closed_default_calendar_feedback']
    prepared=json.loads(store.get('provider-PREPARED.json'))
    assert SHA(original)==prepared['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
    for name,digest in prepared['provider_files'].items():
        if name.startswith('build/'):assert SHA(store.get('original-provider-build/'+name[len('build/'):]))==digest
    return dict(actual_producer=PRODUCER,actual_physical_source=PHYSICAL,actual_source_zip_sha256=q['sha256'],actual_source_members=len(q['members'])-len(absent),
                actual_controller_tar_sha256=controller['sha256'],actual_controller_members=len(controller['members']),actual_workflow_git_blob=tree[workflow],
                original_SWAP_ZIP_sha256=SHA(original),actual_toolchain=prepared['toolchain'],actual_persisted_test_selection=selection)


def audit(data,platform,opt):
    assert platform in RUNS and opt in ['O0','O2']
    name='CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_'+platform.upper()+'_'+opt+'_ORIGINAL_V1'
    with ExitStack() as stack:
        store=Archive(data,name,stack)
        assert store.record['actual_workflow_run']==RUNS[platform] and store.record['actual_producer_source']==PRODUCER
        provenance=source(store,platform);root=ReadView(store,'current');cohort=json.loads((root/'RESULT.json').read_text())
        assert cohort['actual_source']==PRODUCER and cohort['optimization']==opt and cohort['scope']=='independent'
        assert cohort['status']=='ALL_SELECTED_CLOSED_DEFAULT_CALENDAR_LOCAL_CONTEXTS_AND_NATIVE_CONTROLS_PASS_NOT_QUALIFIED'
        plan=json.loads(git('show',PRODUCER+':'+P+'CLOSED_DEFAULT_CALENDAR_STATE14_FINITE_CASE_PLAN_V1.json'))
        assert len(cohort['contexts'])==5 and [v['case'] for v in cohort['contexts']]==plan['independent_qualification_cases']
        assert cohort['deferred_numerical_cases']==[]
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));contexts=[];original_store=OriginalInputs(stack)
        for entry in cohort['contexts']:
            assert entry['status']=='PASS_NOT_QUALIFIED' and entry['runtime']['returncode']==entry['native']['returncode']==0
            profile=root/entry['case'];q=json.loads((profile/'RESULT.json').read_text());assert q['actual_source']==PRODUCER and q['optimization']==opt
            compiled=projection[q['build_root']];assert compiled['actual_BUILD_sha256']==q['actual_BUILD_sha256']
            build=ReadView(store,compiled['archive_prefix']);inputs=profile/'inputs';controls=root/(entry['case']+'-native-controls')
            actual=observe(profile,None,build=build,inputs=inputs,controls=controls,store=original_store,original_sdk=ReadView(store,'original-provider-build'))
            identity=json.loads((build/'BUILD.json').read_text())['identity'];actual['actual_original_SDK']=sdk(store,identity)
            target=identity['target'];assert ('mingw' in target) if platform=='Windows' else ('linux' in target)
            contexts.append(actual)
        counts=dict(context_count=len(contexts),primary_days=sum(v['days'] for v in contexts),native_samples=sum(len(v['native_samples']) for v in contexts),
                    exact_cold_windows=sum(len(v['cold']) for v in contexts),compiled_native_refusals=sum(v['native_refusals'] for v in contexts),external_transaction_contexts=len(contexts))
        assert (counts['context_count'],counts['primary_days'],counts['native_samples'],counts['exact_cold_windows'],counts['compiled_native_refusals'])==(5,175,35,15,146)
        return dict(status='FIVE_ACTUAL_PORTABLE_CLOSED_DEFAULT_CALENDAR_COUPLINGS_ORIGINAL_INPUTS_1E10_NATIVE_COLD_YEAR_TRANSACTIONS_AND_COMPILED_REFUSALS_INDEPENDENT_PASS',
                    platform=platform,optimization=opt,actual_producer_source=PRODUCER,actual_original_artifact_sha256=store.record['sha256'],source_provenance=provenance,
                    contexts=contexts,**counts,compiler_executions=0,model_executions=0,original_source_or_path_identities_rewritten=False,canonical_admission=False)
