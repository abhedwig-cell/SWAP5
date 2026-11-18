"""Actual production Snow annual-reset epochs and native counter refusal."""
import argparse,json,subprocess,sys,struct,zipfile
from datetime import date,timedelta
from pathlib import Path
import perstep_domain_runtime as runtime
from original_output_baseline import assignment


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args();args.output.mkdir();q=dict(status='RUNNING',optimization=args.optimization,cases={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for snow,reset,epoch in ((snow,reset,epoch) for snow in (0,1) for reset in (0,1) for epoch in ('2002-12-15','2003-12-15')):
            key=f'snow{snow}-reset{reset}-{epoch}';root=args.output/key;root.mkdir();inputs=root/'input';runtime.fixture(inputs,'explicit',2,3,reset,nprintday=3,snow=snow)
            path=inputs/'swap.swp';text=assignment(path.read_text(encoding='cp1252'),'TSTART',epoch)
            event=(date.fromisoformat(epoch)+timedelta(days=4)).isoformat();assert text.count('2002-01-05')==1
            path.write_text(text.replace('2002-01-05',event),encoding='cp1252')
            command=[sys.executable,'-B',str(Path(runtime.__file__)),'--reference-work',args.reference_work,'--output',root/'actual',
                '--existing-input',inputs,'--mode','explicit','--hysteresis','2','--format','3','--reset',str(reset),'--snow',str(snow),'--nprintday','3','--optimization',args.optimization]
            result=subprocess.run(list(map(str,command)),cwd=runtime.ROOT,capture_output=True,text=True,timeout=300)
            (root/'stdout').write_text(result.stdout,encoding='utf8');(root/'stderr').write_text(result.stderr,encoding='utf8');result.check_returncode()
            report=json.loads((root/'actual/RESULT.json').read_text(encoding='utf8'));assert report['status']=='ACTUAL_WATER_PERSTEP_DOMAIN_SHORT_NATIVE_USER_OUTPUT_PASS'
            checks=[];meta=json.loads((Path(report['build_root'])/'BUILD.json').read_text(encoding='utf8'));n=meta['project']['nodes']
            for day in (2,4,8,19,23,30,34,35):
                with zipfile.ZipFile(root/f'actual/trajectory/accepted-column-1-day-{day}.zip') as checkpoint:raw=checkpoint.read('macro.bin')
                pos,header,_=runtime.calendar(raw,n)
                completed=date.fromisoformat(epoch)+timedelta(days=day-1);expected=min(day,completed.timetuple().tm_yday) if reset else day
                assert header[6]==day and header[7]==expected and header[8]==1 and header[11]==reset and header[18:20]==(1,1),(epoch,day,header,expected)
                checks.append(dict(day=day,completed=completed.isoformat(),global_day=header[6],annual_counter=header[7],expected=expected))
            assert any(c['annual_counter']!=c['global_day'] for c in checks)==bool(reset),'Incorrect actual reset policy'
            q['cases'][key]=dict(root=str(root),epoch=epoch,snow=snow,reset=reset,report=report,actual_native_counters=checks);save()
        q['status']='EIGHT_NONJANUARY_WATER_PERSTEP_EPOCHS_BOTH_RESET_NATIVE_COLD_PASS';print(q['status'],args.optimization,flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
