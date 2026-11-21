"""Read signed-default raw postimages against admitted unsigned byte interfaces."""
from contextlib import ExitStack
import io
import json
from pathlib import Path
import re
import zipfile

from ordinary_pond_verify import ROOT,git,SURFACES
from model7_search_science import SHA
from model7_unselected_science import rows,physical
from default_model_grammar_postimages import baseline
from default_model_grammar_source_inverse import complete_inverse,RUNTIME
from implicit_conductivity_forensics import output_records
from original_output_files import compare as compare_output

EXPECTED={
 'groundwater-explicit-history-step':{'host','implicit_groundwater_trial.source_sha256','implicit_groundwater_trial.original_projection_owner_sha256','original_output.source_sha256','original_output.history_owner_sha256','experimental_input_adapter','micro_lookup_state_source','lower_boundary_receipt.composition_sha256','groundwater_native_state.source_sha256','restart_publisher.library_sha256'},
 'snow-groundwater-explicit-daily':{'host','original_output.source_sha256','experimental_input_adapter','micro_lookup_state_source','lower_boundary_receipt.composition_sha256','restart_publisher.library_sha256'},
 'snow-cde-implicit-head-clock':{'host','implicit_conductivity.source_sha256','implicit_root_finalization.lookup_owner_sha256','cde_native_receipt.source_sha256','original_output.providers.snow_undrained.py','experimental_input_adapter','micro_lookup_state_source','restart_publisher.library_sha256'}}


def mapped(store,path):return store.view('profiles/'+str(path).replace('\\','/').split('/evidence/',1)[1])


def read(evidence,store=None):
    complete_inverse();observations=[];stocks=0
    locate=lambda path:mapped(store,path) if store else Path(path)
    compiled=json.loads(store.get('COMPILED_PROJECTION_V1.json')) if store else None
    with ExitStack() as stack:
        for opt in ('O0','O2'):
            cohort=evidence/f'default-model-grammar-{opt}-v3';q=json.loads((cohort/'RESULT.json').read_text())
            assert q['status']=='THREE_ACTUAL_DEFAULT_MODEL_STATE_OWNER_POSTIMAGES_PASS_NOT_ADMITTED'
            assert not git('diff',RUNTIME,q['source'],'--',*SURFACES)
            assert len(q['profiles'])==3 and q['fresh_full_periods']==0
            prior=locate(q['original_failed_observer']['path']);assert SHA(prior.read_bytes())==q['original_failed_observer']['sha256']
            assert json.loads(prior.read_text())['status']=='FAILED'
            for name,oldinputs,oldbuild,oldwarm,provenance in baseline(ROOT/'integration/f-ci/nomacro-complete01',opt,stack):
                item=q['profiles'][name];assert item['status']=='ACTUAL_SIGNED_DEFAULT1_COMPLETE_COMPILED_FORTRAN_PROVIDER_PHYSICAL_NATIVE_USER_OUTPUT_SHORT_COLD_PASS_NOT_ADMITTED'
                assert item['baseline']==provenance and item['literal']=='+0001' and item['parsed_numeric_model']==1
                if store:
                    projection=compiled[item['build_root']];build=store.view(projection['archive_prefix'])
                    assert SHA((build/'BUILD.json').read_bytes())==projection['actual_BUILD_sha256']
                else:build=Path(item['build_root'])
                assert SHA((build/'BUILD.json').read_bytes())==item['actual_BUILD_sha256']
                meta=json.loads((build/'BUILD.json').read_text());before=json.loads((oldbuild/'BUILD.json').read_text())
                new_source={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in build.glob('*.f90')}
                old_source={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in oldbuild.glob('*.f90')}
                assert new_source==old_source and {k:SHA(v) for k,v in new_source.items()}==item['complete_Fortran']
                for key in ('donor_objects','donor_flags','kernel_flags'):assert meta['identity'][key]==before['identity'][key]
                from calendar_evidence import differences
                compared=json.loads(json.dumps(meta['identity']));optional=None
                if name=='snow-cde-implicit-head-clock':
                    optional=compared['cde_native_receipt'].pop('optional_native_prefixes')
                    assert optional=={'S5HVC003':'48 + 8*(14+2*actual_layers), checked duplicated vapor domain'} and not meta['identity'].get('hydraulic_vapor')
                assert optional==item['inactive_vapor_only_CDE_descriptor']
                delta=differences(before['identity'],compared)
                assert delta==item['identity_changes'] and set(delta)==EXPECTED[name]
                def value(tree,path):
                    # Provider filenames contain a dot; all remaining paths
                    # are the original nested metadata keys.
                    if path=='original_output.providers.snow_undrained.py':return tree['original_output']['providers']['snow_undrained.py']
                    for field in path.split('.'):tree=tree[field]
                    return tree
                assert all(isinstance(value(compared,key),str) and re.fullmatch('[0-9a-f]{64}',value(compared,key)) for key in delta)
                from calendar_publisher import publisher_equivalence
                import types
                publisher=types.FunctionType(publisher_equivalence.__code__,dict(publisher_equivalence.__globals__,Path=lambda v:v))
                assert publisher(oldbuild/'restart_publish.dll',build/'restart_publish.dll')==item['publisher_equivalence']
                inputs=locate(item['input_root'])
                for filename,digest in item['input_inventory']:
                    actual=(inputs/filename).read_bytes();assert SHA(actual)==digest
                    original=(oldinputs/filename).read_bytes()
                    if filename!='swap.swp':assert actual==original
                    else:
                        strip=lambda raw:re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*\r?\n?','',raw.decode('cp1252').replace('\r\n','\n')).rstrip('\n')
                        assert strip(actual)==strip(original)
                warm=locate(item['trajectory_root']);data=rows(warm);assert len(data)==35 and physical(data)==physical(rows(oldwarm)[:35])
                assert meta['identity']['original_output']['trial_water_guard_cm']==1e-10
                for day in (2,4,30,34,35):
                    member=f'accepted-column-1-day-{day}.zip'
                    with zipfile.ZipFile(io.BytesIO((warm/member).read_bytes())) as actual,zipfile.ZipFile(io.BytesIO((oldwarm/member).read_bytes())) as original:
                        for native in ('macro.bin','result.end'):assert actual.read(native)==original.read(native)
                        if name=='snow-cde-implicit-head-clock':
                            from cde_native_receipt import decode
                            raw=actual.read('macro.bin');assert raw[:8]!=b'S5HVC003'
                            assert decode(raw,meta['project']['nodes'])==data[day-1]['solute_end_mg_cm2'];stocks+=1
                for filename in ('result_output.csv','result_output.bin'):
                    actual=warm/'original'/filename;original=oldwarm/'original'/filename
                    assert actual.is_file()==original.is_file()
                    if actual.is_file():
                        values=output_records(actual.read_bytes(),filename);assert values==output_records(original.read_bytes(),filename)[:len(values)]
                coldroot=locate(item['retained_actual_cold_root']) if item.get('retained_actual_cold_root') else cohort/name
                assert len(item['cold'])==2
                for low,high in ((2,4),(30,34)):
                    cold=coldroot/('own-'+str(low));actual=rows(cold)
                    assert len(actual)==high-low and physical(actual)==physical(data[low:high])
                    member=f'accepted-column-1-day-{high}.zip'
                    with zipfile.ZipFile(io.BytesIO((warm/member).read_bytes())) as a,zipfile.ZipFile(io.BytesIO((cold/member).read_bytes())) as b:
                        for native in ('macro.bin','result.end'):assert a.read(native)==b.read(native)
                    output=compare_output(warm/'original',cold/'original',meta['identity']['original_output'],low,high,meta['project']['start_date'])
                    receipt=next(v for v in item['cold'] if (v['start'],v['end'])==(low,high))
                    assert receipt['exact_physical'] and receipt['exact_complete_native'] and receipt['origin_unchanged'] and receipt['exact_original_output']==output
                observations.append(dict(optimization=opt,case=name,whole_Fortran_provider_flags_exact=True,source_only_identity_changes=delta,physical_native_and_user_output_exact=True,cold_windows=2,actual_BUILD_sha256=item['actual_BUILD_sha256']))
    assert len(observations)==6 and stocks==10
    return dict(status='INDEPENDENT_SIX_SIGNED_DEFAULT_MODEL_SOURCE_PROVIDER_PHYSICAL_NATIVE_USER_OUTPUT_POSTIMAGES_PASS',short35_contexts=6,exact_cold_windows=12,exact_CDE_private_native_stock_samples=stocks,observations=observations,new_full_periods=0,compiler_executions=0,model_executions=0,canonical_admission=False)
