"""Fresh complete24 original scientific contexts and actual current postimages."""
import argparse,json
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_calendar_state_portable_custody import source as custody
from frost_history_state_central import generated,compiled
from frost_boundary_archive_science import case_audit,read

ROOT=Path(__file__).resolve().parents[2]
CURRENT='3a30d3829d0355b316f93cc69daa280f01034817'
PREVIOUS='6049f82bcf265ef17de2ff86a69b4ef4c33f768f'
FIRST='16988131766408867b0c1fa94a3a45cabe68b6fe'


def audit(proof):
    contexts=[];postimages=[];provenance=[];refusals=[]
    expected={(bottom,kind,implicit) for bottom in (5,8) for kind in ('water','cde') for implicit in (0,1) if not(bottom==8 and implicit)}
    for platform in ('Windows','Ubuntu'):
        for opt in ('O0','O2'):
            with ExitStack() as stack:
                stem='FROST_BOUNDARY03_'+platform.upper()+'_'+opt+'_ORIGINAL_V'
                first=Archive(proof,stem+'1',stack);previous=Archive(proof,stem+'3',stack);current=Archive(proof,stem+'4',stack)
                workflow='.github/workflows/nomacro-frost-boundary03-'+('windows' if platform=='Windows' else 'ubuntu')+'.yml'
                for store,producer in ((first,FIRST),(previous,PREVIOUS),(current,CURRENT)):
                    _,item=custody(store,stack,producer,producer,workflow);provenance.append(dict(platform=platform,optimization=opt,**item))
                batch=json.loads(current.get('current/RESULT.json'))
                assert batch['source']==CURRENT and batch['status']=='SIX_ACTUAL_BOUNDED_FROST_BOUNDARY_FULL35_COLD_COMPILED_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
                assert len(batch['contexts'])==6 and len({x['case'] for x in batch['contexts']})==6
                projection_old=json.loads(previous.get('COMPILED_PROJECTION_V1.json'))
                # The first actual169 period is copied byte-for-byte into6049;
                # native controls added by6049 have their own genuine identity.
                first_case='water-bottom5-implicit0-hys2-initial2'
                prefix='current/'+first_case+'/science/'
                for name in first.names:
                    if name.startswith(prefix):assert previous.get(name)==first.get(name)
                keys=[]
                for item in batch['contexts']:
                    name=item['case'];fields=name.split('-');case=dict(name=name,kind=fields[0],bottom=int(fields[1][-1]),implicit=int(fields[2][-1]));keys.append((case['bottom'],case['kind'],case['implicit']))
                    if item.get('completed_full35_reused_without_model_replay'):
                        science=read(ReadView(previous,'current/'+name+'/science/RESULT.json'))
                        old=ReadView(previous,projection_old[science['build_root']]['archive_prefix'])
                        new=ReadView(current,'compiled/current-preservation/'+name)
                        comparison=dict(generated=generated(old,new),compiled=compiled(old,new))
                        assert comparison==item['current_generated_compiled']
                        assert item['actual_current_compiler']==CURRENT and item['source']==science['source'] and item['model_executions']==0
                        assert item['original_science']==science
                        postimages.append(dict(platform=platform,optimization=opt,case=name,actual_current_compiler=CURRENT,**comparison))
                        result=case_audit(previous,name,case)
                    else:
                        assert name=='cde-bottom5-implicit1-hys2-initial2'
                        result=case_audit(current,name,case);assert result['actual_compiler_source']==CURRENT
                    contexts.append(dict(platform=platform,**result))
                assert set(keys)==expected and len(keys)==len(expected)
                failure=ReadView(previous,'current/water-bottom8-implicit1-hys2-initial2/science/trajectory')
                assert (failure/'daily.jsonl').read_bytes()==b''
                assert b'Implicit original retry reached clock resolution' in (failure/'original/donor.stderr').read_bytes()
                refusals.append(dict(platform=platform,optimization=opt,actual_source=PREVIOUS,accepted_days=0,
                                     diagnostic='Implicit original retry reached clock resolution'))
    keys=[(x['platform'],x['optimization'],x['case']['name']) for x in contexts];assert len(keys)==len(set(keys))==24
    result=dict(status='ALL24_BOUNDED_FROST_BOUNDARY_ORIGINAL_SCIENCE_NATIVE_COLD_TRANSACTIONS_AND_CURRENT_POSTIMAGES_PASS_NOT_ADMITTED',
                contexts=24,full35_contexts=24,primary_accepted_model_days=840,
                native_samples=sum(x['native_samples'] for x in contexts),exact_cold_windows=sum(x['exact_cold_windows'] for x in contexts),
                actual_compiled_native_refusals=sum(x['controls']['actual_compiled_refusals'] for x in contexts),
                actual_discard_replay_accept_recovery_contexts=sum(x['controls']['actual_discard_replay_accept_recovery_contexts'] for x in contexts),
                original_scientific_sources=sorted({x['actual_compiler_source'] for x in contexts}),actual_current_compiler=CURRENT,
                original_contexts_reused_without_full_model_replay=20,current_complete_generated_compiled_postimages=postimages,
                actual_zero_day_implicit8_water_refusals=refusals,actual_source_controller_workflow_and_provider_custody=provenance,
                contexts_original=contexts,canonical_admission=False,global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
    assert (result['native_samples'],result['exact_cold_windows'],result['actual_compiled_native_refusals'],result['actual_discard_replay_accept_recovery_contexts'])==(168,72,1196,48)
    assert len(postimages)==20
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    assert not a.output.exists();result=audit(a.proof);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],flush=True)
