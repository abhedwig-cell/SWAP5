#!/usr/bin/env python3
"""Audit the pinned research provider against an 80-digit conductivity oracle.

No production edit, solver qualification, or physical width selection is made.
"""
import argparse
from decimal import Decimal, localcontext
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
D = Decimal

def high_precision_k(head, width):
    # Match the fixture's binary64 parameter values, then evaluate the declared
    # smooth law at high precision without intermediate theta cancellation.
    alpha = D.from_float(0.0135)
    n = D.from_float(1.455)
    m = D.from_float(1.0 - 1.0 / 1.455)
    ell = D.from_float(0.365)
    ks = D.from_float(4.75)
    se_mvg = (D(1) + abs(alpha * head) ** n) ** (-m)
    x = (head + width) / width
    w = x ** 3 * (D(10) + x * (D(-15) + D(6) * x))
    se = (D(1) - w) * se_mvg + w
    k_mvg = ks * se ** ell * (D(1) - (D(1) - se ** (D(1)/m)) ** m) ** 2
    return (D(1)-w) * k_mvg + w * ks

DRIVER = '''program audit
 use iso_fortran_env, only: real64
 use mod_b110_default_mvg_provider
 implicit none
 type(b110_default_mvg_parameters_t), target :: p
 type(b110_default_mvg_provider_t) :: hyd
 real(real64) :: c(24,1),h(1),theta(1),k(1),cap(1),dk(1),kp,km,eps,base_theta,base_k,base_cap,base_dk
 real(real64) :: head,width
 integer :: ios,j
 character(80) :: arg
 call get_command_argument(1,arg); read(arg,*) width
 c=0
 c(1,1)=0.032_real64;c(2,1)=0.423_real64;c(3,1)=4.75_real64
 c(4,1)=0.0135_real64;c(5,1)=0.365_real64;c(6,1)=1.455_real64
 c(7,1)=1.0_real64-1.0_real64/c(6,1);c(9,1)=0
 call initialize_b110_default_mvg_parameters(p,c)
 call bind_b110_default_mvg_provider(hyd,p,0.03125_real64)
 do
   read(*,*,iostat=ios) head
   if(ios/=0) exit
   h=head;call hyd%evaluate_demand(h,15,theta,k,cap,dk)
   base_theta=theta(1);base_k=k(1);base_cap=cap(1);base_dk=dk(1)
   do j=1,5
     eps=min(abs(head)*0.01_real64,width*0.001_real64)*10.0_real64**(1-j)
     h=head+eps;call hyd%evaluate_demand(h,3,theta,k,cap,dk);kp=k(1)
     h=head-eps;call hyd%evaluate_demand(h,3,theta,k,cap,dk);km=k(1)
     write(*,'(8(ES25.17,1X))') head,base_theta,base_k,base_cap,base_dk,eps,(kp-km)/(2*eps),kp-km
   end do
 end do
end program
'''

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--compiler',default='gfortran')
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args()
    args.output.mkdir(parents=True,exist_ok=True)
    results=[]
    with tempfile.TemporaryDirectory(prefix='top03-derivative-') as tmp:
        tmp=Path(tmp)
        for width in (0.02,0.2,2.0):
            provider=tmp/'provider.f90'
            subprocess.run(['python3',str(ROOT/'tests/fapp/make_top03_joint_nearsaturation.py'),
                str(provider),str(tmp/'unused.f90'),str(width)],check=True,stdout=subprocess.DEVNULL)
            driver=tmp/'driver.f90';driver.write_text(DRIVER)
            # Probe multiple distances from both ends, including the historical
            # failing head. All samples lie strictly inside the transition.
            heads=sorted(set([-width*x for x in (0.999,0.9,0.75,0.5,0.25,0.1,0.05,0.01,0.005,0.001,0.0005,0.0001)]+[-0.0001]))
            inp=''.join(f'{h:.17g}\n' for h in heads)
            outputs=[]
            for opt in (0,2):
                build=tmp/f'w{width}-o{opt}';build.mkdir()
                subprocess.run([args.compiler,f'-O{opt}','-std=f2008','-ffree-line-length-none',
                    '-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J',str(build),'-I',str(build),
                    str(ROOT/'src/solver/mod_soil_water_solver_contract.f90'),str(provider),str(driver),
                    '-o',str(build/'audit')],check=True,cwd=build,capture_output=True)
                outputs.append(subprocess.check_output([str(build/'audit'),str(width)],input=inp,text=True))
            if outputs[0]!=outputs[1]:raise RuntimeError('O0/O2 identity failed')
            raw=args.output/f'width-{width}.txt';raw.write_text(outputs[0])
            rows=[list(map(float,line.split())) for line in outputs[0].splitlines()]
            for head in heads:
                records=[r for r in rows if r[0]==head]
                actual=records[0]
                with localcontext() as ctx:
                    ctx.prec=80
                    hd=D.from_float(head);wd=D.from_float(width);step=abs(hd)*D('1e-8')
                    ref=(high_precision_k(hd+step,wd)-high_precision_k(hd-step,wd))/(2*step)
                    ref2=(high_precision_k(hd+step/2,wd)-high_precision_k(hd-step/2,wd))/step
                expected=float(ref2)
                results.append({'width_cm':width,'head_cm':head,'theta':actual[1],
                    'K_cm_day':actual[2],'analytic_dKdh':actual[4],
                    'high_precision_dKdh':expected,'high_precision_step_halving_difference':float(abs(ref-ref2)),
                    'absolute_error':abs(actual[4]-expected),
                    'within_inherited_gate':abs(actual[4]-expected)<=1e-6+2e-5*abs(expected),
                    'binary64_FD_steps':[{'eps':r[5],'derivative':r[6],'K_difference':r[7]} for r in records]})
    report={'baseline':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        'compiler':subprocess.check_output([args.compiler,'--version'],text=True).splitlines()[0],
        'audit_script_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'generator_sha256':hashlib.sha256((ROOT/'tests/fapp/make_top03_joint_nearsaturation.py').read_bytes()).hexdigest(),
        'scope':'One inherited MvG material; in-band derivative audit only; no trajectory or production admission',
        'O0_O2_identity':True,'precision_decimal_digits':80,'points':len(results),
        'failed_inherited_gate':sum(not r['within_inherited_gate'] for r in results),
        'rows':results,'production_admission':False}
    (args.output/'result.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='rows'},indent=2))
    for width in (0.02,0.2,2.0):
        worst=max((r for r in results if r['width_cm']==width),key=lambda r:r['absolute_error'])
        print('WORST',width,worst['head_cm'],worst['analytic_dKdh'],worst['high_precision_dKdh'],worst['absolute_error'])

if __name__=='__main__':main()
