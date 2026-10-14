#!/usr/bin/env python3
"""Complete original highest current-source execution with verified warm providers.

Measures actual enclosing wall/CPU and fresh original assertions. This warm
scenario is not a cold end-to-end matched baseline and never proves 10x.
"""
import argparse,json,os,pathlib,subprocess,time
ROOT=pathlib.Path(__file__).resolve().parents[2]
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--prior-root',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);args=a.parse_args();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
 start=time.monotonic();events=[];env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'}
 def launch(label,cmd):
  so=(out/(label+'.stdout')).open('w');se=(out/(label+'.stderr')).open('w');cp=subprocess.Popen(cmd,stdout=so,stderr=se,env=env);return cp,so,se,time.monotonic()
 def finish(label,handle):
  cp,so,se,started=handle;_,status,usage=os.wait4(cp.pid,0);cp.returncode=os.waitstatus_to_exitcode(status);so.close();se.close();rec={'label':label,'wall':time.monotonic()-started,'cpu':usage.ru_utime+usage.ru_stime,'exit':cp.returncode};events.append(rec);(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,rec
 for opt in [0,2]:
  label=f'rebind-o{opt}';finish(label,launch(label,['python',str(ROOT/'tools/performance/rebind_low_air_runtime_build.py'),'--build',str(args.prior_root/f'guarded-full-o{opt}'),'--qualification',str(args.prior_root/f'guarded-qual-o{opt}'),'--output',str(out/f'build-o{opt}')]))
 pending=[]
 for opt,workers in [(0,3),(2,1)]:
  label=f'qualify-o{opt}';pending.append((label,launch(label,['python',str(ROOT/'tools/performance/run_low_air_ab.py'),'--build',str(out/f'build-o{opt}'),'--output',str(out/f'qual-o{opt}'),'--candidate-only','--repeat','1','--workers',str(workers)])))
 for label,handle in pending:finish(label,handle)
 # wait4 parent wall includes waiting after launch, hence label walls can overlap.
 total={'scope':'COMPLETE_HIGHEST_CURRENT_SOURCE_WARM_PROVIDERS','whole_wall':time.monotonic()-start,'whole_child_cpu':sum(x['cpu']for x in events),'events':events,'fine_worker_reuse':False,'cold_end_to_end_ab':'UNKNOWN','tenfold_proved':False,'admitted':False}
 from verify_low_air_ab import verify
 total['qualifications']={str(opt):verify(out/f'qual-o{opt}')for opt in [0,2]}
 for family in range(1,7):assert (out/f'qual-o0/0-{family}-candidate.stdout').read_bytes()==(out/f'qual-o2/0-{family}-candidate.stdout').read_bytes(),family
 (out/'RESULTS.json').write_text(json.dumps(total,indent=2)+'\n');print(json.dumps({k:v for k,v in total.items()if k not in ['qualifications','events']}),flush=True)
if __name__=='__main__':main()
