"""Attack actual compiled boundary3 model/drainage/partition/codec header, with no accepted days."""
import contextlib,struct,zipfile
from frost_calendar_state_native import m
from frost_analytical_composition import selected,native_domain


def native(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project)
    source=full/'accepted-column-1-day-2.zip';before=m.sha(source)
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    item=selected(project);header=native_domain(good,item,project.nodes)
    packed=struct.pack('<'+str(len(header))+'i',*header);at=good.index(packed+packed)
    attacks=[('version',0,4),('nodes',1,project.nodes+1),('layers',2,len(item['analytical_frost_models'])+1),
             ('kind',3,1-int(project.solute)),('bottom',4,8 if item['bottom']==5 else 5)]
    for i,model in enumerate(item['analytical_frost_models']):
        attacks.extend((f'layer-{i}-model-{value}',7+i,value) for value in (2,12,3 if model!=3 else 7))
    attacks += [('drainage',5,1-item['drainage']),('partition-active',6,1-int(item['drainage']==1)),('foreign-codec',None,None),('old09-codec',None,None),('all-foreign-model',None,None),('header-witness',0,4),('missing-model-block',None,None)]
    checks=[]
    for label,index,value in attacks:
        target=out/label;target.mkdir(parents=True);origin=target/'origin'
        receipt=m.h.verify_checkpoint(source,2,meta['binding'],origin);bad=bytearray(good)
        if label in ('foreign-codec','old09-codec'):bad[:8]=b'S5FAC001' if not project.solute and label=='foreign-codec' else b'S5FAW001' if project.solute and label=='foreign-codec' else b'S5UAC001' if project.solute else b'S5UAW001'
        elif label=='missing-model-block':del bad[at:at+2*len(packed)]
        elif label=='all-foreign-model':
            for i in range(len(item['analytical_frost_models'])):
                for offset in (at,at+len(packed)):struct.pack_into('<i',bad,offset+4*(7+i),1 if any(x!=1 for x in item['analytical_frost_models']) else 3)
        else:
            struct.pack_into('<i',bad,at+4*index,value)
            if label!='header-witness':struct.pack_into('<i',bad,at+len(packed)+4*index,value)
        assert bytes(bad)!=good;(origin/'macro.bin').write_bytes(bad)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',2,origin,receipt)],runtime=True,checkpoint_enabled=True,
                    binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'))
            diagnostic='\n'.join(p.read_text(errors='replace') for p in errors)
            assert errors and outputs and 'ERROR STOP' in diagnostic and not list(target.rglob('accepted-*.zip'))
            assert all('HYBRID_READY' not in p.read_text() and 'HYBRID_DAY_RETURN' not in p.read_text() for p in outputs)
            checks.append(dict(attack=label,status='ACTUAL_COMPILED_NATIVE_MODEL_DOMAIN_REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Malformed analytical Frost model domain accepted: '+label)
        assert m.sha(source)==before
    assert len(checks)==18
    return checks
