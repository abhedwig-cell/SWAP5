"""Actual post-year native counter forgeries rejected by production workers."""
import argparse,contextlib,json,struct
from pathlib import Path
import thermal_reset_runtime as runtime


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','epoch-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    args=parser.parse_args();args.output.mkdir();epochs=json.loads((args.epoch_root/'RESULT.json').read_text(encoding='utf8'))
    assert epochs['status']=='TWO_NONJANUARY_ORIGINAL_EPOCHS_YEAR_RESET_ACTUAL_NATIVE_COLD_PASS'
    m=runtime.m;q=dict(status='RUNNING',optimization=epochs['optimization'],cases={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for epoch,item in epochs['cases'].items():
            report=item['report'];build=Path(report['build_root']);project=m.e.load(Path(report['input_root']),original_output=True)
            meta,case=m.validate_bundle(build,args.reference_work,project);day=30;source=Path(item['root'])/f'actual/trajectory/accepted-column-1-day-{day}.zip';digest=m.sha(source)
            expected=next(c['annual_counter'] for c in item['actual_native_counters'] if c['day']==day);assert expected!=day
            checks=[]
            for attack,value in [('global-counter',day),('previous-year-counter',expected+365),('shifted-epoch-counter',expected+1),('zero-counter',0)]:
                out=args.output/epoch/attack;out.mkdir(parents=True);origin=out/'origin';receipt=m.h.verify_checkpoint(source,day,meta['binding'],origin)
                path=origin/'macro.bin';raw=bytearray(path.read_bytes());snow=struct.pack('<4i',1,project.nodes,0,7);pos=raw.index(snow+snow)+88
                assert struct.unpack_from('<20i',raw,pos)==struct.unpack_from('<20i',raw,pos+80)
                assert struct.unpack_from('<i',raw,pos+28)[0]==expected
                for offset in (28,108):struct.pack_into('<i',raw,pos+offset,value)
                path.write_bytes(raw)
                try:
                    with contextlib.ExitStack() as stack:
                        m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,[m.h.ColumnStart('original',day,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
                except (ValueError,RuntimeError) as error:
                    diagnostic='\n'.join(p.read_text(errors='replace') for p in out.rglob('donor.stderr'))
                    assert 'Inconsistent original Snow annual-reset day counter' in diagnostic and not list(out.glob('accepted-*.zip')),(attack,diagnostic,str(error))
                    checks.append(dict(attack=attack,day=day,actual_counter=expected,forged_counter=value,status='REFUSED',diagnostic=diagnostic,error=str(error)))
                else:raise AssertionError('Forged post-year native counter accepted: '+attack)
                assert m.sha(source)==digest
            q['cases'][epoch]=dict(source=str(source),source_sha256=digest,checks=checks);save()
        q['status']='EIGHT_ACTUAL_POST_YEAR_NATIVE_COUNTER_FORGERIES_REFUSED';print(q['status'],epochs['optimization'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
