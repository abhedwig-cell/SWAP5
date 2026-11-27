"""Real original model1 calendar readers: own positive and zero-day corruptions."""
import argparse,json,struct,subprocess,zipfile
from pathlib import Path
from closed_default_calendar_feedback import R,SHA,m,git

READERS={'S5IOW001':'original_output_controls','S5IHW001':'output_hysteresis_controls',
         'S5CIC001':'cde_interval_controls','S5CIH001':'cde_interval_controls'}


def controls(profile,reference,out):
    q=json.loads((profile/'RESULT.json').read_text())
    assert q['status']=='ACTUAL_CLOSED_DEFAULT_CALENDAR_BUDGET_NATIVE_COLD_AND_TRANSACTION_FEEDBACK_PASS_NOT_QUALIFIED'
    project=m.e.load(q['input_root'],original_output=True,time_step_policy=q['time_step_policy'])
    from closed_default_calendar_science import source_contract
    contract=source_contract(q['actual_source'])
    build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text());case=Path(q['input_root'])
    assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']
    for name,digest in meta['identity']['donor_generated'].items():assert SHA((build/name).read_bytes())==digest
    for role,digest in meta['executable_sha256'].items():assert SHA(m.h.executable(build,'day_'+role).read_bytes())==digest
    assert meta['inputs']==dict(q['input_inventory'])
    source=profile/'trajectory/accepted-column-1-day-4.zip';digest=SHA(source.read_bytes())
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    codec=raw[:8].decode();reader=READERS[codec]
    out.mkdir();positive=out/'genuine-own-positive';positive.mkdir()
    result=dict(status='RUNNING_ACTUAL_DEFAULT_CALENDAR_NATIVE_CONTROLS',actual_observer_source=git('rev-parse','HEAD').decode().strip(),
        actual_producer_source=q['actual_source'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),
        original_checkpoint_sha256=digest,native_codec=codec,original_native_reader_family=reader,mutation_owner='actual-default-calendar-native-header-and-private-state-v2',compiler_executions=0,model_days=0,
        canonical_admission=False,actual_producer_source_contract=contract,refusals=[])
    save=lambda:(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    save()
    try:
        origin=positive/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        worker=positive/'original';m.h.prepare_column(case,worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (positive/'donor.stdout').write_bytes(child.stdout);(positive/'donor.stderr').write_bytes(child.stderr)
        assert child.returncode in (0,100) and not child.stderr and b'HYBRID_READY' in child.stdout and b'HYBRID_DAY_RETURN' not in child.stdout
        result['genuine_own_positive_ready']=True;save()
        attacks=[('foreign-magic',b'S5BAD999'+raw[8:]),('truncated',raw[:-1]),('trailing',raw+b'x')]
        positions=[]
        for pos in range(8,len(raw)-160):
            if raw[pos:pos+8]!=struct.pack('<2i',1,project.nodes):continue
            h=struct.unpack_from('<20i',raw,pos)
            if h[3]>100 and h==struct.unpack_from('<20i',raw,pos+80):positions.append((pos,h))
        assert len(positions)==1;pos,h=positions[0];nr=h[3]
        for label,index,value,witness in [('shape',1,project.nodes+1,True),('policy',4,h[4]+1,True),
            ('nprint',5,h[5]+1,True),('foreign-day',6,5,True),('negative-day',6,-1,True),
            ('counter',7,h[7]+1,True),('negative-counter',7,-1,True),('print-counter',8,h[8]+1,True),
            ('zero-pointer',9,0,True),('overflow-pointer',10,2147483647,True),('future-pointer',10,100,True),
            ('reset-policy',11,1-h[11],True),('flag-domain',12,2,True),('short-flag',18,1-h[18],True),
            ('step-flag',19,1-h[19],True),('header-witness',7,h[7]+1,False)]:
            bad=bytearray(raw)
            for offset in ([pos,pos+80] if witness else [pos]):struct.pack_into('<i',bad,offset+4*index,value)
            attacks.append((label,bytes(bad)))
        for label,index,value,witness in [('nonfinite',0,float('nan'),True),('value-witness',0,123.,False),('negative-period',nr-1,-1.,True)]:
            bad=bytearray(raw)
            for offset in ([pos+160,pos+160+8*nr] if witness else [pos+160]):struct.pack_into('<d',bad,offset+8*index,value)
            attacks.append((label,bytes(bad)))
        if project.solute:
            cp=pos+160+16*nr;version,nn,size=struct.unpack_from('<3i',raw,cp)
            assert version==2 and nn==project.nodes and size==20+nn and raw[cp:cp+12]==raw[cp+12:cp+24]
            for index in range(3):
                bad=bytearray(raw)
                for offset in [cp,cp+12]:struct.pack_into('<i',bad,offset+4*index,struct.unpack_from('<i',raw,cp+4*index)[0]+1)
                attacks.append(('cde-header-'+str(index),bytes(bad)))
            for label,index,value,witness in [('cde-nonfinite',1,float('nan'),True),('cde-negative-initial',0,-1.,True),
                ('cde-private-anchor',size-2,struct.unpack_from('<d',raw,cp+24+8*(size-2))[0]+1.,True),
                ('cde-private-negative',size-2,-1.,True),('cde-private-rounderr-nonfinite',size-1,float('nan'),True),('cde-private-witness',size-2,123.,False)]:
                bad=bytearray(raw)
                for offset in ([cp+24,cp+24+8*size] if witness else [cp+24]):struct.pack_into('<d',bad,offset+8*index,value)
                attacks.append((label,bytes(bad)))
        if q['specification']['history']:
            header=struct.pack('<5i',1,project.nodes,0,q['specification']['history'],int(project.solute));assert raw.count(header+header)==1;hp=raw.index(header+header)
            for index in range(5):
                bad=bytearray(raw)
                for offset in [hp,hp+20]:struct.pack_into('<i',bad,offset+4*index,struct.unpack_from('<i',raw,hp+4*index)[0]+1)
                attacks.append(('history-domain-'+str(index),bytes(bad)))
            bad=bytearray(raw);struct.pack_into('<i',bad,hp+20,2);attacks.append(('history-domain-witness',bytes(bad)))
        for label,bad in attacks:
            target=out/'native'/label;target.mkdir(parents=True);origin=target/'origin'
            receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);(origin/'macro.bin').write_bytes(bad)
            worker=target/'original';m.h.prepare_column(case,worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
            child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
            (target/'donor.stdout').write_bytes(child.stdout);(target/'donor.stderr').write_bytes(child.stderr)
            assert child.returncode not in (0,100) and b'ERROR STOP' in child.stderr and b'HYBRID_READY' not in child.stdout and b'HYBRID_DAY_RETURN' not in child.stdout,(label,child.returncode)
            result['refusals'].append(dict(attack=label,status='REFUSED',mutant_sha256=SHA(bad),returncode=child.returncode,diagnostic=child.stderr.decode('utf8',errors='replace')));save()
        assert result['refusals'] and all(v['status']=='REFUSED' for v in result['refusals'])
        assert SHA(source.read_bytes())==digest
        result['status']='ACTUAL_DEFAULT_CALENDAR_OWN_POSITIVE_AND_COMPILED_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
    except Exception as error:
        result.update(status='FAILED_ACTUAL_DEFAULT_CALENDAR_NATIVE_CONTROLS',error=repr(error));raise
    finally:save()
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser()
    for name in ['profile','reference-work','output']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();q=controls(a.profile,a.reference_work,a.output);print(q['status'],len(q['refusals']),flush=True)
