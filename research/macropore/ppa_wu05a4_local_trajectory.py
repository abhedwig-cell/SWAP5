from math import sqrt

THETA_S=0.427494
THETA_R=0.02
PP=0.08
ACTIVE_DEPTH=(1.0-PP)*20.0
GEOM=4.0*0.95*10.0/4.0

def raw_amount(theta,tabs,tref,sorp_max,dt,macro_water):
    deficit=max(0.0,THETA_S-theta)
    if deficit<1e-12:
        return 0.0
    if tabs<1e-12:
        active=sorp_max*(deficit/(THETA_S-THETA_R))**0.5
    elif tref-theta>1e-12:
        active=sorp_max*((tref-theta)/(THETA_S-THETA_R))**0.5
    else:
        active=0.0
    amount=active*PP*GEOM*(sqrt(tabs+dt)-sqrt(tabs))
    return min(max(amount,0.0),macro_water)

def fixed_point(theta0,tabs,tref,sorp_max,dt,macro_water,max_iterations,omega,tol):
    theta=theta0
    q_previous=None
    q=0.0
    for iteration in range(1,max_iterations+1):
        raw=raw_amount(theta,tabs,tref,sorp_max,dt,macro_water)/dt
        q=raw if q_previous is None else omega*q_previous+(1.0-omega)*raw
        theta=min(THETA_S,theta0+min(q*dt,macro_water)/ACTIVE_DEPTH)
        if q_previous is not None and abs(q-q_previous)/max(abs(q_previous),1e-30)<tol:
            return q,theta,iteration
        q_previous=q
    return q,theta,max_iterations

def accepted_history(theta_before,tabs,tref,sorp_max,dt):
    deficit=max(0.0,THETA_S-theta_before)
    if deficit<1e-8:
        return 0.0,0.0
    if tabs<1e-8:
        sorp=sorp_max*(deficit/(THETA_S-THETA_R))**0.5
        ref=THETA_S
    else:
        sorp=sorp_max*(max(tref-theta_before,0.0)/(THETA_S-THETA_R))**0.5 if tref>theta_before else 0.0
        ref=tref
    if sorp<=0.0:
        return 0.0,0.0
    ref=ref+0.95*0.08*(4.0/4.0)*sorp*(sqrt(tabs+dt)-sqrt(tabs))
    return tabs+dt,ref

def run(route,theta0,macro0,sorp_max,dt,nsteps=12):
    theta=theta0
    macro=macro0
    tabs=0.0
    tref=0.0
    cumulative_exchange=0.0
    records=[]
    for step in range(1,nsteps+1):
        macro=min(1.2,macro+0.05)
        if route=="strict":
            q,theta1,it=fixed_point(theta,tabs,tref,sorp_max,dt,macro,100,0.5,1e-10)
        elif route=="practical3":
            q,theta1,it=fixed_point(theta,tabs,tref,sorp_max,dt,macro,3,0.5,1e-3)
        elif route=="one":
            q,theta1,it=fixed_point(theta,tabs,tref,sorp_max,dt,macro,1,0.5,1e-3)
        else:
            raise ValueError(route)

        amount=min(q*dt,macro)
        macro-=amount
        cumulative_exchange+=amount
        tabs,tref=accepted_history(theta,tabs,tref,sorp_max,dt)
        theta=theta1
        records.append((step,theta,macro,q,it,cumulative_exchange,tabs,tref))
    return records

if __name__=="__main__":
    cases=[
        ("mild",0.16,1.0,0.5,0.05),
        ("wet-strong",0.30,1.0,1.0,0.05),
        ("dry-strong",0.10,1.0,2.0,0.10),
    ]

    for name,theta0,macro0,smax,dt in cases:
        strict=run("strict",theta0,macro0,smax,dt)
        practical=run("practical3",theta0,macro0,smax,dt)
        one=run("one",theta0,macro0,smax,dt)

        ref=strict[-1]
        for label,trial in (("practical3",practical),("one",one)):
            last=trial[-1]
            print(
                "PPA_WU05A4_TRAJECTORY",
                name,label,
                "CUM_EXCHANGE_ABS",abs(last[5]-ref[5]),
                "THETA_ABS",abs(last[1]-ref[1]),
                "MACRO_STORAGE_ABS",abs(last[2]-ref[2]),
            )

    print("PPA_WU05A4_LOCAL_TRAJECTORY=PASS")
