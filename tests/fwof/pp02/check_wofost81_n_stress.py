#!/usr/bin/env python3
import random,subprocess,sys,math
rnd=random.Random(810051)
cases=[]
# explicit nonstress, intermediate, strong stress
cases += [
 [.03,.5,.0176,.0082,.004,1000,800,100,30,12,1.76],
 [.03,.5,.0176,.0082,.004,1000,800,100,20,8,1.0],
 [.03,.5,.0176,.0082,.004,1000,800,100,5,2,0.2],
]
for _ in range(2000):
 nmax=rnd.uniform(.012,.065); fs=rnd.uniform(.3,.8); nso=rnd.uniform(.005,.025); rg=rnd.uniform(.005,.015); rgmin=rnd.uniform(.001,rg)
 wlv=rnd.uniform(10,4000); wst=rnd.uniform(0,3000); wso=rnd.uniform(0,4000)
 mxlv=wlv*nmax; mxst=wst*nmax*fs; mxso=wso*nso
 # keep aboveground N positive
 frac=rnd.uniform(.2,1.2)
 nlv=max(1e-6,mxlv*frac); nst=mxst*rnd.uniform(.2,1.2); ns=mxso*rnd.uniform(.2,1.2)
 cases.append([nmax,fs,nso,rg,rgmin,wlv,wst,wso,nlv,nst,ns])
payload='\n'.join(' '.join(f'{x:.17g}' for x in c) for c in cases)+'\n'
out=subprocess.run([sys.argv[1]],input=payload,text=True,capture_output=True,check=True).stdout.splitlines()
assert len(out)==len(cases)
ma=mr=0.0
for i,(line,c) in enumerate(zip(out,cases)):
 vals=line.split(); status=int(vals[0]); aidx=float(vals[1]); arfr=float(vals[2])
 if status: raise SystemExit(f'case {i} status {status}')
 nmax,fs,nso,rg,rgmin,wlv,wst,wso,nlv,nst,ns=c
 abg=nlv+nst+ns; mx=wlv*nmax+wst*(fs*nmax)+wso*nso; ratio=mx/abg
 eidx=1.0 if ratio<=1 else (2.0 if ratio>2 else ratio)
 conc=nlv/wlv if wlv>0 else 0.0
 idx=max(0,min(1,(conc-.9*nmax)/(.1*nmax)))
 erfr=1-(1-idx)*(rg-rgmin)/rg
 for a,e in [(aidx,eidx),(arfr,erfr)]:
  err=abs(a-e); rel=err/max(1,abs(e)); ma=max(ma,err);mr=max(mr,rel)
  if err>2e-13+2e-13*abs(e): raise SystemExit(f'case {i} mismatch {a} {e}')
print(f'SWAP431_WOF81_05_N_STRESS_ORACLE_PASS cases={len(cases)} max_abs={ma:.3e} max_rel={mr:.3e}')
