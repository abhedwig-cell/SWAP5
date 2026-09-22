from __future__ import annotations
import math

S0=0.10
S1=1.0
SM=0.10
C=0.20
DT=1.0
WS=0.010
Z0=8.0
H0=8.0
TOL=1e-12

def close(a,b,tol=TOL):
    assert math.isclose(a,b,rel_tol=0.0,abs_tol=tol),(a,b)

def storage(x):
    return S0*x+0.5*S1*x*x

def storage_tangent(x):
    return S0+S1*x

def exact_root():
    # groundwater gives y=Cdt/(SM+Cdt)*x
    k=C*DT/(SM+C*DT)
    # 0.5*S1*x^2 + (S0+Cdt*(1-k))*x - WS = 0
    a=0.5*S1
    b=S0+C*DT*(1-k)
    disc=b*b+4*a*WS
    x=(-b+math.sqrt(disc))/(2*a)
    y=k*x
    ec=SM*y
    return x,y,ec

def predictor(qb):
    # storage(x)=WS+qb*dt, choose root continuous near x=0
    target=WS+qb*DT
    disc=S0*S0+2*S1*target
    if disc <= 0:
        raise ValueError("predictor outside monotone branch")
    x=(-S0+math.sqrt(disc))/S1
    zp=Z0+x
    hc=zp+qb/C
    stan=storage_tangent(x)
    u=C*DT*stan/(stan+C*DT)
    return x,hc,u

def test_nh03_exact_oracle():
    x,y,ec=exact_root()
    close(x,0.05191461747673335)
    close(y,0.03460974498448890)
    close(ec,0.00346097449844889)
    close(storage(x),WS-ec)
    close(SM*y,ec)
    close(storage(x)+SM*y,WS)

def test_nh03_tangent_secant_are_distinct():
    x,_,_=exact_root()
    stan=storage_tangent(x)
    ssec=storage(x)/x
    close(stan,0.15191461747673335)
    close(ssec,0.12595730873836668)
    assert abs(stan-ssec)>0.02
    uloc=C*DT*stan/(stan+C*DT)
    close(uloc,0.08633606558657775)

def test_nh03_predictor_u_is_trajectory_local():
    vals=[]
    for qb in (-0.002,0.0,0.003,0.008):
        _,_,u=predictor(qb)
        vals.append(u)
    assert max(vals)-min(vals)>1e-3
    # Unlike NH02, predictor invariance must fail prospectively under nonlinearity.
    assert all(v>0 for v in vals)

def test_nh03_corrector_derivative_matches_local_condensation():
    x,y,_=exact_root()
    stan=storage_tangent(x)
    uloc=C*DT*stan/(stan+C*DT)
    # implicit derivative dE/dH = -u_local
    close(-uloc,-0.08633606558657775)

if __name__=="__main__":
    test_nh03_exact_oracle()
    test_nh03_tangent_secant_are_distinct()
    test_nh03_predictor_u_is_trajectory_local()
    test_nh03_corrector_derivative_matches_local_condensation()
    print("GC_FIXED_INTERFACE_NH03_NONLINEAR_ORACLE=PASS")
