"""Actual new Snow7/private-CDE native corruption controls, zero model days."""
import contextlib,math,struct,zipfile


def extra(m,build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';before=m.sha(source)
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    expected=struct.pack('<4i',1,project.nodes,int(project.solute),7);assert good.count(expected+expected)==1;snow=good.index(expected+expected)
    codecs=(b'S5FCW001',b'S5FCC001',b'S5FCW002',b'S5FCC002',b'S5FDW001',b'S5FDC001',b'S5FIW002',b'S5FIC002',
            b'S5FBW001',b'S5FBC001',b'S5FBW002',b'S5FBC002',b'S5BCW001',b'S5BCC001',b'S5BCW002',b'S5BCC002')
    assert len(set(codecs))==16 and good[:8] in codecs
    attacks=[('foreign-codec-'+code.decode(),code) for code in codecs if code!=good[:8]]
    attacks += [('snow-domain-'+str(i),i) for i in range(4)]
    attacks += [('snow-header-witness',None),('snow-missing-block',None)]
    attacks += [('snow-nan-'+str(i),i) for i in range(7)]
    attacks += [('snow-negative-'+str(i),i) for i in range(7)]
    if project.solute:attacks += [('private-sampro0-negative',None),('private-sampro0-inconsistent',None),('private-rounderr-nan',None),('private-value-witness',None)]
    checks=[]
    for label,index in attacks:
        target=out/label;target.mkdir(parents=True);origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);bad=bytearray(good)
        if label.startswith('foreign-codec-'):bad[:8]=index
        elif label.startswith('snow-domain-'):
            value=struct.unpack_from('<i',bad,snow+4*index)[0]+1
            for offset in (snow,snow+16):struct.pack_into('<i',bad,offset+4*index,value)
        elif label=='snow-header-witness':struct.pack_into('<i',bad,snow+16,2)
        elif label=='snow-missing-block':del bad[snow:snow+88]
        elif label.startswith('snow-'):
            struct.pack_into('<d',bad,snow+32+8*index,float('nan') if label.startswith('snow-nan-') else -1.)
        else:
            n=20+project.nodes;header=struct.pack('<3i',2,project.nodes,n);assert good.count(header+header)==1;c=good.index(header+header)+24
            field=n-1 if label=='private-rounderr-nan' else n-2
            previous=struct.unpack_from('<d',bad,c+8*field)[0]
            value=float('nan') if label=='private-rounderr-nan' else -1. if label=='private-sampro0-negative' else previous+1.
            struct.pack_into('<d',bad,c+8*field,value)
            if label!='private-value-witness':struct.pack_into('<d',bad,c+8*(n+field),value)
        assert bytes(bad)!=good;(origin/'macro.bin').write_bytes(bad)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,[m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            errors=list(target.rglob('donor.stderr'));outputs=list(target.rglob('donor.stdout'));diagnostic='\n'.join(p.read_text(errors='replace') for p in errors)
            assert errors and outputs and 'ERROR STOP' in diagnostic and not list(target.rglob('accepted-*.zip')),(label,diagnostic,str(error))
            assert all('HYBRID_READY' not in p.read_text() and 'HYBRID_DAY_RETURN' not in p.read_text() for p in outputs)
            checks.append(dict(attack=label,status='ACTUAL_COMPILED_NATIVE_REFUSED',diagnostic=diagnostic,error=str(error)))
        else:raise AssertionError('Malformed actual calendar native accepted: '+label)
        assert m.sha(source)==before
    assert len(checks)==len(attacks)==(39 if project.solute else 35)
    return checks
