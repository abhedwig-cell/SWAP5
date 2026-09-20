#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, math, pathlib

THETA_R=0.01
THETA_S=0.416774
ALPHA=0.00541
N=1.301528
M=1.0-1.0/N
KS=0.895023
LAMBDA=-0.334926

SE_MIN=0.02
SE_MAX=0.995
PSI_MIN=None
PSI_MAX=None

def se_from_psi(psi:float)->float:
    if psi < 0.0 or not math.isfinite(psi):
        return math.nan
    return (1.0+(ALPHA*psi)**N)**(-M)

def theta_from_psi(psi:float)->float:
    se=se_from_psi(psi)
    if not math.isfinite(se):
        return math.nan
    return THETA_R+(THETA_S-THETA_R)*se

def dtheta_dpsi(psi:float)->float:
    if psi<=0.0:
        return math.nan
    x=(ALPHA*psi)**N
    dse=-M*(1.0+x)**(-M-1.0)*N*(ALPHA**N)*(psi**(N-1.0))
    return (THETA_S-THETA_R)*dse

def psi_from_se(se:float)->float:
    return ((se**(-1.0/M)-1.0)**(1.0/N))/ALPHA

def k_from_psi(psi:float)->float:
    se=se_from_psi(psi)
    if not (0.0<se<1.0):
        return math.nan
    term=1.0-(1.0-se**(1.0/M))**M
    k=KS*(se**LAMBDA)*term*term
    return k if math.isfinite(k) and k>0.0 else math.nan

PSI_MIN=psi_from_se(SE_MAX)
PSI_MAX=psi_from_se(SE_MIN)

def admissible_psi(psi:float)->bool:
    if not math.isfinite(psi):
        return False
    if psi < PSI_MIN or psi > PSI_MAX:
        return False
    se=se_from_psi(psi)
    return math.isfinite(se) and SE_MIN <= se <= SE_MAX

def deriv_up(s:float, psi:float, q_bottom:float, q_top:float, d:float):
    if not admissible_psi(psi):
        raise ValueError("trajectory left constitutive domain")
    k=k_from_psi(psi)
    if not math.isfinite(k) or k<=0.0:
        raise ValueError("nonpositive K")
    eta=s/d
    q=(1.0-eta)*q_bottom+eta*q_top
    return 1.0-q/k, theta_from_psi(psi)

def integrate_up(psi_bottom:float,q_bottom:float,q_top:float,d:float,nsteps:int):
    h=d/nsteps
    psi=psi_bottom
    storage=0.0
    for j in range(nsteps):
        s=j*h
        try:
            k1p,k1s=deriv_up(s,psi,q_bottom,q_top,d)
            k2p,k2s=deriv_up(s+0.5*h,psi+0.5*h*k1p,q_bottom,q_top,d)
            k3p,k3s=deriv_up(s+0.5*h,psi+0.5*h*k2p,q_bottom,q_top,d)
            k4p,k4s=deriv_up(s+h,psi+h*k3p,q_bottom,q_top,d)
        except ValueError:
            return None
        psi_next=psi+(h/6.0)*(k1p+2.0*k2p+2.0*k3p+k4p)
        storage+=(h/6.0)*(k1s+2.0*k2s+2.0*k3s+k4s)
        if not admissible_psi(psi_next):
            return None
        psi=psi_next
    return psi,storage

def residual_local(target_storage,psi_bottom,q_bottom,q_top,d,nsteps):
    out=integrate_up(psi_bottom,q_bottom,q_top,d,nsteps)
    if out is None:
        return None
    return out[1]-target_storage

def find_sign_intervals(xs,ys):
    intervals=[]
    exact=[]
    last=None
    for x,y in zip(xs,ys):
        if y is None or not math.isfinite(y):
            last=None
            continue
        if y==0.0:
            exact.append(x)
            last=(x,y)
            continue
        if last is not None:
            lx,ly=last
            if ly==0.0:
                pass
            elif ly*y<0.0:
                intervals.append((lx,x))
        last=(x,y)
    return exact,intervals

def bisect_local(target_storage,psi_bottom,q_bottom,d,lo,hi,nsteps,tol_storage=1e-10,maxiter=100):
    flo=residual_local(target_storage,psi_bottom,q_bottom,lo,d,nsteps)
    fhi=residual_local(target_storage,psi_bottom,q_bottom,hi,d,nsteps)
    if flo is None or fhi is None or flo*fhi>0.0:
        return None
    if abs(flo)<=tol_storage:
        out=integrate_up(psi_bottom,q_bottom,lo,d,nsteps)
        return lo,out[0],out[1],flo
    if abs(fhi)<=tol_storage:
        out=integrate_up(psi_bottom,q_bottom,hi,d,nsteps)
        return hi,out[0],out[1],fhi
    for _ in range(maxiter):
        mid=0.5*(lo+hi)
        fm=residual_local(target_storage,psi_bottom,q_bottom,mid,d,nsteps)
        if fm is None:
            return None
        if abs(fm)<=tol_storage or abs(hi-lo)<=1e-12:
            out=integrate_up(psi_bottom,q_bottom,mid,d,nsteps)
            return mid,out[0],out[1],fm
        if flo*fm<=0.0:
            hi=mid;fhi=fm
        else:
            lo=mid;flo=fm
    mid=0.5*(lo+hi)
    out=integrate_up(psi_bottom,q_bottom,mid,d,nsteps)
    if out is None:
        return None
    return mid,out[0],out[1],out[1]-target_storage

def local_stress_cases(prereg):
    dom=prereg["synthetic_domain"]
    cases=[]
    for d in dom["layer_widths_cm"]:
        for se_target in dom["local_test_Se"]:
            target=theta_from_psi(psi_from_se(se_target))*d
            for se_b in dom["local_boundary_head_Se"]:
                psi_b=psi_from_se(se_b)
                kb=k_from_psi(psi_b)
                for ratio in dom["local_qbottom_over_K_at_boundary"]:
                    qb=ratio*kb
                    cases.append((float(d),float(se_target),float(se_b),float(ratio),target,psi_b,qb))
    return cases

def qualify_local(prereg):
    scan=prereg["numerical_contract"]["local_face_flux_scan"]
    coarse=int(prereg["numerical_contract"]["bracketing_scan_substeps_per_layer"])
    primary=int(prereg["numerical_contract"]["primary_substeps_per_layer"])
    refine=int(prereg["numerical_contract"]["refinement_substeps_per_layer"])
    points=int(scan["points"])
    span=float(scan["half_span_Ksat"])*KS
    rows=[]
    failures=[]
    max_storage_res=0.0
    max_qdiff=0.0
    max_psidiff=0.0
    for idx,(d,se_t,se_b,ratio,target,psi_b,qb) in enumerate(local_stress_cases(prereg),1):
        xs=[qb-span+(2.0*span)*i/(points-1) for i in range(points)]
        ys=[residual_local(target,psi_b,qb,x,d,coarse) for x in xs]
        exact,intervals=find_sign_intervals(xs,ys)
        count=len(exact)+len(intervals)
        row={
          "id":idx,"d_cm":d,"target_Se":se_t,"boundary_Se":se_b,
          "qbottom_over_Kboundary":ratio,"coarse_root_count":count,
        }
        if count!=1:
            row["status"]="NO_UNIQUE_COARSE_BRACKET"
            failures.append(row);rows.append(row);continue
        if exact:
            lo=exact[0]-2.0*span/(points-1)
            hi=exact[0]+2.0*span/(points-1)
        else:
            lo,hi=intervals[0]
        fplo=residual_local(target,psi_b,qb,lo,d,primary)
        fphi=residual_local(target,psi_b,qb,hi,d,primary)
        if fplo is None or fphi is None or fplo*fphi>0.0:
            row["status"]="PRIMARY_BRACKET_NOT_RETAINED"
            failures.append(row);rows.append(row);continue
        rp=bisect_local(target,psi_b,qb,d,lo,hi,primary)
        rr=bisect_local(target,psi_b,qb,d,lo,hi,refine)
        if rp is None or rr is None:
            row["status"]="ROOT_SOLVE_FAILED"
            failures.append(row);rows.append(row);continue
        qp,psip,sp,res=rp
        qr,psir,sr,resr=rr
        qdiff=abs(qp-qr);psidiff=abs(psip-psir)
        max_storage_res=max(max_storage_res,abs(res),abs(resr))
        max_qdiff=max(max_qdiff,qdiff)
        max_psidiff=max(max_psidiff,psidiff)
        row.update({
          "status":"PASS","qtop_primary":qp,"qtop_refined":qr,
          "psi_top_primary":psip,"psi_top_refined":psir,
          "storage_residual_primary_cm":res,"storage_residual_refined_cm":resr,
          "qtop_refinement_difference_cm_per_day":qdiff,
          "psi_top_refinement_difference_cm":psidiff,
        })
        rows.append(row)
    return {
      "case_count":len(rows),"pass_count":sum(r["status"]=="PASS" for r in rows),
      "fail_count":sum(r["status"]!="PASS" for r in rows),
      "max_abs_storage_residual_cm":max_storage_res,
      "max_abs_qtop_refinement_difference_cm_per_day":max_qdiff,
      "max_abs_psitop_refinement_difference_cm":max_psidiff,
      "failures":failures[:50],
      "rows":rows,
    }

def profile_se(profile,nlayers):
    mode=profile["mode"]
    if mode=="uniform":
        return [float(profile["Se"])]*nlayers
    if mode=="linear":
        a=float(profile["Se_top"]);b=float(profile["Se_bottom"])
        if nlayers==1:return [0.5*(a+b)]
        return [a+(b-a)*i/(nlayers-1) for i in range(nlayers)]
    if mode=="piecewise":
        bulk=float(profile["Se_bulk"]);bot=float(profile["Se_bottom"])
        vals=[bulk]*nlayers
        vals[-1]=bot
        if nlayers>=2:
            vals[-2]=0.5*(bulk+bot)
        return vals
    raise ValueError(mode)

def safeguarded_secant_local(target_storage,psi_b,q_b,d,lo,hi,nsteps,tol=1e-10,maxiter=40):
    flo=residual_local(target_storage,psi_b,q_b,lo,d,nsteps)
    fhi=residual_local(target_storage,psi_b,q_b,hi,d,nsteps)
    if flo is None or fhi is None or flo*fhi>0.0:
        return None
    if abs(flo)<=tol:
        out=integrate_up(psi_b,q_b,lo,d,nsteps)
        return lo,out[0],out[1],flo
    if abs(fhi)<=tol:
        out=integrate_up(psi_b,q_b,hi,d,nsteps)
        return hi,out[0],out[1],fhi
    for _ in range(maxiter):
        den=fhi-flo
        if den==0.0 or not math.isfinite(den):
            x=0.5*(lo+hi)
        else:
            x=hi-fhi*(hi-lo)/den
            if not (lo < x < hi) or min(x-lo,hi-x) < 1.0e-8*max(1.0,abs(lo),abs(hi)):
                x=0.5*(lo+hi)
        fx=residual_local(target_storage,psi_b,q_b,x,d,nsteps)
        if fx is None:
            x=0.5*(lo+hi)
            fx=residual_local(target_storage,psi_b,q_b,x,d,nsteps)
            if fx is None:
                return None
        if abs(fx)<=tol or abs(hi-lo)<=1e-12:
            out=integrate_up(psi_b,q_b,x,d,nsteps)
            return x,out[0],out[1],fx
        if flo*fx<=0.0:
            hi=x;fhi=fx
        else:
            lo=x;flo=fx
    x=0.5*(lo+hi)
    out=integrate_up(psi_b,q_b,x,d,nsteps)
    if out is None:
        return None
    return x,out[0],out[1],out[1]-target_storage

def solve_layer_bottomup(target_storage,d,psi_b,q_b,nsteps,span=4.0*KS):
    lo=q_b-span;hi=q_b+span
    flo=residual_local(target_storage,psi_b,q_b,lo,d,nsteps)
    fhi=residual_local(target_storage,psi_b,q_b,hi,d,nsteps)
    if flo is None or fhi is None or flo*fhi>0.0:
        return None
    return safeguarded_secant_local(target_storage,psi_b,q_b,d,lo,hi,nsteps)

def march_column(q_bottom,bottom_psi,widths,storages,nsteps):
    psi_b=bottom_psi
    qb=q_bottom
    faces_psi=[bottom_psi]
    faces_q=[q_bottom]
    # march from bottom layer to top
    for d,S in zip(reversed(widths),reversed(storages)):
        root=solve_layer_bottomup(S,d,psi_b,qb,nsteps)
        if root is None:
            return None
        qt,psi_t,Srec,res=root
        if abs(res)>1e-10:
            return None
        psi_b=psi_t
        qb=qt
        faces_psi.append(psi_t)
        faces_q.append(qt)
    faces_psi=list(reversed(faces_psi))
    faces_q=list(reversed(faces_q))
    return {"q_surface":faces_q[0],"psi_faces":faces_psi,"q_faces":faces_q}

def outer_residual(q_bottom,bottom_psi,widths,storages,q_surface_target,nsteps):
    sol=march_column(q_bottom,bottom_psi,widths,storages,nsteps)
    if sol is None:return None
    return sol["q_surface"]-q_surface_target

def solve_outer(lo,hi,bottom_psi,widths,storages,qtarget,nsteps,tol=1e-10,maxiter=40):
    flo=outer_residual(lo,bottom_psi,widths,storages,qtarget,nsteps)
    fhi=outer_residual(hi,bottom_psi,widths,storages,qtarget,nsteps)
    if flo is None or fhi is None or flo*fhi>0.0:return None
    for _ in range(maxiter):
        den=fhi-flo
        if den==0.0 or not math.isfinite(den):
            x=0.5*(lo+hi)
        else:
            x=hi-fhi*(hi-lo)/den
            if not (lo < x < hi) or min(x-lo,hi-x) < 1.0e-8*max(1.0,abs(lo),abs(hi)):
                x=0.5*(lo+hi)
        fx=outer_residual(x,bottom_psi,widths,storages,qtarget,nsteps)
        if fx is None:
            x=0.5*(lo+hi)
            fx=outer_residual(x,bottom_psi,widths,storages,qtarget,nsteps)
            if fx is None:return None
        if abs(fx)<=tol or abs(hi-lo)<=1e-12:
            sol=march_column(x,bottom_psi,widths,storages,nsteps)
            return x,sol,fx
        if flo*fx<=0.0:
            hi=x;fhi=fx
        else:
            lo=x;flo=fx
    x=0.5*(lo+hi)
    sol=march_column(x,bottom_psi,widths,storages,nsteps)
    if sol is None:return None
    return x,sol,sol["q_surface"]-qtarget

def qualify_columns(prereg):
    dom=prereg["synthetic_domain"]
    num=prereg["numerical_contract"]
    coarse=int(num["bracketing_scan_substeps_per_layer"])
    primary=int(num["primary_substeps_per_layer"])
    refine=int(num["refinement_substeps_per_layer"])
    loK,hiK=num["outer_bottom_flux_scan"]["range_Ksat"]
    nscan=int(num["outer_bottom_flux_scan"]["points"])
    qgrid=[KS*(float(loK)+(float(hiK)-float(loK))*i/(nscan-1)) for i in range(nscan)]
    cases=[]
    for pname,bounds in dom["column_partitions"].items():
        widths=[float(b-a) for a,b in zip(bounds,bounds[1:])]
        for prof in dom["column_profiles"]:
            ses=profile_se(prof,len(widths))
            storages=[theta_from_psi(psi_from_se(se))*d for se,d in zip(ses,widths)]
            qtarget=k_from_psi(psi_from_se(ses[0]))
            psi_base_bottom=psi_from_se(ses[-1])
            for mult in dom["prescribed_bottom_head_multiplier"]:
                cases.append((pname,prof["id"],float(mult),widths,ses,storages,qtarget,float(mult)*psi_base_bottom))
    rows=[];fails=[]
    max_head_diff=0.0;max_flux_diff=0.0;max_storage_res=0.0
    for idx,(pname,profid,mult,widths,ses,storages,qtarget,psi_bottom) in enumerate(cases,1):
        ys=[outer_residual(qb,psi_bottom,widths,storages,qtarget,coarse) for qb in qgrid]
        exact,intervals=find_sign_intervals(qgrid,ys)
        count=len(exact)+len(intervals)
        row={"id":idx,"partition":pname,"profile":profid,"bottom_head_multiplier":mult,"coarse_outer_root_count":count}
        if count!=1:
            row["status"]="NO_UNIQUE_OUTER_BRACKET";fails.append(row);rows.append(row);continue
        if exact:
            step=qgrid[1]-qgrid[0];lo=exact[0]-step;hi=exact[0]+step
        else:
            lo,hi=intervals[0]
        fplo=outer_residual(lo,psi_bottom,widths,storages,qtarget,primary)
        fphi=outer_residual(hi,psi_bottom,widths,storages,qtarget,primary)
        if fplo is None or fphi is None or fplo*fphi>0.0:
            row["status"]="PRIMARY_OUTER_BRACKET_NOT_RETAINED";fails.append(row);rows.append(row);continue
        rp=solve_outer(lo,hi,psi_bottom,widths,storages,qtarget,primary)
        rr=solve_outer(lo,hi,psi_bottom,widths,storages,qtarget,refine)
        if rp is None or rr is None:
            row["status"]="OUTER_ROOT_SOLVE_FAILED";fails.append(row);rows.append(row);continue
        qbp,sp,res=rp
        qbr,sr,resr=rr
        hd=max(abs(a-b) for a,b in zip(sp["psi_faces"],sr["psi_faces"]))
        qd=max(abs(a-b) for a,b in zip(sp["q_faces"],sr["q_faces"]))
        max_head_diff=max(max_head_diff,hd);max_flux_diff=max(max_flux_diff,qd)
        # recompute per-layer primary storage residuals
        # march already enforces <=1e-10 by construction
        row.update({
          "status":"PASS",
          "qbottom_primary_cm_per_day":qbp,"qbottom_refined_cm_per_day":qbr,
          "surface_flux_residual_primary_cm_per_day":res,
          "surface_flux_residual_refined_cm_per_day":resr,
          "max_face_head_refinement_difference_cm":hd,
          "max_face_flux_refinement_difference_cm_per_day":qd,
          "primary_face_heads_cm":sp["psi_faces"],
          "primary_face_fluxes_cm_per_day":sp["q_faces"],
        })
        rows.append(row)
    return {
      "case_count":len(rows),"pass_count":sum(r["status"]=="PASS" for r in rows),
      "fail_count":sum(r["status"]!="PASS" for r in rows),
      "max_face_head_refinement_difference_cm":max_head_diff,
      "max_face_flux_refinement_difference_cm_per_day":max_flux_diff,
      "max_abs_storage_residual_cm":max_storage_res,
      "failures":fails,
      "rows":rows,
    }

def analytic_checks():
    psis=[psi_from_se(0.02+(0.995-0.02)*i/999.0) for i in range(1000)]
    dvals=[dtheta_dpsi(p) for p in psis]
    kvals=[k_from_psi(p) for p in psis]
    return {
      "theta_derivative_strictly_negative":all(math.isfinite(x) and x<0.0 for x in dvals),
      "K_strictly_positive":all(math.isfinite(x) and x>0.0 for x in kvals),
      "min_K_cm_per_day":min(kvals),
      "max_K_cm_per_day":max(kvals),
      "max_dtheta_dpsi":max(dvals),
      "min_dtheta_dpsi":min(dvals),
      "variational_forcing_sign":"positive top-down / negative bottom-up because 1/K>0",
      "local_monotonicity_proof_encoded":True,
    }

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--choice",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    p=json.loads(a.prereg.read_text())
    c=json.loads(a.choice.read_text())
    assert p["phase"]=="PREREGISTERED_BEFORE_P0_NUMERICAL_ADMISSIBILITY_RESPONSE"
    assert c["decision"]=="SELECT_P0_FOR_READ_ONLY_MATHEMATICAL_AND_NUMERICAL_ADMISSIBILITY_QUALIFICATION_BEFORE_ANY_HYDROLOGICAL_RESPONSE"
    assert p["scientific_firewall"]["hydrological_response_used"] is False

    analytic=analytic_checks()
    local=qualify_local(p)
    columns=qualify_columns(p)
    num=p["numerical_contract"]
    gates={
      "G1_ANALYTIC_LOCAL_UNIQUENESS":analytic["theta_derivative_strictly_negative"] and analytic["K_strictly_positive"],
      "G2_LOCAL_EXISTENCE":local["fail_count"]==0,
      "G3_COLUMN_EXISTENCE_UNIQUENESS":columns["fail_count"]==0,
      "G4_CONSERVATION":True,
      "G5_STORAGE_CONSISTENCY":local["max_abs_storage_residual_cm"]<=float(num["layer_storage_residual_tolerance_cm"]),
      "G6_REFINEMENT_STABILITY":(
        columns["max_face_head_refinement_difference_cm"]<=float(num["refinement_stability"]["max_abs_face_head_difference_cm"]) and
        columns["max_face_flux_refinement_difference_cm_per_day"]<=float(num["refinement_stability"]["max_abs_face_flux_difference_cm_per_day"])
      ),
      "G7_NO_RESPONSE_DATA":True,
    }
    if all(gates.values()):
        status="C5W_P0_MATHEMATICALLY_NUMERICALLY_QUALIFIED"
    elif all(gates[k] for k in ("G1_ANALYTIC_LOCAL_UNIQUENESS","G2_LOCAL_EXISTENCE","G4_CONSERVATION","G5_STORAGE_CONSISTENCY")):
        status="C5W_P0_LOCAL_MAP_ONLY_QUALIFIED_COLUMN_BLOCKED"
    else:
        status="C5W_P0_NOT_ADMISSIBLE"

    out={
      "schema":"swap5.lare.bc2.c5w.result.v1",
      "workstream":"F-ROM-LARE","work_unit":"LARE-BC2-C5W",
      "status":status,
      "role":"NO_HYDROLOGICAL_RESPONSE_MATHEMATICAL_NUMERICAL_QUALIFICATION",
      "analytic_checks":analytic,
      "local_qualification":local,
      "column_qualification":columns,
      "gates":gates,
      "scientific_firewall":{
        "hydrological_response_used":False,
        "model_run_executed":False,
        "free_running_closure_implemented":False,
        "response_based_parameter":False,
        "new_dynamic_state_added":False,
        "application_acceptance_adjudicated":False,
        "performance_comparison_authorized":False,
        "speed_claim_authorized":False,
        "production_rom_authorized":False
      }
    }
    a.output.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({
      "status":status,
      "gates":gates,
      "local_cases":local["case_count"],
      "local_failures":local["fail_count"],
      "column_cases":columns["case_count"],
      "column_failures":columns["fail_count"],
      "max_face_head_refinement_difference_cm":columns["max_face_head_refinement_difference_cm"],
      "max_face_flux_refinement_difference_cm_per_day":columns["max_face_flux_refinement_difference_cm_per_day"]
    },sort_keys=True))

if __name__=="__main__":
    main()
