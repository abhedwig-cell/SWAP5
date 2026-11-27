"""Read current native recovery and original failed runtime roles from immutable archives."""
from contextlib import ExitStack
import ast,json
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual
from closed_joint_history_calendar_feedback import R,git
from closed_joint_history_calendar_science import source_contract,payload
CURRENT='38eb3fa35db913ed6b4df20e3bc9dc1b178702a3'
ORIGINAL='9f794ca219367b85b79bdd9850617e4e26c691a1'
HELPER='app/hybrid_water/closed_default_calendar.py'


def native_delta():
    text=git('show',CURRENT+':'+HELPER).decode();tree=ast.parse(text)
    fn=next(v for v in tree.body if isinstance(v,ast.FunctionDef) and v.name=='render_regular_counter_validation')
    literals={v.targets[0].id:ast.literal_eval(v.value) for v in fn.body if isinstance(v,ast.Assign) and len(v.targets)==1 and isinstance(v.targets[0],ast.Name) and isinstance(v.value,ast.Constant)}
    suffixes=[]
    for call in ast.walk(fn):
        if not isinstance(call,ast.Call) or not isinstance(call.func,ast.Attribute) or call.func.attr!='replace' or len(call.args)!=3:continue
        left,value,count=call.args
        if isinstance(left,ast.Name) and left.id=='declaration':
            assert isinstance(value,ast.BinOp) and isinstance(value.op,ast.Add) and isinstance(value.left,ast.Name) and value.left.id=='declaration'
            assert ast.literal_eval(count)==1;suffixes.append(ast.literal_eval(value.right))
    assert len(suffixes)==1
    return literals['declaration'],suffixes[0],literals['anchor'],literals['validation']


def positive(stdout,stderr,receipt):
    assert not stderr and b'HYBRID_READY' in stdout and b'HYBRID_DAY_RETURN' not in stdout
    lines=stdout.decode().splitlines();at=next(i for i,v in enumerate(lines) if v.startswith('HYBRID_READY '));lines=lines[:at]
    stocks=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_STOCK_FLUX ')][-1]
    heads=[list(map(float,v.split()[1:])) for v in lines if v.startswith('HYBRID_HYDRAULIC ')][-1]
    assert stocks[:6]==receipt['stock_end_cm'] and heads[2:]==receipt['pressure_head_cm'] and heads[0]==receipt['groundwater_cm']


def audit(data):
    assert not git('diff',CURRENT,'HEAD','--','app','src','tools/solute','tools/vq','reference')
    contract=source_contract(CURRENT);declaration,suffix,anchor,validation=native_delta()
    with ExitStack() as stack:
        original=Archive(data,'CLOSED_JOINT_HISTORY_STATE16_ALL_LOCAL_RAW_V1',stack)
        current=Archive(data,'CLOSED_JOINT_HISTORY_STATE16_CURRENT_NATIVE_RECOVERY_RAW_V2',stack)
        assert original.record['sha256']=='236aee5648f1fd1dacfc4032dcc4085e4ab39e7d082f450d9ec17d11c6ca8cbe'
        assert current.record['sha256']=='ed69b40dc05679235890e58a74dec5819ce83894ac18b2b34861869a40643709'
        identity=json.loads(current.get('ACTUAL_DISTINCT_SOURCE_IDENTITIES.json'))
        assert identity['actual_current_compiler_source']==CURRENT and identity['actual_original_runtime_source']==ORIGINAL and not identity['original_source_roles_rebound']
        assert identity['current_tree']==git('rev-parse',CURRENT+'^{tree}').decode().strip() and identity['original_tree']==git('rev-parse',ORIGINAL+'^{tree}').decode().strip()
        oldcode=git('show',ORIGINAL+':tests/nomacro_drainage/closed_joint_history_calendar_native_controls.py').decode()
        code=current.get('observations/closed-joint-history16-current-native-recovery-controls-v2.py').decode()
        begin="        attacks=[";end="        assert SHA(source.read_bytes())==digest"
        tail=lambda s:s[s.index(begin):s.index(end)+len(end)]
        assert tail(oldcode).replace("m.h.verify_checkpoint(source,4,meta['binding'],origin)","m.h.verify_checkpoint(source,4,oldmeta['binding'],origin)")==tail(code)
        rows=[]
        for opt in ['O0','O2']:
            compile_record=json.loads(current.get('actual/evidence/closure16-current-native-v1/'+opt+'/RESULT.json'))
            assert compile_record['actual_current_compiler_source']==CURRENT and compile_record['original_runtime_source']==ORIGINAL
            for name in ['hys2-periodic-water-initial1','hys2-periodic-water-initial2']:
                profile=ReadView(original,'actual/evidence/closure16-feedback-v1/'+opt+'/'+name);q=json.loads((profile/'RESULT.json').read_text());assert q['actual_source']==ORIGINAL
                oldbuild=actual(original,q['build_root']);old=json.loads((oldbuild/'BUILD.json').read_text());assert SHA((oldbuild/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
                entry=next(v for v in compile_record['contexts'] if v['case']==name);assert entry['compile']['returncode']==0 and entry['actual_current_compiler_source']==CURRENT and entry['actual_original_runtime_source']==ORIGINAL
                build=actual(current,entry['current_build']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==entry['actual_current_BUILD_sha256']
                for key in ['compiler','compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert meta['identity'][key]==old['identity'][key]
                assert meta['inputs']==old['inputs']==dict(q['input_inventory']) and meta['identity']['original_output']==old['identity']['original_output']
                for role in ['donor','kernel']:
                    matches=[n for n in ['day_'+role,'day_'+role+'.exe'] if (build/n).is_file()];assert len(matches)==1 and SHA((build/matches[0]).read_bytes())==meta['executable_sha256'][role]
                assert meta['identity']['donor_generated'].keys()==old['identity']['donor_generated'].keys()
                for filename,digest in old['identity']['donor_generated'].items():
                    before=(oldbuild/filename).read_bytes();after=(build/filename).read_bytes();assert SHA(before)==digest and SHA(after)==meta['identity']['donor_generated'][filename]
                    if filename=='integral.f90':
                        text=before.decode('cp1252').replace('\r\n','\n');assert text.count(declaration)==text.count(anchor)==1
                        expected=text.replace(declaration,declaration+suffix,1).replace(anchor,anchor+validation,1)
                        assert before in [text.encode('cp1252'),text.replace('\n','\r\n').encode('cp1252')]
                        assert after in [expected.encode('cp1252'),expected.replace('\n','\r\n').encode('cp1252')] and before!=after
                    else:assert before==after
                old_objects={v.name:v for v in oldbuild.glob('*.o')};new_objects={v.name:v for v in build.glob('*.o')};assert old_objects.keys()==new_objects.keys() and len(old_objects)==23
                same=0
                for filename,path in old_objects.items():
                    if filename=='integral.o':assert path.read_bytes()!=new_objects[filename].read_bytes()
                    else:assert path.read_bytes()==new_objects[filename].read_bytes();same+=1
                controls=ReadView(current,'actual/evidence/closure16-current-native-recovery-v2/'+opt+'/'+name+'/native-controls');c=json.loads((controls/'RESULT.json').read_text())
                assert c['actual_current_compiler_source']==CURRENT and c['actual_original_runtime_source']==ORIGINAL and c['actual_original_BUILD_sha256']==q['actual_BUILD_sha256'] and c['actual_BUILD_sha256']==entry['actual_current_BUILD_sha256']
                assert c['actual_current_compiler_source_contract']==contract and c['actual_original_runtime_source_contract']==source_contract(ORIGINAL)
                assert c['genuine_own_positive_ready'] and c['actual_original_stock_and_head_restored_exactly'] and c['status']=='ACTUAL_DEFAULT_CALENDAR_OWN_POSITIVE_AND_COMPILED_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
                checkpoint=profile/'trajectory/accepted-column-1-day-4.zip';assert SHA(checkpoint.read_bytes())==c['original_checkpoint_sha256'];receipt,native=payload(checkpoint);assert receipt['binding']==old['binding']
                positive((controls/'genuine-own-positive/donor.stdout').read_bytes(),(controls/'genuine-own-positive/donor.stderr').read_bytes(),receipt['receipt'])
                assert len(c['refusals'])==28 and len({v['attack'] for v in c['refusals']})==28
                for attack in c['refusals']:
                    folder=controls/'native'/attack['attack'];raw=(folder/'origin/macro.bin').read_bytes();assert raw!=native['macro.bin'] and SHA(raw)==attack['mutant_sha256'] and attack['status']=='REFUSED'
                    assert b'ERROR STOP' in (folder/'donor.stderr').read_bytes() and b'HYBRID_READY' not in (folder/'donor.stdout').read_bytes() and b'HYBRID_DAY_RETURN' not in (folder/'donor.stdout').read_bytes()
                for day in [2,7,9,30,34,35]:
                    receipt,_=payload(profile/'trajectory'/f'accepted-column-1-day-{day}.zip');folder=ReadView(current,'actual/evidence/closure16-current-native-all-samples-v1/'+opt+'/'+name+'/'+str(day))
                    assert receipt['binding']==old['binding'];positive((folder/'donor.stdout').read_bytes(),(folder/'donor.stderr').read_bytes(),receipt['receipt'])
                rows.append(dict(case=name,optimization=opt,actual_original_runtime_source=ORIGINAL,actual_current_compiler_source=CURRENT,actual_original_BUILD_sha256=q['actual_BUILD_sha256'],actual_current_BUILD_sha256=entry['actual_current_BUILD_sha256'],unchanged_whole_objects=same,exact_original_native_positives=7,compiled_native_refusals=28,original_periods_replayed=0))
        assert len(rows)==4 and sum(v['unchanged_whole_objects'] for v in rows)==88
        return dict(status='FOUR_ACTUAL_CURRENT_NATIVE_READERS_LITERAL_SOURCE_88WHOLE_OBJECTS_28EXACT_ORIGINAL_RESTORES_112CORRUPTIONS_ARCHIVE_INDEPENDENT_PASS',contexts=rows,current_compiled_contexts=4,unchanged_whole_objects=88,exact_original_native_positives=28,compiled_native_refusals=112,compiler_executions=0,model_executions=0,original_scientific_roles_rebound=False,canonical_admission=False)
