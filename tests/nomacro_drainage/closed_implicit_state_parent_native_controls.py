"""Current compiled static guard reads exact original native bytes; zero model days."""
from pathlib import Path
import hashlib,json,struct,subprocess,zipfile
from closed_implicit_state_feedback import R,P,PARENT,git,m
from implicit_hydraulic_state import selected,header,native_tag,validate_candidate
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def native_controls(archive,original,oldmeta,build,project,output):
    item=selected(project)
    if item is None:return dict(selected=False,model_days=0)
    output.mkdir();checkpoint=output/'original-accepted-day4.zip';raw=archive.get(original.path+'/trajectory/accepted-column-1-day-4.zip');checkpoint.write_bytes(raw)
    with zipfile.ZipFile(checkpoint) as z:
        manifest=json.loads(z.read('checkpoint.json'));good=z.read('macro.bin')
    assert manifest['binding']==oldmeta['binding'] and manifest['receipt']['day']==4
    values=header(item,project.nodes);packed=struct.pack('<'+str(len(values))+'i',*values);tag=native_tag(item);suffix=tag+packed+packed;assert good.endswith(suffix);validate_candidate(good,project)
    result=dict(actual_current_compiler_source=git('rev-parse','HEAD').decode().strip(),actual_original_checkpoint_sha256=SHA(raw),original_checkpoint_binding_preserved=True,current_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),selected=True,model_days=0,model_executions=0,controls=[])
    save=lambda:(output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    def start(name,mutant):
        root=output/name;root.mkdir();origin=root/'origin';receipt=m.h.verify_checkpoint(checkpoint,4,oldmeta['binding'],origin);(origin/'macro.bin').write_bytes(mutant)
        worker=root/'original';m.h.prepare_column(Path(project.input_directory),worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (root/'donor.stdout').write_bytes(child.stdout);(root/'donor.stderr').write_bytes(child.stderr)
        assert b'HYBRID_DAY_RETURN' not in child.stdout and SHA(checkpoint.read_bytes())==SHA(raw)
        return child,receipt
    positive,receipt=start('exact-original-native-positive',good)
    assert positive.returncode in (0,100) and b'HYBRID_READY' in positive.stdout and not positive.stderr
    lines=positive.stdout.decode().splitlines();stocks=[v.split()[1:] for v in lines if v.startswith('HYBRID_STOCK_FLUX ')];heads=[v.split()[1:] for v in lines if v.startswith('HYBRID_HYDRAULIC ')]
    assert len(stocks)==len(heads)==1 and list(map(float,stocks[0][:6]))==receipt['stock_end_cm']
    assert list(map(float,heads[0][2:]))==receipt['pressure_head_cm'] and float(heads[0][0])==receipt['groundwater_cm']
    result['exact_original_native_positive']=dict(returncode=positive.returncode,initial_physical_stock_and_head_receipt_exact=True);save()
    attacks=[('missing-extension',good[:-len(suffix)]),('truncated-extension',good[:-1]),('foreign-tag',good[:-len(suffix)]+b'S5BAD999'+good[-len(suffix)+8:]),('trailing-byte',good+b'x')]
    pos=len(good)-len(suffix)+8;size=len(packed)
    for index,value in enumerate(values):
        mutant=bytearray(good)
        for offset in [pos,pos+size]:struct.pack_into('<i',mutant,offset+4*index,value+1)
        attacks.append(('field-'+str(index),bytes(mutant)))
    mutant=bytearray(good);struct.pack_into('<i',mutant,pos+size,values[0]+1);attacks.append(('single-witness',bytes(mutant)))
    for name,mutant in attacks:
        try:validate_candidate(mutant,project)
        except ValueError:pass
        else:raise AssertionError('Python accepted corrupted original native domain')
        child,_=start(name,mutant);assert child.returncode not in (0,100) and b'ERROR STOP' in child.stderr and b'HYBRID_READY' not in child.stdout
        result['controls'].append(dict(attack=name,mutant_sha256=SHA(mutant),returncode=child.returncode,compiled_refused_before_ready=True));save()
    result['status']='CURRENT_STATIC_GUARD_EXACT_ORIGINAL_NATIVE_POSITIVE_AND_COMPILED_REFUSALS_PASS_ZERO_MODEL_DAYS';save();return result


def compare(before,build,project):
    old=json.loads((before/'BUILD.json').read_text());new=json.loads((build/'BUILD.json').read_text())
    for key in ['compiler_sha256','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources']:assert old['identity'][key]==new['identity'][key],key
    assert old['inputs']==new['inputs']
    sources={p.name:p.read_bytes() for p in before.glob('*.f90')};current={p.name:p.read_bytes() for p in build.glob('*.f90')};assert sources and sources.keys()==current.keys()
    changes={name for name in sources if sources[name]!=current[name]};allowed={'implicit_hydraulic_state_native.f90','implicit_frost_hydraulic_state_native.f90'};assert changes<=allowed
    proposal=json.loads(git('show','HEAD:'+P+'CLOSED_IMPLICIT_STATE13_SOURCE_PROPOSAL_V7.json'))
    for name in changes:
        path='app/hybrid_water/'+name;left=sources[name].replace(b'\r\n',b'\n');right=current[name].replace(b'\r\n',b'\n')
        assert left==git('show',PARENT+':'+path) and right==git('show','HEAD:'+path)
        assert SHA(left)==proposal['files'][path]['before_lf_sha256'] and SHA(right)==proposal['files'][path]['after_lf_sha256']
    objects={p.name:p.read_bytes() for p in before.glob('*.o')};now={p.name:p.read_bytes() for p in build.glob('*.o')};assert objects and objects.keys()==now.keys()
    differences={name for name in objects if objects[name]!=now[name]};assert differences<={name.removesuffix('.f90')+'.o' for name in changes}
    assert not any('closed_desaturation_trial' in raw.decode('cp1252') for name,raw in current.items() if name=='headcalc.f90')
    return dict(all_original_inputs_exact=True,static_guard_source_changes=sorted(changes),static_guard_object_changes=sorted(differences),all_other_complete_sources_and_whole_objects_exact=True,unchanged_whole_objects={name:SHA(raw) for name,raw in objects.items() if name not in differences},current_changed_static_guard_objects={name:SHA(now[name]) for name in differences},original_changed_static_guard_objects={name:SHA(objects[name]) for name in differences},generated_files={name:SHA(raw) for name,raw in current.items()},whole_objects={name:SHA(raw) for name,raw in now.items()},original_numerical_implementation_and_native_layout_unchanged=True,physical_periods_replayed=0)
