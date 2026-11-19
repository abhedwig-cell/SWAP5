"""Actual production Snow annual-reset epochs and native counter refusal."""
import argparse,json,subprocess,sys,struct,zipfile
from datetime import date,timedelta
from pathlib import Path
import cde_clock_runtime as runtime
from original_output_baseline import assignment


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args();args.output.mkdir();q=dict(status='RUNNING',optimization=args.optimization,cases={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        cases=[(0,0,'2002-12-15',False,2),(0,1,'2003-12-15',False,3),
               (1,0,'2003-12-15',False,3),(1,1,'2002-12-15',False,2),
               (0,0,'2003-12-15',True,1),(0,1,'2002-12-15',True,3),
               (1,0,'2002-12-15',True,3),(1,1,'2003-12-15',True,1)]
        for snow,reset,epoch,perstep,npd in cases:
            key=f'snow{snow}-reset{reset}-step{int(perstep)}-np{npd}-{epoch}';root=args.output/key;root.mkdir();inputs=root/'input'
            runtime.fixture(inputs,'explicit',2,3,reset,0,snow,'interval' if snow else 'point',None,npd,perstep)
            path=inputs/'swap.swp';text=assignment(path.read_text(encoding='cp1252'),'TSTART',epoch)
            path.write_text(text,encoding='cp1252')
            irrigation=inputs/'fixed-irrigation.irg';events=irrigation.read_text(encoding='cp1252')
            for old,offset in [('2002-01-05',4),('2002-01-07',6)]:
                assert events.count(old)==1;events=events.replace(old,(date.fromisoformat(epoch)+timedelta(days=offset)).isoformat())
            irrigation.write_text(events,encoding='cp1252')
            command=[sys.executable,'-B',str(Path(runtime.__file__)),'--reference-work',args.reference_work,'--output',root/'actual',
                '--existing-input',inputs,'--mode','explicit','--hysteresis','2','--format','3','--reset',str(reset),'--snow',str(snow),'--source','interval' if snow else 'point','--nprintday',str(npd),'--optimization',args.optimization]+(['--perstep'] if perstep else [])
            result=subprocess.run(list(map(str,command)),cwd=runtime.ROOT,capture_output=True,text=True,timeout=300)
            (root/'stdout').write_text(result.stdout,encoding='utf8');(root/'stderr').write_text(result.stderr,encoding='utf8');result.check_returncode()
            report=json.loads((root/'actual/RESULT.json').read_text(encoding='utf8'));assert report['status']=='ACTUAL_CDE_CLOCK_SHORT_NATIVE_USER_OUTPUT_PASS'
            checks=[];meta=json.loads((Path(report['build_root'])/'BUILD.json').read_text(encoding='utf8'));n=meta['project']['nodes']
            for day in (2,4,8,19,23,30,34,35):
                with zipfile.ZipFile(root/f'actual/trajectory/accepted-column-1-day-{day}.zip') as checkpoint:raw=checkpoint.read('macro.bin')
                pos,header,_=runtime.calendar(raw,n)
                completed=date.fromisoformat(epoch)+timedelta(days=day-1)
                assert header[6]==day and header[8]==(1 if perstep else day*npd+1) and header[11]==reset and header[18:20]==(1,int(perstep)),(epoch,day,header)
                cp=pos+160+16*header[3];size=20+n;values=struct.unpack_from('<'+str(size)+'d',raw,cp+24)
                assert values[0]>=0 and values[-2]>=0
                expected=min(day,completed.timetuple().tm_yday) if perstep and reset else day if perstep else 0;assert header[7]==expected
                checks.append(dict(day=day,completed=completed.isoformat(),global_day=header[6],period_counter=header[7],expected_counter=expected,print_counter=header[8],actual_samini=values[0],actual_private_anchor=values[-2],actual_private_rounderr=values[-1],actual_sdstor=values[14]))
            assert all(row['actual_private_anchor']>=0 for row in checks)
            q['cases'][key]=dict(root=str(root),epoch=epoch,snow=snow,reset=reset,perstep=perstep,nprintday=npd,report=report,actual_native_counters=checks);save()
        q['status']='EIGHT_NONJANUARY_CDE_CLOCK_EPOCHS_BOTH_RESET_NATIVE_COLD_PASS';print(q['status'],args.optimization,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
