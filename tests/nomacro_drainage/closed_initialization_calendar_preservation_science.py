"""Independently read whole objects, exact canonical metadata and real native controls."""
from contextlib import ExitStack
import io,json,struct,zipfile
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from implicit_hydraulic_state_postimages_archive_science import actual,compare
from closed_initialization_calendar_feedback import R,PARENT,git


def audit(data):
    with ExitStack() as stack:
        current=Archive(data,'CLOSED_INITIALIZATION_STATE15_CURRENT_OLD_PRESERVATION_RAW_V2',stack)
        assert current.record['sha256']=='8ccf9b64fa763559f52ce4c42b71e2af44592f3df7d0adc0601f881ff9bafc81'
        old=Archive(GitArchiveSource(R,PARENT),'CLOSED_DEFAULT_CALENDAR_STATE14_ALL_LOCAL_FAILURES_AND_SUCCESSES_RAW_V2',stack)
        assert old.record['sha256']=='736057de6b483eb42bb3e36e57b6277d0cc3136c15f35fce625f98d693c8106a'
        records=[]
        for opt in ['O0','O2']:
            canonical=Archive(GitArchiveSource(R,PARENT),'CLOSED_DEFAULT_CALENDAR_STATE14_FIRST_WINDOWS_'+opt+'_ORIGINAL_V1',stack)
            assert canonical.record['actual_producer_source']=='94c86c2918278ffd9595b9960eb8e1522652277a'
            projection=json.loads(canonical.get('COMPILED_PROJECTION_V1.json'))
            prefix='actual/evidence/closure15-preservation-v2/'+opt
            result=json.loads(current.get(prefix+'/RESULT.json'))
            assert result['status']=='FIVE_CURRENT_OLD_INITIAL1_COMPLETE_GENERATED_OBJECTS_AND_ORIGINAL_NATIVE_READERS_PASS_ZERO_MODEL_DAYS' and result['actual_compiler_source']=='9704f2626ef655e8b7b6108e058035b46e4f7119' and result['model_days']==result['model_executions']==0 and len(result['contexts'])==5
            for row in result['contexts']:
                name=row['case'];folder=ReadView(current,prefix+'/'+name);build=actual(current,row['build_root']);before=ReadView(old,row['actual_original_build_prefix'])
                proof=compare(before,build,row['actual_original_BUILD_sha256'],row['actual_current_BUILD_sha256']);assert proof==row['whole_object_proof']
                meta=json.loads((build/'BUILD.json').read_text());old_result=json.loads(old.get(row['actual_original_profile']+'/RESULT.json'))
                assert old_result['actual_source']==row['actual_original_scientific_producer'] and old_result['actual_BUILD_sha256']==row['actual_original_BUILD_sha256']
                canonical_result=json.loads(canonical.get('current/'+name+'/RESULT.json'));canonical_build=ReadView(canonical,projection[canonical_result['build_root']]['archive_prefix'])
                canonical_meta=json.loads((canonical_build/'BUILD.json').read_text())
                assert SHA((canonical_build/'BUILD.json').read_bytes())==canonical_result['actual_BUILD_sha256']
                assert meta['inputs']==canonical_meta['inputs'] and meta['identity']['original_output']==canonical_meta['identity']['original_output']
                for path,digest in meta['inputs'].items():assert SHA((folder/'inputs'/path).read_bytes())==digest
                original=canonical.get('current/'+name+'/trajectory/accepted-column-1-day-4.zip')
                assert (folder/'native-controls/original-accepted-day4.zip').read_bytes()==original
                with zipfile.ZipFile(io.BytesIO(original)) as z:receipt=json.loads(z.read('checkpoint.json'));good=z.read('macro.bin')
                controls=row['compiled_original_native'];assert controls['actual_original_checkpoint_sha256']==SHA(original) and controls['actual_original_binding']==receipt['binding'] and controls['actual_current_BUILD_sha256']==row['actual_current_BUILD_sha256']
                assert controls['actual_original_scientific_producer']==canonical_result['actual_source'] and controls['actual_original_artifact_sha256']==canonical.record['sha256'] and controls['actual_original_BUILD_sha256']==canonical_result['actual_BUILD_sha256']
                assert controls['compiler_bytes_claimed_identical'] is False and controls['canonical_metadata_compared_complete'] and len(controls['controls'])==5
                mutated=bytearray(good);struct.pack_into('<i',mutated,8,meta['project']['nodes']+1)
                payloads={'own-positive':good,'foreign-magic':b'S5BAD999'+good[8:],'truncated':good[:-1],'trailing':good+b'x','foreign-node-count':bytes(mutated)}
                for item in controls['controls']:
                    label=item['control'];root=folder/'native-controls'/label;raw=(root/'origin/macro.bin').read_bytes()
                    assert raw==payloads[label] and SHA(raw)==item['actual_mutant_sha256'] and item['model_days']==0
                    out=(root/'donor.stdout').read_bytes();err=(root/'donor.stderr').read_bytes();assert b'HYBRID_DAY_RETURN' not in out
                    if label=='own-positive':
                        assert item['returncode'] in (0,100) and b'HYBRID_READY' in out and not err
                        lines=out.decode().splitlines();lines=lines[:next(i for i,v in enumerate(lines) if v.startswith('HYBRID_READY '))]
                        stock=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_STOCK_FLUX ')][-1]
                        heads=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_HYDRAULIC ')][-1]
                        assert stock[:6]==receipt['receipt']['stock_end_cm'] and heads[2:]==receipt['receipt']['pressure_head_cm'] and heads[0]==receipt['receipt']['groundwater_cm']
                    else:assert item['returncode'] not in (0,100) and b'ERROR STOP' in err and b'HYBRID_READY' not in out
                records.append(dict(case=name,optimization=opt,actual_original_numerical_producer=row['actual_original_scientific_producer'],actual_current_compiler_source=result['actual_compiler_source'],actual_canonical_metadata_native_producer=canonical_result['actual_source'],original_compiler_and_canonical_metadata_roles_distinct=True,whole_object_proof=proof,actual_canonical_native_checkpoint_sha256=SHA(original),original_native_positives=1,compiled_native_refusals=4,old_model_days=0))
        assert len(records)==10 and sum(v['whole_object_proof']['actual_complete_objects'] for v in records)==210
        return dict(status='TEN_CURRENT_OLD_INITIAL1_COMPLETE_OBJECT_CONTEXTS_EXACT_CANONICAL_METADATA_ORIGINAL_NATIVE_AND_DISTINCT_PRODUCER_ROLES_INDEPENDENT_PASS',contexts=records,context_count=10,whole_objects=210,original_native_positives=10,compiled_native_refusals=40,old_model_periods_replayed=0,compiler_executions=0,model_executions=0,scientific_producers_rebound=False)
