"""Read ten actual local contexts and their exact original mixed SDK offline."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual
from closed_initialization_calendar_science import observe,OriginalInputs,CODECS
from implicit_hydraulic_state_portable_source import sdk as verify_sdk


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_INITIALIZATION_STATE15_ALL_LOCAL_RAW_V1',stack)
        assert store.record['sha256']=='5d1936732d3212926d154ec6c06789140451ba092ddceb9f40da5fba62d3a798'
        from frost_boundary_git_archive import GitArchiveSource
        from closed_initialization_calendar_feedback import R,PARENT,git
        sdk=Archive(GitArchiveSource(R,PARENT),'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_MIXED_J_SDK_RAW_V5',stack)
        identities=json.loads(store.get('ORIGINAL_CANONICAL_GIT_SOURCE_IDENTITIES.json'))
        assert identities['actual_original_scientific_producer']=='c23ae582a249b4167dad0d59823e33d87e108475' and identities['original_working_checkout_source_bytes_claimed'] is False
        assert identities['actual_source_tree']==git('rev-parse','c23ae582a249b4167dad0d59823e33d87e108475^{tree}').decode().strip()
        assert identities['source_inventory']==git('ls-tree','-r','c23ae582a249b4167dad0d59823e33d87e108475','--','app','src','tools/solute','tools/vq','tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','reference/swap-4.3.1').decode().splitlines()
        assert sdk.record['sha256']=='0fb81e6854395c858153dd9efd33e34b5c48b79a7c9f1d964ecf909ab967271e'
        assert sdk.record['SDK_rebuilt'] is False and sdk.record['source_identity_rebound'] is False and sdk.record['all_O0_provider_claimed'] is False
        original=OriginalInputs(stack);contexts=[];SDK_bindings=[]
        for opt in ['O0','O2']:
            for name in CODECS:
                folder=ReadView(store,'actual/evidence/closure15-feedback-v1/'+opt+'/'+name)
                q=json.loads((folder/'RESULT.json').read_text());assert q['optimization']==opt and q['case']==name
                build=actual(store,q['build_root']);controls=ReadView(store,'actual/evidence/closure15-feedback-v1/'+opt+'/'+name+'-native-controls')
                identity=json.loads((build/'BUILD.json').read_text())['identity']
                SDK_bindings.append(dict(case=name,optimization=opt,**verify_sdk(sdk,identity)))
                contexts.append(observe(folder,None,build=build,inputs=folder/'inputs',controls=controls,store=original,original_sdk=ReadView(sdk,'original-provider-build')))
        assert len(contexts)==10 and sum(v['days'] for v in contexts)==350 and sum(v['native_refusals'] for v in contexts)==292
        return dict(status='TEN_ACTUAL_LOCAL_CONTEXTS_AND_ORIGINAL_MIXED_SDK_STRICT_ARCHIVE_SCIENCE_PASS',contexts=contexts,actual_original_SDK_bindings=SDK_bindings,context_count=10,primary_days=350,native_samples=sum(len(v['native_samples']) for v in contexts),exact_cold_windows=sum(len(v['cold']) for v in contexts),compiled_native_refusals=292,compiler_executions=0,model_executions=0,additional_local_contexts_counted_again=False,canonical_admission=False)
