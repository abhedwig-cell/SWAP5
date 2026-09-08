from __future__ import annotations

import json
import math
import random
import sys

from run_lmfp04_ab import SAND, CLAY
from run_lmfp06_darcian_reference import MATERIALS, solve_steady_flux
from run_lmfp06_lookup_surrogate import DarcianLookup, HEAD_AXIS


def geometric_axis(n, wet=-1.0, dry=-500.0):
    if n < 2 or not (wet < 0.0 and dry < wet):
        raise ValueError((n,wet,dry))
    a=math.log(-wet); b=math.log(-dry)
    return [-math.exp(a+(b-a)*i/(n-1)) for i in range(n)]


def relerr(a,b,floor=1.0e-8):
    return abs(a-b)/max(abs(b),floor)


def percentile(vals,p):
    v=sorted(vals)
    return v[min(len(v)-1,int(p*len(v)))]


def diagonal_flux(table, code, h):
    # Raw lookup, to measure interpolation drift on a known exact Darcian identity.
    qraw=table.flux(h,h)
    qexact=MATERIALS[code].conductivity(h)
    return qraw,qexact


def run():
    axes={
        "16_existing":list(HEAD_AXIS),
        "24_geometric":geometric_axis(24),
        "32_geometric":geometric_axis(32),
    }
    faces=[("sand_sand",1,1,5.0,5.0),("sand_clay",1,2,5.0,5.0)]
    rng=random.Random(4310707)
    validation=[]
    for _ in range(80):
        hu=-math.exp(rng.uniform(math.log(1.02),math.log(480.0)))
        hl=-math.exp(rng.uniform(math.log(1.02),math.log(480.0)))
        validation.append((hu,hl))
    diag_heads=[-math.exp(math.log(1.02)+(math.log(480.0)-math.log(1.02))*i/24.0) for i in range(25)]

    ev={"schema_version":1,"work_unit":"F-LMFP07",
        "experiment":"ORACLE_DERIVED_DARCIAN_LOOKUP_DENSITY",
        "legacy_swkmean7_reproduced":False,"results":{}}
    for aname,axis in axes.items():
        ae={"head_points":len(axis),"values_per_face_class":len(axis)**2,
            "bytes_per_face_class_before_metadata":len(axis)**2*8,"faces":{}}
        for fname,cu,cl,lu,ll in faces:
            table=DarcianLookup(cu,cl,lu,ll,axis=axis)
            errs=[]; sign=0; rows=[]
            for hu,hl in validation:
                qref,*_=solve_steady_flux(MATERIALS[cu],MATERIALS[cl],hu,hl,lu,ll)
                qtab=table.flux(hu,hl)
                er=relerr(qtab,qref)
                errs.append(er)
                if abs(qref)>1.0e-7 and qref*qtab<0:
                    sign+=1
                rows.append({"heads":[hu,hl],"q_ref":qref,"q_lookup":qtab,"rel_error":er})
            diag=[]
            if cu==cl:
                for h in diag_heads:
                    qraw,qexact=diagonal_flux(table,cu,h)
                    diag.append({"h":h,"q_lookup":qraw,"q_exact":qexact,
                                 "rel_error":relerr(qraw,qexact)})
            ae["faces"][fname]={
                "validation_cases":len(validation),"direction_mismatches":sign,
                "error":{"median":percentile(errs,0.5),"p90":percentile(errs,0.9),"maximum":max(errs)},
                "known_equal_head_identity_raw_lookup":{
                    "cases":len(diag),
                    "maximum_rel_error":max((x["rel_error"] for x in diag),default=0.0),
                    "analytic_override_would_be_exact":True,
                    "rows":diag,
                },
                "rows":rows,
            }
        ev["results"][aname]=ae

    # Feasibility gate only: denser tables must reduce the p90 oracle error for both tested face classes,
    # without direction errors. No production density is selected here.
    base=ev["results"]["16_existing"]["faces"]
    fine=ev["results"]["32_geometric"]["faces"]
    improvements={}
    passed=True
    for fname,_,_,_,_ in faces:
        b=base[fname]["error"]["p90"]
        f=fine[fname]["error"]["p90"]
        improvements[fname]={"p90_16":b,"p90_32":f,"ratio_16_over_32":b/max(f,1e-300)}
        passed=passed and f<b and fine[fname]["direction_mismatches"]==0
    ev["density_improvement"]=improvements
    ev["structural_pass"]=passed
    return ev


def main():
    ev=run()
    print(json.dumps(ev,indent=2,sort_keys=True))
    if len(sys.argv)==2:
        open(sys.argv[1],"w").write(json.dumps(ev,indent=2,sort_keys=True)+"\n")
    elif len(sys.argv)!=1:
        raise SystemExit("usage: run_lmfp07_lookup_density.py [OUTPUT_JSON]")
    raise SystemExit(0 if ev["structural_pass"] else 1)


if __name__=="__main__":
    main()
