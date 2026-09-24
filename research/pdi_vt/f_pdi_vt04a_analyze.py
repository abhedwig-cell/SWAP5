#!/usr/bin/env python3
from __future__ import annotations
import json, math, sys
from pathlib import Path

def vals(path: Path):
    out=[]
    for line in path.read_text(errors="strict").splitlines():
        if line.startswith("*"): continue
        for tok in line.split():
            try: out.append(float(tok))
            except ValueError: pass
    return out

def take(a,i,n):
    return a[i:i+n], i+n

def parse(path: Path):
    a=vals(path); i=0
    swop=int(a[i]); i+=1
    period_header=a[i:i+4]; i+=4
    numnod=int(a[i]); numlay=int(a[i+1]); nrlevs=int(a[i+2]); i+=3
    botcom,i=take(a,i,numlay)
    thetas,i=take(a,i,numlay)
    k100,i=take(a,i,numlay)
    k15849,i=take(a,i,numlay)
    dz_m,i=take(a,i,numnod)
    if swop==2:
        _,i=take(a,i,3*numnod)
    theta0,i=take(a,i,numnod)
    gwl0_pond0,i=take(a,i,2)
    ssnow0=a[i]; i+=1
    tsoil0,i=take(a,i,numnod)
    if swop==2: _,i=take(a,i,5)
    recs=[]
    block=18+3*numnod+(numnod+1)+nrlevs*numnod+4+1+numnod
    while i < len(a):
        if len(a)-i < block:
            raise ValueError(f"trailing token count {len(a)-i}, expected record {block}")
        scal,i=take(a,i,18)
        h,i=take(a,i,numnod)
        theta,i=take(a,i,numnod)
        rootflux,i=take(a,i,numnod)
        q,i=take(a,i,numnod+1)
        drains=[]
        for _ in range(nrlevs):
            d,i=take(a,i,numnod); drains.append(d)
        canopy,i=take(a,i,4)
        tav=a[i]; i+=1
        tsoil,i=take(a,i,numnod)
        recs.append(dict(
          time=scal[0], outper=scal[1], rain=scal[2], snow=scal[3], irrigation=scal[4],
          interception=scal[5], net_irrigation=scal[6], sublimation=scal[7],
          potential_evap_component=scal[8], reserved_zero=scal[9],
          soil_evaporation=scal[10], transpiration=scal[11], runon=scal[12],
          runoff=scal[13], gwl_m=scal[14], pond_m=scal[15], snow_storage_m=scal[16],
          water_balance=scal[17], h_cm=h, theta=theta, rootflux_m_d=rootflux,
          vertical_flux_m_d=q, canopy=canopy, tav_C=tav, tsoil_C=tsoil))
    return dict(swop=swop,numnod=numnod,numlay=numlay,nrlevs=nrlevs,period_header=period_header,
                dz_m=dz_m,theta0=theta0,gwl0_pond0=gwl0_pond0,ssnow0=ssnow0,tsoil0=tsoil0,records=recs)

def finite(x): return math.isfinite(x)

def arr_stats(c,k,key):
    x=c[key]; y=k[key]
    pairs=[(a,b) for a,b in zip(x,y) if finite(a) and finite(b)]
    dif=[abs(a-b) for a,b in pairs]
    return {
      "control_nonfinite":sum(not finite(v) for v in x),
      "candidate_nonfinite":sum(not finite(v) for v in y),
      "finite_pair_count":len(pairs),
      "max_abs_difference":max(dif) if dif else None
    }

def storage_m(theta,dz): return sum(t*z for t,z in zip(theta,dz) if finite(t) and finite(z))

def main():
    cv=parse(Path(sys.argv[1])); kv=parse(Path(sys.argv[2]))
    cn=parse(Path(sys.argv[3])); kn=parse(Path(sys.argv[4]))
    assert len(cv["records"])==len(kv["records"])
    result={"schema_version":1,"records":len(cv["records"]),"numnod":cv["numnod"],"vapor_on":[]}
    for rc,rk in zip(cv["records"],kv["records"]):
        qstats=arr_stats(rc,rk,"vertical_flux_m_d")
        result["vapor_on"].append({
          "time":rc["time"],
          "pressure_head_cm":arr_stats(rc,rk,"h_cm"),
          "water_content":arr_stats(rc,rk,"theta"),
          "root_flux":arr_stats(rc,rk,"rootflux_m_d"),
          "vertical_flux":qstats,
          "top_flux_m_d":{"control":rc["vertical_flux_m_d"][0],"candidate":rk["vertical_flux_m_d"][0]},
          "bottom_flux_m_d":{"control":rc["vertical_flux_m_d"][-1],"candidate":rk["vertical_flux_m_d"][-1]},
          "soil_evaporation_m_d":{"control":rc["soil_evaporation"],"candidate":rk["soil_evaporation"]},
          "storage_m":{"control":storage_m(rc["theta"],cv["dz_m"]),"candidate":storage_m(rk["theta"],kv["dz_m"])},
          "water_balance":{"control":rc["water_balance"],"candidate":rk["water_balance"]},
          "temperature_C":{"air_control":rc["tav_C"],"air_candidate":rk["tav_C"],
                           "soil_control_nonfinite":sum(not finite(v) for v in rc["tsoil_C"]),
                           "soil_candidate_nonfinite":sum(not finite(v) for v in rk["tsoil_C"])}
        })
    # exact numeric NoVap identity after metadata timestamp normalization was already established by byte comparator;
    # reinforce semantic equality here.
    result["novap_semantic_identical"] = cn == kn
    result["candidate_all_hydraulic_arrays_finite"] = all(
      all(finite(v) for key in ("h_cm","theta","rootflux_m_d","vertical_flux_m_d") for v in r[key])
      and finite(r["soil_evaporation"]) and finite(r["water_balance"]) for r in kv["records"])
    result["control_has_nonfinite_hydraulic_values"] = any(
      any(not finite(v) for key in ("h_cm","theta","rootflux_m_d","vertical_flux_m_d") for v in r[key])
      for r in cv["records"])
    print(json.dumps(result,indent=2,sort_keys=True,allow_nan=True))

if __name__=="__main__": main()
