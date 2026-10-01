#!/usr/bin/env python3
"""F-MACRO-EMP01: North-China ponded PF fraction boundary-regime evidence.

Numeric values are transcribed from Table 2 of:
Zhang et al. (2022), Geoderma 428, 116205.
DOI: 10.1016/j.geoderma.2022.116205

This is a research evidence summarizer. It does not calibrate RFM sigma_B.
"""
from __future__ import annotations
import json, statistics

LY = [
    {"no":1,"sir_m_d":2.17,"mir_m_d":0.05,"pfir_m_d":2.16,"pfir_sir":0.98},
    {"no":2,"sir_m_d":1.89,"mir_m_d":0.05,"pfir_m_d":1.87,"pfir_sir":0.97},
    {"no":3,"sir_m_d":2.13,"mir_m_d":0.05,"pfir_m_d":2.11,"pfir_sir":0.97},
    {"no":4,"sir_m_d":3.51,"mir_m_d":0.05,"pfir_m_d":3.50,"pfir_sir":0.98},
    {"no":5,"sir_m_d":5.92,"mir_m_d":0.05,"pfir_m_d":5.90,"pfir_sir":0.99},
    {"no":6,"sir_m_d":3.28,"mir_m_d":0.05,"pfir_m_d":3.27,"pfir_sir":0.98},
    {"no":7,"sir_m_d":6.38,"mir_m_d":0.05,"pfir_m_d":6.36,"pfir_sir":0.99},
    {"no":8,"sir_m_d":5.56,"mir_m_d":0.05,"pfir_m_d":5.54,"pfir_sir":0.99},
    {"no":9,"sir_m_d":2.55,"mir_m_d":0.05,"pfir_m_d":2.53,"pfir_sir":0.98},
]
SZ = [
    {"no":1,"sir_m_d":1.14,"mir_m_d":0.26,"pfir_m_d":0.87,"pfir_sir":0.77},
    {"no":2,"sir_m_d":0.76,"mir_m_d":0.26,"pfir_m_d":0.50,"pfir_sir":0.65},
    {"no":3,"sir_m_d":0.50,"mir_m_d":0.26,"pfir_m_d":0.24,"pfir_sir":0.47},
    {"no":4,"sir_m_d":0.46,"mir_m_d":0.26,"pfir_m_d":0.20,"pfir_sir":0.42},
    {"no":5,"sir_m_d":0.17,"mir_m_d":0.17,"pfir_m_d":0.00,"pfir_sir":0.00},
    {"no":6,"sir_m_d":0.73,"mir_m_d":0.26,"pfir_m_d":0.47,"pfir_sir":0.64},
    {"no":7,"sir_m_d":0.24,"mir_m_d":0.24,"pfir_m_d":0.00,"pfir_sir":0.00},
    {"no":8,"sir_m_d":0.33,"mir_m_d":0.26,"pfir_m_d":0.07,"pfir_sir":0.20},
]

def summarize(rows):
    x=[r["pfir_sir"] for r in rows]
    return {
        "n":len(x),
        "mean":statistics.mean(x),
        "median":statistics.median(x),
        "min":min(x),
        "max":max(x),
        "population_cv":statistics.pstdev(x)/statistics.mean(x),
    }

print(json.dumps({
    "schema":"swap5.f_macro_emp01.north_china_ponded_pf.v1",
    "status":"RESEARCH_EVIDENCE",
    "source":{
        "citation":"Zhang et al. (2022), Geoderma 428, 116205",
        "doi":"10.1016/j.geoderma.2022.116205",
        "table":"Table 2",
        "boundary":"double-ring steady infiltration under 5 cm maintained head",
    },
    "LY":{"rows":LY,"summary":summarize(LY)},
    "SZ":{"rows":SZ,"summary":summarize(SZ)},
    "decision":{
        "quantitative_pf_fraction_available":True,
        "valid_sigma_B_calibration_target":False,
        "reason":"ponded/head-controlled steady infiltration is outside frozen unponded sigma_B boundary regime",
        "valid_future_ponded_pf_boundary_target":True,
    }
},indent=2,sort_keys=True))
