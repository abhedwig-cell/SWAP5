"""Bounded native replay of existing ACCEPT01 contexts, no new solver variant."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, sys, time, zipfile

ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]
WORK=Path('C:/Users/Veldh012/swap431-state02-work')
OLD=WORK/'phase'
AUDIT=WORK/'audit'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x): p.write_text(json.dumps(x,indent=2)+'\n')

def recover():
    manifest=json.loads((WORK/'file-manifest.json').read_text())
    for x in manifest:
        p=WORK/x['path']; assert p.stat().st_size==x['size'] and sha(p)==x['sha256'],str(p)
    before=json.loads((OLD/'RESULT.json').read_text())
    subprocess.run([sys.executable,str(OLD/'assess_b1_accept01.py'),'--root',str(OLD),'--b0-case',str(AUDIT/'run-control-output')],check=True,capture_output=True)
    assert json.loads((OLD/'RESULT.json').read_text())==before
    save(ROOT/'RECOVERY.json',dict(files_verified=len(manifest),assessment_exact=True,models_launched=0,compilers_launched=0,archive_sha256=sha(REPO/'research/swap431-macro-b1-accept01/B1_ACCEPT01_EVIDENCE.tar.xz')))

def prepare():
    # Extract only the existing retry routine text, without importing its CLI.
    import ast
    module=ast.parse((OLD/'b1_observe.py').read_text())
    retry=next(ast.literal_eval(x.value) for x in module.body if isinstance(x,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='RETRY' for t in x.targets))
    start=retry.index(' do kind=1,2')
    end=retry.index('\ncontains',start)
    retry=retry[:start]+''' call get_environment_variable('STATE02_MODE',mode)
 if(trim(mode)/='reject'.and.trim(mode)/='direct') return
 call dump('origin')
 if(trim(mode)=='reject') then
  call headcalc
  call dump('rejected')
  if(.not.fldecdt.or.FlDecMpRat) error stop 'expected ordinary rejection'
  call SoilWaterStateVar(2)
  call MacroStateVar(2)
 else
  fldecdt=.true.
 end if
 call TimeControl(5)
 call dump('rollback')
 call drain(2)
 call SoilWaterStateVar(1)
 call MacroStateVar(1)
 call headcalc
 call dump('retry')
 if(fldecdt.or.FlDecMpRat) error stop 'retry not accepted'
 ! Execute the actual accepted hydraulic/macro transition, including the clock.
 call SoilWater(3)
 call dump('committed')
 stop 0
'''+retry[end:]
    retry=retry.replace(' integer :: kind,status',' integer :: kind,status\n character(32) :: mode')
    retry=retry.replace('subroutine audit_retry()','subroutine audit_retry()',1)
    # SoilWater(3) is reached by this diagnostic while SoilWater(2) is on stack.
    soil=(AUDIT/'build/swap-selected/soilwater.f90').read_text(encoding='cp1252')
    soil=soil.replace('subroutine soilwater (task)','recursive subroutine soilwater (task)')
    soil=soil.replace('            call headcalc','            call audit_retry()\n            call headcalc',1)
    soil=soil.replace('end module MOD_SoilWater',retry+'\nend module MOD_SoilWater')
    (ROOT/'soilwater_probe.f90').write_text(soil,encoding='cp1252')
    head=(OLD/'V1/headcalc_metrics.f90').read_text(encoding='cp1252')
    head=head.replace('         call audit_attempt(0)','         call state02_rate()\n         call audit_attempt(0)',1)
    rate='''
subroutine state02_rate()
 use MOD_macropore, only: NumDm,QExcMtxDmCp,FrReduQ,WaSrMpDm,TimAbsCumDmCp,ThtSrpRefDmCp,SorpDmCp
 integer,save :: count=0
 integer :: target,ios,u
 character(32) :: mode,sel
 real(8) :: oldf(macp),oldq(macp),oldh(macp),oldtheta(macp),oldstock(100),oldclock(100,macp)
 call get_environment_variable('STATE02_MODE',mode)
 if(trim(mode)/='rate') return
 if(IDecMpRat/=1) return
 count=count+1
 call get_environment_variable('STATE02_INDEX',sel)
 read(sel,*,iostat=ios) target
 if(ios/=0) error stop 'missing rate index'
 if(count/=target) return
 oldf=F;oldq=QExcMpMtx;oldh=h;oldtheta=theta
 open(newunit=u,file='rate.txt',status='replace')
 write(u,*) 'context',count,t1900,dt,IDecMpRat,FrReduQ,CritDevBalCp,CritDevBalTot
 write(u,*) 'accepted_f',F(1:NN)
 write(u,*) 'accepted_q',QExcMpMtx(1:NN)
 write(u,*) 'accepted_pair',sum(QExcMtxDmCp(1:NumDm,1:NN),dim=1)
 write(u,*) 'stock',WaSrMpDm(1:NumDm)
 write(u,*) 'clock',TimAbsCumDmCp(1:NumDm,1:NN)
 ! The accepted operator is freshly certified by V1. No history/head changes
 ! precede this single diagnostic unscaled evaluation. Exit afterwards.
 IDecMpRat=0
 call vector_F(1,hgrad)
 write(u,*) 'unreduced_f',F(1:NN)
 write(u,*) 'unreduced_q',QExcMpMtx(1:NN)
 write(u,*) 'unreduced_pair',sum(QExcMtxDmCp(1:NumDm,1:NN),dim=1)
 write(u,*) 'unreduced_stock',WaSrMpDm(1:NumDm)
 write(u,*) 'unreduced_clock',TimAbsCumDmCp(1:NumDm,1:NN)
 write(u,*) 'heads_unchanged',maxval(abs(h-oldh)),maxval(abs(theta-oldtheta))
 write(u,*) 'attribution',maxval(abs(F(1:NN)-oldf(1:NN)+QExcMpMtx(1:NN)-oldq(1:NN)))
 close(u)
 stop 0
end subroutine state02_rate
'''
    head=head.replace('\ncontains\n','\ncontains\n'+rate,1)
    (ROOT/'headcalc_probe.f90').write_text(head,encoding='cp1252')
    save(ROOT/'STATUS.json',dict(work_unit='SWAP431-MACRO-B1-STATE02',baseline='87792cdee54380424b9e1efb62ac272cdde1ab76',stage='PREPARED_NOT_TESTED',scope='One wet rejection and existing reduced contexts; no production patch',next_safe_step='Build native O0/O2 closure and run bounded replay',invariants=['unchanged physics/criteria/reduction/dt limits','paired exchange','protected references unchanged'],qualification='NOT_PROMOTED'))

def build(opt):
    sys.path.insert(0,str(REPO/'tools/vq'))
    import b0_source_runner as b
    out=WORK/opt;out.mkdir(exist_ok=True)
    tt=out/'tt';tt.mkdir(exist_ok=True)
    with zipfile.ZipFile(AUDIT/'distribution/tools/SWAP/source/TTUTIL.ZIP') as z:z.extractall(tt)
    tt=tt/'TTUTIL'; obj=out/'obj';obj.mkdir(exist_ok=True)
    logs=[]
    def run(cmd):
        s=time.perf_counter();q=subprocess.run(list(map(str,cmd)),cwd=obj,capture_output=True,text=True,timeout=60)
        logs.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-s,returncode=q.returncode,output=q.stdout+q.stderr))
        save(ROOT/(opt+'_BUILD.json'),logs)
        assert q.returncode==0,q.stdout+q.stderr
    flags=['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch']
    for p in [tt/'ttutilprefs.f90',tt/'ttutil.f90']+[p for p in sorted(tt.glob('*.f90'))+sorted(tt.glob('*.for')) if p.name not in ['ttutilprefs.f90','ttutil.f90']]:
        run(flags+['-ffixed-line-length-none' if p.suffix=='.for' else '-ffree-line-length-none','-I',tt,'-I',obj,'-c',p])
    ttobjects=list(obj.glob('*.o'))
    run(['ar','rcs',out/'libttutil.a',*ttobjects])
    for p in ttobjects:p.unlink()
    for name in b.SWAP_ORDER:
        p=ROOT/('headcalc_probe.f90' if name=='headcalc.f90' else 'soilwater_probe.f90') if name in ['headcalc.f90','soilwater.f90'] else AUDIT/'build/swap-selected'/name
        run(flags+['-cpp','-Dlinux','-ffree-line-length-none','-I',obj,'-c',p,'-o',obj/(Path(name).stem+'.o')])
    run(['gfortran','-o',out/'swap.exe',*sorted(obj.glob('*.o')),out/'libttutil.a'])
    save(ROOT/(opt+'_IDENTITY.json'),dict(compiler=subprocess.check_output(['gfortran','--version'],text=True),exe_sha256=sha(out/'swap.exe'),sources={p.name:sha(p) for p in ROOT.glob('*.f90')},original_selected_sources={p.name:sha(p) for p in (AUDIT/'build/swap-selected').glob('*.f90')}))

def execute(opt,mode,index):
    case=WORK/opt/(mode+str(index));case.mkdir(exist_ok=True)
    source=OLD/'O2/V1/case'
    for x in json.loads((AUDIT/'CASE_IDENTITY.json').read_text()):
        p=Path(x['path']);(case/p).parent.mkdir(exist_ok=True,parents=True);shutil.copy2(source/p,case/p)
    env=os.environ.copy();env.update(STATE02_MODE=mode,STATE02_INDEX=str(index))
    s=time.perf_counter()
    try:
        q=subprocess.run([str(WORK/opt/'swap.exe'),'./swap.swp'],cwd=case,env=env,capture_output=True,text=True,timeout=20)
        result=dict(mode=mode,index=index,returncode=q.returncode,seconds=time.perf_counter()-s,censored=False,stdout=q.stdout,stderr=q.stderr)
    except subprocess.TimeoutExpired:
        result=dict(mode=mode,index=index,seconds=time.perf_counter()-s,censored=True)
    save(ROOT/(opt+'_'+mode+str(index)+'_RUN.json'),result)
    for name in ['origin.txt','rejected.txt','rollback.txt','retry.txt','committed.txt','rate.txt','attempts.txt']:
        if (case/name).exists():
            target=ROOT/'data'/opt/(mode+str(index));target.mkdir(parents=True,exist_ok=True);shutil.copy2(case/name,target/name)
    print(result)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--mode',default='rate');p.add_argument('--index',type=int,default=1);a=p.parse_args()
    if a.action=='recover':recover()
    elif a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':execute(a.opt,a.mode,a.index)
