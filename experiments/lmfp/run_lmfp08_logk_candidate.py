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

X_AXIS = list(core.X_AXIS)
G_AXIS = list(core.G_AXIS)
_SHARED_TABLES = {}


def bracket(axis, x):
    if x < axis[0] or x > axis[-1]:
        raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis)-2, len(axis)-1
    i=bisect.bisect_right(axis,x)-1
    return max(0,i),min(len(axis)-1,i+1)


def oracle_kdar(code,h_u,g,length):
    """Positive Darcian mean K such that q=(1-g)K for a homogeneous face."""
    if abs(g) <= 1.0e-14:
        return core.MATERIAL_BY_CODE[code].conductivity(h_u)

    def eval_at(gg):
        h_l=h_u+gg*length
        q=core.direct_homogeneous(code,h_u,h_l,length)
        grad=1.0-gg
        if abs(grad)<1.0e-14:
            raise ZeroDivisionError(gg)
        k=q/grad
        if not math.isfinite(k) or k<=0.0:
            raise RuntimeError(("nonpositive_kdar",code,h_u,gg,length,q,k))
        return k

    if abs(g-1.0)<=1.0e-14:
        eps=2.0e-3
        # Interpolate the positive conductance in log space across the removable
        # hydrostatic q/G limit.
        return math.exp(0.5*(math.log(eval_at(1.0-eps))+math.log(eval_at(1.0+eps))))
    return eval_at(g)


class LogKDarTable:
    """Immutable positive Darcian conductance representation.

    Runtime structure is q=(1-g)*exp(logK_interp). Sign therefore cannot reverse
    relative to the total hydraulic gradient. Equal-head gravity flow is evaluated
    analytically at g=0 and hydrostatic flow is exactly zero at g=1.
    """
    def __init__(self,code,length,x_axis=X_AXIS,g_axis=G_AXIS):
        self.code=int(code); self.length=float(length)
        self.x_axis=list(x_axis); self.g_axis=list(g_axis)
        self.logk=[]
        for x in self.x_axis:
            hu=-10.0**x
            row=[]
            for g in self.g_axis:
                k=oracle_kdar(self.code,hu,g,self.length)
                row.append(math.log(k))
            self.logk.append(row)

    def kdar(self,h_u,g):
        if h_u>=0.0:
            raise ValueError(("upper_head_not_unsaturated",h_u))
        if abs(g)<=2.0e-14:
            return core.MATERIAL_BY_CODE[self.code].conductivity(h_u)
        x=math.log10(-h_u)
        i0,i1=bracket(self.x_axis,x); j0,j1=bracket(self.g_axis,g)
        x0,x1=self.x_axis[i0],self.x_axis[i1]
        g0,g1=self.g_axis[j0],self.g_axis[j1]
        tx=0.0 if x1==x0 else (x-x0)/(x1-x0)
        tg=0.0 if g1==g0 else (g-g0)/(g1-g0)
        a00=self.logk[i0][j0]; a10=self.logk[i1][j0]
        a11=self.logk[i1][j1]; a01=self.logk[i0][j1]
        a=((1-tx)*(1-tg)*a00 + tx*(1-tg)*a10 +
           tx*tg*a11 + (1-tx)*tg*a01)
        return math.exp(a)

    def flux(self,h_u,h_l):
        g=(h_l-h_u)/self.length
        if abs(g-1.0)<=2.0e-14:
            return 0.0
        return (1.0-g)*self.kdar(h_u,g)


class LogKCache:
    def __init__(self):
        self.tables={}; self.build_count=0; self.transient_calls=0; self.coverage_misses=0
    def table(self,code,length):
        key=(int(code),round(float(length),12))
        if key not in _SHARED_TABLES:
            _SHARED_TABLES[key]=LogKDarTable(code,length)
        if key not in self.tables:
            self.tables[key]=_SHARED_TABLES[key]; self.build_count+=1
        return self.tables[key]
    def flux(self,code,h_u,h_l,length):
        self.transient_calls+=1
        try:
            return self.table(code,length).flux(h_u,h_l)
        except ValueError as exc:
            self.coverage_misses+=1
            raise RuntimeError("logk_coverage:"+str(exc)) from exc
    def diagnostics(self):
        n=len(X_AXIS)*len(G_AXIS)
        return {
            "table_builds":self.build_count,"values_per_table":n,
            "table_values_total":self.build_count*n,
            "bytes_double_values_before_metadata":self.build_count*n*8,
            "transient_face_calls":self.transient_calls,"coverage_misses":self.coverage_misses,
            "upper_head_envelope_cm":[-10.0**X_AXIS[-1],-10.0**X_AXIS[0]],
            "gradient_envelope":[G_AXIS[0],G_AXIS[-1]],
            "coordinates":"x=log10(-h_upper), g=(h_lower-h_upper)/L",
            "stored_quantity":"log(K_DAR), K_DAR>0",
            "flux_structure":"q=(1-g)*K_DAR",
        }


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_lmfp08_logk_candidate.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    core.CorrectionCache=LogKCache
    identities=core.identity_tests()
    face=core.face_validation()
    response=core.response_diagnostics()
    transient=core.transient_matrix(Path(sys.argv[1]))
    structural=identities["pass"] and face["pass"] and response["pass"] and transient["pass"]
    evidence={
        "schema_version":1,"work_unit":"F-LMFP08",
        "candidate":"POSITIVE_LOG_KDAR_HOMOGENEOUS_FACE_REPRESENTATION",
        "rejected_predecessors":[
            "factored C correction: transient stress 3/5",
            "direct Delta-q correction: sign reversal in face sweep and transient stress 3/5"
        ],
        "heterogeneous_faces":"current MFP equal-flux interface retained unchanged",
        "representation":{
            "formula":"q=(1-g)*exp(interp(log(K_DAR)))",
            "g":"(h_lower-h_upper)/face_distance",
            "x_axis_points":len(X_AXIS),"g_axis_points":len(G_AXIS),
            "values_per_material_geometry_class":len(X_AXIS)*len(G_AXIS),
            "bytes_per_class_before_metadata":len(X_AXIS)*len(G_AXIS)*8,
            "positive_conductance_by_construction":True,
            "flow_direction_fixed_by_total_hydraulic_gradient":True,
            "equal_head_g0_exact_Kh":True,
            "hydrostatic_g1_exact_zero_flux":True,
            "runtime_extrapolation":False,
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
            "response_tangent_admission":"none",
            "lookup_ownership":"immutable shared hydraulic parameter data",
            "solver_policy":"explicit LayeredMFP physical model configuration only",
        }
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural else 1)

if __name__=="__main__":
    main()
