from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp08_physics_informed_correction as core
from run_lmfp08_logk_candidate import oracle_kdar

X_AXIS = list(core.X_AXIS)
G_AXIS = list(core.G_AXIS)
_SHARED_TABLES = {}


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis)-2, len(axis)-1
    i = bisect.bisect_right(axis, x)-1
    return max(0, i), min(len(axis)-1, i+1)


def mfp_table_limit_k(tab, h):
    """d Phi_table / dh for the exact interpolation used by MFPTable.value.

    This is the limiting secant conductance of the current immutable MFP table.
    It is deliberately distinct from the constitutive K(h). The candidate below
    reconciles them on the known g=0 physics manifold instead of jumping between
    the two definitions at exactly equal heads.
    """
    if h >= 0.0:
        return tab.mat.conductivity(0.0)
    if h <= tab.heads[0]:
        return tab.mat.conductivity(tab.heads[0])
    if h > tab.heads[-1]:
        return (tab.phi0-tab.phi[-1])/(0.0-tab.heads[-1])
    i = bisect.bisect_right(tab.heads, h)-1
    i = max(0, min(i, len(tab.heads)-2))
    slope_pf = (tab.phi[i+1]-tab.phi[i])/(tab.pfs[i+1]-tab.pfs[i])
    dpf_dh = 1.0/(h*math.log(10.0))
    k = slope_pf*dpf_dh
    if not math.isfinite(k) or k <= 0.0:
        raise RuntimeError(("nonpositive MFP table limit K", h, i, k))
    return k


def continuous_mfp_ksec(code, h_u, h_l):
    tab = core.TABLES[code]
    scale=max(1.0,abs(h_u),abs(h_l))
    if abs(h_u-h_l) <= 1.0e-14*scale:
        return mfp_table_limit_k(tab,0.5*(h_u+h_l))
    k=(tab.value(h_u)-tab.value(h_l))/(h_u-h_l)
    if not math.isfinite(k) or k <= 0.0:
        raise RuntimeError(("nonpositive continuous MFP secant",code,h_u,h_l,k))
    return k


def continuous_mfp_flux(code,h_u,h_l,length):
    g=(h_l-h_u)/length
    return continuous_mfp_ksec(code,h_u,h_l)*(1.0-g)


def g0_hat(g):
    """Cardinal weight of the g=0 row in the existing piecewise-linear axis."""
    j=G_AXIS.index(0.0)
    gl=G_AXIS[j-1]
    gr=G_AXIS[j+1]
    if gl <= g <= 0.0:
        return (g-gl)/(0.0-gl)
    if 0.0 <= g <= gr:
        return (gr-g)/(gr-0.0)
    return 0.0


class ConstrainedMFPLogRatioTable:
    """Darcian/MFP conductance ratio with exact diagonal manifold correction.

    Grid values store R=log(K_DAR/K_MFPtable_secant). Runtime starts from the
    continuous limiting form of the existing MFP-table secant. Bilinear R is
    then corrected only by the cardinal weight of the g=0 interpolation row so
    that the entire continuous equal-head manifold satisfies q=K(h) exactly.
    Strong-gradient cells, including the regime where MFP is a useful baseline,
    are unchanged by this analytic manifold reconciliation.
    """
    def __init__(self,code,length,x_axis=X_AXIS,g_axis=G_AXIS):
        self.code=int(code)
        self.length=float(length)
        self.x_axis=list(x_axis)
        self.g_axis=list(g_axis)
        self.values=[]
        for x in self.x_axis:
            h_u=-10.0**x
            row=[]
            for g in self.g_axis:
                h_l=h_u+g*self.length
                kd=oracle_kdar(self.code,h_u,g,self.length)
                kb=continuous_mfp_ksec(self.code,h_u,h_l)
                ratio=kd/kb
                if not math.isfinite(ratio) or ratio <= 0.0:
                    raise RuntimeError(("nonpositive Darcian/MFP ratio",self.code,
                                        self.length,h_u,g,kd,kb,ratio))
                row.append(math.log(ratio))
            self.values.append(row)

    def raw_log_ratio(self,h_u,g):
        if h_u >= 0.0:
            raise ValueError(("upper_head_not_unsaturated",h_u))
        x=math.log10(-h_u)
        i0,i1=bracket(self.x_axis,x)
        j0,j1=bracket(self.g_axis,g)
        x0,x1=self.x_axis[i0],self.x_axis[i1]
        g0,g1=self.g_axis[j0],self.g_axis[j1]
        tx=0.0 if x1==x0 else (x-x0)/(x1-x0)
        tg=0.0 if g1==g0 else (g-g0)/(g1-g0)
        a00=self.values[i0][j0]
        a10=self.values[i1][j0]
        a11=self.values[i1][j1]
        a01=self.values[i0][j1]
        return ((1-tx)*(1-tg)*a00 + tx*(1-tg)*a10 +
                tx*tg*a11 + (1-tx)*tg*a01)

    def log_ratio(self,h_u,g):
        raw=self.raw_log_ratio(h_u,g)
        w=g0_hat(g)
        if w == 0.0:
            return raw
        k_exact=core.MATERIAL_BY_CODE[self.code].conductivity(h_u)
        k_lim=mfp_table_limit_k(core.TABLES[self.code],h_u)
        r0_exact=math.log(k_exact/k_lim)
        r0_interp=self.raw_log_ratio(h_u,0.0)
        return raw + w*(r0_exact-r0_interp)

    def flux(self,h_u,h_l):
        g=(h_l-h_u)/self.length
        qbase=continuous_mfp_flux(self.code,h_u,h_l,self.length)
        return qbase*math.exp(self.log_ratio(h_u,g))


class ConstrainedMFPCache:
    def __init__(self):
        self.tables={}
        self.build_count=0
        self.transient_calls=0
        self.coverage_misses=0

    def table(self,code,length):
        key=(int(code),round(float(length),12))
        if key not in _SHARED_TABLES:
            _SHARED_TABLES[key]=ConstrainedMFPLogRatioTable(code,length)
        if key not in self.tables:
            self.tables[key]=_SHARED_TABLES[key]
            self.build_count+=1
        return self.tables[key]

    def flux(self,code,h_u,h_l,length):
        self.transient_calls+=1
        try:
            return self.table(code,length).flux(h_u,h_l)
        except ValueError as exc:
            self.coverage_misses+=1
            raise RuntimeError("constrained_mfp_ratio_coverage:"+str(exc)) from exc

    def diagnostics(self):
        n=len(X_AXIS)*len(G_AXIS)
        return {
            "table_builds":self.build_count,
            "values_per_table":n,
            "table_values_total":self.build_count*n,
            "bytes_double_values_before_metadata":self.build_count*n*8,
            "transient_face_calls":self.transient_calls,
            "coverage_misses":self.coverage_misses,
            "upper_head_envelope_cm":[-10.0**X_AXIS[-1],-10.0**X_AXIS[0]],
            "gradient_envelope":[G_AXIS[0],G_AXIS[-1]],
            "stored_quantity":"R=log(K_DAR/K_MFPtable_secant)",
            "runtime_constraint":"analytic g=0 cardinal-row reconciliation",
            "flux_structure":"q=q_MFPtable_continuous*exp(R_constrained)",
        }


def continuity_refinement():
    cache=ConstrainedMFPCache()
    rows=[]; ratios=[]; finite=True
    eps_large=1.0e-3; eps_small=2.0e-4
    for code in (1,2):
        for length in (10.0,20.0):
            tab=cache.table(code,length)
            for h_u in (-200.0,-80.0,-20.0):
                for g0 in (0.0,1.0):
                    def q(g): return tab.flux(h_u,h_u+g*length)
                    q0=q(g0); qlm=q(g0-eps_large); qlp=q(g0+eps_large)
                    qsm=q(g0-eps_small); qsp=q(g0+eps_small)
                    large=max(abs(qlm-q0),abs(qlp-q0))
                    small=max(abs(qsm-q0),abs(qsp-q0))
                    ratio=0.0 if large<1e-14 and small<1e-14 else small/max(large,1e-300)
                    finite=finite and all(math.isfinite(v) for v in (q0,qlm,qlp,qsm,qsp,ratio))
                    ratios.append(ratio)
                    rows.append({"code":code,"length":length,"h_upper":h_u,"g":g0,
                                 "eps_large":eps_large,"eps_small":eps_small,
                                 "q_center":q0,"large_max_distance":large,
                                 "small_max_distance":small,"small_over_large":ratio})
    return {"pass":finite and max(ratios)<=0.35,"finite":finite,
            "epsilon_ratio":eps_small/eps_large,"maximum_small_over_large":max(ratios),
            "threshold":0.35,"response_tangent_admitted":False,"rows":rows,
            "cache":cache.diagnostics()}


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_lmfp08_constrained_mfp_ratio.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    core.CorrectionCache=ConstrainedMFPCache
    identities=core.identity_tests()
    face=core.face_validation()
    response=core.response_diagnostics()
    continuity=continuity_refinement()
    transient=core.transient_matrix(Path(sys.argv[1]))
    structural=(identities["pass"] and face["pass"] and response["pass"] and
                continuity["pass"] and transient["pass"])
    evidence={
        "schema_version":1,"work_unit":"F-LMFP08",
        "candidate":"CONSTRAINED_CONTINUOUS_MFP_LOG_DARCIAN_RATIO",
        "heterogeneous_faces":"current MFP equal-flux interface retained unchanged",
        "representation":{
            "formula":"q=q_MFPtable_continuous*exp(R_constrained)",
            "raw_R":"log(K_DAR/K_MFPtable_secant)",
            "g0_constraint":"replace only the g=0 interpolation-row contribution with analytic log(K_exact/K_MFPtable_limit)",
            "hydrostatic_identity":"q_MFPtable contains factor (1-g), hence q=0 at g=1",
            "positive_effective_conductivity":True,
            "flow_direction_fixed_by_total_hydraulic_gradient":True,
            "values_per_material_geometry_class":len(X_AXIS)*len(G_AXIS),
            "bytes_per_class_before_metadata":len(X_AXIS)*len(G_AXIS)*8,
        },
        "tests":{"exact_identities":identities,"face_oracle_validation":face,
                 "response_diagnostics_legacy":response,
                 "strict_response_continuity_refinement":continuity,
                 "transient_matrix":transient},
        "structural_pass":structural,
        "interpretation":{
            "production_admission":"none","response_tangent_admission":"none; continuity only",
            "lookup_ownership":"immutable shared hydraulic parameter data",
            "solver_policy":"explicit LayeredMFP physical model configuration only",
            "motivation":"retain MFP strong-gradient interpolation quality while removing its equal-head table-secant point discontinuity"
        }
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural else 1)

if __name__=="__main__":
    main()
