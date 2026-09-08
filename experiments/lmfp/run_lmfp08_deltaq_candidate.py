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
    i = bisect.bisect_right(axis, x)-1
    return max(0, i), min(len(axis)-1, i+1)


class DeltaQTable:
    """Immutable constrained flux-residual table for one homogeneous face class.

    Stores Delta q = q_Darcy - q_MFP directly in (log10(-h_upper), g),
    where g=(h_lower-h_upper)/L. At g=0 and g=1 the residual is set to
    exactly zero and runtime also returns the MFP identity branch exactly.
    """
    def __init__(self, code, length, x_axis=X_AXIS, g_axis=G_AXIS):
        self.code = int(code)
        self.length = float(length)
        self.x_axis = list(x_axis)
        self.g_axis = list(g_axis)
        self.values = []
        for x in self.x_axis:
            hu = -10.0**x
            row = []
            for g in self.g_axis:
                if g == 0.0 or g == 1.0:
                    row.append(0.0)
                else:
                    hl = hu + g*self.length
                    qd = core.direct_homogeneous(self.code, hu, hl, self.length)
                    qm = core.mfp_homogeneous(self.code, hu, hl, self.length)
                    row.append(qd-qm)
            self.values.append(row)

    def residual(self, h_u, g):
        if h_u >= 0.0:
            raise ValueError(("upper_head_not_unsaturated", h_u))
        # Exact physical manifolds, independent of floating-point bracketing.
        if abs(g) <= 2.0e-14 or abs(g-1.0) <= 2.0e-14:
            return 0.0
        x = math.log10(-h_u)
        i0,i1 = bracket(self.x_axis,x)
        j0,j1 = bracket(self.g_axis,g)
        x0,x1 = self.x_axis[i0],self.x_axis[i1]
        g0,g1 = self.g_axis[j0],self.g_axis[j1]
        tx = 0.0 if x1==x0 else (x-x0)/(x1-x0)
        tg = 0.0 if g1==g0 else (g-g0)/(g1-g0)
        d00=self.values[i0][j0]; d10=self.values[i1][j0]
        d11=self.values[i1][j1]; d01=self.values[i0][j1]
        return ((1-tx)*(1-tg)*d00 + tx*(1-tg)*d10 +
                tx*tg*d11 + (1-tx)*tg*d01)

    def flux(self,h_u,h_l):
        g=(h_l-h_u)/self.length
        qm=core.mfp_homogeneous(self.code,h_u,h_l,self.length)
        return qm + self.residual(h_u,g)


class DeltaQCache:
    def __init__(self):
        self.tables={}
        self.build_count=0
        self.transient_calls=0
        self.coverage_misses=0

    def table(self,code,length):
        key=(int(code),round(float(length),12))
        if key not in _SHARED_TABLES:
            _SHARED_TABLES[key]=DeltaQTable(code,length)
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
            raise RuntimeError("deltaq_coverage:"+str(exc)) from exc

    def diagnostics(self):
        nvals=len(X_AXIS)*len(G_AXIS)
        return {
            "table_builds":self.build_count,
            "values_per_table":nvals,
            "table_values_total":self.build_count*nvals,
            "bytes_double_values_before_metadata":self.build_count*nvals*8,
            "transient_face_calls":self.transient_calls,
            "coverage_misses":self.coverage_misses,
            "upper_head_envelope_cm":[-10.0**X_AXIS[-1],-10.0**X_AXIS[0]],
            "gradient_envelope":[G_AXIS[0],G_AXIS[-1]],
            "coordinates":"x=log10(-h_upper), g=(h_lower-h_upper)/L",
            "stored_quantity":"Delta_q=q_Darcy-q_MFP",
        }


def main():
    if len(sys.argv)!=3:
        raise SystemExit("usage: run_lmfp08_deltaq_candidate.py FULLRICHARDS_OUTPUT EVIDENCE_JSON")
    core.CorrectionCache=DeltaQCache
    identities=core.identity_tests()
    face=core.face_validation()
    response=core.response_diagnostics()
    transient=core.transient_matrix(Path(sys.argv[1]))
    structural=identities["pass"] and face["pass"] and response["pass"] and transient["pass"]
    evidence={
        "schema_version":1,
        "work_unit":"F-LMFP08",
        "candidate":"MFP_PLUS_CONSTRAINED_DIRECT_DELTAQ_ON_HOMOGENEOUS_FACES",
        "predecessor_candidate":"factored_C representation failed transient stress gate",
        "heterogeneous_faces":"current MFP equal-flux interface retained unchanged",
        "representation":{
            "formula":"q=q_MFP + Delta_q(log10(-h_upper),g)",
            "g":"(h_lower-h_upper)/face_distance",
            "x_axis_points":len(X_AXIS),
            "g_axis_points":len(G_AXIS),
            "values_per_material_geometry_class":len(X_AXIS)*len(G_AXIS),
            "bytes_per_class_before_metadata":len(X_AXIS)*len(G_AXIS)*8,
            "g0_residual_exact_zero":True,
            "g1_residual_exact_zero":True,
            "equal_head_identity_preserved_by_construction":True,
            "hydrostatic_identity_preserved_by_construction":True,
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
            "response_tangent_admission":"none; finite-difference diagnostics only",
            "lookup_ownership":"immutable shared hydraulic parameter data",
            "solver_policy":"explicit LayeredMFP physical model configuration only",
        }
    }
    Path(sys.argv[2]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural else 1)


if __name__=="__main__":
    main()
