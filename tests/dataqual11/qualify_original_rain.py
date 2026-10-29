#!/usr/bin/env python3
"""Qualify source forcing only. Never grants full-project water qualification."""
import argparse,csv,hashlib,io,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--distribution',type=Path,required=True)
p.add_argument('--ttutil',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--fc',default='gfortran');a=p.parse_args();out=a.output.resolve();out.mkdir(exist_ok=False)
manifest=json.loads((ROOT/'reference/swap-4.3.1/projects/MANIFEST.json').read_text())
raw=a.distribution.read_bytes();assert sha(raw)==manifest['distribution_sha256']
z=zipfile.ZipFile(io.BytesIO(raw))
for name,entry in manifest['members'].items():
 b=(ROOT/'reference/swap-4.3.1/projects'/name).read_bytes()
 assert b==z.read('SWAP_4.3.1/cases/'+name) and sha(b)==entry['sha256'] and len(b)==entry['bytes']
sources=zipfile.ZipFile(io.BytesIO(z.read('SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP')))
original=sources.read('SWAP/MOD_meteo.f90');text=original.decode()
assert 'real(8), parameter   :: vsmall = 1.0d-8' in text
statements=['rtim = all_wet(i)','rainflx(rain_rec) = all_rain(i) * 0.1d0 / rtim']
assert all(s in text for s in statements)
# Executable comparator uses literal arithmetic statements from immutable B0,
# outside the production module. No legacy solver or full model claim follows.
program='''program original_duration_oracle
use iso_fortran_env,only:real64
use mod_daily_rain_duration
implicit none
real(real64),allocatable::all_rain(:),all_wet(:)
real(real64)::rtim,rainflx(1),duration,rate
integer::i,n,status,rain_rec,wetdays
call rdinit(74,0,'input.met');call rdinne('rain',n)
allocate(all_rain(n),all_wet(n))
call rdfdor('rain',0d0,1000d0,all_rain,n,n)
call rdfdor('wet',0d0,1d0,all_wet,n,n);close(74)
rain_rec=1;wetdays=0
 do i=1,n
 call resolve_daily_rain_duration(all_rain(i),all_wet(i),duration,rate,status)
 if(status/=0)error stop 'production rejects original forcing'
 if(all_rain(i)>1d-8)then
'''+ '\n'.join(statements)+'''
 if(duration/=rtim.or.rate/=rainflx(1))error stop 'B0 duration/rate mismatch'
 wetdays=wetdays+1
 else
 if(duration/=0d0.or.rate/=0d0)error stop 'B0 dry threshold mismatch'
 end if
 end do
print *, 'ORIGINAL_DURATION_ORACLE_PASS',n,wetdays
end program
'''
(out/'oracle.f90').write_text(program)
results=[]
for opt in ['O0','O2']:
 d=out/opt;d.mkdir();case=ROOT/'reference/swap-4.3.1/projects/2.grassgrowth'
 for src,target in [(case/'swap.swp','input.swp'),(case/'260.met','input.met')]: (d/target).write_bytes(src.read_bytes())
 flags=['-'+opt,'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(d)]
 def run(cmd,label):
  r=subprocess.run(list(map(str,cmd)),cwd=d,stdin=subprocess.DEVNULL,capture_output=True,timeout=60)
  (d/(label+'.stdout')).write_bytes(r.stdout);(d/(label+'.stderr')).write_bytes(r.stderr)
  assert r.returncode==0,(label,r.stderr.decode());return r
 process=ROOT/'src/process/mod_daily_rain_duration.f90'
 for name,driver in [('contract',ROOT/'tests/dataqual11/test_rain_duration.f90'),('oracle',out/'oracle.f90'),('prepare',ROOT/'app/solute_project/prepare_rain_duration.f90')]:
  run([a.fc,*flags,process,driver,a.ttutil.resolve(),'-o',d/name],'build-'+name)
  run([d/name,*(['input.swp','input.met']if name=='prepare'else[])],name)
 rows=list(csv.DictReader((d/'rain_events.csv').open()));weather=list(csv.DictReader(l for l in (d/'input.met').read_text().splitlines()if l.strip()and not l.startswith('*')))
 depths=[0.]*len(weather);previous=0.
 for row in rows:
  end=float(row['end_day']);rate=float(row['rate_cm_day']);assert end>previous
  depths[int(previous+1e-10)]+=(end-previous)*rate;previous=end
 errors=[abs(depth-float(w['Rain'])*.1)for depth,w in zip(depths,weather)]
 assert previous==len(weather)==1827 and max(errors)<1e-10
 results.append(dict(optimization=opt,days=len(weather),wet_days=951,events=len(rows),rain_cm=sum(depths),maximum_daily_depth_error_cm=max(errors),output_sha256=sha((d/'rain_events.csv').read_bytes())))
assert results[0]['output_sha256']==results[1]['output_sha256']
result=dict(status='PASS_FORCING_ONLY',original_meteo_source_sha256=sha(original),distribution_sha256=sha(raw),original_statements=statements,results=results,
 dependencies={str(f.relative_to(ROOT)):sha(f.read_bytes())for f in [ROOT/'src/process/mod_daily_rain_duration.f90',ROOT/'app/solute_project/prepare_rain_duration.f90',Path(__file__)]},
 full_model_executed=False,water_balance_qualified=False,solute_balance_qualified=False,restart_qualified=False)
(out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
