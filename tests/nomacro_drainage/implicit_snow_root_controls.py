"""Actual compiled startup refusals for the added original root diagnostic carry."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();profile=json.loads((a.profile/'RESULT.json').read_text())
    build=Path(profile['build_root']);project=m.e.load(profile['input_root'],original_output=True)
    meta,case=m.validate_bundle(build,a.reference_work,project)
    selected=meta['identity']['original_output'];policy=selected['implicit_snow_root_carry']
    source=a.profile/'trajectory/accepted-column-1-day-4.zip';before=m.sha(source)
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    offset=len(raw)-96;assert raw[:8].decode()==policy['new_codec']
    attacks=[('parent-codec',None),('other-water-codec',None),('missing-tail',None),('truncated-tail',None),('extra-tail',None)]
    attacks += [('domain-'+str(i),i) for i in range(8)]
    attacks += [('domain-witness-'+str(i),i) for i in range(8)]
    attacks += [('nan-'+str(i),i) for i in range(2)]
    attacks += [('value-witness-'+str(i),i) for i in range(2)]
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        actual_BUILD_sha256=m.sha(build/'BUILD.json'),original_checkpoint_sha256=before,refusals=[],
        expected_compiled_refusals=len(attacks),accepted_model_days=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for label,index in attacks:
            target=a.output/label;target.mkdir();origin=target/'origin'
            receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
            bad=bytearray(raw)
            if label=='parent-codec':bad[:8]=policy['parent_codec'].encode()
            elif label=='other-water-codec':bad[:8]=b'S5IRW005' if raw[:8]!=b'S5IRW005' else b'S5IRW001'
            elif label=='missing-tail':del bad[-96:]
            elif label=='truncated-tail':del bad[-1:]
            elif label=='extra-tail':bad.extend(b'X')
            elif label.startswith('domain-'):
                value=struct.unpack_from('<i',bad,offset+4*index)[0]+1
                struct.pack_into('<i',bad,offset+4*index,value)
                if not label.startswith('domain-witness-'):struct.pack_into('<i',bad,offset+32+4*index,value)
            else:
                position=offset+64+8*index
                value=float('nan') if label.startswith('nan-') else struct.unpack_from('<d',bad,position)[0]+1
                struct.pack_into('<d',bad,position,value)
                if label.startswith('nan-'):struct.pack_into('<d',bad,position+16,value)
            (origin/'macro.bin').write_bytes(bad)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                        binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostics='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in target.rglob('donor.stderr'))
                assert 'ERROR STOP' in diagnostics and not list(target.rglob('accepted-*.zip')),(label,str(error),diagnostics)
                q['refusals'].append(dict(attack=label,status='REFUSED',authority='compiled_native',error=str(error),diagnostic=diagnostics))
            else:raise AssertionError('Malformed original root carry was accepted: '+label)
            assert m.sha(source)==before;save()
        q['status']='ACTUAL_COMPILED_IMPLICIT_SNOW_ROOT_NATIVE_REFUSALS_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['refusals']))


if __name__=='__main__':main()
