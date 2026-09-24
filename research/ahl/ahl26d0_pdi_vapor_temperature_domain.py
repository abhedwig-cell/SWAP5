#!/usr/bin/env python3
import json,math
MgR=0.018015*9.81/8.314
theta=0.10;theta_s=0.45;h=-100000.0
out=[]
for T in (-5.0,5.0,20.0,35.0):
    rec={"temperature_C":T}
    try:
        MgRT=MgR/(T+273.15)
        Da=2.14e-5*((T+273.15)/273.15)**2
        rho=1e-3*math.exp(31.3716-6014.79/T-7.92495e-3*T)/T
        f=rho/1000.0*MgRT
        ksi=(theta_s-theta)**(7/3)/theta_s**2
        D=ksi*(theta_s-theta)*Da
        Hr=math.exp(h/100*MgRT)
        kv=f*D*Hr
        rec.update({"MgRT":MgRT,"Da":Da,"Rho_sv":rho,"Hr":Hr,"Kvap_m_per_s":kv,
                    "finite":all(math.isfinite(x) for x in (MgRT,Da,rho,Hr,kv)),
                    "positive":rho>0 and kv>=0})
    except Exception as e:
        rec.update({"finite":False,"positive":False,"error":type(e).__name__+":"+str(e)})
    out.append(rec)
status="PASS_SOURCE_DOMAIN" if all(r["finite"] and r["positive"] for r in out) else "SOURCE_DOMAIN_FAILURE"
print(json.dumps({"work_unit":"F-AHL26D0","status":status,"cases":out},indent=2))
