"""Actual accepted non1 closed ordinary/Snow/Frost inputs cannot select model1."""
from contextlib import ExitStack
import json,re
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from closed_default_calendar_feedback import R,PARENT,git
from closed_default_calendar import input_domain
from experimental_project import switches


def audit():
    for name in ['implicit_hydraulic_state.py','implicit_hydraulic_state_native.f90','implicit_frost_hydraulic_state_native.f90','implicit_closed_desaturation.py','implicit_closed_desaturation_trial.f90']:
        path='app/hybrid_water/'+name;assert git('show','HEAD:'+path)==git('show',PARENT+':'+path)
    assert not git('diff',PARENT,'HEAD','--','src','tools','reference')
    modified=git('diff','--name-only',PARENT,'HEAD','--','app').decode().splitlines();assert len(modified)==8 and all(path.endswith('.py') for path in modified)
    rows=[]
    with ExitStack() as stack:
        for platform in ['WINDOWS','UBUNTU']:
            for opt in ['O0','O2']:
                store=Archive(GitArchiveSource(R,PARENT),'CLOSED_IMPLICIT_STATE13_FIRST_'+platform+'_'+opt+'_ORIGINAL_V1',stack)
                root=ReadView(store,'current');cohort=json.loads((root/'RESULT.json').read_text());assert len(cohort['contexts'])==14
                for entry in cohort['contexts']:
                    folder=root/entry['case'];q=json.loads((folder/'RESULT.json').read_text());text=(folder/'inputs/swap.swp').read_bytes().decode('cp1252');s=switches(text)
                    assert q['status'].endswith('FEEDBACK_PASS_NOT_QUALIFIED') and q['days']==35 and q['specification']['bottom']==6 and q['specification']['drainage']==0
                    assert s['SWDRA']==0 and s['SWBOTB']==6 and s['SWKIMPL']==1
                    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
                    model=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active);assert len(model)==1
                    models=list(map(int,model[0].split()));assert models==q['specification']['models'] and any(value!=1 for value in models)
                    assert input_domain(text,s,True) is None
                    rows.append(dict(platform=platform,optimization=opt,case=q['case'],actual_original_scientific_producer=q['actual_source'],actual_original_artifact_sha256=store.record['sha256'],actual_original_input_sha256=SHA(text.encode('cp1252')),models=models,new_default_model1_branch_selected=False))
    assert len(rows)==56
    return dict(status='ALL_FIFTYSIX_ACCEPTED_NON1_CLOSED_DOMAINS_EXCLUDE_THE_NEW_MODEL1_BRANCH_AND_RETAIN_COMPLETE_NATIVE_AND_NUMERICAL_OWNERS',contexts=rows,original_source_files_byte_identical=5,old_model_periods_replayed=0,compiler_executions=0,model_executions=0,old_scientific_roles_rebound=False)
