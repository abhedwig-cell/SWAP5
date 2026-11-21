"""Read actual original Ubuntu artifacts through their original immutable paths."""
from contextlib import ExitStack
import json
from analytical_hydraulic_archives import Archive
from analytical_hydraulic_science import CASES,SHA,source
from analytical_hydraulic_forensics import audit
from hydraulic_mixed_analytical_read import audit as mixed_audit


def read(proof):
    observations=[];sources={};components={}
    with ExitStack() as stack:
        for opt in ('O0','O2'):
            current=Archive(proof,'HYDRAULIC_ANALYTICAL_UBUNTU_'+opt+'_RAW_V1',stack)
            sources[opt]=source(current,'source');assert sources[opt]=='a7d7fba5fa1e07aeeedbc8a1042665c9a900fecc'
            prefix='analytical-hydraulic-family/'
            top=json.loads(current.get(prefix+'RESULT.json'))
            assert top['status']=='ACTUAL_ANALYTICAL_PORTABLE_20FULL_20SHORT_200COLD_MIXED_COMPONENTS_INDEPENDENT_PASS_NOT_ADMITTED'
            assert top['producer']==sources[opt] and top['optimization']==opt and all(s['status']=='PASS' for s in top['steps'])
            components[opt]=mixed_audit(current.view(prefix+'mixed-capacity-0'),current.view(prefix+'mixed-capacity-1'))
            projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'))
            reference=current.view('original-provider-build')
            class Reference:
                def __truediv__(self,name):
                    assert name=='build' or name.startswith('build/')
                    return reference if name=='build' else reference/name[6:]
            for label,models,oxygen in CASES:
                for kind in ('water','cde'):
                    for phase in ('short','full'):
                        profile=current.view(prefix+label+'-'+kind+'-'+phase);q=json.loads((profile/'RESULT.json').read_text())
                        assert q['optimization']==opt and q['kind']==kind and q['layer_models']==models and q['oxygen_policy']==oxygen and q['source']==sources[opt]
                        item=projection[q['build_root']];build=current.view(item['archive_prefix'])
                        assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                        inputs=current.view(q['input_root'].split('/proof/',1)[1])
                        result=audit(profile,Reference(),locations=dict(build=build,inputs=inputs))
                        assert result['days']==(35 if phase=='short' else 1096) and result['status']=='INDEPENDENT_ANALYTICAL_HYDRAULIC_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
                        observations.append(dict(case=label,kind=kind,phase=phase,**result))
    assert len(observations)==80 and sum(item['days']==1096 for item in observations)==40
    return dict(status='ACTUAL_UBUNTU_ANALYTICAL_FAMILY_RAW_FULL_NATIVE_MIXED_COMPONENTS_INDEPENDENT_PASS_NO_ADMISSION',sources=sources,components=components,observations=observations,
        full1096_contexts=40,short35_contexts=40,exact_cold_windows=sum(item['cold_windows'] for item in observations),compiler_executions=0,model_executions=0,public_admission=False,whole_historical_family_closed=False)
