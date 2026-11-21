"""Read actual unselected model7 postimages against unchanged admitted raw bytes."""
from contextlib import ExitStack
import io
import json
import types
import zipfile
from analytical_hydraulic_archives import Archive,SHA
from analytical_interface_reuse import compare
from model7_search_science import Store
from model7_capacity_forensics import audit
from model7_unselected_science import physical,rows
from frost_cde_drainage_portable_forensics import binary
from calendar_publisher import publisher_equivalence
from calendar_evidence import differences
from vapor_windows_science import mapped,source_epoch


def read(proof):
    observations=[]
    with ExitStack() as stack:
        current=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_POSTIMAGES_RAW_V1',stack)
        old=Store(proof,'HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack)
        provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
        projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'));prior_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'))
        class Reference:
            def __truediv__(self,name):
                assert name.startswith('build/')
                return provider.view('original-provider-build/'+name[6:])
        publisher=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value))
        for opt in ('O0','O2'):
            first=json.loads(current.get(f'profiles/vapor-unselected-model7-postimages-{opt}-v1/RESULT.json'))
            assert first['status']=='FAILED' and first['error'].startswith('AssertionError')
            top=json.loads(current.get(f'profiles/vapor-unselected-model7-postimages-{opt}-v2/RESULT.json'))
            assert top['status']=='ACTUAL_VAPOR_UNSELECTED_MODEL7_COMPLETE_COMPILED_NATIVE_SHORT_POSTIMAGES_EXACT_OLD_FULL_CONTROLS_REUSABLE' and top['fresh_full_periods']==0
            source_epoch(top['source'])
            for item in top['contexts']:
                profile=mapped(current,item['profile_root']);q=json.loads((profile/'RESULT.json').read_text());kind=item['kind'];source_epoch(q['source'])
                assert q['kind']==kind and q['optimization']==opt
                key=projection[q['build_root']];build=current.view(key['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==key['actual_BUILD_sha256']==item['actual_BUILD_sha256']
                meta=json.loads((build/'BUILD.json').read_text());prefix=f'profiles/model7-search-daily-{kind}-short-{opt}-v1'
                prior=json.loads(old.get(prefix+'/RESULT.json'));oldbuild=old.view(prior_projection[prior['build_root']]['archive_prefix']);oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
                interface=compare(build,oldbuild,[7]);compared=json.loads(json.dumps(meta['identity']))
                optional=None
                if kind=='cde':
                    optional=compared['cde_native_receipt'].pop('optional_native_prefixes')
                    assert optional=={'S5HVC003':'48 + 8*(14+2*actual_layers), checked duplicated vapor domain'}
                assert optional==item['inactive_vapor_only_CDE_descriptor']
                delta=differences(oldmeta['identity'],compared)
                assert delta==item['identity_changes'] and set(delta)<={'host','model7_capacity.source_sha256','model7_terminal_water.source_sha256','model7_terminal_water.policy','experimental_input_adapter','restart_publisher.library_sha256','cde_native_receipt.source_sha256','original_output.source_sha256'}
                if 'restart_publisher.library_sha256' in delta:assert publisher(oldbuild/'restart_publish.dll',build/'restart_publish.dll')==item['publisher_equivalence']
                result=audit(profile,Reference(),locations=dict(build=build,inputs=mapped(current,q['input_root'])))
                assert result['days']==35 and result['cold_windows']==3
                warm=profile/'trajectory';oldwarm=old.view(prefix+'/trajectory');assert physical(rows(warm))==physical(rows(oldwarm))
                for day in (2,4,19,23,30,34,35):
                    with zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{day}.zip').read_bytes())) as x,zipfile.ZipFile(io.BytesIO((oldwarm/f'accepted-column-1-day-{day}.zip').read_bytes())) as y:
                        assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                assert binary((warm/'original/result_output.bin').read_bytes())==binary((oldwarm/'original/result_output.bin').read_bytes())
                observations.append(dict(kind=kind,optimization=opt,independent=result,interface=interface,physical_native_REAL4_postimage_exact=True))
    assert len(observations)==4
    return dict(status='ACTUAL_VAPOR_UNSELECTED_MODEL7_COMPILED_NATIVE_SHORT_POSTIMAGES_INDEPENDENT_PASS_FULL_CONTROLS_REUSED',
        observations=observations,short35_contexts=4,exact_cold_windows=12,new_full_periods=0,compiler_executions=0,model_executions=0,public_admission=False)
