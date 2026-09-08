from __future__ import annotations

import bisect
import json
import math
import random
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from run_lmfp03_column import homogeneous_face_flux, heterogeneous_face_flux
from run_lmfp04_ab import DZ, SAND, CLAY, TABLES, case_definition, parse_reference
from run_lmfp06_darcian_reference import MATERIALS, solve_steady_flux
from run_lmfp07_transient_abc import STRESS, integrate_candidate

MATERIAL_BY_CODE = {1: SAND, 2: CLAY}

# F-LMFP08 deliberately uses coordinates aligned with the two known homogeneous
# Darcy identities. x=log10(-h_upper) keeps the unsaturated head dimension smooth;
# g=(h_lower-h_upper)/L makes equal-head g=0 and hydrostatic g=1 exact columns.
X_AXIS = [i * math.log10(350.0) / 15.0 for i in range(16)]
G_AXIS = [
    -28.0, -24.0, -20.0, -16.0, -12.0, -8.0, -5.0, -3.0,
    -2.0, -1.0, -0.5, 0.0, 0.25, 0.5, 0.75, 1.0,
    1.25, 1.5, 2.0, 3.0, 5.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0,
]


def rms(values):
    return math.sqrt(sum(v*v for v in values) / len(values))


def percentile(vals, p):
    vals = sorted(vals)
    if not vals:
        return math.nan
    return vals[min(len(vals)-1, int(p*len(vals)))]


def relerr(a, b, floor=1.0e-8):
    return abs(a-b) / max(abs(b), floor)


def mfp_homogeneous(code, h_u, h_l, length):
    return homogeneous_face_flux(TABLES[code], h_u, h_l, length)


def direct_homogeneous(code, h_u, h_l, length):
    return solve_steady_flux(MATERIALS[code], MATERIALS[code], h_u, h_l,
                             0.5*length, 0.5*length)[0]


def correction_coefficient(code, h_u, g, length):
    """Return C in q_D - q_M = g*(g-1)*C.

    At the two exact zero-residual manifolds the removable limit is estimated
    offline by a symmetric probe. Runtime never performs this operation.
    """
    def raw(gg):
        h_l = h_u + gg*length
        qd = direct_homogeneous(code, h_u, h_l, length)
        qm = mfp_homogeneous(code, h_u, h_l, length)
        denom = gg*(gg-1.0)
        if abs(denom) < 1.0e-14:
            raise ZeroDivisionError(gg)
        return (qd-qm)/denom

    if abs(g) < 1.0e-14 or abs(g-1.0) < 1.0e-14:
        eps = 2.0e-3
        return 0.5*(raw(g-eps) + raw(g+eps))
    return raw(g)


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis)-2, len(axis)-1
    i = bisect.bisect_right(axis, x)-1
    return max(0, i), min(len(axis)-1, i+1)


class FactoredCorrectionTable:
    """Immutable homogeneous Darcian correction table for one material/geometry class.

    The table stores C(x,g), not absolute K_DAR. Runtime flux is
      q = q_MFP + g*(g-1)*C_interp.
    This preserves q=K(h) at g=0 and q=0 at g=1 exactly by construction.
    """

    def __init__(self, code, length, x_axis=X_AXIS, g_axis=G_AXIS):
        self.code = int(code)
        self.length = float(length)
        self.x_axis = list(x_axis)
        self.g_axis = list(g_axis)
        self.values = []
        for x in self.x_axis:
            h_u = -10.0**x
            row = []
            for g in self.g_axis:
                row.append(correction_coefficient(self.code, h_u, g, self.length))
            self.values.append(row)

    def coefficient(self, h_u, g):
        if h_u >= 0.0:
            raise ValueError(("upper_head_not_unsaturated", h_u))
        x = math.log10(-h_u)
        i0, i1 = bracket(self.x_axis, x)
        j0, j1 = bracket(self.g_axis, g)
        x0, x1 = self.x_axis[i0], self.x_axis[i1]
        g0, g1 = self.g_axis[j0], self.g_axis[j1]
        tx = 0.0 if x1 == x0 else (x-x0)/(x1-x0)
        tg = 0.0 if g1 == g0 else (g-g0)/(g1-g0)
        c00 = self.values[i0][j0]
        c10 = self.values[i1][j0]
        c11 = self.values[i1][j1]
        c01 = self.values[i0][j1]
        return ((1-tx)*(1-tg)*c00 + tx*(1-tg)*c10 +
                tx*tg*c11 + (1-tx)*tg*c01)

    def flux(self, h_u, h_l):
        g = (h_l-h_u)/self.length
        qm = mfp_homogeneous(self.code, h_u, h_l, self.length)
        c = self.coefficient(h_u, g)
        return qm + g*(g-1.0)*c


class CorrectionCache:
    def __init__(self):
        self.tables = {}
        self.build_count = 0
        self.transient_calls = 0
        self.coverage_misses = 0

    def table(self, code, length):
        key = (int(code), round(float(length), 12))
        if key not in self.tables:
            self.tables[key] = FactoredCorrectionTable(code, length)
            self.build_count += 1
        return self.tables[key]

    def flux(self, code, h_u, h_l, length):
        self.transient_calls += 1
        try:
            return self.table(code, length).flux(h_u, h_l)
        except ValueError as exc:
            self.coverage_misses += 1
            raise RuntimeError("factored_correction_coverage:"+str(exc)) from exc

    def diagnostics(self):
        nvals = len(X_AXIS)*len(G_AXIS)
        return {
            "table_builds": self.build_count,
            "values_per_table": nvals,
            "table_values_total": self.build_count*nvals,
            "bytes_double_values_before_metadata": self.build_count*nvals*8,
            "transient_face_calls": self.transient_calls,
            "coverage_misses": self.coverage_misses,
            "upper_head_envelope_cm": [-10.0**X_AXIS[-1], -10.0**X_AXIS[0]],
            "gradient_envelope": [G_AXIS[0], G_AXIS[-1]],
            "coordinates": "x=log10(-h_upper), g=(h_lower-h_upper)/L",
        }


def corrected_trial(base_storage, codes, thickness, step_duration, top_flux, cache):
    n = len(base_storage)
    mats = [MATERIAL_BY_CODE[c] for c in codes]
    heads = []
    for w,m,dz in zip(base_storage,mats,thickness):
        theta = w/dz
        if theta < m.theta_r-1.0e-10 or theta > m.theta_s+1.0e-10:
            return {"accepted":False,"reason":"base_state_out_of_bounds","state":list(base_storage)}
        te = min(m.theta_s,max(m.theta_r+1.0e-12,theta))
        heads.append(m.head_from_theta(te))

    face = [0.0]*(n+1)
    face[0] = top_flux
    max_interface_iterations = 0
    for i in range(n-1):
        lu = 0.5*thickness[i]
        ll = 0.5*thickness[i+1]
        if codes[i] == codes[i+1]:
            try:
                face[i+1] = cache.flux(codes[i], heads[i], heads[i+1], lu+ll)
            except RuntimeError as exc:
                return {"accepted":False,"reason":str(exc),"state":list(base_storage),"heads":heads}
        else:
            q,_,it,_ = heterogeneous_face_flux(TABLES[codes[i]],TABLES[codes[i+1]],
                                                heads[i],heads[i+1],lu,ll)
            face[i+1] = q
            max_interface_iterations = max(max_interface_iterations,it)

    face[-1] = mats[-1].conductivity(heads[-1])
    rate = [face[i]-face[i+1] for i in range(n)]
    cand = [base_storage[i]+step_duration*rate[i] for i in range(n)]
    expected = step_duration*(face[0]-face[-1])
    actual = sum(cand)-sum(base_storage)
    mass = actual-expected

    admissible = math.inf
    violated=[]
    for i,(m,dz,r) in enumerate(zip(mats,thickness,rate)):
        lo=(m.theta_r+1.0e-10)*dz
        hi=(m.theta_s-1.0e-10)*dz
        if r>0.0:
            admissible=min(admissible,max(0.0,(hi-base_storage[i])/r))
        elif r<0.0:
            admissible=min(admissible,max(0.0,(base_storage[i]-lo)/(-r)))
        if cand[i] < lo-1.0e-12 or cand[i] > hi+1.0e-12:
            violated.append(i)
    advised=0.95*admissible if math.isfinite(admissible) else None
    if violated:
        return {"accepted":False,"reason":"storage_bounds:"+str(violated),
                "state":list(base_storage),"heads":heads,"face":face,
                "mass_residual":mass,"advised_step_duration":advised,
                "max_interface_iterations":max_interface_iterations}
    return {"accepted":True,"reason":"accepted","state":cand,"heads":heads,
            "face":face,"rate":rate,"mass_residual":mass,
            "advised_step_duration":advised,"max_interface_iterations":max_interface_iterations}


def integrate_corrected(codes,heads0,thickness,duration,dt,top_flux,cache):
    mats=[MATERIAL_BY_CODE[c] for c in codes]
    state=[m.theta(h)*dz for m,h,dz in zip(mats,heads0,thickness)]
    initial=sum(state)
    nsteps=round(duration/dt)
    if abs(nsteps*dt-duration) > 1.0e-10*max(1.0,duration):
        raise ValueError((duration,dt,nsteps))
    max_mass=0.0
    max_interface_iterations=0
    retries=0
    final=None
    for _ in range(nsteps):
        tr=corrected_trial(state,codes,thickness,dt,top_flux,cache)
        if not tr["accepted"]:
            retries += 1
            return {"accepted":False,"reason":tr["reason"],"retries":retries,
                    "dt":dt,"nsteps":nsteps,"initial_storage":initial}
        state=tr["state"]
        final=tr
        max_mass=max(max_mass,abs(tr["mass_residual"]))
        max_interface_iterations=max(max_interface_iterations,tr["max_interface_iterations"])
    theta=[w/dz for w,dz in zip(state,thickness)]
    heads=[m.head_from_theta(t) for m,t in zip(mats,theta)]
    return {"accepted":True,"closure":"mfp_plus_factored_darcian_correction",
            "dt":dt,"nsteps":nsteps,"initial_storage":initial,"final_storage":sum(state),
            "bottom_down":final["face"][-1] if final else mats[-1].conductivity(heads0[-1]),
            "mass_max":max_mass,"max_interface_iterations":max_interface_iterations,
            "retries":retries,"theta":theta,"h":heads}


def trajectory_metrics(a,b):
    return {
        "theta_max_abs":max(abs(x-y) for x,y in zip(a["theta"],b["theta"])),
        "theta_rmse":rms([x-y for x,y in zip(a["theta"],b["theta"])]),
        "head_max_abs_cm":max(abs(x-y) for x,y in zip(a["h"],b["h"])),
        "storage_abs_cm":abs(a["final_storage"]-b["final_storage"]),
        "bottom_flux_abs_cm_d":abs(a["bottom_down"]-b["bottom_down"]),
    }


def fullrichards_metrics(ref,cand):
    rtheta=[ref["nodes"][i]["theta"] for i in range(1,len(cand["theta"])+1)]
    rh=[ref["nodes"][i]["h"] for i in range(1,len(cand["h"])+1)]
    return {
        "theta_max_abs":max(abs(a-b) for a,b in zip(cand["theta"],rtheta)),
        "theta_rmse":rms([a-b for a,b in zip(cand["theta"],rtheta)]),
        "head_max_abs_cm":max(abs(a-b) for a,b in zip(cand["h"],rh)),
        "storage_abs_cm":abs(cand["final_storage"]-ref["summary"]["final_storage"]),
        "bottom_flux_abs_cm_d":abs(cand["bottom_down"]-ref["summary"]["bottom_down"]),
    }


def identity_tests():
    cache=CorrectionCache()
    rows=[]
    max_equal=0.0
    max_hydro=0.0
    for code in (1,2):
        for length in (10.0,15.0,20.0):
            tab=cache.table(code,length)
            for h in (-300.0,-100.0,-20.0,-2.0):
                q=tab.flux(h,h)
                exp=MATERIAL_BY_CODE[code].conductivity(h)
                max_equal=max(max_equal,abs(q-exp))
                rows.append({"code":code,"length":length,"kind":"equal_head","h":h,
                             "q":q,"expected":exp,"abs_error":abs(q-exp)})
                q0=tab.flux(h,h+length)
                max_hydro=max(max_hydro,abs(q0))
                rows.append({"code":code,"length":length,"kind":"hydrostatic","h_upper":h,
                             "h_lower":h+length,"q":q0,"expected":0.0,"abs_error":abs(q0)})
    return {
        "pass":max_equal<2.0e-11 and max_hydro<2.0e-11,
        "max_equal_head_abs_error":max_equal,
        "max_hydrostatic_abs_flux":max_hydro,
        "rows":rows,
        "cache":cache.diagnostics(),
    }


def face_validation():
    cache=CorrectionCache()
    rng=random.Random(4310801)
    rows=[]
    sign_mismatch=0
    failures=0
    for code in (1,2):
        for length in (10.0,12.0,15.0,20.0):
            for _ in range(24):
                h_u=-10.0**rng.uniform(math.log10(1.2),math.log10(320.0))
                # Mix ordinary gradients with deliberately strong tails.
                if rng.random()<0.45:
                    g=rng.uniform(-5.0,8.0)
                else:
                    g=rng.uniform(-27.0,27.0)
                h_l=h_u+g*length
                try:
                    qd=direct_homogeneous(code,h_u,h_l,length)
                    qm=mfp_homogeneous(code,h_u,h_l,length)
                    qc=cache.flux(code,h_u,h_l,length)
                except Exception as exc:
                    failures+=1
                    rows.append({"failed":True,"code":code,"length":length,"heads":[h_u,h_l],
                                 "g":g,"error":type(exc).__name__+":"+str(exc)})
                    continue
                if abs(qd)>1.0e-7 and qc*qd<0.0:
                    sign_mismatch+=1
                rows.append({"failed":False,"code":code,"length":length,"heads":[h_u,h_l],"g":g,
                             "q_direct":qd,"q_mfp":qm,"q_corrected":qc,
                             "mfp_rel_error":relerr(qm,qd),"corrected_rel_error":relerr(qc,qd)})
    valid=[r for r in rows if not r["failed"] and abs(r["q_direct"])>1.0e-7]
    m=[r["mfp_rel_error"] for r in valid]
    c=[r["corrected_rel_error"] for r in valid]
    strong=[r for r in valid if abs(r["g"])>=8.0]
    ms=[r["mfp_rel_error"] for r in strong]
    cs=[r["corrected_rel_error"] for r in strong]
    return {
        "pass":failures==0 and sign_mismatch==0 and percentile(cs,0.9)<percentile(ms,0.9),
        "cases":len(rows),"failures":failures,"sign_mismatches":sign_mismatch,
        "mfp":{"median":percentile(m,0.5),"p90":percentile(m,0.9),"maximum":max(m)},
        "corrected":{"median":percentile(c,0.5),"p90":percentile(c,0.9),"maximum":max(c)},
        "strong_gradient":{
            "cases":len(strong),
            "mfp":{"median":percentile(ms,0.5),"p90":percentile(ms,0.9),"maximum":max(ms)},
            "corrected":{"median":percentile(cs,0.5),"p90":percentile(cs,0.9),"maximum":max(cs)},
        },
        "fraction_corrected_better":sum(r["corrected_rel_error"]<r["mfp_rel_error"] for r in valid)/len(valid),
        "cache":cache.diagnostics(),"rows":rows,
    }


def response_diagnostics():
    cache=CorrectionCache()
    rows=[]
    max_jump=0.0
    max_slope_ratio=0.0
    for code in (1,2):
        for length in (10.0,20.0):
            tab=cache.table(code,length)
            for h_u in (-200.0,-80.0,-20.0):
                for g0 in (0.0,1.0):
                    eps=2.0e-5
                    def qg(g):
                        return tab.flux(h_u,h_u+g*length)
                    qm=qg(g0)
                    ql=qg(g0-eps)
                    qr=qg(g0+eps)
                    sl=(qm-ql)/eps
                    sr=(qr-qm)/eps
                    jump=abs(qr-ql)
                    ratio=abs(sl-sr)/max(1.0e-10,abs(sl),abs(sr))
                    max_jump=max(max_jump,jump)
                    max_slope_ratio=max(max_slope_ratio,ratio)
                    rows.append({"code":code,"length":length,"h_upper":h_u,"g":g0,
                                 "q_left":ql,"q_center":qm,"q_right":qr,
                                 "left_slope_per_g":sl,"right_slope_per_g":sr,
                                 "relative_slope_mismatch":ratio})
    # Continuity is required. Derivative mismatch is diagnostic because bilinear C
    # interpolation is only piecewise differentiable and response-tangent admission
    # is not part of F-LMFP08.
    finite=all(math.isfinite(v) for r in rows for v in
               (r["q_left"],r["q_center"],r["q_right"],r["left_slope_per_g"],r["right_slope_per_g"]))
    return {"pass":finite and max_jump<1.0,
            "finite":finite,"max_two_sided_flux_span_for_eps":max_jump,
            "max_relative_slope_mismatch":max_slope_ratio,
            "response_tangent_admitted":False,"rows":rows,
            "cache":cache.diagnostics()}


def transient_matrix(reference_path):
    ref=parse_reference(reference_path)
    cache=CorrectionCache()
    cases={}
    all_accept=[]
    all_mass=[]
    ordinary_better_direct=0
    ordinary_compared=0
    for cid in range(1,7):
        name,codes,heads0,duration,base_dt,top=case_definition(cid)
        row={"refinements":{}}
        for refinement in (1,2):
            dt=base_dt/refinement
            mfp=integrate_candidate(codes,heads0,DZ,duration,dt,top,"mfp")
            corrected=integrate_corrected(codes,heads0,DZ,duration,dt,top,cache)
            item={"fullrichards":ref[(cid,refinement)],"mfp":mfp,"corrected":corrected}
            if mfp["accepted"] and corrected["accepted"]:
                item["mfp_vs_fullrichards"]=fullrichards_metrics(ref[(cid,refinement)],mfp)
                item["corrected_vs_fullrichards"]=fullrichards_metrics(ref[(cid,refinement)],corrected)
            row["refinements"][str(refinement)]=item
            for cand in (mfp,corrected):
                all_accept.append(cand["accepted"])
                if cand["accepted"]:
                    all_mass.append(cand["mass_max"])
        # Direct Darcian face control only at the finer trajectory.
        direct=integrate_candidate(codes,heads0,DZ,duration,base_dt/2.0,top,"oracle")
        fine=row["refinements"]["2"]
        fine["direct_darcian"]=direct
        if direct["accepted"] and fine["mfp"]["accepted"] and fine["corrected"]["accepted"]:
            md=trajectory_metrics(fine["mfp"],direct)
            cd=trajectory_metrics(fine["corrected"],direct)
            fine["mfp_vs_direct_darcian"]=md
            fine["corrected_vs_direct_darcian"]=cd
            ordinary_compared+=1
            if cd["theta_max_abs"]<md["theta_max_abs"]:
                ordinary_better_direct+=1
        cases[name]=row

    stress={}
    stress_better=0
    stress_compared=0
    for name,codes,heads0,dz in STRESS:
        duration=1.0e-4
        base_dt=1.0e-5
        row={"refinements":{}}
        for refinement in (1,2):
            dt=base_dt/refinement
            direct=integrate_candidate(codes,heads0,dz,duration,dt,0.0,"oracle")
            mfp=integrate_candidate(codes,heads0,dz,duration,dt,0.0,"mfp")
            corrected=integrate_corrected(codes,heads0,dz,duration,dt,0.0,cache)
            item={"direct_darcian":direct,"mfp":mfp,"corrected":corrected}
            if direct["accepted"] and mfp["accepted"] and corrected["accepted"]:
                item["mfp_vs_direct_darcian"]=trajectory_metrics(mfp,direct)
                item["corrected_vs_direct_darcian"]=trajectory_metrics(corrected,direct)
            row["refinements"][str(refinement)]=item
            for cand in (direct,mfp,corrected):
                all_accept.append(cand["accepted"])
                if cand["accepted"]:
                    all_mass.append(cand["mass_max"])
        fine=row["refinements"]["2"]
        if fine.get("mfp_vs_direct_darcian") and fine.get("corrected_vs_direct_darcian"):
            stress_compared+=1
            if fine["corrected_vs_direct_darcian"]["theta_max_abs"] < fine["mfp_vs_direct_darcian"]["theta_max_abs"]:
                stress_better+=1
        stress[name]=row

    return {
        "pass":all(all_accept) and max(all_mass,default=0.0)<2.0e-10 and
               cache.coverage_misses==0 and stress_better==stress_compared and stress_compared==len(STRESS),
        "cases":cases,"stress_cases":stress,
        "all_steps_accepted":all(all_accept),
        "maximum_mass_residual":max(all_mass,default=0.0),
        "ordinary_corrected_closer_to_direct_darcian":{"count":ordinary_better_direct,"compared":ordinary_compared},
        "stress_corrected_closer_to_direct_darcian":{"count":stress_better,"compared":stress_compared},
        "cache":cache.diagnostics(),
    }


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_lmfp08_physics_informed_correction.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    identities=identity_tests()
    face=face_validation()
    response=response_diagnostics()
    transient=transient_matrix(Path(sys.argv[1]))
    structural=identities["pass"] and face["pass"] and response["pass"] and transient["pass"]
    evidence={
        "schema_version":1,"work_unit":"F-LMFP08",
        "candidate":"MFP_PLUS_FACTORED_DARCIAN_RESIDUAL_ON_HOMOGENEOUS_FACES",
        "heterogeneous_faces":"current MFP equal-flux interface retained unchanged",
        "representation":{
            "formula":"q=q_MFP + g*(g-1)*C(log10(-h_upper),g)",
            "g":"(h_lower-h_upper)/face_distance",
            "x_axis_points":len(X_AXIS),"g_axis_points":len(G_AXIS),
            "values_per_material_geometry_class":len(X_AXIS)*len(G_AXIS),
            "bytes_per_class_before_metadata":len(X_AXIS)*len(G_AXIS)*8,
            "equal_head_identity_preserved_by_construction":True,
            "hydrostatic_identity_preserved_by_construction":True,
        },
        "tests":{
            "exact_identities":identities,
            "face_oracle_validation":face,
            "response_diagnostics":response,
            "transient_matrix":transient,
        },
        "structural_pass":structural,
        "interpretation":{
            "production_admission":"none",
            "response_tangent_admission":"none; finite-difference slope diagnostics only",
            "solver_policy":"candidate face law is explicit LayeredMFP model configuration, never an execution-policy fallback",
            "lookup_ownership":"immutable shared hydraulic parameter data by compatible material/geometry class",
        }
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural else 1)


if __name__=="__main__":
    main()
