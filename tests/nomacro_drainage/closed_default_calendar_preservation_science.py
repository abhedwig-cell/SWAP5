"""Independently read forty original/current whole-object and native comparisons."""
from contextlib import ExitStack
import json,zipfile,io
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from frost_boundary_git_archive import GitArchiveSource
from implicit_hydraulic_state_postimages_archive_science import actual,compare
from closed_default_calendar_feedback import R,PARENT,git
PRODUCER='12833d6ede29b8379d330fcee238c9ae32d4f3ef'


def audit(data):
    with ExitStack() as stack:
        current=Archive(data,'CLOSED_DEFAULT_CALENDAR_STATE14_FORTY_OLD_OBJECTS_AND_NATIVE_RAW_V4',stack)
        old=Archive(GitArchiveSource(R,PARENT),'CLOSED_IMPLICIT_STATE13_FORTY_NATIVE_PRESERVATION_RAW_V8',stack)
        assert old.record['sha256']=='1e07ff4764eeae2c5f705a1985d1897237f6c50fc7145abc196f4fa23df9cd68'
        assert not git('diff',PRODUCER,'HEAD','--','app','src','tools','reference')
        contexts=[];positives=refusals=0
        for opt in ['O0','O2']:
            prefix='actual/evidence/closure14-preservation-v1/'+opt
            q=json.loads(current.get(prefix+'/RESULT.json'))
            assert q['status']=='TWENTY_ACTUAL_OLD_COMPLETE_GENERATED_AND_OBJECT_CONTEXTS_CURRENT_NATIVE_READERS_PASS_ZERO_MODEL_DAYS'
            assert q['actual_compiler_source']==PRODUCER and q['actual_accepted_parent']==PARENT and q['model_days']==q['model_executions']==0 and len(q['contexts'])==20
            for item in q['contexts']:
                assert item['actual_source']==PRODUCER and item['actual_original_archive_sha256']==old.record['sha256']
                before=ReadView(old,item['original_build_prefix']);now=actual(current,item['build_root'])
                report=compare(before,now,item['actual_original_BUILD_sha256'],item['actual_current_BUILD_sha256'])
                assert report==item['whole_object_proof']
                original=json.loads((before/'BUILD.json').read_text());meta=json.loads((now/'BUILD.json').read_text());inputs=actual(current,item['input_root'])
                for name,digest in original['inputs'].items():assert SHA((inputs/name).read_bytes())==digest
                for name,digest in meta['identity']['donor_generated'].items():assert SHA((now/name).read_bytes())==digest
                controls=item['compiled_original_native']
                if controls is not None:
                    assert item['case'].startswith('current-') and controls['model_days']==0 and controls['actual_current_BUILD_sha256']==item['actual_current_BUILD_sha256']
                    root=ReadView(current,prefix+'/'+item['case']+'/native-controls');checkpoint=(root/'original-accepted-day4.zip').read_bytes()
                    oldpath='actual/evidence/closure13-native-preservation-v2/'+opt+'/current/'+item['case'].removeprefix('current-')+'/native-controls/original-accepted-day4.zip'
                    assert checkpoint==old.get(oldpath) and SHA(checkpoint)==controls['actual_original_checkpoint_sha256']
                    with zipfile.ZipFile(io.BytesIO(checkpoint)) as z:manifest=json.loads(z.read('checkpoint.json'));good=z.read('macro.bin')
                    assert manifest['binding']==controls['actual_original_binding'] and manifest['receipt']['day']==4
                    positions=[i for i in range(len(good)-8) if good[i:i+8] in (b'S5IHX001',b'S5IFX001')];assert len(positions)==1;pos=positions[0]
                    attacks={'own-positive':good,'foreign-magic':b'S5BAD999'+good[8:],'missing-domain':good[:pos],'truncated':good[:-1],'trailing':good+b'x'}
                    assert len(controls['controls'])==len(attacks)==5
                    for control in controls['controls']:
                        name=control['control'];assert control['mutant_sha256']==SHA(attacks[name]) and control['actual_compiled_reader'] and control['model_days']==0
                        stdout=(root/name/'donor.stdout').read_bytes();stderr=(root/name/'donor.stderr').read_bytes();assert b'HYBRID_DAY_RETURN' not in stdout
                        if name=='own-positive':
                            assert control['returncode'] in (0,100) and b'HYBRID_READY' in stdout and not stderr
                            lines=stdout.decode().splitlines();ready=next(i for i,line in enumerate(lines) if line.startswith('HYBRID_READY '));lines=lines[:ready]
                            stocks=[list(map(float,line.split()[1:])) for line in lines if line.startswith('HYBRID_STOCK_FLUX ')];heads=[list(map(float,line.split()[1:])) for line in lines if line.startswith('HYBRID_HYDRAULIC ')]
                            assert stocks[-1][:6]==manifest['receipt']['stock_end_cm'] and heads[-1][2:]==manifest['receipt']['pressure_head_cm'] and heads[-1][0]==manifest['receipt']['groundwater_cm'];positives+=1
                        else:assert control['returncode'] not in (0,100) and b'ERROR STOP' in stderr and b'HYBRID_READY' not in stdout;refusals+=1
                contexts.append(dict(case=item['case'],optimization=opt,actual_current_producer=PRODUCER,**report))
        assert len(contexts)==40 and sum(v['actual_complete_objects'] for v in contexts)==1046 and positives==24 and refusals==96
        return dict(status='INDEPENDENT_FORTY_COMPLETE_OLD_NUMERICAL_SOURCE_AND_OBJECT_CONTEXTS_AND_ORIGINAL_NATIVE_READERS_PASS',contexts=contexts,whole_objects=1046,complete_original_native_positives=24,compiled_native_refusals=96,compiler_executions=0,model_executions=0,old_model_periods_replayed=0,scientific_producers_rebound=False,canonical_admission=False)
