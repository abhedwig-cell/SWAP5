#!/usr/bin/env python3
"""Visibility-neutral main instrumentation; reuse identified original production objects.

Writes existing public counters and accepted durations outside the timed interval.
wait4 measures individual native CPU and peak RSS (KiB on Linux). Physical files
must match the uninstrumented paired benchmark. No model method is replaced.
"""
import argparse,csv,hashlib,json,os,re,shlex,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
FIELDS='transaction_calls accepted_substeps attempts retries trial_rollbacks solver_rejections temporal_rejections mass_rejections checkpoint_uses headcalc_calls nonlinear_iterations jacobian_builds linear_solves workspace_full_resets workspace_zeroed_bytes'.split()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--retain-proposal',action='store_true',help='Diagnostic only: enable existing opt-in step proposal; physical equality is reported rather than required')
 for k in ['before','after','benchmark','output']:ap.add_argument('--'+k,type=Path,required=True)
 a=ap.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);report=dict(builds={},runs=[])
 subprocess.run(['gcc','-O2',str(ROOT/'tools/performance/native_usage.c'),'-o',str(out/'usage')],check=True)
 for arm in ['before','after']:
  base=getattr(a,arm).resolve();build=json.loads((base/'build-complete.json').read_text());b=out/arm;b.mkdir()
  original=ROOT/'app/solute_column/main.f90';text=original.read_text()
  if sha(original)!=build['input_sha256']['app/solute_column/main.f90']:raise ValueError('main source drift')
  if a.retain_proposal:text=text.replace('  numerical%transaction%temporal_tolerance=temporal_tolerance','  numerical%transaction%temporal_tolerance=temporal_tolerance\n  numerical%retain_accepted_step_proposal=.true.',1)
  text=text.replace('  implicit none','  implicit none\n  integer :: perf_u,perf_s\n  real(real64) :: perf_start,perf_end',1)
  needle='  do j=first,stop_after';text=text.replace(needle,"  open(newunit=perf_u,file='counters.csv',status='new')\n  open(newunit=perf_s,file='steps.csv',status='new')\n  write(perf_u,'(A)') 'window,core_cpu,"+','.join(FIELDS)+"'\n  write(perf_s,'(A)') 'window,t0,t1'\n"+needle,1)
  needle='    call run_pond_joint_interval(backend,column_id,template,p,water,forcing,numerical,solute,supply,t0,t1,result)'
  if text.count(needle)!=1:raise ValueError('call preimage')
  text=text.replace(needle,'    call cpu_time(perf_start)\n'+needle+'\n    call cpu_time(perf_end)\n'+"    write(perf_u,'(I0,\",\",ES25.17E3,15(\",\",I0))')j,perf_end-perf_start, &\n      "+', &\n      '.join('result%diagnostics%'+f for f in FIELDS),1)
  needle='      associate(s=>observation%accepted_water_flux_substeps(k))';text=text.replace(needle,needle+"\n        write(perf_s,'(I0,2(\",\",ES25.17E3))')j,s%t0,s%t1",1)
  shadow=b/'main.f90';shadow.write_text(text);fc=shlex.split(os.environ.get('FC','gfortran'));flags=[x for x in build['flags']if not x.startswith(('-J','-I'))]+['-J'+str(b),'-I'+str(b),'-I'+str(base)]
  objects=[]
  for e in build['events']:
   if e['category']=='compile':
    cmd=e['command']
    if not cmd[cmd.index('-c')+1].endswith('/app/solute_column/main.f90'):objects.append(cmd[cmd.index('-o')+1])
  with (b/'compile.log').open('w')as log:
   subprocess.run(fc+flags+['-c',str(shadow),'-o',str(b/'main.o')],check=True,stdout=log,stderr=log)
   subprocess.run(fc+flags+objects+[str(b/'main.o'),'-o',str(b/'observe')],check=True,stdout=log,stderr=log)
  report['builds'][arm]=dict(original_main_sha256=sha(original),shadow_sha256=sha(shadow),source_inputs=build['input_sha256'],executable_sha256=sha(b/'observe'))
  for n in [4,32,256]:
   run=b/str(n);run.mkdir();source=a.benchmark.resolve()/f'input-{n}.nml'
   with (run/'stdout').open('wb')as so,(run/'stderr').open('wb')as se:
    p=subprocess.Popen([str(out/'usage'),'taskset','-c',str(max(os.sched_getaffinity(0))),str(b/'observe'),str(source),'-','8'],cwd=run,stdout=so,stderr=se,)
    _,status,usage=os.wait4(p.pid,0);p.returncode=os.waitstatus_to_exitcode(status)
   if p.returncode:raise RuntimeError(str(run))
   usage_fields=re.search(rb'PERF01_USAGE (\S+) (\d+)',(run/'stderr').read_bytes())
   if not usage_fields:raise ValueError('missing native rusage')
   files={f:sha(run/f)for f in ['budget.csv','state.csv','endpoint.csv','restart.bin']}
   exact=all(h==sha(a.benchmark/f'{n}-0-{arm}'/f)for f,h in files.items())
   if not a.retain_proposal and not exact:raise ValueError('observer physical drift')
   counters=list(csv.DictReader((run/'counters.csv').open()));steps=list(csv.DictReader((run/'steps.csv').open()));dt=sorted(float(s['t1'])-float(s['t0'])for s in steps)
   rec=dict(arm=arm,nodes=n,diagnostic_proposal=a.retain_proposal,physical_byte_exact=exact,native_cpu=float(usage_fields[1]),peak_rss_kib=int(usage_fields[2]),core_cpu=sum(float(x['core_cpu'])for x in counters),counters={f:sum(int(x[f])for x in counters)for f in FIELDS},dt=dict(count=len(dt),mean=sum(dt)/len(dt),min=dt[0],p50=dt[len(dt)//2],p90=dt[int(.9*(len(dt)-1))],max=dt[-1]),files=files)
   report['runs'].append(rec);print(json.dumps(rec),flush=True);(out/'CONTROL.json').write_text(json.dumps(report,indent=2))
if __name__=='__main__':main()
