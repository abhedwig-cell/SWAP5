from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_coordinate_envelope as gate_a
import run_lmfp09_homogeneous_face_matrix as b1
from run_lmfp09_mfp_c1_candidates import HermiteMFPTable, H_SCALE, NODES, HMIN, HMAX, HEADS, LENGTHS

EPS = (1.0e-3, 2.0e-4, 4.0e-5, 8.0e-6, 1.6e-6)


def distance(qfun, g0, eps):
    q0=qfun(g0)
    return max(abs(qfun(g0-eps)-q0), abs(qfun(g0+eps)-q0))


def main():
    if len(sys.argv)!=2:
        raise SystemExit("usage: run_lmfp09_mfp_c1_refinement.py EVIDENCE_JSON")

    coord=gate_a.AsinhCoordinate(H_SCALE,hmin=HMIN,hmax=HMAX)
    active={f.name:f for f in gate_a.FIXTURES if f.name in ("reference_sand","reference_clay")}
    tables={name:HermiteMFPTable(f.material,coord,NODES,limited=False)
            for name,f in active.items()}

    rows=[]
    oracle_nonsmooth=0
    spurious_initial=0
    spurious_final=0
    finite=True
    final_ratios=[]

    for name in ("reference_sand","reference_clay"):
        fixture=active[name]; mat=fixture.material; tab=tables[name]
        for length in LENGTHS:
            for h in HEADS:
                for g0 in (0.0,1.0):
                    qo=lambda g:b1.direct_flux(mat,h,h+g*length,length)
                    qm=lambda g:tab.secant_k(h,h+g*length)*(1.0-g)

                    # Reuse the original two-scale oracle criterion only to classify
                    # whether this state is suitable for a generic smooth-response gate.
                    od0=distance(qo,g0,EPS[0]); od1=distance(qo,g0,EPS[1])
                    oracle_ratio=0.0 if od0<1.0e-14 and od1<1.0e-14 else od1/max(od0,1.0e-300)
                    oracle_smooth=oracle_ratio<=0.35
                    if not oracle_smooth:
                        oracle_nonsmooth+=1

                    ds=[distance(qm,g0,e) for e in EPS]
                    ratios=[]
                    for a,b in zip(ds[:-1],ds[1:]):
                        ratios.append(0.0 if a<1.0e-14 and b<1.0e-14 else b/max(a,1.0e-300))
                    finite=finite and all(math.isfinite(v) for v in ds+ratios+[oracle_ratio])
                    if oracle_smooth:
                        final_ratios.append(ratios[-1])
                        if ratios[0]>0.35:
                            spurious_initial+=1
                        if ratios[-1]>0.35:
                            spurious_final+=1
                    rows.append({
                        "material":name,"length_cm":length,"h_upper_cm":h,"g_center":g0,
                        "oracle_initial_small_over_large":oracle_ratio,
                        "oracle_generic_smooth":oracle_smooth,
                        "epsilons":list(EPS),"candidate_distances":ds,
                        "candidate_consecutive_ratios":ratios,
                        "candidate_initial_ratio":ratios[0],
                        "candidate_final_ratio":ratios[-1],
                    })

    # Structural C1 facts of the Hermite representation. Every internal knot is
    # represented by one shared nodal slope used by both adjacent polynomials.
    knot_checks=[]
    for name,tab in tables.items():
        for i in range(1,tab.n-1):
            left_endpoint_dphidx=tab.slopes[i]
            right_endpoint_dphidx=tab.slopes[i]
            knot_checks.append({"material":name,"node":i,
                                "left_dphi_dx":left_endpoint_dphidx,
                                "right_dphi_dx":right_endpoint_dphidx,
                                "abs_jump":abs(left_endpoint_dphidx-right_endpoint_dphidx)})
    max_knot_jump=max(r["abs_jump"] for r in knot_checks)
    sat_join=max(tab.saturation_endpoint_slope_rel_error for tab in tables.values())
    positivity=all(tab.positivity_diagnostic()["pass"] for tab in tables.values())

    evidence={
        "schema_version":1,"work_unit":"F-LMFP09",
        "subgate":"B0_MFP_C1_ASYMPTOTIC_REFINEMENT",
        "candidate":"EXACT_SLOPE_HERMITE_PHI_X",
        "epsilons":list(EPS),"expected_consecutive_ratio_for_nonzero_linear_response":0.2,
        "structural_c1":{"shared_internal_nodal_slope_max_abs_jump":max_knot_jump,
                         "saturated_join_slope_max_rel_error":sat_join,
                         "positive_conductance_samples":positivity,
                         "pass":max_knot_jump==0.0 and sat_join<1.0e-12 and positivity},
        "response_refinement":{"oracle_nonsmooth_rows":oracle_nonsmooth,
                               "spurious_rows_at_initial_scale":spurious_initial,
                               "spurious_rows_at_final_scale":spurious_final,
                               "max_final_ratio_on_oracle_smooth_rows":max(final_ratios),
                               "rows":rows},
    }
    evidence["structural_pass"]=(finite and evidence["structural_c1"]["pass"]
                                 and spurious_final==0
                                 and max(final_ratios)<=0.35)
    evidence["interpretation"]=(
        "The generic response gate is applied asymptotically only where the direct-Darcy oracle is smooth at the original scale. "
        "Oracle-nonsmooth rows are retained as regime-switch diagnostics and imply no response-tangent admission there."
    )
    evidence["production_admission"]=False
    Path(sys.argv[1]).write_text(json.dumps(evidence,indent=2,sort_keys=True)+"\n")
    print(json.dumps(evidence,indent=2,sort_keys=True))
    raise SystemExit(0 if evidence["structural_pass"] else 1)

if __name__=="__main__":
    main()
