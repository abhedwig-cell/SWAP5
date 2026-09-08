from __future__ import annotations

import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as b1
from run_lmfp09_coordinate_envelope import AsinhCoordinate, AsinhMFPTable

HEADS = (-0.05, -0.02, -0.015, -0.01, -0.008, -0.006, -0.005, -0.003,
         -0.001, 0.0, 0.001, 0.01)
LENGTHS = (10.0, 20.0)
EPS_LARGE = 1.0e-3
EPS_SMALL = 2.0e-4


def refinement_ratio(qfun, g0):
    q0 = qfun(g0)
    qlm = qfun(g0 - EPS_LARGE)
    qlp = qfun(g0 + EPS_LARGE)
    qsm = qfun(g0 - EPS_SMALL)
    qsp = qfun(g0 + EPS_SMALL)
    large = max(abs(qlm-q0), abs(qlp-q0))
    small = max(abs(qsm-q0), abs(qsp-q0))
    ratio = 0.0 if large < 1.0e-14 and small < 1.0e-14 else small/max(large, 1.0e-300)
    return {
        "q_center": q0,
        "large_max_distance": large,
        "small_max_distance": small,
        "small_over_large": ratio,
        "epsilon_ratio": EPS_SMALL/EPS_LARGE,
        "finite": all(math.isfinite(v) for v in (q0, qlm, qlp, qsm, qsp, ratio)),
    }


def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: run_lmfp09_near_saturation_oracle_diagnostic.py EVIDENCE_JSON")

    coord = AsinhCoordinate(b1.H_SCALE, hmin=b1.MFP_HMIN, hmax=b1.MFP_HMAX)
    evidence = {
        "schema_version": 1,
        "work_unit": "F-LMFP09",
        "diagnostic": "NEAR_SATURATION_ORACLE_CONTINUITY_ATTRIBUTION",
        "epsilon_large": EPS_LARGE,
        "epsilon_small": EPS_SMALL,
        "expected_smooth_ratio": EPS_SMALL/EPS_LARGE,
        "rows": [],
        "constitutive_rows": [],
    }

    oracle_nonsmooth = 0
    mfp_nonsmooth = 0
    finite = True
    max_oracle_identity_error = 0.0

    for fixture in b1.ACTIVE:
        mat = fixture.material
        mfp = AsinhMFPTable(mat, coord, b1.MFP_N)
        ks = mat.conductivity(0.0)

        for h in HEADS:
            # Direct constitutive probes reveal whether K itself has a threshold/kink.
            for dh in (1.0e-3, 2.0e-4, 1.0e-4, 1.0e-5):
                km = mat.conductivity(h-dh)
                k0 = mat.conductivity(h)
                kp = mat.conductivity(h+dh)
                evidence["constitutive_rows"].append({
                    "material": fixture.name,
                    "h_cm": h,
                    "dh_cm": dh,
                    "k_minus": km,
                    "k_center": k0,
                    "k_plus": kp,
                    "left_jump_over_ks": abs(k0-km)/max(ks, 1.0e-300),
                    "right_jump_over_ks": abs(kp-k0)/max(ks, 1.0e-300),
                })

            for length in LENGTHS:
                for g0 in (0.0, 1.0):
                    def q_oracle(g):
                        return b1.direct_flux(mat, h, h + g*length, length)

                    def q_mfp(g):
                        hl = h + g*length
                        return mfp.secant_k(h, hl) * (1.0-g)

                    od = refinement_ratio(q_oracle, g0)
                    md = refinement_ratio(q_mfp, g0)
                    if g0 == 0.0:
                        max_oracle_identity_error = max(
                            max_oracle_identity_error,
                            abs(od["q_center"] - mat.conductivity(h)),
                        )
                    if od["small_over_large"] > 0.35:
                        oracle_nonsmooth += 1
                    if md["small_over_large"] > 0.35:
                        mfp_nonsmooth += 1
                    finite = finite and od["finite"] and md["finite"]
                    evidence["rows"].append({
                        "material": fixture.name,
                        "length_cm": length,
                        "h_upper_cm": h,
                        "g_center": g0,
                        "oracle": od,
                        "mfp_baseline": md,
                    })

    evidence["summary"] = {
        "finite": finite,
        "oracle_rows_over_0p35": oracle_nonsmooth,
        "mfp_rows_over_0p35": mfp_nonsmooth,
        "max_oracle_equal_head_identity_abs_error": max_oracle_identity_error,
        "classification_rule": {
            "oracle_rows_over_0p35_gt_0": "underlying steady-Darcy response is not smooth enough for the generic 0.35 refinement gate at all probed states",
            "oracle_rows_over_0p35_eq_0_and_mfp_gt_0": "representation/MFP baseline is responsible for the continuity failure",
        },
    }
    evidence["diagnostic_pass"] = finite and max_oracle_identity_error < 5.0e-7

    Path(sys.argv[1]).write_text(json.dumps(evidence, indent=2, sort_keys=True) + "\n")
    print(json.dumps(evidence, indent=2, sort_keys=True))
    raise SystemExit(0 if evidence["diagnostic_pass"] else 1)


if __name__ == "__main__":
    main()
