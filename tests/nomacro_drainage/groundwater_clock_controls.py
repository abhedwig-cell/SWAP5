"""Real compiled existing clock refusals plus composed groundwater state attacks."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import cde_clock_controls as clock
import implicit_conductivity_runtime as original
from groundwater_clock_forensics import native as independent_native

m=original.m


def groundwater(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';before=m.sha(source)
    import zipfile
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    row=m.rows(full)[3];selected=meta['identity']['original_output']
    parsed=independent_native(raw,row,meta,selected);offset=parsed['groundwater_domain_offset']
    hys=selected['swhyst'];domain_bytes=104 if hys else 72;count=13 if hys else 9;value_offset=offset+domain_bytes
    n=project.nodes
    attacks=[('old-daily-codec',None),('other-clock-codec',None)]
    attacks += [('domain-'+str(i),i) for i in range(count)]
    attacks += [('nan-'+str(i),i) for i in (0,n,2*n,3*n+1,4*n+2,5*n+2,5*n+3)]
    attacks += [('negative-'+str(i),i) for i in (n,2*n,3*n+1,4*n+2,5*n+3)]
    attacks += [('hydraulic-head',0),('hydraulic-volume',5*n+3)]
    results=[]
    for label,index in attacks:
        target=out/label;target.mkdir(parents=True);origin=target/'origin'
        receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin);path=origin/'macro.bin';bad=bytearray(path.read_bytes())
        if label=='old-daily-codec':bad[:8]=b'S5GHC003' if hys else b'S5GWC001'
        elif label=='other-clock-codec':bad[:8]=b'S5GCH001' if hys!=1 else b'S5GCH003'
        elif label.startswith('domain-'):
            value=struct.unpack_from('<i',bad,offset+4*index)[0]+1
            for position in (offset+4*index,offset+domain_bytes//2+4*index):struct.pack_into('<i',bad,position,value)
        else:
            position=value_offset+8*index
            value=float('nan') if label.startswith('nan-') else -1. if label.startswith('negative-') else struct.unpack_from('<d',bad,position)[0]+1.
            struct.pack_into('<d',bad,position,value)
        path.write_bytes(bad)
        try:
            with contextlib.ExitStack() as stack:
                m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                    [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                    binding=meta['binding'],model=project.model,project=project)
        except (ValueError,RuntimeError) as error:
            diagnostic='\n'.join(p.read_text(encoding='utf-8',errors='replace') for p in target.rglob('donor.stderr'))
            assert ('ERROR STOP' in diagnostic or 'native' in str(error).lower()) and not list(target.glob('accepted-*.zip')),(label,str(error),diagnostic)
            results.append(dict(attack=label,status='REFUSED',error=str(error),diagnostic=diagnostic))
        else:raise AssertionError('Corrupt groundwater CDE clock native accepted: '+label)
        assert m.sha(source)==before
    return results


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();record=json.loads((a.profile/'RESULT.json').read_text())
    build=Path(record['build_root']);project=m.e.load(record['input_root'],original_output=True);before=m.sha(build/'BUILD.json')
    q=dict(status='RUNNING',actual_BUILD_sha256=before)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['clock_refusals']=clock.native(build,a.reference_work,project,a.profile/'trajectory',a.output/'clock-native');save()
        q['groundwater_refusals']=groundwater(build,a.reference_work,project,a.profile/'trajectory',a.output/'groundwater-native');save()
        q['transactions']=clock.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions');save()
        assert m.sha(build/'BUILD.json')==before and all(v is True for v in q['transactions'].values())
        q['status']='ACTUAL_GROUNDWATER_CDE_CLOCK_COMPILED_NATIVE_TRANSACTION_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['clock_refusals']),len(q['groundwater_refusals']))


if __name__=='__main__':main()
