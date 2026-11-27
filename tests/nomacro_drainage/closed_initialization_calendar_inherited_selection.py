"""Actual original old inputs exclude this new domain; no fresh old science PASS."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from closed_initialization_calendar_feedback import R,PARENT,git
from closed_default_calendar import input_domain
from experimental_project import switches


def audit():
    assert not git('diff','12833d6ede29b8379d330fcee238c9ae32d4f3ef',PARENT,'--','app','src','tools/solute','tools/vq','reference')
    rows=[]
    with ExitStack() as stack:
        store=Archive(GitArchiveSource(R,PARENT),'CLOSED_DEFAULT_CALENDAR_STATE14_FORTY_OLD_OBJECTS_AND_NATIVE_RAW_V4',stack)
        assert store.record['sha256']=='5fb267e56a069a1dec1eaefec3840d9e2dfc39c9f9e0f57832506f6debbab114'
        for opt in ['O0','O2']:
            prefix='actual/evidence/closure14-preservation-v1/'+opt;record=json.loads(store.get(prefix+'/RESULT.json'));assert len(record['contexts'])==20
            for item in record['contexts']:
                raw=store.get(prefix+'/'+item['case']+'/inputs/swap.swp');text=raw.decode('cp1252');assert input_domain(text,switches(text),True) is None
                rows.append(dict(case=item['case'],optimization=opt,actual_original_current_compiler_source=record['actual_compiler_source'],actual_original_input_sha256=SHA(raw),actual_original_whole_object_proof=item['whole_object_proof'],current_new_initialization_branch_selected=False))
        assert len(rows)==40 and sum(v['actual_original_whole_object_proof']['actual_complete_objects'] for v in rows)==1046
        return dict(status='FORTY_INHERITED_OLD_CONTEXTS_SOURCE_AND_ALL_ORIGINAL_INPUTS_EXCLUDE_NEW_INITIALIZATION_BRANCH_NO_NEW_COMPILER_OR_MODEL_PASS_CLAIMED',actual_accepted_parent=PARENT,original_archive=store.record['archive'],original_archive_sha256=store.record['sha256'],contexts=rows,whole_objects_inherited=1046,current_selection='NOT_SELECTED_IMPACT_UNCHANGED_GENERATED_SOURCE_ELIGIBILITY',compiler_executions=0,model_executions=0,scientific_producers_rebound=False)
