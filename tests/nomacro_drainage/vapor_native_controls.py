"""Exercise actual compiled vapor startup before accepting any model day."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import original_output_controls as inherited
m=inherited.m


def main():
    parser=argparse.ArgumentParser()
    for name in ('reference-work','profile','output'):parser.add_argument('--'+name,type=Path,required=True)
    a=parser.parse_args();a.output.mkdir()
    profile=json.loads((a.profile/'RESULT.json').read_text());build=Path(profile['build_root'])
    project=m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    meta,case=m.validate_bundle(build,a.reference_work,project);vapor=meta['identity']['hydraulic_vapor']
    source=a.profile/'trajectory/accepted-column-1-day-532.zip';digest=m.sha(source)
    with zipfile.ZipFile(source) as archive:good=archive.read('macro.bin')
    assert good[:8]==vapor['native_codec'].encode()
    values=[3,project.nodes,vapor['numlay'],0,int(project.solute),0,0,0,0,0,1,2,1,6]+vapor['models']+vapor['SWVAPOR']
    header=struct.pack('<'+str(len(values))+'i',*values);assert good.count(header+header)==1
    domain=good.index(header+header);width=len(header)
    micros=[]
    for offset in range(len(good)-40):
        if good[offset:offset+8]!=struct.pack('<2i',2,1):continue
        fields=struct.unpack_from('<8i',good,offset)
        if fields[3:]==(3,1,vapor['numlay'],431,431):micros.append(offset)
    assert len(micros)==1;micro=micros[0];clock=struct.unpack_from('<d',good,micro+32)[0]
    micro_end=micro+40+8*862*vapor['numlay']
    assert struct.unpack_from('<i',good,micro_end)[0]==44+8*862*vapor['numlay']
    oxygen_header=struct.pack('<3id',1,1,project.nodes,clock)
    assert good.count(oxygen_header)==1;oxygen=good.index(oxygen_header)
    top_header=struct.pack('<id',1,clock)
    tops=[i for i in range(oxygen,micro) if good[i:i+12]==top_header]
    assert len(tops)==1;top=tops[0]
    attacks=[]
    for kind in ('domain','domain-witness'):
        for index in range(len(values)):
            edits=[(domain+4*index,struct.pack('<i',values[index]+1))]
            if kind=='domain':edits.append((domain+width+4*index,struct.pack('<i',values[index]+1)))
            attacks.append((kind+'-'+str(index),edits))
    for codec in (b'S5HVW001',b'S5HVW002',b'S5HVC002',b'S5IOW001',b'S5IOC001'):
        attacks.append((codec.decode(),[(0,codec)]))
    for index in range(8):
        old=struct.unpack_from('<i',good,micro+4*index)[0]
        attacks.append(('micro-header-'+str(index),[(micro+4*index,struct.pack('<i',old+1))]))
    attacks.extend((label,[(offset,struct.pack('<d',value))]) for label,offset,value in (
        ('micro-clock',micro+32,clock+1),('micro-M-nan',micro+40,float('nan')),
        ('micro-K-negative',micro+40+8*431*vapor['numlay'],-1),
        ('oxygen-clock',oxygen+12,clock+1),('oxygen-nan',oxygen+20,float('nan')),
        ('top-clock',top+4,clock+1),('top-nan',top+12,float('nan'))))
    attacks.append(('micro-trailer',[(micro_end,struct.pack('<i',0))]))
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        actual_BUILD_sha256=m.sha(build/'BUILD.json'),original_checkpoint_sha256=digest,
        accepted_model_days=0,refusals=[],public_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    def worker(label,raw):
        target=a.output/label;target.mkdir();origin=target/'origin'
        receipt=m.h.verify_checkpoint(source,532,meta['binding'],origin);(origin/'macro.bin').write_bytes(raw)
        directory=target/'original'
        m.h.prepare_column(case,directory,m.h.ColumnStart('original',532,origin,receipt),True,True,project)
        r=subprocess.run([str(m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,input=b'0 0\n',capture_output=True,timeout=20)
        (directory/'donor.stdout').write_bytes(r.stdout);(directory/'donor.stderr').write_bytes(r.stderr)
        return r
    save()
    try:
        positive=worker('positive-startup',good)
        assert positive.returncode in (0,100) and not positive.stderr and b'HYBRID_READY' in positive.stdout and b'HYBRID_DAY_RETURN' not in positive.stdout
        result['positive_compiled_startup']=True;save()
        for label,edits in attacks:
            bad=bytearray(good)
            for offset,value in edits:bad[offset:offset+len(value)]=value
            r=worker(label,bad);diagnostic=r.stderr.decode(errors='replace')
            assert r.returncode!=0 and 'ERROR STOP' in diagnostic and b'HYBRID_READY' not in r.stdout and b'HYBRID_DAY_RETURN' not in r.stdout,(label,diagnostic)
            result['refusals'].append(dict(attack=label,returncode=r.returncode,diagnostic=diagnostic));assert m.sha(source)==digest;save()
        result['inherited_output_native_refusals']=inherited.native(build,a.reference_work,project,a.profile/'trajectory',a.output/'inherited-native');save()
        result['transactions']=inherited.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions')
        result['status']='ACTUAL_COMPILED_VAPOR_NATIVE3_REFUSALS_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'],len(result['refusals']),len(result['inherited_output_native_refusals']),flush=True)


if __name__=='__main__':main()
