"""Actual compiled closed/Gardner native startup attacks, zero accepted model days."""
import argparse,json,re,struct,subprocess,sys,zipfile
from pathlib import Path
from closed_implicit_state_feedback import R,SHA,m


def controls(profile,reference,out):
    q=json.loads((profile/'RESULT.json').read_text());assert q['status'].endswith('PASS_NOT_QUALIFIED')
    build=Path(q['build_root']);spec=q['specification']
    project=m.e.load(q['input_root'],original_output=True,time_step_policy=q['time_step_policy'])
    meta,case=m.validate_bundle(build,reference,project);nodes=project.nodes
    source=profile/'trajectory/accepted-column-1-day-4.zip';before=SHA(source.read_bytes())
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    domains=[]
    if spec['frost']:
        domains.append(('thermal',[1,nodes,0,int(project.solute),spec['hysteresis'],1,1,spec['drainage'],1,2]))
        if spec['implicit']:domains.append(('root',[5,nodes,int(project.solute),1,spec['hysteresis'],spec['bottom'],1,0]))
    elif spec['snow']:
        from snow_undrained import selection
        selected=selection(project)
        domains.append(('root',[3,nodes,int(project.solute),1,spec['hysteresis'],spec['bottom'],spec['implicit'],0]))
    elif spec['hysteresis']:domains.append(('hysteresis',[1,nodes,0,spec['hysteresis'],int(project.solute)]))
    from implicit_hydraulic_state import selected as hydraulic_selection,header as hydraulic_header
    hydraulic=hydraulic_selection(project);assert hydraulic and hydraulic['bottom']==6 and hydraulic['drainage']==0
    domains.append(('implicit-per-layer',hydraulic_header(hydraulic,nodes)))
    attacks=[('foreign-magic',b'S5BAD999'+good[8:]),('truncated',good[:-1]),('trailing',good+b'x')]
    text=(Path(q['input_root'])/'swap.swp').read_text(encoding='cp1252')
    if spec['calendar']=='dates':
        date_rows=re.findall(r'(?mis)^\s*OUTDATINT\s*=\s*\n\s*(\d{4}-\d{2}-\d{2})',text)
        assert len(date_rows)==1
        if date_rows[0]<meta['project']['start_date']:
            positions=[]
            for pos in range(8,len(good)-160):
                if good[pos:pos+8]!=struct.pack('<2i',1,nodes):continue
                header=struct.unpack_from('<20i',good,pos)
                if header[3]>100 and header==struct.unpack_from('<20i',good,pos+80):positions.append((pos,header))
            assert len(positions)==1;pos,header=positions[0];assert header[10]==1
            bad=bytearray(good)
            for offset in (pos,pos+80):struct.pack_into('<i',bad,offset+40,2)
            attacks.append(('forged-advance-of-original-pending-date-pointer',bytes(bad)))
    for name,values in domains:
        header=struct.pack('<'+str(len(values))+'i',*values);assert good.count(header+header)==1,(name,values)
        pos=good.index(header+header);size=len(header)
        for index,value in enumerate(values):
            bad=bytearray(good)
            for offset in (pos,pos+size):struct.pack_into('<i',bad,offset+4*index,value+1)
            attacks.append((name+'-field-'+str(index),bytes(bad)))
        bad=bytearray(good);struct.pack_into('<i',bad,pos+size,values[0]+1)
        attacks.append((name+'-single-witness',bytes(bad)))
    out.mkdir();result=dict(status='RUNNING_ACTUAL_COMPILED_CLOSED_IMPLICIT_NATIVE_REFUSALS',actual_observer_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),
        actual_producer_source=q['actual_source'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes()),
        original_checkpoint_sha256=before,model_days=0,compiler_executions=0,canonical_admission=False,domains=domains,refusals=[])
    save=lambda:(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    save()
    def startup(label,raw):
        target=out/label;target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
        (origin/'macro.bin').write_bytes(raw);worker=target/'original'
        m.h.prepare_column(case,worker,m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        child=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=worker,input=b'0 0\n',capture_output=True,timeout=20)
        (target/'donor.stdout').write_bytes(child.stdout);(target/'donor.stderr').write_bytes(child.stderr)
        assert b'HYBRID_DAY_RETURN' not in child.stdout and SHA(source.read_bytes())==before
        return child
    try:
        child=startup('genuine-own-positive',good)
        assert child.returncode in (0,100) and not child.stderr and b'HYBRID_READY' in child.stdout
        result['genuine_own_positive_ready']=True;save()
        for label,bad in attacks:
            child=startup(label,bad)
            assert child.returncode not in (0,100) and b'ERROR STOP' in child.stderr and b'HYBRID_READY' not in child.stdout,(label,child.returncode,child.stdout,child.stderr)
            result['refusals'].append(dict(attack=label,actual_mutant_sha256=SHA(bad),returncode=child.returncode,compiled_refused_before_ready=True,diagnostic=child.stderr.decode('utf8',errors='replace')));save()
        result['status']='ACTUAL_COMPILED_CLOSED_IMPLICIT_OWN_POSITIVE_AND_NATIVE_REFUSALS_PASS_ZERO_MODEL_DAYS'
    except Exception as error:result.update(status='FAILED_ACTUAL_COMPILED_CLOSED_IMPLICIT_NATIVE_REFUSALS',error=repr(error));raise
    finally:save()
    return result


def main():
    p=argparse.ArgumentParser()
    for name in ['profile','reference-work','output']:p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();q=controls(a.profile,a.reference_work,a.output);print(q['status'],len(q['refusals']),flush=True)

if __name__=='__main__':main()
