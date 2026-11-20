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
from groundwater_snow_forensics import native as independent_native
import cde_interval_controls as interval

m=original.m


def groundwater(build,reference,project,full,out):
    meta,case=m.validate_bundle(build,reference,project);source=full/'accepted-column-1-day-4.zip';before=m.sha(source)
    import zipfile
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    row=m.rows(full)[3];selected=meta['identity']['original_output']
    parsed=independent_native(raw,row,meta,selected);offset=parsed['groundwater_domain_offset']
    hys=selected['swhyst'];domain_bytes=104;count=13;value_offset=offset+domain_bytes
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
        if label=='old-daily-codec':bad[:8]=('S5GTC'+f'{2*hys+1:03d}').encode()
        elif label=='other-clock-codec':bad[:8]=('S5GS'+('I' if selected.get('cde_clock_output') else 'C')+f'{0 if hys==0 else 2*hys-1:03d}').encode()
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
            # Ordinary groundwater restores the authoritative accessible head;
            # the existing public receipt guard then rejects its disagreement.
            # History modes instead compare the original hydraulic witness in
            # the compiled reader. Preserve both actual refusal authorities.
            public_head=(hys==0 and label=='hydraulic-head' and type(error) is ValueError and
                         str(error)=='Restored donor state differs from the accepted checkpoint receipt')
            assert ('ERROR STOP' in diagnostic or public_head) and not list(target.glob('accepted-*.zip')),(label,str(error),diagnostic)
            results.append(dict(attack=label,status='REFUSED',error=str(error),diagnostic=diagnostic,
                                refusal_authority='accepted_receipt' if public_head else 'compiled_native'))
        else:raise AssertionError('Corrupt groundwater CDE clock native accepted: '+label)
        assert m.sha(source)==before
    return results


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--reuse-native-from',type=Path)
    a=p.parse_args();a.output.mkdir(parents=True);record=json.loads((a.profile/'RESULT.json').read_text())
    build=Path(record['build_root']);project=m.e.load(record['input_root'],original_output=True);before=m.sha(build/'BUILD.json')
    q=dict(status='RUNNING',actual_BUILD_sha256=before,profile_root=str(a.profile),
           source_commit=__import__('subprocess').check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        selected=m.validate_bundle(build,a.reference_work,project)[0]['identity']['original_output']
        owner=interval if selected.get('groundwater_cde_interval') else clock
        if selected.get('groundwater_cde_interval') and selected['swdra']==0:
            from groundwater_snow_interval_native import native
            if a.reuse_native_from:
                previous=json.loads((a.reuse_native_from/'RESULT.json').read_text())
                assert previous['status']=='FAILED' and previous['error']=='AssertionError()' and previous['actual_BUILD_sha256']==before
                q['original_failed_control_root']=str(a.reuse_native_from)
            q['clock_refusals']=native(build,a.reference_work,project,a.profile/'trajectory',a.output/'clock-native',
                None if a.reuse_native_from is None else a.reuse_native_from/'clock-native')
        else:
            assert a.reuse_native_from is None
            q['clock_refusals']=owner.native(build,a.reference_work,project,a.profile/'trajectory',a.output/'clock-native')
        save()
        q['groundwater_refusals']=groundwater(build,a.reference_work,project,a.profile/'trajectory',a.output/'groundwater-native');save()
        q['transactions']=clock.transactions(build,a.reference_work,project,a.profile/'trajectory',a.output/'transactions');save()
        assert m.sha(build/'BUILD.json')==before and all(v is True for v in q['transactions'].values())
        q['status']='ACTUAL_EXPLICIT_SNOW_GROUNDWATER_CDE_COMPILED_NATIVE_TRANSACTION_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'],len(q['clock_refusals']),len(q['groundwater_refusals']))


if __name__=='__main__':main()
