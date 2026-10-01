#!/usr/bin/env python3
"""F-MACRO-ALT20: bounded Griessfirn appendix-data discrimination.

Research-only.
Uses the published HESS 2022 Table A1 relative frequencies at 0-100 cm.
No raw GFZ payload and no model calibration.

The six flow-type categories are encoded numerically in the published order:
0 macropore flow with low interaction
1 mixed macropore flow
2 macropore flow / finger-shaped flow paths
3 heterogeneous matrix flow and finger-shaped flow paths
4 homogeneous matrix flow
5 matrix flow between rocks
"""

import json

TABLE_A1 = {
    110: {
        20: [0.01,0.02,0.29,0.02,0.48,0.19],
        40: [0.01,0.01,0.21,0.04,0.62,0.10],
        60: [0.01,0.02,0.29,0.02,0.48,0.19],
    },
    160: {
        20: [0.03,0.02,0.34,0.08,0.41,0.11],
        40: [0.01,0.01,0.28,0.06,0.37,0.27],
        60: [0.03,0.02,0.39,0.03,0.41,0.12],
    },
    4900: {
        20: [0.02,0.01,0.56,0.02,0.23,0.15],
        40: [0.01,0.01,0.62,0.03,0.20,0.13],
        60: [0.02,0.02,0.75,0.00,0.08,0.12],
    },
    13500: {
        20: [0.03,0.04,0.71,0.01,0.13,0.07],
        40: [0.03,0.03,0.67,0.02,0.21,0.03],
        60: [0.01,0.02,0.62,0.03,0.23,0.09],
    },
}

def monotonic(values):
    return all(b >= a for a,b in zip(values, values[1:]))

def main():
    rows = []
    for age, intensities in TABLE_A1.items():
        derived = []
        for intensity in (20,40,60):
            vals = intensities[intensity]
            pf_associated = sum(vals[:4])
            finger_core = vals[2]
            matrix_associated = sum(vals[4:])
            derived.append({
                "intensity_mm_h": intensity,
                "pf_associated_frequency": pf_associated,
                "finger_core_frequency": finger_core,
                "matrix_associated_frequency": matrix_associated,
            })
        rows.append({
            "moraine_age_y": age,
            "intensity_rows": derived,
            "pf_associated_monotone_increasing": monotonic(
                [r["pf_associated_frequency"] for r in derived]
            ),
            "finger_core_monotone_increasing": monotonic(
                [r["finger_core_frequency"] for r in derived]
            ),
        })

    print(json.dumps({
        "schema":"swap5.f_macro_alt20.griessfirn_table_a1.v1",
        "status":"RESEARCH_ONLY",
        "source":"Hartmann et al. 2022 HESS Table A1, 0-100 cm flow-type relative frequencies",
        "rows":rows,
        "interpretation":[
            "4900-y moraine shows monotone increase of PF-associated and finger-core frequency with intensity.",
            "13500-y moraine shows decreasing categorical PF/finger frequency with intensity.",
            "Therefore categorical flow-type frequency is not a valid one-to-one proxy for preferential activation amount.",
            "RFM activation must be compared against quantitative dye coverage/path number/depth and surface runoff, not only categorical flow class."
        ]
    },indent=2,sort_keys=True))

if __name__=="__main__":
    main()
