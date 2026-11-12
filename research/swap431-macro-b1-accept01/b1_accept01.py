"""Two bounded B0-derived acceptance experiments; never a production builder."""
from pathlib import Path
import argparse, json, hashlib, subprocess, os, time, shutil, difflib

P=argparse.ArgumentParser()
P.add_argument('action',choices=['prepare','run'])
P.add_argument('--provider',type=Path,required=True)
P.add_argument('--output',type=Path,required=True)
P.add_argument('--optimization',choices=['O0','O2'],default='O2')
A=P.parse_args();R=A.output.resolve();OLD=A.provider.resolve();R.mkdir(exist_ok=True,parents=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
src=(OLD/'build/swap-selected/headcalc.f90').read_text(encoding='cp1252')
raw=(OLD/'b0/SWAP/headcalc.f90').read_bytes()
assert hashlib.sha256(raw).hexdigest()=='db667598dd0a9dbc2cd651d63f0074d3051db748fa45ee460da9c61904c113f5'
conv_start=src.index('!     initialize flags\n!     main flag for testing the convergence')
conv_end=src.index('!     implemented to improve iteration performance in case of macropores')
criteria=src[conv_start:conv_end]
marker='      if (dabs(sum1) > CritDevBalTot) flnonconv = .TRUE.'
refresh='''!     B1 EXPERIMENT V1: certify the current coupled operator at provisional convergence.
      if (swmacro == 1 .AND. .NOT.flnonconv .AND. dabs(sum1) <= CritDevBalTot) then
         flunsatok(1:3) = .FALSE.
         call vector_F(1,hgrad)
         sump = 0.5d0 * dot_product(F(1:NN),F(1:NN))
         sum1 = sum(F(1:NN))
         Fmax = maxval(dabs(F(1:NN)))
'''+criteria+'''      end if

'''
v1=src.replace(marker,refresh+marker,1)
freeze='if (dt <  0.01d0 .AND. swmacro == 1 .AND. .NOT.flnonconv3) then'
assert src.count(freeze)==1
v2=src.replace(freeze,'if (.FALSE.) then ! B1 EXPERIMENT V2: retain active coupling throughout Newton',1)

METRICS='''
subroutine audit_attempt(branch)
 integer,intent(in) :: branch
 integer :: u
 open(newunit=u,file='attempts.txt',status='unknown',position='append')
 write(u,*) branch,t1900,dt,numbit,IDecMpRat,maxval(abs(F(1:NN))),sum(F(1:NN)), &
  CritDevBalCp,CritDevBalTot,pond,maxval(abs(h(1:NN))),sum(QExcMpMtx(1:NN))
 close(u)
end subroutine audit_attempt
'''
def observed(s):
    s=s.replace('!        special case for macropores','         call audit_attempt(0)\n!        special case for macropores',1)
    s=s.replace('      fldecdt = .TRUE.','      fldecdt = .TRUE.\n      call audit_attempt(1)',1)
    s=s.replace('      FlDecMpRat = .TRUE.','      FlDecMpRat = .TRUE.\n      call audit_attempt(2)',1)
    s=s.replace('!     continue without convergence !!!','      call audit_attempt(3)\n!     continue without convergence !!!',1)
    return s.replace('\ncontains\n','\ncontains\n'+METRICS,1)

if A.action=='prepare':
    selection={
      'work_unit':'SWAP431-MACRO-B1-ACCEPT01','baseline':'798c0bff798e6906c46b0cbfb8c8850fed3a037e',
      'B0_archive_sha256':'1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151',
      'V1':'At provisional convergence reset freeze, reevaluate original coupled operator, reapply original local/head/pond/global criteria, continue original iteration if failure.',
      'V2':'Disable only original macro-freeze optimization; retain original equations, derivative, line search, limits and retry policies.',
      'model_selection':'Original cold Andelst first two days; TEND short window and output-only controls inherited from audit.',
      'order':'O2 discrimination first; O0/O2 qualification of any viable candidate. No third variant.',
      'cap_seconds_per_model':20,'tolerance_changes':False,'physics_changes':False,
      'acceptance':'Complete within cap, no continue-without-convergence acceptance, actual fresh coupled residual meets unchanged criteria; mass/actual rejected-trial rollback/selected derivative controls required before promotion.',
      'safety':'V1 extra rate evaluation mutates original trial workspace; unchanged legacy rollback is NOT presumed qualified. Any completion is provisional until tested.',
      'stop':'Two failing/censored variants => no B1 promotion; record narrow numerical blocker, no long trajectory.'}
    for name,s in [('B0',src),('V1',v1),('V2',v2)]:
        d=R/name;d.mkdir(exist_ok=True)
        (d/'headcalc.f90').write_text(s,encoding='cp1252')
        (d/'headcalc_metrics.f90').write_text(observed(s),encoding='cp1252')
        if name!='B0':
            (d/'fix.patch').write_text(''.join(difflib.unified_diff(src.splitlines(True),s.splitlines(True),fromfile='B0-selected/headcalc.f90',tofile=name+'/headcalc.f90')))
    selection['sources']={str(p.relative_to(R)):sha(p) for p in R.glob('*/*.f90')}
    (R/'PREREGISTRATION.json').write_text(json.dumps(selection,indent=2)+'\n')
    print(json.dumps(selection,indent=2));raise SystemExit()

selection=json.loads((R/'PREREGISTRATION.json').read_text())
for name,digest in selection['sources'].items():assert sha(R/name)==digest,name
identity=json.loads((OLD/'BUILD_IDENTITY.json').read_text())
for name,digest in identity['objects'].items():assert sha(OLD/'build/swap-obj'/name)==digest,name
env=os.environ.copy();comp=OLD/'compiler'
env['PATH']=str(comp/'bin')+':'+env['PATH']
env['GCC_EXEC_PREFIX']=str(comp/'root/usr/lib/gcc/')
env['COMPILER_PATH']=str(comp/'root/usr/libexec/gcc/x86_64-linux-gnu/14')
env['LIBRARY_PATH']=str(comp/'root/usr/lib/gcc/x86_64-linux-gnu/14')+':/usr/lib/gcc/x86_64-linux-gnu/14'
build=R/A.optimization;build.mkdir(exist_ok=True)
obj=OLD/'build/swap-obj';tt=OLD/'build/ttutil-obj/libttutil.a'
assert A.optimization=='O2','O0 full closure must be constructed separately, never mix object optimization silently'
logs=[];runs=[]
def execute(cmd,cwd,limit=40):
    start=time.monotonic()
    try:
        q=subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=limit)
        rec=dict(command=list(map(str,cmd)),returncode=q.returncode,seconds=time.monotonic()-start,stdout=q.stdout,censored=False)
    except subprocess.TimeoutExpired as e:
        rec=dict(command=list(map(str,cmd)),returncode=None,seconds=time.monotonic()-start,stdout=(e.stdout or b'').decode(errors='replace') if isinstance(e.stdout,bytes) else e.stdout,censored=True)
    return rec
for name in ['B0','V1','V2']:
    d=build/name;d.mkdir(exist_ok=True)
    flags=['gfortran',*identity['flags'],'-I',obj,'-I',OLD/'build/ttutil-obj','-c',R/name/'headcalc_metrics.f90','-o',d/'headcalc.o']
    log=execute(flags,d);logs.append(log);assert log['returncode']==0,log['stdout']
    objects=[p for p in sorted(obj.glob('*.o')) if p.name!='headcalc.o']+[d/'headcalc.o']
    log=execute(['gfortran','-B/usr/lib/gcc/x86_64-linux-gnu/14/','-o',d/'swap',*objects,tt],d);logs.append(log);assert log['returncode']==0,log['stdout']
    case=d/'case';case.mkdir(exist_ok=True)
    for item in json.loads((OLD/'CASE_IDENTITY.json').read_text()):
        p=Path(item['path']);(case/p).parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(OLD/'run-control'/p,case/p)
    shutil.copy2(OLD/'run-control-output/swap.swp',case/'swap.swp')
    log=execute([d/'swap','./swap.swp'],case,20)
    (case/'stdout.txt').write_text(log.pop('stdout') or '')
    log.update(name=name,optimization=A.optimization,exe_sha256=sha(d/'swap'),swap_ok=(case/'swap.ok').exists(),input_sha256=sha(case/'swap.swp'))
    if (case/'attempts.txt').exists():
        rows=[list(map(float,l.split())) for l in (case/'attempts.txt').read_text().splitlines()]
        accepted=[r for r in rows if r[0]==0]
        log['attempt_counts']={str(i):sum(r[0]==i for r in rows) for i in range(4)}
        log['cached_failures']=sum(r[5]>r[7] or abs(r[6])>r[8] for r in accepted)
        log['max_accepted_IDecMpRat']=max((r[4] for r in accepted),default=None)
        log['last_attempt']=rows[-1] if rows else None
    runs.append(log)
    (build/'BUILD.json').write_text(json.dumps(logs,indent=2)+'\n')
    (build/'RUNS.json').write_text(json.dumps(runs,indent=2)+'\n')
    print(json.dumps(log),flush=True)
