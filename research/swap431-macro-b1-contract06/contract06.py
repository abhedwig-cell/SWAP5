"""One documented-law repair in the original live context; baseline prefix intact."""
from pathlib import Path
import argparse,hashlib,json,os,shutil,subprocess,time,zipfile,sys,difflib
sys.dont_write_bytecode=True
R=Path(__file__).resolve().parent
PREV=R.parent/'swap431-macro-b1-stagnation05'
WORK=Path('C:/Users/Veldh012/swap431-contract06-work')
OLD=Path('C:/Users/Veldh012/swap431-state02-work')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
COLS='id node layer h gate_layer gate_node theta theta_s k HMp DelH RecRes sorp_factor raw_sorp raw_darcy chosen_potential sorption_chosen dt clock top_wet'.split()

def prepare():
    raw=(OLD/'audit/build/swap-selected/macrorate.f90').read_text(encoding='cp1252')
    old='H(ic) < cofgen(9,lay)-1.d-8 .AND. HMp > 1.d-8'
    new='H(ic) < 0.d0-1.d-8 .AND. HMp > 1.d-8'
    assert raw.count(old)==1
    fixed=raw.replace(old,new,1)
    (R/'minimal_contract.patch').write_text(''.join(difflib.unified_diff(raw.splitlines(True),fixed.splitlines(True),fromfile='B0-selected/macrorate.f90',tofile='B1-experiment/macrorate.f90')))
    # A harness switch allows the identical original prefix. It is NOT part of
    # the proposed patch, not physical state, and is false until the live origin.
    s=raw.replace('      subroutine ABSORPTION(ITask,id,flwoutmtxunsdmcppot,flwoutmtxunsdmpot)',
'''      subroutine ABSORPTION(ITask,id,flwoutmtxunsdmcppot,flwoutmtxunsdmpot)
      use CONTRACT06_CONTROL, only:use_patch,trace_on,trace_unit''',1)
    s=s.replace('      real(8)                             :: AbsDarc, AbsSorp, DelH','      real(8)                             :: AbsDarc, AbsSorp, DelH, selected_gate, raw_sorp, raw_darcy',1)
    s=s.replace('                  if ('+old+') then',
'''                  selected_gate=cofgen(9,lay)
                  if(use_patch) selected_gate=0.d0
                  if (H(ic) < selected_gate-1.d-8 .AND. HMp > 1.d-8) then''',1)
    marker='            if (AbsSorp > SorpFac*AbsDarc) then'
    s=s.replace(marker,'            raw_sorp=AbsSorp\n            raw_darcy=AbsDarc\n'+marker,1)
    marker='            FlwOutMtxUnsDmPot(id) = FlwOutMtxUnsDmPot(id) + FlwOutMtxUnsDmCpPot(id,ic)'
    s=s.replace(marker,'''            if(trace_on.and.ic==45) then
             write(trace_unit,*) id,ic,lay,H(ic),cofgen(9,lay),cofgen(9,ic),theta(ic),thetas(ic),K(ic), &
             HMp,DelH,RecRes,SorpFac,raw_sorp,raw_darcy,FlwOutMtxUnsDmCpPot(id,ic), &
             merge(1,0,FlSorp(id,ic)),dt,TimAbsCumDmCp(id,ic),ICpTpWaSrDm(id)
            end if
'''+marker,1)
    (R/'macrorate_contract.f90').write_text(s,encoding='cp1252')
    soil=(PREV/'soilwater_inventory.f90').read_text(encoding='cp1252')
    soil=soil.replace('subroutine unreduced_driver()','subroutine unreduced_driver()\n use CONTRACT06_CONTROL, only:use_patch,trace_on,trace_unit',1)
    soil=soil.replace(' IDecMpRat=0', ''' call get_environment_variable('CONTRACT06_POLICY',name)
 use_patch=trim(name)=='PATCH'
 open(newunit=trace_unit,file='absorption.txt',status='replace')
 trace_on=.true.
 IDecMpRat=0''',1)
    (R/'soilwater_contract.f90').write_text(soil,encoding='cp1252')
    (R/'control.f90').write_text('module CONTRACT06_CONTROL\n implicit none\n logical,save :: use_patch=.false.,trace_on=.false.\n integer,save :: trace_unit=0\nend module CONTRACT06_CONTROL\n')
    save(R/'ABSORPTION_COLUMNS.json',COLS)

def overlay(arc,sub,opt):
    with zipfile.ZipFile(arc) as z:
        for x in json.loads(z.read('manifest.json')):
            if not x['path'].startswith('native/'+opt+'/'):continue
            data=z.read(x['path']);assert hashlib.sha256(data).hexdigest()==x['sha256']
            p=WORK/x['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)

def build(opt):
    for folder in [R.parent/'swap431-macro-b1-state02',PREV]:
        meta=json.loads((folder/'EVIDENCE.json').read_text());arc=folder/meta['file'];assert sha(arc)==meta['sha256'];overlay(arc,None,opt)
    out=WORK/'native'/opt;obj=out/'obj';logs=[]
    commands=[]
    for src,dest in [('control.f90','control.o'),('macrorate_contract.f90','macrorate.o'),('soilwater_contract.f90','soilwater.o')]:
        commands.append(['gfortran','-'+opt,'-finit-local-zero','-fallow-argument-mismatch','-cpp','-Dlinux','-ffree-line-length-none','-I',str(obj),'-c',str(R/src),'-o',str(obj/dest)])
    objects=sorted(set(obj.glob('*.o'))|{obj/'control.o'})
    commands.append(['gfortran','-o',str(out/'contract.exe'),*map(str,objects),str(out/'libttutil.a')])
    commands.append(['gfortran','-o',str(out/'operator.exe'),*map(str,[p for p in objects if p.name!='headcalc.o']),str(out/'threshold.o'),str(out/'libttutil.a')])
    for cmd in commands:
        t=time.perf_counter();p=subprocess.run(cmd,cwd=obj,capture_output=True,text=True,timeout=60);logs.append(dict(command=cmd,seconds=time.perf_counter()-t,returncode=p.returncode,output=p.stdout+p.stderr));save(R/(opt+'_BUILD.json'),logs);assert p.returncode==0,p.stderr
    save(R/(opt+'_IDENTITY.json'),dict(compiler=subprocess.check_output(['gfortran','--version'],text=True),sources={p.name:sha(p) for p in R.glob('*.f90')},executables={p.name:sha(p) for p in [out/'contract.exe',out/'operator.exe']},inherited_state02=json.loads((R.parent/'swap431-macro-b1-state02/EVIDENCE.json').read_text())['sha256'],inherited_stagnation05=json.loads((PREV/'EVIDENCE.json').read_text())['sha256']))

def run(opt,profile):
    case=WORK/(opt+'-'+profile);case.mkdir(exist_ok=True);assert not list(case.glob('*.txt'))
    for x in json.loads((OLD/'audit/CASE_IDENTITY.json').read_text()):
        p=Path(x['path']);(case/p).parent.mkdir(parents=True,exist_ok=True);shutil.copy2(OLD/'phase/O2/V1/case'/p,case/p)
    side=profile.split('_')[-1] if profile.endswith(('LEFT','RIGHT')) else None
    env=os.environ.copy();env['CONTRACT06_POLICY']='PATCH' if profile.startswith('PATCH') else 'BASE';env['STAG05_VARIANT']='V1';env.pop('UNRED04_DIRECT_DT',None);env.pop('STAG05_PROBE_SIDE',None)
    if side:
        env['STAG05_PROBE_SIDE']=side
        h=next(s.split()[1:] for s in (PREV/'data/O2/V2/solver_1.txt').read_text().splitlines() if s.split()[0]=='h')
        (case/'probe_h.txt').write_text(' '.join(h)+'\n')
    exe=WORK/'native'/opt/('operator.exe' if side else 'contract.exe');cmd=[str(exe),'./swap.swp'];t=time.perf_counter()
    try:
        p=subprocess.run(cmd,cwd=case,env=env,capture_output=True,text=True,timeout=20);q=dict(command=cmd,profile=profile,returncode=p.returncode,censored=False,seconds=time.perf_counter()-t,stdout=p.stdout,stderr=p.stderr)
    except subprocess.TimeoutExpired:q=dict(command=cmd,profile=profile,censored=True,seconds=time.perf_counter()-t)
    save(R/(opt+'_'+profile+'_RUN.json'),q);d=R/'data'/opt/profile;d.mkdir(parents=True,exist_ok=True)
    for p in case.glob('*.txt'):shutil.copy2(p,d/p.name)
    print(json.dumps(q),flush=True)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action');p.add_argument('--opt',default='O2');p.add_argument('--profile',default='PATCH_SOLVE');a=p.parse_args()
    if a.action=='prepare':prepare()
    elif a.action=='build':build(a.opt)
    elif a.action=='run':run(a.opt,a.profile)
