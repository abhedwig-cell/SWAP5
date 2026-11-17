"""Standalone B0-derived numerical reference; imports no SWAP5 model code.

Only original converged-iteration effort and diagnostic DTMAX change. All
original physical functions, residual assembly, convergence tolerances,
rollback and time integration remain owned by original431. No production
HeadCalc, hybrid step budget, kernel or host object is linked.
"""
import argparse,csv,difflib,hashlib,json,math,shutil,subprocess,time
from pathlib import Path

sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def head_source(raw):
    patches=[
      ('   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror',
       '   integer                          :: i, j, itry,  MaxIt1, NN, iBackTr, ierror\n   integer :: reference_polish'),
      ('!  reset some variables at the start of a new day',
       '   reference_polish=0\n!  reset some variables at the start of a new day'),
      ('      if (.NOT.flnonconv) then      ! convergence has been reached',
       '''      ! Independent reference effort: do not change any original criterion.
      ! Two further ORIGINAL converged Newton iterations avoid accepting its
      ! first loose stopping point. All F/sum1 calculations remain original.
      if (.not.flnonconv.and.reference_polish<2) then
         reference_polish=reference_polish+1
         flnonconv=.true.
      endif
      if (.NOT.flnonconv) then      ! convergence has been reached''')]
    for old,new in patches:
        if raw.count(old)!=1:raise ValueError('Foreign original reference anchor: '+old)
        raw=raw.replace(old,new)
    return raw

def csvrows(p):return list(csv.DictReader(s for s in p.read_text(encoding='cp1252').splitlines() if s and not s.startswith('*')))

def main():
 p=argparse.ArgumentParser();p.add_argument('--provider',type=Path,required=True);p.add_argument('--seed-input',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--opt',nargs='+',choices=['O0','O2'],default=['O0','O2']);p.add_argument('--caps',type=float,nargs='+',default=[.0004,.0001,.000025]);a=p.parse_args();provider=a.provider.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False);ref=provider/'build'
 manifest=json.loads((provider/'PREPARED.json').read_text());result={'kind':'INDEPENDENT_ORIGINAL431_NEWTON_REFERENCE_NUMERICAL_WINDOW_ONLY','provider_manifest_sha256':sha(provider/'PREPARED.json'),'production_imports':False,'shared_swap5_headcalc':False,'shared_swap5_mass_guard':False,'input_tolerances_changed':False,'water_guard_cm':1e-10,'model_timeout_seconds':20,'profiles':{}}
 # Validate immutable provider bytes named by its preparation manifest.
 def entries(v):
  if isinstance(v,dict):
   for k,x in v.items():
    if isinstance(x,str) and len(x)==64 and k.startswith('build/'):yield k,x
    else:yield from entries(x)
  elif isinstance(v,list):
   for x in v:yield from entries(x)
 checks=dict(entries(manifest));assert checks and all((provider/n).is_file() and sha(provider/n)==s for n,s in checks.items());result['validated_provider_files']=len(checks)
 raw=(ref/'swap-selected/headcalc.f90').read_text(encoding='cp1252');head=head_source(raw);assert 'hybrid_' not in head.lower() and 'projected_water_residual' not in head
 (out/'headcalc.patch').write_text(''.join(difflib.unified_diff(raw.splitlines(True),head.splitlines(True),fromfile='B0/headcalc.f90',tofile='reference/headcalc.f90')))
 def save():(out/'RESULT.json').write_text(json.dumps(result,indent=2))
 save()
 flags0=['-cpp','-Dlinux','-finit-local-zero','-ffree-line-length-none','-fallow-argument-mismatch','-ffp-contract=off','-march=x86-64','-mtune=generic']
 for opt in a.opt:
  for index,cap in enumerate(a.caps):
   assert 1e-6<=cap<=.04;name=opt+'-'+format(cap,'.9g').replace('.','p');build=out/(name+'-build');build.mkdir();hp=build/'headcalc.f90';hp.write_text(head,encoding='cp1252');sp=build/'swap.f90';s=(ref/'swap-selected/swap.f90').read_text(encoding='cp1252');s=s.replace('gwl, gwlm1, dt, t1900','gwl, gwlm1, dt, dtmax, t1900');anchor='         call TimeControl(2)';assert s.count(anchor)==1;s=s.replace(anchor,f'         dtmax={cap:.17f}d0;dt=min(dt,dtmax)\n'+anchor);sp.write_text(s,encoding='cp1252');flags=['-'+opt,*flags0,'-I',str(ref/'swap-obj'),'-I',str(ref/'ttutil-obj'),'-I',str(build),'-J',str(build)];exe=build/('original_reference.exe' if __import__('os').name=='nt' else 'original_reference');commands=[]
   for source in (sp,hp):commands.append(['gfortran',*flags,'-c',str(source)])
   objects=sorted((ref/'swap-obj').glob('*.o'));assert objects
   linked=[build/v.name if v.name in ('swap.o','headcalc.o') else v for v in objects];commands.append(['gfortran','-o',str(exe),*map(str,linked),str(ref/'ttutil-obj/libttutil.a')])
   compile_start=time.perf_counter()
   for cmd in commands:
    r=subprocess.run(cmd,cwd=build,capture_output=True,text=True,timeout=30);assert r.returncode==0,r.stderr
   compile_seconds=time.perf_counter()-compile_start;folder=out/name;folder.mkdir();inputs={}
   for f in a.seed_input.iterdir():
    if f.is_file() and (f.suffix.lower() in ('.swp','.met','.crp','.dra','.ru','.cmd','.inp') or f.name in ('restart.end','macro.bin')):
     shutil.copy2(f,folder/f.name);inputs[f.name]=sha(f)
   control=(folder/'swap.swp').read_text(encoding='cp1252');assert 'SWINITYPE = 2' in control
   start=time.perf_counter();record=dict(optimization=opt,dtmax_day=cap,compile_seconds=compile_seconds,commands=commands,source_sha256={'headcalc.f90':sha(hp),'swap.f90':sha(sp)},executable_sha256=sha(exe),linked_objects={str(x):sha(x) for x in linked},inputs=inputs)
   try:
    with (folder/'stdout').open('wb') as log:r=subprocess.run([str(exe),'./swap.swp'],cwd=folder,stdout=log,stderr=subprocess.STDOUT,timeout=20)
   except subprocess.TimeoutExpired:
    record.update(status='CENSORED_AT_20_SECONDS_NOT_QUALIFIED',seconds=time.perf_counter()-start);result['profiles'][name]=record;save();return
   record.update(seconds=time.perf_counter()-start,returncode=r.returncode);assert r.returncode==100 and (folder/'swap.ok').is_file();data=csvrows(folder/'result_output.csv');assert len(data)==4
   assert all(sha(folder/n)==v for n,v in inputs.items());assert all(math.isfinite(float(v['GWL'])) and abs(float(v['BALDEV']))<=1e-10 for v in data[1:]),'Independent original balance failed'
   record.update(status='COMPLETE_INDEPENDENT_ORIGINAL_BALANCE_PASS',initial=data[0],daily=data[1:],maximum_original_BALDEV_cm=max(abs(float(v['BALDEV'])) for v in data[1:]));result['profiles'][name]=record;save();print(name,record['seconds'],data[2]['GWL'],record['maximum_original_BALDEV_cm'],flush=True)
if __name__=='__main__':main()
