from __future__ import annotations
from dataclasses import dataclass
import math, json

@dataclass(frozen=True)
class B110Material:
    c: tuple

    @staticmethod
    def from_input(vals):
        c=[0.0]*43
        for j,v in enumerate(vals, start=1):
            if j>24: break
            c[j]=float(v)
        H_CRIT=-1.0e-2
        c[25]=c[2]-c[1]
        alfa=c[4]
        c[26]=c[1]+c[25]/((1+(abs(alfa*H_CRIT))**c[6])**c[7])
        c[27]=(c[2]-c[26])/(-H_CRIT)
        c[28]=(1+(abs(alfa*c[9]))**c[6])**(-c[7])
        c[29]=c[6]*c[7]*alfa
        c[30]=c[6]-1
        c[31]=c[7]+1
        c[32]=1/c[7]
        c[33]=c[6]*(2+c[7]*c[5])
        c[34]=c[5]+2
        c[35]=c[7]-1
        c[36]=c[5]-1
        c[37]=c[14]*c[15]*c[13]
        c[38]=c[14]-1
        c[39]=c[15]+1
        c[40]=1/c[15] if c[15]>0 else 0
        if c[9] < 0:
            h105=1.05*c[9]
            t105=c[1]+(c[2]-c[1])*((1+(abs(alfa*c[9]))**c[6])**c[7])/((1+(abs(alfa*h105))**c[6])**c[7])
            c105=(c[2]-c[1])*alfa*c[7]*c[6]*(abs(alfa*h105)**(c[6]-1))*((1+abs(alfa*c[9])**c[6])**c[7])/((1+abs(alfa*h105)**c[6])**(c[7]+1))
            a=(t105-c[2]-c105*h105)/(c105*h105**2)
            b=(t105*t105-2*t105*c[2]+c[2]*c[2])/(t105-c[2]-c105*h105)
        else:
            a=b=0.0
        c[41]=a
        c[42]=a*b
        return B110Material(tuple(c))

    @property
    def theta_r(self): return self.c[1]
    @property
    def theta_s(self): return self.c[2]

    def theta(self, head):
        c=self.c; H_CRIT=-1.0e-2; alfa=c[4]
        if head >= 0:
            return c[2]
        if c[9] > H_CRIT:
            if head > H_CRIT:
                return min(c[26]+c[27]*(head-H_CRIT), c[2])
            helpv=(1+(abs(alfa*head))**c[6])**c[7]
            return c[1]+c[25]/helpv
        h105=1.05*c[9]
        if head >= h105:
            return c[2]+c[42]*head/(1+c[41]*head)
        helpv=(1+(abs(alfa*head))**c[6])**c[7]
        return c[1]+c[25]/(helpv*c[28])

    def conductivity(self, head):
        c=self.c; VSMALL=1.0e-10
        theta=self.theta(head)
        relsat=(theta-c[1])/c[25]
        relsat=max(0.0, min(1.0, relsat))
        H_CRIT=-1.0e-2
        if c[9] > H_CRIT:
            if head < -1e14: kval=VSMALL
            elif relsat > 1-1e-6: kval=c[3]
            else:
                term1=(1-relsat**c[32])**c[7]
                kval=c[3]*(relsat**c[5])*(1-term1)**2
        else:
            if head < -1e14: kval=VSMALL
            elif head >= c[9]: kval=c[3]
            else:
                se=((1+abs(c[4]*head)**c[6])**(-c[7]))/c[28]
                term1=(1-(se*c[28])**c[32])**c[7]
                term2=(1-c[28]**c[32])**c[7]
                kval=c[3]*se**c[5]*((1-term1)/(1-term2))**2
        return min(kval,c[3])

    def head_from_theta(self, theta, hmin=-1e8, max_iter=100):
        if theta >= self.theta_s: return 0.0
        lo=hmin; hi=0.0
        flo=self.theta(lo)-theta
        fhi=self.theta(hi)-theta
        if flo > 0:
            raise ValueError("theta below inverse bracket")
        if fhi < 0:
            raise ValueError("theta above inverse bracket")
        for _ in range(max_iter):
            mid=0.5*(lo+hi)
            fm=self.theta(mid)-theta
            if abs(fm) < 1e-13 or abs(hi-lo)<1e-10*max(1.0,abs(mid)):
                return mid
            if fm<0: lo=mid
            else: hi=mid
        return 0.5*(lo+hi)

def make_fixture_material(i):
    vals=[0.0]*24
    vals[0]=0.03+0.005*i
    vals[1]=0.42+0.004*i
    vals[2]=5.0+2.0*i
    vals[3]=0.015+0.004*i
    vals[4]=0.35+0.03*i
    vals[5]=1.45+0.08*i
    vals[6]=1.0-1.0/vals[5]
    vals[7]=vals[3]
    vals[8]=(-10.0-2.0*i) if i%2==0 else 0.0
    vals[9]=vals[2]
    vals[10]=0.999
    vals[11]=0.99*vals[2]
    vals[21]=-1e6
    vals[22]=1e-12
    return B110Material.from_input(vals)

def adaptive_simpson(f,a,b,atol=1e-10,rtol=1e-9,max_depth=22):
    if a==b: return 0.0,0
    sign=1.0
    if b<a:
        a,b=b,a; sign=-1.0
    fa=f(a); fb=f(b); m=(a+b)/2; fm=f(m)
    whole=(b-a)*(fa+4*fm+fb)/6
    evals=3
    def rec(a,b,fa,fm,fb,whole,depth):
        nonlocal evals
        m=(a+b)/2; lm=(a+m)/2; rm=(m+b)/2
        flm=f(lm); frm=f(rm); evals+=2
        left=(m-a)*(fa+4*flm+fm)/6
        right=(b-m)*(fm+4*frm+fb)/6
        total=left+right
        tol=atol+rtol*abs(total)
        if depth<=0 or abs(total-whole)<=15*tol:
            return total+(total-whole)/15
        return rec(a,m,fa,flm,fm,left,depth-1)+rec(m,b,fm,frm,fb,right,depth-1)
    return sign*rec(a,b,fa,fm,fb,whole,max_depth), evals

def mfp_difference(mat, h_a, h_b):
    return adaptive_simpson(mat.conductivity, h_b, h_a)

def dry_flux_homogeneous(mat, h_upper, h_lower, dz_upper, dz_lower):
    dphi, evals=mfp_difference(mat,h_upper,h_lower)
    return 2.0*dphi/(dz_upper+dz_lower), evals

def dry_flux_heterogeneous(mat_u, mat_l, h_upper, h_lower, dz_u, dz_l, tol=1e-8, max_iter=50):
    if abs(h_upper-h_lower) < 1e-15:
        return 0.0,h_upper,0,0.0
    lo=min(h_upper,h_lower); hi=max(h_upper,h_lower)
    def flows(h_int):
        d1,e1=mfp_difference(mat_u,h_upper,h_int)
        d2,e2=mfp_difference(mat_l,h_int,h_lower)
        q1=d1/(0.5*dz_u)
        q2=d2/(0.5*dz_l)
        return q1,q2,e1+e2
    q1lo,q2lo,e=flows(lo); flo=q1lo-q2lo
    q1hi,q2hi,e2=flows(hi); fhi=q1hi-q2hi; e+=e2
    if flo==0: return q1lo,lo,0,e
    if fhi==0: return q1hi,hi,0,e
    if flo*fhi>0:
        raise ValueError(f"no interface-head bracket: f(lo)={flo}, f(hi)={fhi}")
    total_e=e
    for it in range(1,max_iter+1):
        mid=0.5*(lo+hi)
        q1,q2,ee=flows(mid); total_e+=ee
        res=q1-q2
        if abs(res)<=tol:
            return 0.5*(q1+q2),mid,it,total_e
        if flo*res<=0:
            hi=mid; fhi=res
        else:
            lo=mid; flo=res
    q1,q2,ee=flows(0.5*(lo+hi)); total_e+=ee
    return 0.5*(q1+q2),0.5*(lo+hi),max_iter,total_e

def wet_flux_harmonic(mat_u,mat_l,h_u,h_l,dz_u,dz_l):
    ku=mat_u.conductivity(h_u); kl=mat_l.conductivity(h_l)
    return (dz_u+dz_l)/(dz_u/ku+dz_l/kl)

def equal_potential_transfer(mat_u,mat_l,Wu,Wl,dzu,dzl,tol_head=1e-7,max_iter=80):
    xmin=max(Wu-mat_u.theta_s*dzu, mat_l.theta_r*dzl-Wl)
    xmax=min(Wu-mat_u.theta_r*dzu, mat_l.theta_s*dzl-Wl)
    eps=1e-12
    xmin+=eps; xmax-=eps
    def f(x):
        thu=(Wu-x)/dzu; thl=(Wl+x)/dzl
        return mat_u.head_from_theta(thu)-mat_l.head_from_theta(thl)
    flo=f(xmin); fhi=f(xmax)
    if flo==0: return xmin,0
    if fhi==0: return xmax,0
    if flo*fhi>0: raise ValueError((xmin,xmax,flo,fhi))
    lo,hi=xmin,xmax
    for it in range(1,max_iter+1):
        mid=0.5*(lo+hi); fm=f(mid)
        if abs(fm)<=tol_head or abs(hi-lo)<1e-12:
            return mid,it
        if flo*fm<=0:
            hi=mid; fhi=fm
        else:
            lo=mid; flo=fm
    return 0.5*(lo+hi),max_iter

def apply_transfer(Wu,Wl,x): return Wu-x,Wl+x

def conservative_update(W, face_flux, source, sink, dt):
    n=len(W)
    assert len(face_flux)==n+1
    Wn=[]
    for i in range(n):
        Wn.append(W[i]+dt*(face_flux[i]-face_flux[i+1]+source[i]-sink[i]))
    expected=dt*(face_flux[0]-face_flux[-1]+sum(source)-sum(sink))
    actual=sum(Wn)-sum(W)
    return Wn, actual-expected

def lineage_upward_step(mat_u,mat_l,Wu,Wl,dzu,dzl,fraction=0.5):
    xeq,_=equal_potential_transfer(mat_u,mat_l,Wu,Wl,dzu,dzl)
    x=min(0.0,xeq)*fraction if xeq<0 else 0.0
    return *apply_transfer(Wu,Wl,x), x, xeq

def exponential_upward_step(mat_u,mat_l,Wu,Wl,dzu,dzl,dt,tau):
    xeq,_=equal_potential_transfer(mat_u,mat_l,Wu,Wl,dzu,dzl)
    frac=1-math.exp(-dt/tau)
    x=min(0.0,xeq)*frac if xeq<0 else 0.0
    return *apply_transfer(Wu,Wl,x), x, xeq, frac

class MFPTable:
    """Candidate shared immutable MFP table, not an exact historical table discretisation."""
    def __init__(self, mat, n=513, pf_max=6.0, pf_min=-4.0):
        import bisect
        self._bisect = bisect
        self.mat = mat
        self.pfs = [pf_max + (pf_min-pf_max)*i/(n-1) for i in range(n)]
        self.heads = [-10.0**pf for pf in self.pfs]
        self.phi = [0.0]
        evals = 0
        for a,b in zip(self.heads[:-1], self.heads[1:]):
            val,e = adaptive_simpson(mat.conductivity, a, b, atol=1e-11, rtol=1e-9)
            self.phi.append(self.phi[-1] + val)
            evals += e
        tail,e = adaptive_simpson(mat.conductivity, self.heads[-1], 0.0, atol=1e-11, rtol=1e-9)
        self.phi0 = self.phi[-1] + tail
        self.precompute_constitutive_evals = evals + e

    def value(self, h):
        if h <= self.heads[0]:
            raise ValueError("head below MFP table envelope")
        if h >= 0.0:
            return self.phi0
        if h > self.heads[-1]:
            f = (h-self.heads[-1])/(0.0-self.heads[-1])
            return self.phi[-1] + f*(self.phi0-self.phi[-1])
        i = self._bisect.bisect_right(self.heads, h) - 1
        i = max(0, min(i, len(self.heads)-2))
        pf = math.log10(-h)
        p0,p1 = self.pfs[i],self.pfs[i+1]
        f = (pf-p0)/(p1-p0)
        return self.phi[i] + f*(self.phi[i+1]-self.phi[i])

    def diff(self, h_a, h_b):
        return self.value(h_a)-self.value(h_b)

def dry_flux_heterogeneous_table(tab_u, tab_l, h_upper, h_lower, dz_u, dz_l,
                                 tol=1e-8, max_iter=50):
    if abs(h_upper-h_lower) < 1e-15:
        return 0.0,h_upper,0
    lo=min(h_upper,h_lower); hi=max(h_upper,h_lower)
    phi_u_center=tab_u.value(h_upper)
    phi_l_center=tab_l.value(h_lower)
    def residual(h_int):
        q1=(phi_u_center-tab_u.value(h_int))/(0.5*dz_u)
        q2=(tab_l.value(h_int)-phi_l_center)/(0.5*dz_l)
        return q1-q2,q1,q2
    flo,_,_=residual(lo)
    fhi,_,_=residual(hi)
    if flo == 0.0:
        _,q1,q2=residual(lo); return 0.5*(q1+q2),lo,0
    if fhi == 0.0:
        _,q1,q2=residual(hi); return 0.5*(q1+q2),hi,0
    if flo*fhi > 0.0:
        raise ValueError("no heterogeneous interface bracket")
    for it in range(1,max_iter+1):
        mid=0.5*(lo+hi)
        fm,q1,q2=residual(mid)
        if abs(fm) <= tol:
            return 0.5*(q1+q2),mid,it
        if flo*fm <= 0.0:
            hi=mid
        else:
            lo=mid; flo=fm
    mid=0.5*(lo+hi)
    _,q1,q2=residual(mid)
    return 0.5*(q1+q2),mid,max_iter

def run():
    m1=make_fixture_material(1)
    m2=make_fixture_material(2)
    evidence={"tests":{}, "metrics":{}}

    max_inv=0.0
    for mat in [m1,m2]:
        for h in [-1000,-300,-100,-30,-10,-3,-1,-0.1]:
            th=mat.theta(h); hr=mat.head_from_theta(th)
            max_inv=max(max_inv,abs(hr-h))
    evidence["tests"]["theta_head_inverse"]={"pass":max_inv<1e-5,"max_abs_head_error":max_inv}

    max_rel=0.0
    for h in [-300,-100,-30,-10,-3,-1]:
        eps=max(1e-5,abs(h)*1e-5)
        dphi,_=mfp_difference(m1,h+eps,h-eps)
        deriv=dphi/(2*eps); k=m1.conductivity(h)
        rel=abs(deriv-k)/max(abs(k),1e-12)
        max_rel=max(max_rel,rel)
    evidence["tests"]["mfp_derivative_equals_K"]={"pass":max_rel<2e-5,"max_rel_error":max_rel}

    qh,_=dry_flux_homogeneous(m1,-5,-80,20,30)
    qs,hi,its,_=dry_flux_heterogeneous(m1,m1,-5,-80,20,30)
    evidence["tests"]["homogeneous_split_identity"]={
        "pass":abs(qh-qs)<1e-7,"q_direct":qh,"q_split":qs,"abs_error":abs(qh-qs),
        "interface_head":hi,"iterations":its}

    q,hi,its,evals=dry_flux_heterogeneous(m1,m2,-5,-80,20,30)
    d1,_=mfp_difference(m1,-5,hi); d2,_=mfp_difference(m2,hi,-80)
    q1=d1/10; q2=d2/15
    evidence["tests"]["heterogeneous_equal_flux"]={
        "pass":abs(q1-q2)<1e-8 and its<=50,"q":q,"q_upper_half":q1,"q_lower_half":q2,
        "residual":q1-q2,"interface_head":hi,"iterations":its,"quadrature_evals":evals}

    ku=m1.conductivity(-5); kl=m2.conductivity(-80)
    qw=wet_flux_harmonic(m1,m2,-5,-80,20,30)
    evidence["tests"]["wet_harmonic_bounds"]={"pass":min(ku,kl)<=qw<=max(ku,kl),"Ku":ku,"Kl":kl,"qwet":qw}

    dzu=20.; dzl=30.
    Wu=m1.theta(-100)*dzu; Wl=m2.theta(-5)*dzl
    xeq,eqits=equal_potential_transfer(m1,m2,Wu,Wl,dzu,dzl)
    Wue,Wle=apply_transfer(Wu,Wl,xeq)
    heq1=m1.head_from_theta(Wue/dzu); heq2=m2.head_from_theta(Wle/dzl)
    evidence["tests"]["equal_potential_transfer"]={
        "pass":abs(heq1-heq2)<1e-5 and xeq<0,"transfer":xeq,"head_upper_final":heq1,
        "head_lower_final":heq2,"head_residual":heq1-heq2,"iterations":eqits}

    _,_,x1,_=lineage_upward_step(m1,m2,Wu,Wl,dzu,dzl,0.5)
    W1b,W2b,xa,_=lineage_upward_step(m1,m2,Wu,Wl,dzu,dzl,0.5)
    W1b,W2b,xb,_=lineage_upward_step(m1,m2,W1b,W2b,dzu,dzl,0.5)
    one=x1; two=xa+xb
    evidence["tests"]["fixed_half_step_noninvariance"]={
        "pass":abs(one-two)>1e-6,"one_step_transfer":one,"two_half_steps_transfer":two,
        "difference":two-one,"interpretation":"same per-step 0.50 rule produces a different 1-day endpoint after step subdivision"}

    tau=1/math.log(2)
    A1,_,_,_,f1=exponential_upward_step(m1,m2,Wu,Wl,dzu,dzl,1.0,tau)
    B1,B2,_,_,fh=exponential_upward_step(m1,m2,Wu,Wl,dzu,dzl,0.5,tau)
    B1,B2,_,_,_=exponential_upward_step(m1,m2,B1,B2,dzu,dzl,0.5,tau)
    expdiff=B1-A1
    evidence["tests"]["exponential_relaxation_step_composition"]={
        "pass":abs(expdiff)<5e-10,"tau_days":tau,"one_step_upper_storage":A1,
        "two_half_upper_storage":B1,"storage_difference":expdiff,"fraction_1d":f1,"fraction_half":fh}

    W=[3.0,5.0,7.0]; faces=[0.4,0.1,-0.2,0.05]
    src=[0.02,0.0,0.03]; sink=[0.01,0.04,0.0]
    Wn,res=conservative_update(W,faces,src,sink,0.37)
    evidence["tests"]["face_flux_mass_conservation"]={"pass":abs(res)<5e-15,"mass_residual":res,"W_new":Wn}

    heads=[(-2,-20),(-5,-80),(-20,-5),(-100,-1),(-1,-300)]
    maxits=0; rows=[]
    for hu,hl in heads:
        for a,b in [(m1,m1),(m1,m2),(m2,m1),(m2,m2)]:
            q,_,it,_=dry_flux_heterogeneous(a,b,hu,hl,20,30)
            maxits=max(maxits,it); rows.append({"hu":hu,"hl":hl,"iterations":it,"q":q})
    evidence["tests"]["bounded_local_interface_iteration"]={"pass":maxits<=50,"max_iterations":maxits,"cases":len(rows)}
    evidence["metrics"]["interface_iteration_rows"]=rows

    tables={1:MFPTable(m1,513),2:MFPTable(m2,513)}
    table_cases=[(-2,-20),(-5,-80),(-20,-5),(-100,-1),(-1,-300),(-0.1,-1000),(-300,-3)]
    max_table_abs=0.0; max_table_rel=0.0; max_table_it=0
    for hu,hl in table_cases:
        for a,b,ta,tb in [(m1,m1,tables[1],tables[1]),(m1,m2,tables[1],tables[2]),
                          (m2,m1,tables[2],tables[1]),(m2,m2,tables[2],tables[2])]:
            qref,_,_,_=dry_flux_heterogeneous(a,b,hu,hl,20,30)
            qt,_,it=dry_flux_heterogeneous_table(ta,tb,hu,hl,20,30)
            err=abs(qt-qref); rel=err/max(abs(qref),1e-12)
            max_table_abs=max(max_table_abs,err); max_table_rel=max(max_table_rel,rel); max_table_it=max(max_table_it,it)
    evidence["tests"]["shared_mfp_table_against_integration_oracle"]={
        "pass":max_table_rel<2.0e-4 and max_table_it<=50,"nodes_per_material":513,"pf_range":[-4.0,6.0],
        "cases":28,"max_abs_flux_error":max_table_abs,"max_rel_flux_error":max_table_rel,
        "max_interface_iterations":max_table_it,"precompute_constitutive_evals_two_materials":
        tables[1].precompute_constitutive_evals+tables[2].precompute_constitutive_evals,
        "runtime_quadrature_evals_per_mfp_lookup":0,"approx_double_storage_bytes_per_material_for_pf_plus_phi":513*2*8}

    evidence["interpretation"]={
        "lineage_daily_upward_fraction":"The fixed 0.50 factor is per step. It fails step-subdivision invariance and is not generic-time physics.",
        "exponential_relaxation_demo":"A dt-aware exponential fraction composes across substeps, but tau is not physically qualified here.",
        "mfp_table":"Pretabulation removes numerical K(h) quadrature from the runtime face solve; table resolution and interpolation remain qualification choices.",
        "scope":"Standalone reconstruction only. No FullRichards physical equivalence and no production admission are claimed."}
    evidence["overall_pass"]=all(v["pass"] for v in evidence["tests"].values())
    return evidence

if __name__=="__main__":
    ev=run()
    print(json.dumps(ev,indent=2,sort_keys=True))
    raise SystemExit(0 if ev["overall_pass"] else 1)
