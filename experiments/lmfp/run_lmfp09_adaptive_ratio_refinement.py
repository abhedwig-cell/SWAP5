from __future__ import annotations

import bisect
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable
from run_lmfp09_homogeneous_c1_coarse import asymptotic_continuity_test, tolerant_bracket

# This subgate is deliberately restricted to the single B1 class that failed at
# 33 ratio-head nodes. The refinement interval is selected from table variation
# only, never from validation error.
core.AsinhMFPTable = HermiteMFPTable
core.bracket = tolerant_bracket
core.MASTER_NX = 33
core.VIEW_NX = (33,)

FIXTURE = next(f for f in core.ACTIVE if f.name == "reference_sand")
LENGTH = 20.0
PROBE_SEED = 431090101
KNOWN_OUTLIER_INTERVAL = (-115.30715360110095, -46.56309852748798)


def interpolation_row(master, h_u):
    row = []
    oracle_solves = 0
    for g in core.G_AXIS:
        h_l = h_u + g * master.length
        if h_l < core.MFP_HMIN or h_l > core.MFP_HMAX:
            raise RuntimeError(("adaptive_face_outside_mfp_envelope", h_u, h_l, g,
                                master.length, core.MFP_HMIN, core.MFP_HMAX))
        kd, calls = core.oracle_kdar(master.mat, h_u, g, master.length)
        oracle_solves += calls
        kb = master.mfp.secant_k(h_u, h_l)
        if not math.isfinite(kb) or kb <= 0.0:
            raise RuntimeError(("nonpositive_mfp_secant", h_u, h_l, kb))
        ratio = kd / kb
        if not math.isfinite(ratio) or ratio <= 0.0:
            raise RuntimeError(("nonpositive_ratio", h_u, g, kd, kb, ratio))
        row.append(math.log(ratio))
    return row, oracle_solves


def interval_scores(master):
    rows = []
    for i in range(len(master.x_axis)-1):
        deltas = [abs(master.values[i+1][j]-master.values[i][j])
                  for j in range(len(core.G_AXIS))]
        rows.append({
            "interval_index": i,
            "x_left": master.x_axis[i],
            "x_right": master.x_axis[i+1],
            "h_left_cm": master.h_axis[i],
            "h_right_cm": master.h_axis[i+1],
            "score_max_abs_delta_log_ratio": max(deltas),
            "gradient_index_at_max": max(range(len(deltas)), key=deltas.__getitem__),
            "gradient_at_max": core.G_AXIS[max(range(len(deltas)), key=deltas.__getitem__)],
        })
    return rows


class AdaptiveRatioView:
    def __init__(self, master, selected_interval):
        self.master = master
        self.fixture = master.fixture
        self.mat = master.mat
        self.length = master.length
        self.mfp = master.mfp
        self.nx = len(master.x_axis) + 1
        self.selected_interval = selected_interval

        i = selected_interval["interval_index"]
        x_mid = 0.5*(master.x_axis[i] + master.x_axis[i+1])
        h_mid = master.coordinate.h(x_mid)
        mid_values, calls = interpolation_row(master, h_mid)
        self.extra_oracle_solves = calls
        self.inserted_x = x_mid
        self.inserted_h = h_mid

        self.x_axis = list(master.x_axis[:i+1]) + [x_mid] + list(master.x_axis[i+1:])
        self.values = [list(r) for r in master.values[:i+1]] + [mid_values] + \
                      [list(r) for r in master.values[i+1:]]

    def raw_log_ratio(self, h_u, g):
        if h_u < core.R_HMIN or h_u > core.R_HMAX:
            raise ValueError(("upper_head_out_of_ratio_envelope", h_u,
                              core.R_HMIN, core.R_HMAX))
        if g < core.G_AXIS[0] or g > core.G_AXIS[-1]:
            raise ValueError(("gradient_out_of_ratio_envelope", g,
                              core.G_AXIS[0], core.G_AXIS[-1]))
        x = self.master.coordinate.x(h_u)
        i0,i1 = tolerant_bracket(self.x_axis, x)
        j0,j1 = tolerant_bracket(core.G_AXIS, g)
        x0,x1 = self.x_axis[i0],self.x_axis[i1]
        g0,g1 = core.G_AXIS[j0],core.G_AXIS[j1]
        tx = 0.0 if x1 == x0 else (x-x0)/(x1-x0)
        tg = 0.0 if g1 == g0 else (g-g0)/(g1-g0)
        a00=self.values[i0][j0]; a10=self.values[i1][j0]
        a11=self.values[i1][j1]; a01=self.values[i0][j1]
        return ((1-tx)*(1-tg)*a00 + tx*(1-tg)*a10 +
                tx*tg*a11 + (1-tx)*tg*a01)

    def log_ratio(self,h_u,g):
        raw=self.raw_log_ratio(h_u,g)
        w=core.g0_hat(g)
        if w == 0.0:
            return raw
        k_exact=self.mat.conductivity(h_u)
        k_lim=self.mfp.limit_k(h_u)
        r0_exact=math.log(k_exact/k_lim)
        r0_interp=self.raw_log_ratio(h_u,0.0)
        return raw+w*(r0_exact-r0_interp)

    def flux(self,h_u,h_l):
        g=(h_l-h_u)/self.length
        if h_l < core.MFP_HMIN or h_l > core.MFP_HMAX:
            raise ValueError(("lower_head_out_of_mfp_envelope",h_l,
                              core.MFP_HMIN,core.MFP_HMAX))
        kbase=self.mfp.secant_k(h_u,h_l)
        qbase=kbase*(1.0-g)
        return qbase*math.exp(self.log_ratio(h_u,g))

    def memory(self):
        n=self.nx*len(core.G_AXIS)
        return {"values":n,"bytes_before_metadata":n*8}


def same_interval(a,b,tol=1.0e-9):
    aa=sorted(a); bb=sorted(b)
    return all(abs(x-y)<=tol*max(1.0,abs(x),abs(y)) for x,y in zip(aa,bb))


def main():
    if len(sys.argv)!=2:
        raise SystemExit("usage: run_lmfp09_adaptive_ratio_refinement.py EVIDENCE_JSON")

    mfp_coord=core.AsinhCoordinate(core.H_SCALE,hmin=core.MFP_HMIN,hmax=core.MFP_HMAX)
    mfp=HermiteMFPTable(FIXTURE.material,mfp_coord,core.MFP_N)
    master=core.RatioMaster(FIXTURE,LENGTH,mfp)
    scores=interval_scores(master)
    selected=max(scores,key=lambda r:r["score_max_abs_delta_log_ratio"])
    view=AdaptiveRatioView(master,selected)
    probes=core.build_probe_rows(FIXTURE,LENGTH,PROBE_SEED)

    identity=core.identity_test(view)
    continuity=asymptotic_continuity_test(view)
    fail_closed=core.fail_closed_test(view)
    face=core.metrics_for_view(view,probes)
    structural_pass=identity["pass"] and continuity["pass"] and fail_closed["pass"] and face["pass"]

    base_memory=33*len(core.G_AXIS)*8
    adaptive_memory=view.memory()["bytes_before_metadata"]
    evidence={
        "schema_version":1,
        "work_unit":"F-LMFP09",
        "subgate":"B1_C1_ADAPTIVE_SINGLE_INTERVAL_RATIO_REFINEMENT",
        "material":FIXTURE.name,
        "face_length_cm":LENGTH,
        "selection_rule":"split exactly the 33-node head interval with maximum max_j abs(delta log(K_DAR/K_MFP)) across the fixed gradient nodes",
        "selection_uses_validation_error":False,
        "base_ratio_head_nodes":33,
        "adaptive_ratio_head_nodes":34,
        "gradient_nodes":len(core.G_AXIS),
        "interval_scores":scores,
        "selected_interval":selected,
        "inserted_midpoint":{"x":view.inserted_x,"h_cm":view.inserted_h},
        "selected_interval_matches_previously_observed_outlier_cell":same_interval(
            (selected["h_left_cm"],selected["h_right_cm"]),KNOWN_OUTLIER_INTERVAL),
        "oracle_cost":{"base_master_oracle_solves":master.oracle_solves,
                       "extra_midpoint_oracle_solves":view.extra_oracle_solves,
                       "runtime_oracle_calls":0},
        "memory":{"base_33_bytes_per_class":base_memory,
                  "adaptive_34_bytes_per_class":adaptive_memory,
                  "increment_bytes":adaptive_memory-base_memory},
        "tests":{"identity":identity,"asymptotic_continuity":continuity,
                 "fail_closed":fail_closed,"face_matrix":face},
        "structural_pass":structural_pass,
        "thresholds_changed_from_B1":False,
        "production_admission":False,
        "interpretation":{
            "if_pass":"single algorithmic local refinement is sufficient for the only 33-node failing class; global 65-node ratio tables are not required by current B1 evidence",
            "if_fail":"do not relax thresholds; next compare top-two adaptive splits or a 65-node table for this class only"
        }
    }
    Path(sys.argv[1]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if structural_pass else 1)

if __name__=="__main__":
    main()
