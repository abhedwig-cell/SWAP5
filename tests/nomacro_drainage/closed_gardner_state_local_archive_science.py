"""Read the actual twelve repaired periods and forty preserved whole-object builds."""
import json
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual,compare
from closed_gardner_state_science import observe
PRODUCER='d143437f4d9d855f03c036a9db1b8a3f86ec63ef'


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_GARDNER_STATE12_REPAIRED_LOCAL_AND_POSTIMAGES_RAW_V1',stack)
        assert store.record['actual_scientific_producer_source']==PRODUCER and store.record['sha256']=='280f57ca5554a5bcd746fa3cb56460da35c668952b52f64e267d6c7aba6a8089'
        names=['IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2','IMPLICIT_HYDRAULIC_STATE11_CURRENT_COUPLINGS_RAW_V3','IMPLICIT_HYDRAULIC_STATE11_FROST_CAUSAL_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_GUARD_RAW_V1','FROST_UNDRAINED_STATE08_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2']
        old={s.record['sha256']:s for s in [Archive(data,n,stack) for n in names]}
        contexts=[];objects=[]
        for opt in ['O0','O2']:
            root=ReadView(store,'actual/closure12-directed-v2/'+opt)
            cohort=json.loads((root/'RESULT.json').read_text());assert cohort['actual_source']==PRODUCER and len(cohort['contexts'])==6
            for entry in cohort['contexts']:
                profile=root/entry['case'];q=json.loads((profile/'RESULT.json').read_text());assert q['actual_source']==PRODUCER and q['optimization']==opt
                contexts.append(observe(profile,build=actual(store,q['build_root']),inputs=profile/'inputs',controls=root/(entry['case']+'-native-controls')))
            for kind,count in [('current',12),('parent',8)]:
                q=json.loads(store.get('actual/closure12-directed-v2/preservation-'+opt+'/'+kind+'/RESULT.json'))
                assert q.get('actual_current_compiler_source',q.get('actual_compiler_source'))==PRODUCER and q['model_days']==q['model_executions']==0 and len(q['contexts'])==count
                for item in q['contexts']:
                    previous=old[item.get('original_archive_sha256',item.get('actual_original_archive_sha256'))]
                    if kind=='parent':prefix=item['original_build_prefix']
                    else:
                        matches=[n for n,v in previous.names.items() if n.endswith('/BUILD.json') and v['sha256']==item['actual_original_BUILD_sha256']];assert len(matches)==1;prefix=matches[0].removesuffix('/BUILD.json')
                    before=ReadView(previous,prefix);current=actual(store,item['build_root'])
                    report=compare(before,current,item['actual_original_BUILD_sha256'],item['actual_current_BUILD_sha256'])
                    assert report['actual_complete_objects']==len(item['whole_objects'])
                    for name,digest in item['whole_objects'].items():assert SHA((current/name).read_bytes())==digest
                    objects.append(dict(case=item['case'],optimization=opt,kind=kind,actual_original_producer=item.get('actual_original_scientific_source',item.get('actual_original_producer')),actual_compiler_source=PRODUCER,**report))
        counts=dict(context_count=len(contexts),primary_days=sum(v['days'] for v in contexts),native_samples=sum(len(v['native_samples']) for v in contexts),exact_cold_windows=sum(len(v['exact_cold_windows']) for v in contexts),compiled_native_refusals=sum(v['compiled_native_refusals'] for v in contexts))
        assert tuple(counts.values())==(12,420,84,44,172)
        assert len(objects)==40 and sum(v['actual_complete_objects'] for v in objects)==1046
        return dict(status='TWELVE_ACTUAL_REPAIRED_CONTEXTS_AND_FORTY_CURRENT_WHOLE_OBJECT_POSTIMAGES_INDEPENDENT_ARCHIVE_PASS',actual_scientific_producer=PRODUCER,contexts=contexts,whole_object_contexts=objects,whole_objects=1046,**counts,compiler_executions=0,model_executions=0,old_periods_replayed=False,original_scientific_identities_rebound=False,additional_local_contexts_counted_again=False)
