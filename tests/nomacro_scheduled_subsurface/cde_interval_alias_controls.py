"""Reject actual nonzero interval stock aliases without guessing private state."""
import argparse,contextlib,json,struct
from pathlib import Path
import cde_interval_runtime as runtime


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();report=json.loads((a.profile_root/'RESULT.json').read_text(encoding='utf8'))
    assert report['status']=='ACTUAL_CDE_INTERVAL_SHORT_NATIVE_USER_OUTPUT_PASS'
    m=runtime.m;build=Path(report['build_root']);project=m.e.load(Path(report['input_root']),original_output=True)
    meta,case=m.validate_bundle(build,a.reference_work,project);day=35;source=a.profile_root/f'trajectory/accepted-column-1-day-{day}.zip';digest=m.sha(source)
    q=dict(status='RUNNING',build_sha256=m.sha(build/'BUILD.json'),source_sha256=digest,checks=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for attack in ('anchor-from-cumulative-samini','shifted-anchor','negative-anchor','nonfinite-anchor','nonfinite-rounderr','changed-interval-stock-delta'):
            out=a.output/attack;out.mkdir();origin=out/'origin';receipt=m.h.verify_checkpoint(source,day,meta['binding'],origin)
            path=origin/'macro.bin';raw=bytearray(path.read_bytes());pos,header,nreal=runtime.calendar(raw,project.nodes);cp=pos+160+16*nreal;n=20+project.nodes
            values=list(struct.unpack_from('<'+str(n)+'d',raw,cp+24));actual_anchor=values[-2];samini=values[0]
            assert abs(actual_anchor-samini)>1.,(actual_anchor,samini)
            if attack=='anchor-from-cumulative-samini':index,value=n-2,samini
            elif attack=='shifted-anchor':index,value=n-2,actual_anchor+1.
            elif attack=='negative-anchor':index,value=n-2,-1.
            elif attack=='nonfinite-anchor':index,value=n-2,float('nan')
            elif attack=='nonfinite-rounderr':index,value=n-1,float('nan')
            else:index,value=14,values[14]+1.
            for offset in (0,8*n):struct.pack_into('<d',raw,cp+24+offset+8*index,value)
            path.write_bytes(raw)
            try:
                with contextlib.ExitStack() as stack:
                    m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,
                        [m.h.ColumnStart('original',day,origin,receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],model=project.model,project=project)
            except (ValueError,RuntimeError) as error:
                diagnostic='\n'.join(p.read_text(encoding='utf8',errors='replace') for p in out.rglob('donor.stderr'))
                assert 'ERROR STOP' in diagnostic and not list(out.glob('accepted-*.zip')),(attack,diagnostic,str(error))
                q['checks'].append(dict(attack=attack,status='REFUSED',actual_anchor=actual_anchor,actual_samini=samini,changed_index=index,
                    forged_value=repr(value),diagnostic=diagnostic,error=str(error)));save()
            else:raise AssertionError('Invalid actual CDE interval alias accepted: '+attack)
            assert m.sha(source)==digest
        q['status']='SIX_ACTUAL_NONZERO_CDE_INTERVAL_ALIAS_FORGERIES_REFUSED';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
