#!/usr/bin/env python3
import random
import subprocess
import sys


def request(p, s, x):
    (dvs,nmaxlv,wlv,wst,wrt,wso,grlv,grst,grrt,grso,rftra,_,_,_,_) = x
    nmaxst=p[0]*nmaxlv; nmaxrt=p[1]*nmaxlv
    lim=1.0 if rftra > 0.01 else 0.0
    dl=max(nmaxlv*wlv-s[0],0.0)+max(grlv*nmaxlv,0.0)
    dst=max(nmaxst*wst-s[1],0.0)+max(grst*nmaxst,0.0)
    drt=max(nmaxrt*wrt-s[2],0.0)+max(grrt*nmaxrt,0.0)
    dso=max(p[2]*wso-s[3],0.0)+max(grso*p[2],0.0)
    d=dl+dst+drt+dso
    fix=max(0.0,p[7]*d)*lim
    if dvs < p[9]:
        tl=ts=tr=tt=0.0
    else:
        al=max(0.0,s[0]-wlv*p[3]); ast=max(0.0,s[1]-wst*p[4]); ar=max(0.0,s[2]-wrt*p[5]); a=al+ast+ar
        tt=min(dso,a/p[6])
        if a == 0.0: tl=ts=tr=0.0
        else: tl=tt*al/a; ts=tt*ast/a; tr=tt*ar/a
    soil=max(0.0,min(d-fix,p[8]))*lim
    return [dl,dst,drt,dso,d,fix,tl,ts,tr,tt,soil]


def deaths_and_applied(p,s,x,q):
    (_,_,wlv,wst,wrt,_,_,_,_,_,_,drlv,drst,drrt,_)=x
    dl=(s[0]/wlv)*drlv if wlv>0 else 0.0
    ds=(s[1]/wst)*drst if wst>0 else 0.0
    dr=(s[2]/wrt)*drrt if wrt>0 else 0.0
    swlv=max(0.0,wlv-drlv); swst=max(0.0,wst-drst); swrt=max(0.0,wrt-drrt)
    snlv=max(0.0,s[0]-dl); snst=max(0.0,s[1]-ds); snrt=max(0.0,s[2]-dr)
    al=max(0.0,snlv-swlv*p[3]); ast=max(0.0,snst-swst*p[4]); ar=max(0.0,snrt-swrt*p[5])
    atl=min(q[6],al); ats=min(q[7],ast); atr=min(q[8],ar)
    return dl,ds,dr,atl,ats,atr,atl+ats+atr


def apply(p,s,x,q):
    (_,_,_,_,_,_,_,_,_,_,_,_,_,_,soil_supply)=x
    soil=min(q[10],soil_supply)
    fix=q[5]; supplied=soil+fix
    dl,ds,dr,atl,ats,atr,att=deaths_and_applied(p,s,x,q)
    if q[4] == 0.0:
        ul=us=ur=uo=0.0
    else:
        tl=q[0]+atl; ts=q[1]+ats; tr=q[2]+atr; to=q[3]-att; scale=supplied/q[4]
        ul=max(0.0,min(tl,tl*scale)); us=max(0.0,min(ts,ts*scale)); ur=max(0.0,min(tr,tr*scale)); uo=max(0.0,min(to,to*scale))
    rl=ul-atl-dl; rs=us-ats-ds; rr=ur-atr-dr; ro=uo+att; loss=dl+ds+dr
    c=[s[0]+rl,s[1]+rs,s[2]+rr,s[3]+ro,s[4]+soil,s[5]+fix,s[6]+loss,s[7]]
    residual=s[7]+c[4]+c[5]-sum(c[:4])-c[6]
    f=[soil,fix,atl,ats,atr,att,ul,us,ur,uo,dl,ds,dr,loss,residual]
    return c,f


def apply_pcse_reference(p,s,x,q):
    (_,_,wlv,wst,wrt,_,_,_,_,_,_,drlv,drst,drrt,soil_supply)=x
    soil=min(q[10],soil_supply); fix=q[5]; supplied=soil+fix
    if q[4] == 0.0:
        ul=us=ur=uo=0.0
    else:
        tl=q[0]+q[6]; ts=q[1]+q[7]; tr=q[2]+q[8]; to=q[3]-q[9]; scale=supplied/q[4]
        ul=max(0.0,min(tl,tl*scale)); us=max(0.0,min(ts,ts*scale)); ur=max(0.0,min(tr,tr*scale)); uo=max(0.0,min(to,to*scale))
    dl=(s[0]/wlv)*drlv if wlv>0 else 0.0
    ds=(s[1]/wst)*drst if wst>0 else 0.0
    dr=(s[2]/wrt)*drrt if wrt>0 else 0.0
    rl=ul-q[6]-dl; rs=us-q[7]-ds; rr=ur-q[8]-dr; ro=uo+q[9]; loss=dl+ds+dr
    c=[s[0]+rl,s[1]+rs,s[2]+rr,s[3]+ro,s[4]+soil,s[5]+fix,s[6]+loss,s[7]]
    residual=s[7]+c[4]+c[5]-sum(c[:4])-c[6]
    return c,[soil,fix,q[6],q[7],q[8],q[9],ul,us,ur,uo,dl,ds,dr,loss,residual]


def build_cases():
    rnd=random.Random(810041)
    cases=[]
    basep=[0.5,0.5,0.0176,0.004,0.002,0.002,10.0,0.0,4.26,0.8]
    for rf,dvs in [(0.0,0.5),(0.011,0.5),(1.0,0.79),(1.0,0.8),(1.0,1.5)]:
        wlv,wst,wrt,wso=1200.,900.,700.,300.; nmaxlv=.03
        s=[25.,10.,8.,2.,0.,0.,0.,45.]
        x=[dvs,nmaxlv,wlv,wst,wrt,wso,30.,20.,10.,15.,rf,5.,3.,2.,0.0]
        q=request(basep,s,x); x[-1]=0.6*q[-1]
        cases.append((basep[:],s[:],x))

    # Reproduces the late-season blocker class: the complete committed leaf
    # biomass dies while WOFOST still requests leaf N translocation.
    p=basep[:]
    s=[6.8500101123455948e-3,2.0375261333043295,4.2215440870592369e-1,26.564893684299076,0.,0.,0.,29.031424236421675]
    x=[1.9,.014,1.5522960948511446,810.1159928239257,180.20513210356495,1800.,1.1,5.,1.,30.,1.0,
       1.5522960948511446,16.202319856478514,3.604102642071299,0.016884862609608604]
    cases.append((p,s,x))

    for _ in range(1800):
        nmaxlv=rnd.uniform(.012,.065); nmaxstfr=rnd.uniform(.3,.8); nmaxrtfr=rnd.uniform(.3,.8)
        p=[nmaxstfr,nmaxrtfr,rnd.uniform(.005,.025),rnd.uniform(.001,.007),rnd.uniform(.0005,.004),rnd.uniform(.0005,.004),rnd.uniform(3.,20.),rnd.uniform(0.,.4),rnd.uniform(1.,10.),rnd.uniform(.5,1.2)]
        wlv=rnd.uniform(50.,4000.); wst=rnd.uniform(20.,3500.); wrt=rnd.uniform(20.,2500.); wso=rnd.uniform(0.,4000.)
        sl=nmaxlv*wlv*rnd.uniform(.55,1.0); ss=nmaxlv*nmaxstfr*wst*rnd.uniform(.55,1.0); sr=nmaxlv*nmaxrtfr*wrt*rnd.uniform(.55,1.0); so=p[2]*wso*rnd.uniform(0.,1.0)
        s=[sl,ss,sr,so,0.,0.,0.,sl+ss+sr+so]
        dvs=rnd.uniform(0.,2.1); rf=rnd.uniform(0.,1.0)
        grlv=rnd.uniform(0.,80.); grst=rnd.uniform(0.,100.); grrt=rnd.uniform(0.,60.); grso=rnd.uniform(0.,120.)
        drlv=wlv*rnd.uniform(0.,.015); drst=wst*rnd.uniform(0.,.01); drrt=wrt*rnd.uniform(0.,.01)
        x=[dvs,nmaxlv,wlv,wst,wrt,wso,grlv,grst,grrt,grso,rf,drlv,drst,drrt,0.0]
        q=request(p,s,x); x[-1]=q[-1]*rnd.uniform(0.,1.0)
        c,_=apply(p,s,x,q)
        if min(c[:4]) < -1e-10: continue
        cases.append((p,s,x))
    return cases


def main(exe):
    cc=build_cases()
    payload='\n'.join(' '.join(f'{z:.17g}' for z in p+s+x) for p,s,x in cc)+'\n'
    out=subprocess.run([exe],input=payload,text=True,capture_output=True,check=True).stdout.splitlines()
    if len(out)!=len(cc): raise SystemExit('output count mismatch')
    max_abs=max_rel=0.0; parity_cases=0; clipped_cases=0
    for i,(line,(p,s,x)) in enumerate(zip(out,cc)):
        vals=line.split(); qs=int(vals[0]); fs=int(vals[1]); got=list(map(float,vals[2:]))
        if qs or fs: raise SystemExit(f'case {i} unexpected status q={qs} f={fs}')
        q=request(p,s,x); c,f=apply(p,s,x,q); exp=q+c+f
        if len(got)!=len(exp): raise SystemExit(f'field count {len(got)} != {len(exp)}')
        for j,(a,e) in enumerate(zip(got,exp)):
            err=abs(a-e); rel=err/max(1.0,abs(e)); max_abs=max(max_abs,err); max_rel=max(max_rel,rel)
            if err > 5e-11 + 3e-12*abs(e):
                raise SystemExit(f'case {i} field {j} mismatch {a:.17g} {e:.17g} err={err:.3e}')
        applied=f[2:6]
        requested=q[6:10]
        if all(abs(a-r) <= 2e-14*max(1.0,abs(r)) for a,r in zip(applied,requested)):
            parity_cases += 1
            cref,fref=apply_pcse_reference(p,s,x,q)
            for j,(a,e) in enumerate(zip(c+f,cref+fref)):
                if abs(a-e) > 5e-11 + 3e-12*abs(e):
                    raise SystemExit(f'case {i} reference parity field {j} mismatch {a:.17g} {e:.17g}')
        else:
            clipped_cases += 1
            if any(a-r > 1e-13 for a,r in zip(applied[:3],requested[:3])):
                raise SystemExit(f'case {i} applied transfer exceeds request')
            if abs(f[-1]) > 2e-10:
                raise SystemExit(f'case {i} clipped balance residual {f[-1]:.3e}')
    if clipped_cases < 1: raise SystemExit('no donor-limited arbitration case exercised')
    print(f'SWAP431_WOF81_07_N_ARBITRATION_PASS cases={len(cc)} parity_cases={parity_cases} clipped_cases={clipped_cases} max_abs={max_abs:.3e} max_rel={max_rel:.3e}')

if __name__=='__main__': main(sys.argv[1])
