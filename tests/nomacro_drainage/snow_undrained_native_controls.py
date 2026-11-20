"""Actual compiled startup attacks on actual new undrained Snow diagnostic native domains."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();qprofile=json.loads((a.profile/'RESULT.json').read_text())
    build=Path(qprofile['build_root']);project=original.m.e.load(qprofile['input_root'],original_output=True)
    meta,case=original.m.validate_bundle(build,a.reference_work,project);selected=meta['identity']['original_output'];n=project.nodes
    warm=Path(qprofile.get('trajectory_root',a.profile/'trajectory'));source=warm/'accepted-column-1-day-4.zip';before=original.m.sha(source)
    with zipfile.ZipFile(source) as z:good=z.read('macro.bin')
    root=len(good)-96
    attacks=[('parent-codec',None),('other-numerical-codec',None),('missing-root',None),('truncated',None),('trailing',None)]
    attacks += [(prefix+str(i),i) for prefix in ('root-domain-','root-witness-') for i in range(8)]
    attacks += [(prefix+str(i),i) for prefix in ('root-nan-','root-value-witness-') for i in range(2)]
    assert len(attacks)==25
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        actual_BUILD_sha256=original.m.sha(build/'BUILD.json'),original_checkpoint_sha256=before,
        expected_compiled_refusals=25,refusals=[],accepted_model_days=0,
        authority='Direct original compiled startup on private prepared inputs; typed reader checked separately on identical malformed bytes')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def worker(target,raw):
        origin=target/'origin';target.mkdir()
        receipt=original.m.h.verify_checkpoint(source,4,meta['binding'],origin);(origin/'macro.bin').write_bytes(raw)
        directory=target/'original'
        original.m.h.prepare_column(case,directory,original.m.h.ColumnStart('original',4,origin,receipt),True,True,project)
        r=subprocess.run([str(original.m.h.executable(build,'day_donor')),'./swap.swp'],cwd=directory,
            input=b'0 0\n',capture_output=True,timeout=20)
        (directory/'donor.stdout').write_bytes(r.stdout);(directory/'donor.stderr').write_bytes(r.stderr)
        return r,receipt
    save()
    try:
        positive,_=worker(a.output/'positive-startup',good)
        # The original main program finishes with CALL EXIT(100).
        assert positive.returncode in (0,100) and not positive.stderr and b'HYBRID_READY' in positive.stdout and b'HYBRID_DAY_RETURN' not in positive.stdout
        q['positive_original_startup']=dict(returncode=positive.returncode,actual_compiled_ready=True,accepted_model_days=0);save()
        for label,index in attacks:
            bad=bytearray(good)
            if label=='parent-codec':bad[:8]=b'S5IRW003'
            elif label=='other-numerical-codec':bad[7]=ord('0') if selected['swkimpl'] else ord('1')
            elif label=='missing-root':del bad[root:]
            elif label=='truncated':del bad[-1:]
            elif label=='trailing':bad.extend(b'X')
            elif label.startswith(('root-domain-','root-witness-')):
                v=struct.unpack_from('<i',bad,root+4*index)[0]+1;struct.pack_into('<i',bad,root+4*index,v)
                if label.startswith('root-domain-'):struct.pack_into('<i',bad,root+32+4*index,v)
            else:
                at=root+64+8*index;v=float('nan') if label.startswith('root-nan-') else struct.unpack_from('<d',bad,at)[0]+1.
                struct.pack_into('<d',bad,at,v)
                if label.startswith('root-nan-'):struct.pack_into('<d',bad,at+16,v)
            result,receipt=worker(a.output/label,bad)
            diagnostic=result.stderr.decode('utf-8',errors='replace')
            assert result.returncode!=0 and 'ERROR STOP' in diagnostic and b'HYBRID_READY' not in result.stdout and b'HYBRID_DAY_RETURN' not in result.stdout,(label,result.returncode,diagnostic)
            from snow_undrained_state import validate_native
            try:validate_native(bytes(bad),selected,n)
            except (ValueError,struct.error):public=True
            else:raise AssertionError('Typed reader accepted actual malformed undrained Snow native: '+label)
            q['refusals'].append(dict(attack=label,status='REFUSED',authority='compiled_native',returncode=result.returncode,
                diagnostic=diagnostic,identical_payload_typed_reader_refused=public));assert original.m.sha(source)==before;save()
        q['status']='ACTUAL_COMPILED_SNOW_UNDRAINED_NATIVE_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['refusals']))


if __name__=='__main__':main()
