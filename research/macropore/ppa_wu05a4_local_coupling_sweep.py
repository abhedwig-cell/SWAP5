from itertools import product
from math import sqrt

THETA_S=0.427494
THETA_R=0.02
PP=0.08
GEOM=4.0*0.95*10.0/4.0
ACTIVE_DEPTH=(1.0-PP)*20.0

def amount(theta,tabs,theta_ref,sorp_max,alpha,dt,macro_water):
    deficit=max(0.0,THETA_S-theta)
    if deficit<1e-12:
        return 0.0
    if tabs<1e-12:
        active=sorp_max*(deficit/(THETA_S-THETA_R))**alpha
    elif theta_ref-theta>1e-12:
        active=sorp_max*((theta_ref-theta)/(THETA_S-THETA_R))**alpha
    else:
        active=0.0
    a=active*PP*GEOM*(sqrt(tabs+dt)-sqrt(tabs))
    return min(max(a,0.0),macro_water)

def fixed_point(theta0,tabs,theta_ref,sorp_max,alpha,dt,macro_water,n=12):
    theta=theta0
    rates=[]
    for _ in range(n):
        a=amount(theta,tabs,theta_ref,sorp_max,alpha,dt,macro_water)
        rates.append(a/dt)
        theta=min(THETA_S,theta0+a/ACTIVE_DEPTH)
    return rates

if __name__=="__main__":
    thetas=[0.05,0.08,0.12,0.16,0.22,0.30,0.36,0.40]
    tabs_values=[0.0,0.001,0.01,0.1,0.5,2.0]
    dts=[1e-4,1e-3,1e-2,5e-2,0.1]
    sorps=[0.1,0.5,1.0,2.0]
    waters=[0.005,0.02,0.1,0.5,2.0]

    rows=[]
    for theta0,tabs,dt,smax,mw in product(thetas,tabs_values,dts,sorps,waters):
        tref=THETA_S if tabs==0 else 0.47
        rates=fixed_point(theta0,tabs,tref,smax,0.5,dt,mw)
        final=rates[-1]
        rel12=abs(rates[1]-rates[0])/max(abs(rates[0]),1e-30)
        err1=abs(rates[0]-final)/max(abs(final),1e-30)
        err2=abs(rates[1]-final)/max(abs(final),1e-30)
        err3=abs(rates[2]-final)/max(abs(final),1e-30)
        rows.append((theta0,tabs,dt,smax,mw,rel12,err1,err2,err3,final))

    maxrow=max(rows,key=lambda r:r[5])
    print("PPA_WU05A4_LOCAL_SWEEP_CASES",len(rows))
    print("PPA_WU05A4_LOCAL_SWEEP_MAX_REL12",maxrow)
    print("PPA_WU05A4_LOCAL_SWEEP_MAX_ERR1",max(r[6] for r in rows))
    print("PPA_WU05A4_LOCAL_SWEEP_MAX_ERR2",max(r[7] for r in rows))
    print("PPA_WU05A4_LOCAL_SWEEP_MAX_ERR3",max(r[8] for r in rows))
    print("PPA_WU05A4_LOCAL_SWEEP_GT5PCT",sum(r[5]>0.05 for r in rows))
    print("PPA_WU05A4_LOCAL_SWEEP_GT10PCT",sum(r[5]>0.10 for r in rows))
    print("PPA_WU05A4_LOCAL_SWEEP=PASS")
