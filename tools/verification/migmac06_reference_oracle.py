"""Independent Decimal equation and exact B1.11 section-D assembly oracle."""
from decimal import Decimal as D, getcontext
from pathlib import Path
import argparse, hashlib, subprocess, tempfile
getcontext().prec = 70
m,a,alpha,beta = D('.2'),D('.6'),D('1.2'),D(3)
r=m/a; peak=alpha/beta
void=(D('.2')+D('.8')*m)*(1+D('.1')*r**alpha*((-beta*r).exp()-(-beta).exp())/(peak**alpha*((-alpha).exp()-(-beta).exp())))
shrink=[D(0), D('.5')-(D('.2')*(-D('.4')).exp()+D('1.2')*m)*D('.5'), D('.5')-void*D('.5'), D('.3')]
kd=D(0)
for sh,fr in zip(shrink[2:],[D('.3'),D('.7')]):
    dynamic=sh-(1-(1-sh)**(D(1)/3))
    ratio=fr*(dynamic+D('.1'))
    width=4*(1-(1-ratio).sqrt())
    kd+=width**3/4*10
kd_all=D(0)
for sh,fr in zip(shrink,[D(1),D('.5'),D('.3'),D('.7')]):
    dynamic=sh-(1-(1-sh)**(D(1)/3));ratio=fr*(dynamic+D('.1'))
    width=4*(1-(1-ratio).sqrt());kd_all+=width**3/4*10
print('PPA_WU05_MIGMAC06_DECIMAL_KD='+str(kd))
print('PPA_WU05_MIGMAC06_DECIMAL_ALL_LAW_KD='+str(kd_all))
args=argparse.ArgumentParser();args.add_argument('--source',required=True);ns=args.parse_args()
p=Path(ns.source)
assert hashlib.sha256(p.read_bytes()).hexdigest()=='f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f'
s=p.read_text();block=s[s.index('!- D. CALCULATION OF REFERENCE KD'):s.index('!- E.1 CALCULATION OF SORPTIVITY')]
code='''program source_reference
implicit none
integer::ir,ICpBtMB,ICpBot,ic,il,ICpHRef,SwDrRap=1,NumLevRapDra=1
integer::Layer(4)=[1,2,3,4],SwSoilShr(4)=[0,1,2,2],SwDTyp(1)=[2]
logical::flRigid
real(8)::DZ(4)=10d0,Z(4)=[-5d0,-15d0,-25d0,-35d0],Z_St=-40d0,ZDraBas=-40d0
real(8)::DZTot,Z_Bot,Zref,HHydrStat,ThetHydrStat,VlShriRl,VlMpDyRl,VlMpRl,WdthCr,KCrRlRef
real(8)::Thetas(4)=0.5d0,GeomFac(4)=3d0,VlMpStCp(4)=1d0,DiPoCp(4)=4d0,RapDraReaExp=3d0
real(8)::PpDmCp(1,4),KDCrRlRef(1)
PpDmCp(1,:)=[1d0,.5d0,.3d0,.7d0]
'''+block+'''
print '(es24.16)',KDCrRlRef(1)
ZDraBas=-10d0
'''+block+'''
print '(es24.16)',KDCrRlRef(1)
SwDTyp=1;SwSoilShr(2)=0;Z_St=-20d0;ZDraBas=-40d0
'''+block+'''
if(KDCrRlRef(1)/=0d0)error stop 'source rigid barrier'
contains
real(8) function watcon(node,head)
integer,intent(in)::node
real(8),intent(in)::head
watcon=.1d0
end function
real(8) function SHRINK(node,theta)
integer,intent(in)::node
real(8),intent(in)::theta
real(8)::values(4)=[0d0,'''+str(shrink[1])+'''d0,'''+str(shrink[2])+'''d0,.3d0]
SHRINK=values(node)
end function
end program
'''
with tempfile.TemporaryDirectory(prefix='migmac06-source-') as t:
    f=Path(t)/'source.f90';f.write_text(code)
    outputs=[]
    for opt in (0,2):
        exe=Path(t)/('o'+str(opt))
        subprocess.run(['gfortran','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-O'+str(opt),str(f),'-o',str(exe)],check=True)
        out=subprocess.check_output([str(exe)],text=True);outputs.append(out)
        values=out.split();assert len(values)==2
        assert abs(D(values[0])-kd)<D('1e-13'),(out,kd)
        assert abs(D(values[1])-kd_all)<D('1e-13'),(out,kd_all)
    assert outputs[0]==outputs[1]
print('PPA_WU05_MIGMAC06_EXACT_SECTION_D_O0_O2=PASS')
