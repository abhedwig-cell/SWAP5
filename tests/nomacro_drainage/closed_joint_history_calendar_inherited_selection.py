"""Actual admitted default cases retain their old policy; no old periods replay."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_joint_history_calendar_feedback import R,PARENT,git
from closed_default_calendar import input_domain,POLICY,GROUNDWATER_POLICY
from experimental_project import switches
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual


def audit():
    rows=[];data=GitArchiveSource(R,PARENT)
    for stem,producer,initial in [('CLOSED_DEFAULT_CALENDAR_STATE14','94c86c2918278ffd9595b9960eb8e1522652277a',1),('CLOSED_INITIALIZATION_STATE15','69a8b46d802cad4c95036700b3e4888254af847f',2)]:
        for platform in ['WINDOWS','UBUNTU']:
            for opt in ['O0','O2']:
                with ExitStack() as stack:
                    store=Archive(data,stem+'_FIRST_'+platform+'_'+opt+'_ORIGINAL_V1',stack)
                    cohort=json.loads(store.get('current/RESULT.json'));assert len(cohort['contexts'])==5 and cohort['actual_source']==producer
                    for entry in cohort['contexts']:
                        q=json.loads(store.get('current/'+entry['case']+'/RESULT.json'));raw=store.get('current/'+entry['case']+'/inputs/swap.swp');s=switches(raw.decode('cp1252'))
                        assert q['actual_source']==producer and q['specification']['initial']==initial and s['SWINCO']==initial
                        assert not (s['SWKIMPL'] and s['SWHYST'])
                        selected=input_domain(raw.decode('cp1252'),s,True)
                        assert selected and selected['initial']==initial and selected['history']==s['SWHYST'] and selected['implicit']==s['SWKIMPL']
                        assert selected['policy']==(POLICY if initial==1 else GROUNDWATER_POLICY)
                        rows.append(dict(original_level=stem,platform=platform,optimization=opt,case=entry['case'],actual_original_scientific_producer=producer,actual_original_artifact_sha256=store.record['sha256'],actual_original_input_sha256=SHA(raw),current_selected_original_policy=selected['policy'],current_new_joint_branch_selected=False))
    assert len(rows)==40
    return dict(status='FORTY_ADMITTED_DEFAULT_INITIAL12_PORTABLE_CONTEXTS_RETAIN_ORIGINAL_POLICY_AND_EXCLUDE_NEW_JOINT_BRANCH',actual_accepted_parent=PARENT,contexts=rows,compiler_executions=0,model_executions=0,old_scientific_roles_rebound=False)


def local_unaffected(data):
    rows=[]
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_JOINT_HISTORY_STATE16_ALL_LOCAL_RAW_V1',stack)
        for opt in ['O0','O2']:
            for name in ['hys1-monthly-water-initial1','hys1-monthly-water-initial2','hys2-dates-cde-initial1','hys2-dates-cde-initial2']:
                folder=ReadView(store,'actual/evidence/closure16-feedback-v1/'+opt+'/'+name);q=json.loads((folder/'RESULT.json').read_text());build=actual(store,q['build_root'])
                meta=json.loads((build/'BUILD.json').read_text());s=switches((folder/'inputs/swap.swp').read_bytes().decode('cp1252'));selected=meta['identity']['original_output']
                # These are the actual first exclusion conditions of the frozen
                # current native renderer. No old source or HEAD is substituted.
                assert s['SWSOLU']==1 if q['specification']['kind']=='cde' else selected['swmonth']==s['SWMONTH']==1
                rows.append(dict(case=name,optimization=opt,actual_original_runtime_source=q['actual_source'],actual_original_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),current_targeted_native_guard_selected=False,complete_original_integral_raw_sha256=SHA((build/'integral.f90').read_bytes()),original_whole_object_hashes={p.name:SHA(p.read_bytes()) for p in build.glob('*.o')},selection='NOT_SELECTED_IMPACT_LITERAL_NATIVE_RENDER_RETURNS_COMPLETE_ORIGINAL_SOURCE',compiler_executions=0,model_days=0))
    assert len(rows)==8
    return dict(status='EIGHT_ACTUAL_LOCAL_CONTEXTS_EXCLUDE_TARGETED_PERIODIC_NATIVE_VALIDATION_NO_NEW_COMPILER_OR_MODEL_PASS',actual_original_runtime_source='9f794ca219367b85b79bdd9850617e4e26c691a1',contexts=rows,compiler_executions=0,model_days=0,original_periods_rebound=False)
