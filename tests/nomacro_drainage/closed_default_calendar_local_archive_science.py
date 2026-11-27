"""Read ten actual local contexts and their exact original mixed SDK offline."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual
from closed_default_calendar_science import observe,OriginalInputs,CODECS
from implicit_hydraulic_state_portable_source import sdk as verify_sdk


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_DEFAULT_CALENDAR_STATE14_ALL_LOCAL_FAILURES_AND_SUCCESSES_RAW_V2',stack)
        assert store.record['sha256']=='736057de6b483eb42bb3e36e57b6277d0cc3136c15f35fce625f98d693c8106a'
        sdk=Archive(data,'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_MIXED_J_SDK_RAW_V5',stack)
        assert sdk.record['sha256']=='0fb81e6854395c858153dd9efd33e34b5c48b79a7c9f1d964ecf909ab967271e'
        assert sdk.record['SDK_rebuilt'] is False and sdk.record['source_identity_rebound'] is False and sdk.record['all_O0_provider_claimed'] is False
        original=OriginalInputs(stack);contexts=[];SDK_bindings=[]
        for opt in ['O0','O2']:
            for name in CODECS:
                version='v3' if name in ['implicit-perstep-water','hys1-clock-water'] else 'v1'
                folder=ReadView(store,'actual/evidence/closure14-feedback-'+version+'/'+opt+'/'+name)
                q=json.loads((folder/'RESULT.json').read_text());assert q['optimization']==opt and q['case']==name
                build=actual(store,q['build_root']);controls=ReadView(store,'actual/evidence/closure14-native-v2/'+opt+'/'+name)
                identity=json.loads((build/'BUILD.json').read_text())['identity']
                SDK_bindings.append(dict(case=name,optimization=opt,**verify_sdk(sdk,identity)))
                contexts.append(observe(folder,None,build=build,inputs=folder/'inputs',controls=controls,store=original,original_sdk=ReadView(sdk,'original-provider-build')))
        assert len(contexts)==10 and sum(v['days'] for v in contexts)==350 and sum(v['native_refusals'] for v in contexts)==292
        return dict(status='TEN_ACTUAL_LOCAL_CONTEXTS_AND_ORIGINAL_MIXED_SDK_STRICT_ARCHIVE_SCIENCE_PASS',contexts=contexts,actual_original_SDK_bindings=SDK_bindings,context_count=10,primary_days=350,native_samples=sum(len(v['native_samples']) for v in contexts),exact_cold_windows=sum(len(v['cold']) for v in contexts),compiled_native_refusals=292,compiler_executions=0,model_executions=0,additional_local_contexts_counted_again=False,canonical_admission=False)
