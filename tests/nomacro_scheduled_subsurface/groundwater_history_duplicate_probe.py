"""Actual original and appended hydraulic-copy consistency before history admission."""
import argparse
import contextlib
import json
from pathlib import Path
import struct
import zipfile
import groundwater_history_runtime as runtime
from groundwater_history_native import decode

m=runtime.m


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir();profile=json.loads((args.profile_root/'RESULT.json').read_text())
    project=m.e.load(Path(profile['input_root']),original_output=profile['original_output']);build=Path(profile['build_root'])
    meta,case=m.validate_bundle(build,args.reference_work,project);source=args.profile_root/'trajectory/accepted-column-1-day-4.zip';digest=m.sha(source)
    with zipfile.ZipFile(source) as z:raw=z.read('macro.bin')
    carry=decode(raw,project);offset=carry['offset'];size=8*(5*project.nodes+4);block=raw[offset:offset+size]
    original=raw.find(block);assert original<offset and raw.count(block)==2
    record=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),source_checkpoint_sha256=digest,
                original_hydraulic_offset=original,appended_hydraulic_offset=offset,published=False,
                scope='Private original native reader initialization only; no daily step or external proposal is executed',
                final_state_overridden_by_appended_copy=None)
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for label,corrupt in (('positive',False),('divergent-original-copy',True)):
            target=args.output/label;target.mkdir();origin=target/'origin';receipt=m.h.verify_checkpoint(source,4,meta['binding'],origin)
            if corrupt:
                path=origin/'macro.bin';changed=bytearray(path.read_bytes());old=struct.unpack_from('<d',changed,original)[0]
                struct.pack_into('<d',changed,original,old+1.);path.write_bytes(changed)
            try:
                with contextlib.ExitStack() as stack:
                    host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,
                        [m.h.ColumnStart('original',4,origin,receipt)],runtime=True,checkpoint_enabled=True,
                        binding=meta['binding'],model=project.model,project=project)
                    assert host.columns[0].day==4
                    observation=dict(status='HYBRID_READY',accepted_day=4,original_source_unchanged=m.sha(source)==digest)
            except (ValueError,RuntimeError) as error:
                if not corrupt:raise
                diagnostic='\n'.join(p.read_text(errors='replace') for p in target.rglob('donor.stderr'))
                assert 'Inconsistent groundwater history hydraulic witness' in diagnostic,(str(error),diagnostic)
                observation=dict(status='REFUSED_INCONSISTENT_HYDRAULIC_WITNESS_BEFORE_READY',diagnostic=diagnostic,error=str(error))
            record[label]=observation;save()
        assert m.sha(source)==digest
        record['final_state_overridden_by_appended_copy']=record['divergent-original-copy']['status']=='HYBRID_READY'
        record['status']='ACTUAL_GROUNDWATER_HISTORY_DUPLICATE_NATIVE_DIAGNOSTIC_COMPLETE'
        print(record['status'],record['divergent-original-copy']['status'],flush=True)
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
