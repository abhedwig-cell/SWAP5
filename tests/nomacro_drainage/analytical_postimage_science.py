"""Independently read immutable actual model7 short postimages, not observer claims."""
from contextlib import ExitStack
import io
import json
import types
import zipfile
from analytical_hydraulic_archives import Archive
from analytical_hydraulic_science import mapped
from analytical_interface_reuse import compare
from model7_search_science import Store,SHA
from model7_capacity_forensics import audit
from model7_unselected_science import physical,rows
from frost_cde_drainage_portable_forensics import binary
from calendar_publisher import publisher_equivalence
from calendar_evidence import differences


def read(proof):
    observations=[];failed=[]
    with ExitStack() as stack:
        current=Archive(proof,'HYDRAULIC_ANALYTICAL_POSTIMAGES_RAW_V1',stack)
        old=Store(proof,'HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack)
        provider=Store(proof,'FROST_IMPLICIT_WINDOWS_SUPPORT_RAW_ARCHIVE',stack)
        projection=json.loads(current.get('COMPILED_PROJECTION_V1.json'));prior_projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'))
        class Reference:
            def __truediv__(self,name):
                assert name=='build' or name.startswith('build/')
                return provider.view('original-provider-build') if name=='build' else provider.view('original-provider-build/'+name[6:])
        publisher=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda value:value))
        for opt in ('O0','O2'):
            for version in (1,2):
                failure=json.loads(current.get(f'profiles/analytical-model7-postimages-{opt}-v{version}/RESULT.json'))
                assert failure['status']=='FAILED' and failure['error'].startswith('AssertionError')
                failed.append(dict(optimization=opt,version=version,error=failure['error'],model_failure=False))
            top=json.loads(current.get(f'profiles/analytical-model7-postimages-{opt}-v3/RESULT.json'))
            assert top['status']=='ACTUAL_MODEL7_COMPLETE_COMPILED_NATIVE_SHORT_POSTIMAGES_EXACT_OLD_FULL_CONTROLS_REUSABLE' and top['fresh_full_periods']==0
            for item in top['contexts']:
                profile=mapped(current,item['profile_root']);q=json.loads((profile/'RESULT.json').read_text());kind=item['kind']
                assert q['kind']==kind and q['optimization']==opt
                key=projection[q['build_root']];build=current.view(key['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']==key['actual_BUILD_sha256']
                meta=json.loads((build/'BUILD.json').read_text())
                prefix=f'profiles/model7-search-daily-{kind}-short-{opt}-v1';prior=json.loads(old.get(prefix+'/RESULT.json'));oldbuild=old.view(prior_projection[prior['build_root']]['archive_prefix']);oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
                interface=compare(build,oldbuild,[7]);delta=differences(oldmeta['identity'],meta['identity'])
                assert delta==item['identity_changes'] and set(delta)<={'host','model7_capacity.source_sha256','model7_terminal_water.source_sha256','model7_terminal_water.policy','experimental_input_adapter','restart_publisher.library_sha256'}
                if 'restart_publisher.library_sha256' in delta:assert publisher(oldbuild/'restart_publish.dll',build/'restart_publish.dll')==item['publisher_equivalence']
                result=audit(profile,Reference(),locations=dict(build=build,inputs=mapped(current,q['input_root'])))
                assert result['days']==35
                warm=profile/'trajectory';oldwarm=old.view(prefix+'/trajectory');assert physical(rows(warm))==physical(rows(oldwarm))
                for day in (2,4,19,23,30,34,35):
                    with zipfile.ZipFile(io.BytesIO((warm/f'accepted-column-1-day-{day}.zip').read_bytes())) as x,zipfile.ZipFile(io.BytesIO((oldwarm/f'accepted-column-1-day-{day}.zip').read_bytes())) as y:
                        assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                assert binary((warm/'original/result_output.bin').read_bytes())==binary((oldwarm/'original/result_output.bin').read_bytes())
                observations.append(dict(kind=kind,optimization=opt,independent=result,interface=interface,physical_native_REAL4_postimage_exact=True))
    assert len(observations)==4 and len(failed)==4
    return dict(status='ACTUAL_MODEL7_SHORT_COMPILED_NATIVE_POSTIMAGES_INDEPENDENT_PASS_FULL_CONTROLS_REUSED',contexts=observations,original_observer_refusals=failed,
        short35_contexts=4,exact_cold_windows=12,new_full_periods=0,compiler_executions=0,model_executions=0,public_admission=False)
