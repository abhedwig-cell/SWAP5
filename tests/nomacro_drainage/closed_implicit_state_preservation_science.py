"""Independently read all forty old numerical builds and actual native consumers."""
from contextlib import ExitStack
import json,struct
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_postimages_archive_science import actual,compare as exact_compare
from closed_implicit_state_feedback import P,PARENT,git
PRODUCER='62cf6eefb110099ab1c181b06f2a5ae74b48f144'
RAW_SHA='1e07ff4764eeae2c5f705a1985d1897237f6c50fc7145abc196f4fa23df9cd68'


def objects(before,current,item):
    left=json.loads((before/'BUILD.json').read_text());right=json.loads((current/'BUILD.json').read_text())
    assert SHA((before/'BUILD.json').read_bytes())==item['actual_original_BUILD_sha256'] and SHA((current/'BUILD.json').read_bytes())==item['actual_current_BUILD_sha256']
    for key in ['compiler','compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert left['identity'][key]==right['identity'][key],key
    assert left['inputs']==right['inputs']
    source={p.name:p.read_bytes() for p in before.glob('*.f90')};now={p.name:p.read_bytes() for p in current.glob('*.f90')};assert source and source.keys()==now.keys()
    changed={n for n in source if source[n]!=now[n]};assert changed<={'implicit_hydraulic_state_native.f90','implicit_frost_hydraulic_state_native.f90'}
    proposal=json.loads(git('show',PRODUCER+':'+P+'CLOSED_IMPLICIT_STATE13_SOURCE_PROPOSAL_V7.json'))
    for name in changed:
        path='app/hybrid_water/'+name;a=source[name].replace(b'\r\n',b'\n');b=now[name].replace(b'\r\n',b'\n')
        assert a==git('show',PARENT+':'+path) and b==git('show',PRODUCER+':'+path)
        assert SHA(a)==proposal['files'][path]['before_lf_sha256'] and SHA(b)==proposal['files'][path]['after_lf_sha256']
    old={p.name:p.read_bytes() for p in before.glob('*.o')};new={p.name:p.read_bytes() for p in current.glob('*.o')};assert old and old.keys()==new.keys()
    delta={n for n in old if old[n]!=new[n]};assert delta<={n.removesuffix('.f90')+'.o' for n in changed}
    assert {n:SHA(v) for n,v in new.items()}==item['whole_objects']
    assert {n:SHA(v) for n,v in now.items()}==item['generated_files']
    proof=item['current_native_guard_proof'];assert proof['static_guard_object_changes']==sorted(delta) and proof['static_guard_source_changes']==sorted(changed)
    assert proof['unchanged_whole_objects']=={n:SHA(v) for n,v in old.items() if n not in delta}
    assert b'closed_desaturation_trial' not in now['headcalc.f90']
    for folder,meta in [(before,left),(current,right)]:
        for name,digest in meta['identity']['donor_generated'].items():assert SHA((folder/name).read_bytes())==digest
        for role in ['donor','kernel']:
            names=[n for n in ['day_'+role,'day_'+role+'.exe'] if (folder/n).is_file()];assert len(names)==1 and SHA((folder/names[0]).read_bytes())==meta['executable_sha256'][role]
    return dict(whole_objects=len(old),unchanged_whole_objects=len(old)-len(delta),changed_static_guard_objects=sorted(delta),all_other_whole_numerical_objects_exact=True,actual_original_BUILD_sha256=SHA((before/'BUILD.json').read_bytes()),actual_current_BUILD_sha256=SHA((current/'BUILD.json').read_bytes()))


def native(store,item,current,original,before_build):
    from closed_implicit_state_science import payload
    control=item['current_compiled_original_native_controls'];assert control['selected'] is True and control['model_days']==control['model_executions']==0
    root=ReadView(store,'actual/evidence/closure13-native-preservation-v2/'+item['optimization']+'/current/'+item['case']+'/native-controls')
    checkpoint=root/'original-accepted-day4.zip';meta,raw=payload(checkpoint);good=raw['macro.bin']
    assert checkpoint.read_bytes()==(original/'trajectory/accepted-column-1-day-4.zip').read_bytes() and SHA(checkpoint.read_bytes())==control['actual_original_checkpoint_sha256']
    old=json.loads((before_build/'BUILD.json').read_text());assert meta['binding']==old['binding'] and meta['receipt']['day']==4
    # Obtain the exact unchanged serialized domain from both literal witnesses.
    positions=[i for i in range(len(good)-8) if good[i:i+8] in (b'S5IHX001',b'S5IFX001')]
    assert len(positions)==1;pos=positions[0];suffix=good[pos:];assert (len(suffix)-8)%8==0;size=(len(suffix)-8)//2;assert suffix[8:8+size]==suffix[8+size:]
    values=struct.unpack('<'+str(size//4)+'i',suffix[8:8+size]);attacks={'missing-extension':good[:pos],'truncated-extension':good[:-1],'foreign-tag':good[:pos]+b'S5BAD999'+good[pos+8:],'trailing-byte':good+b'x'}
    domain=old['identity']['implicit_hydraulic_state'];expected=[1,old['project']['nodes'],len(domain['models']),domain['solute'],1,0,domain['snow'],domain.get('frost',0),1,2,domain.get('drainage',1),domain['bottom'],domain['partition'],*domain['models']]
    assert list(values)==expected and suffix[:8]==domain['native_extension_tag'].encode()
    for index,value in enumerate(values):
        bad=bytearray(good)
        for offset in [pos+8,pos+8+size]:struct.pack_into('<i',bad,offset+4*index,value+1)
        attacks['field-'+str(index)]=bytes(bad)
    bad=bytearray(good);struct.pack_into('<i',bad,pos+8+size,values[0]+1);attacks['single-witness']=bytes(bad)
    assert len(control['controls'])==len({v['attack'] for v in control['controls']})==len(attacks) and {v['attack'] for v in control['controls']}==set(attacks)
    positive=root/'exact-original-native-positive';out=(positive/'donor.stdout').read_bytes();assert not (positive/'donor.stderr').read_bytes() and (positive/'origin/macro.bin').read_bytes()==(positive/'original/macro-origin.bin').read_bytes()==good
    lines=out.decode().splitlines();ready=next(i for i,v in enumerate(lines) if v.startswith('HYBRID_READY '));before=lines[:ready];stocks=[v.split()[1:] for v in before if v.startswith('HYBRID_STOCK_FLUX ')];heads=[v.split()[1:] for v in before if v.startswith('HYBRID_HYDRAULIC ')]
    receipt=meta['receipt'];assert list(map(float,stocks[-1][:6]))==receipt['stock_end_cm'] and list(map(float,heads[-1][2:]))==receipt['pressure_head_cm'] and float(heads[-1][0])==receipt['groundwater_cm'] and b'HYBRID_DAY_RETURN' not in out
    for entry in control['controls']:
        folder=root/entry['attack'];mutant=attacks[entry['attack']];assert SHA(mutant)==entry['mutant_sha256'] and (folder/'origin/macro.bin').read_bytes()==(folder/'original/macro-origin.bin').read_bytes()==mutant
        assert b'ERROR STOP' in (folder/'donor.stderr').read_bytes() and b'HYBRID_READY' not in (folder/'donor.stdout').read_bytes() and b'HYBRID_DAY_RETURN' not in (folder/'donor.stdout').read_bytes()
    return dict(exact_original_checkpoint_sha256=SHA(checkpoint.read_bytes()),positive_receipt_stock_and_heads_exact=True,compiled_native_refusals=len(attacks),old_model_days_replayed=0)


def audit(data):
    with ExitStack() as stack:
        store=Archive(data,'CLOSED_IMPLICIT_STATE13_FORTY_NATIVE_PRESERVATION_RAW_V8',stack);assert store.record['sha256']==RAW_SHA and store.record['actual_compiler_source']==PRODUCER
        names=['IMPLICIT_HYDRAULIC_STATE11_LOCAL_RAW_V2','IMPLICIT_HYDRAULIC_STATE11_CURRENT_COUPLINGS_RAW_V3','IMPLICIT_HYDRAULIC_STATE11_FROST_CAUSAL_RAW_V1','IMPLICIT_HYDRAULIC_STATE11_GUARD_RAW_V1','FROST_UNDRAINED_STATE08_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V1','FROST_ANALYTICAL_BOUNDARY10_LOCAL_WINDOWS_O0_O2_RAW_V2']
        from frost_boundary_git_archive import GitArchiveSource
        from closed_implicit_state_feedback import R
        old={s.record['sha256']:s for s in [Archive(GitArchiveSource(R,PARENT),n,stack) for n in names]};contexts=[]
        for opt in ['O0','O2']:
            for role,n in [('current',12),('parent',8)]:
                q=json.loads(store.get('actual/evidence/closure13-native-preservation-v2/'+opt+'/'+role+'/RESULT.json'));assert len(q['contexts'])==n and q['model_days']==q['model_executions']==0 and q.get('actual_current_compiler_source',q.get('actual_compiler_source'))==PRODUCER
                for entry in q['contexts']:
                    item=dict(entry,optimization=opt);previous=old[item.get('original_archive_sha256',item.get('actual_original_archive_sha256'))];current=actual(store,item['build_root'])
                    current_meta=json.loads((current/'BUILD.json').read_text());inputs=actual(store,item['input_root'])
                    for name,digest in current_meta['inputs'].items():assert SHA((inputs/name).read_bytes())==digest
                    if role=='parent':
                        before=ReadView(previous,item['original_build_prefix']);report=exact_compare(before,current,item['actual_original_BUILD_sha256'],item['actual_current_BUILD_sha256']);report=dict(whole_objects=report['actual_complete_objects'],unchanged_whole_objects=report['actual_complete_objects'],changed_static_guard_objects=[],all_other_whole_numerical_objects_exact=True)
                    else:
                        matches=[k for k,v in previous.names.items() if k.endswith('/BUILD.json') and v['sha256']==item['actual_original_BUILD_sha256']];assert len(matches)==1;before=ReadView(previous,matches[0].removesuffix('/BUILD.json'));report=objects(before,current,item)
                        matches=[k for k,v in previous.names.items() if k.endswith('/RESULT.json') and k.removesuffix('/RESULT.json')+'/trajectory/accepted-column-1-day-4.zip' in previous.names and json.loads(previous.get(k)).get('actual_BUILD_sha256')==item['actual_original_BUILD_sha256']];assert len(matches)==1
                        report['actual_original_native_controls']=native(store,item,current,ReadView(previous,matches[0].removesuffix('/RESULT.json')),before)
                    contexts.append(dict(case=item['case'],optimization=opt,role=role,**report))
        counts=dict(contexts=len(contexts),whole_objects=sum(v['whole_objects'] for v in contexts),unchanged_whole_objects=sum(v['unchanged_whole_objects'] for v in contexts),changed_static_guard_objects=sum(len(v['changed_static_guard_objects']) for v in contexts),compiled_native_positive_controls=sum('actual_original_native_controls' in v for v in contexts),compiled_native_refusals=sum(v.get('actual_original_native_controls',{}).get('compiled_native_refusals',0) for v in contexts),old_model_days_replayed=0)
        assert counts==store.record['counts']
        return dict(status='INDEPENDENT_FORTY_ORIGINAL_NUMERICAL_BUILDS_1022_IDENTICAL_OBJECTS_24_STATIC_GUARDS_AND_480_COMPILED_NATIVE_REFUSALS_PASS',actual_compiler_source=PRODUCER,raw_sha256=RAW_SHA,contexts=contexts,counts=counts,compiler_executions=0,model_executions=0,original_scientific_identities_rebound=False,canonical_admission=False)
