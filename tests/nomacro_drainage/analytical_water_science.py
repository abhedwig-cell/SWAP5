"""Independently read retained Windows water cohorts across exact source epochs."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from analytical_hydraulic_science import CASES,SHA,source,mapped
from analytical_hydraulic_archives import Archive
from analytical_hydraulic_forensics import audit
from model7_search_science import Store
from analytical_interface_reuse import compare as interface_compare


def read(proof):
    observations=[]
    with ExitStack() as stack:
        store=Archive(proof,'HYDRAULIC_ANALYTICAL_WINDOWS_WATER_RAW_V1',stack)
        assert store.record['status']=='ACTUAL_ANALYTICAL_WINDOWS_WATER_RAW_FRONTEND_REFUSALS_PRESERVED_NO_ADMISSION'
        projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
        admitted=Store(proof,'HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack);old_projection=json.loads(admitted.get('COMPILED_PROJECTION_V1.json'))
        provider=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
        class Reference:
            def __truediv__(self,name):
                assert name=='build' or name.startswith('build/')
                return provider.view('original-provider-build') if name=='build' else provider.view('original-provider-build/'+name[6:])
        sources={version:source(store,'profiles/analytical-trial-actual-source-'+version) for version in ('v1','v2','v3')}
        controls=json.loads(store.get('profiles/analytical-frontend-controls-v1/RESULT.json'))
        assert controls['status']=='ORIGINAL_MODEL3_OXYGEN2_EARLY_FUTURE_ROTATION_REFUSAL_AND_VALID_SCOPES_PASS'
        assert len(controls['checks'])==24 and controls['compiler_executions']==controls['model_executions']==0
        assert controls['source']=='70589c1f69649fdb5919b109e498aec2cf6f3fa9'
        for opt in ('O0','O2'):
            prior=json.loads(admitted.get(f'profiles/model7-search-daily-water-short-{opt}-v1/RESULT.json'));baseline=admitted.view(old_projection[prior['build_root']]['archive_prefix'])
            for label,models,oxygen in CASES:
                for phase in ('short','full'):
                    profile=store.view(f'profiles/analytical-{label}-daily-water-{phase}-{opt}-v1')
                    q=json.loads((profile/'RESULT.json').read_text())
                    assert q['kind']=='water' and q['optimization']==opt and q.get('layer_models',[q['hydraulic_model']])==models and q.get('oxygen_policy','original')==oxygen
                    item=projection[q['build_root']];build=store.view(item['archive_prefix'])
                    assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                    result=audit(profile,Reference(),locations=dict(build=build,inputs=mapped(store,q['input_root'])))
                    result['compiled_interface_reuse']=interface_compare(build,baseline,models)
                    assert result['days']==(35 if phase=='short' else 1096) and result['status']=='INDEPENDENT_ANALYTICAL_HYDRAULIC_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
                    observations.append(dict(case=label,phase=phase,**result))
    assert len(observations)==40 and sum(item['days']==1096 for item in observations)==20
    return dict(status='ACTUAL_WINDOWS_ANALYTICAL_WATER_RAW_FULL_NATIVE_INDEPENDENT_PASS_NO_ADMISSION',observations=observations,sources=sources,
        full1096_contexts=20,short35_contexts=20,exact_cold_windows=sum(item['cold_windows'] for item in observations),
        frontend_controls=24,compiler_executions=0,model_executions=0,public_admission=False,whole_historical_family_closed=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('proof','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();assert not a.output.exists();q=read(a.proof);a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],q['full1096_contexts'],q['exact_cold_windows'])
