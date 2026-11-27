"""Read ten actual local contexts and their exact original mixed SDK offline."""
from contextlib import ExitStack
import json,struct
from analytical_hydraulic_archives import Archive
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual
from closed_joint_history_calendar_science import observe,OriginalInputs,CODECS,payload,output_calendar
from implicit_hydraulic_state_portable_source import sdk as verify_sdk


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_JOINT_HISTORY_STATE16_ALL_LOCAL_RAW_V1',stack)
        assert store.record['sha256']=='236aee5648f1fd1dacfc4032dcc4085e4ab39e7d082f450d9ec17d11c6ca8cbe'
        from frost_boundary_git_archive import GitArchiveSource
        from closed_joint_history_calendar_feedback import R,PARENT,git
        sdk=Archive(GitArchiveSource(R,PARENT),'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_MIXED_J_SDK_RAW_V5',stack)
        identities=json.loads(store.get('ORIGINAL_CANONICAL_GIT_SOURCE_IDENTITIES.json'))
        assert identities['actual_original_scientific_producer']=='9f794ca219367b85b79bdd9850617e4e26c691a1' and identities['original_working_checkout_source_bytes_claimed'] is False
        assert identities['actual_source_tree']==git('rev-parse','9f794ca219367b85b79bdd9850617e4e26c691a1^{tree}').decode().strip()
        assert identities['source_inventory']==git('ls-tree','-r','9f794ca219367b85b79bdd9850617e4e26c691a1','--','app','src','tools/solute','tools/vq','tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','reference/swap-4.3.1').decode().splitlines()
        assert sdk.record['sha256']=='0fb81e6854395c858153dd9efd33e34b5c48b79a7c9f1d964ecf909ab967271e'
        assert sdk.record['SDK_rebuilt'] is False and sdk.record['source_identity_rebound'] is False and sdk.record['all_O0_provider_claimed'] is False
        original=OriginalInputs(stack);contexts=[];SDK_bindings=[];failures=[]
        for opt in ['O0','O2']:
            for name in CODECS:
                folder=ReadView(store,'actual/evidence/closure16-feedback-v1/'+opt+'/'+name)
                q=json.loads((folder/'RESULT.json').read_text());assert q['optimization']==opt and q['case']==name
                build=actual(store,q['build_root']);controls=ReadView(store,'actual/evidence/closure16-feedback-v1/'+opt+'/'+name+'-native-controls')
                identity=json.loads((build/'BUILD.json').read_text())['identity']
                SDK_bindings.append(dict(case=name,optimization=opt,**verify_sdk(sdk,identity)))
                control=json.loads((controls/'RESULT.json').read_text())
                complete=control['status']=='ACTUAL_DEFAULT_CALENDAR_OWN_POSITIVE_AND_COMPILED_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
                contexts.append(observe(folder,None,build=build,inputs=folder/'inputs',controls=controls if complete else None,store=original,original_sdk=ReadView(sdk,'original-provider-build')))
                if not complete:
                    assert 'periodic-water' in name and 'counter' in control['error'] and '100' in control['error']
                    meta=json.loads((build/'BUILD.json').read_text());receipt,values=payload(folder/'trajectory/accepted-column-1-day-4.zip');good=values['macro.bin']
                    positive=output_calendar(good,meta['project']['nodes'],receipt['receipt'],meta['identity']['original_output'],meta['project']['start_date'],False)
                    bad=bytearray(good);pos=positive['calendar_offset']
                    for at in [pos,pos+80]:struct.pack_into('<i',bad,at+28,positive['calendar_header'][7]+1)
                    mutant=(controls/'native/counter/origin/macro.bin').read_bytes();assert mutant==bytes(bad)
                    stdout=(controls/'native/counter/donor.stdout').read_bytes();assert b'HYBRID_READY' in stdout and b'HYBRID_DAY_RETURN' not in stdout and not (controls/'native/counter/donor.stderr').read_bytes()
                    error=None
                    try:output_calendar(mutant,meta['project']['nodes'],receipt['receipt'],meta['identity']['original_output'],meta['project']['start_date'],False)
                    except ValueError as exc:error=str(exc)
                    assert error and 'counters differ' in error
                    failures.append(dict(case=name,optimization=opt,actual_original_runtime_source=q['actual_source'],actual_original_native_failure=control['error'],actual_accepted_counter_mutant_sha256=__import__('hashlib').sha256(mutant).hexdigest(),unchanged_independent_observer_refusal=error,original_roles_rebound=False))
        assert len(contexts)==12 and len(failures)==4 and sum(v['days'] for v in contexts)==420 and sum(v['native_refusals'] for v in contexts)==260
        return dict(status='TWELVE_ORIGINAL_LOCAL_SCIENTIFIC_PERIODS_AND_ALL_FOUR_NATIVE_FAILURES_INDEPENDENTLY_RETAINED_NOT_QUALIFIED',contexts=contexts,actual_original_SDK_bindings=SDK_bindings,context_count=12,primary_days=420,native_samples=sum(len(v['native_samples']) for v in contexts),exact_cold_windows=sum(len(v['cold']) for v in contexts),compiled_refusals_from_complete_successful_controls=260,original_native_failures=failures,original_native_failure_contexts_not_qualified=4,compiler_executions=0,model_executions=0,additional_local_contexts_counted_again=False,canonical_admission=False)
