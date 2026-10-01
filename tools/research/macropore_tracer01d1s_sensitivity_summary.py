#!/usr/bin/env python3
from pathlib import Path
import json, sys

def main(paths):
    rows=[]
    centers=[0.05+0.1*i for i in range(10)]
    for p in paths:
        r=json.loads(Path(p).read_text())
        prof=r["final_tracer_profile"]
        total=sum(prof)
        norm=[x/total if total else 0.0 for x in prof]
        centroid=sum(z*m for z,m in zip(centers,norm))
        rows.append({
          "file":str(p),
          "theta1m":float(Path(p).stem.split("_")[-1].replace("p",".")),
          "accepted_packets":r["accepted_packets"],
          "tracer_input_mass":r["tracer_input_mass"],
          "tracer_external_output_mass":r["tracer_external_output_mass"],
          "tracer_final_matrix_mass":r["tracer_final_matrix_mass"],
          "global_tracer_residual":r["global_tracer_residual"],
          "max_bottom_flux_residual":r["max_observer_bottom_flux_residual"],
          "fraction_below_20cm":sum(norm[2:]),
          "fraction_below_50cm":sum(norm[5:]),
          "centroid_m":centroid,
          "profile":prof,
        })
    central=min(rows,key=lambda x:abs(x["theta1m"]-0.274))
    inp=central["tracer_input_mass"]
    for r in rows:
        r["L1_to_central"]=sum(abs(a-b) for a,b in zip(r["profile"],central["profile"]))/inp
    out={
      "schema":"swap5.f_macro_tracer01d1s.sensitivity.v1",
      "status":"RUN_COMPLETE",
      "observed_profile1_centroid_m_from_ALT51":0.176,
      "members":rows,
      "envelope":{
        "max_abs_global_tracer_residual":max(abs(r["global_tracer_residual"]) for r in rows),
        "max_bottom_flux_residual":max(r["max_bottom_flux_residual"] for r in rows),
        "max_L1_to_central":max(r["L1_to_central"] for r in rows),
        "fraction_below_20cm_range":[min(r["fraction_below_20cm"] for r in rows),max(r["fraction_below_20cm"] for r in rows)],
        "fraction_below_50cm_range":[min(r["fraction_below_50cm"] for r in rows),max(r["fraction_below_50cm"] for r in rows)],
        "centroid_m_range":[min(r["centroid_m"] for r in rows),max(r["centroid_m"] for r in rows)],
        "bottom_export_range":[min(r["tracer_external_output_mass"] for r in rows),max(r["tracer_external_output_mass"] for r in rows)]
      }
    }
    print(json.dumps(out,indent=2,sort_keys=True))
if __name__=="__main__": main(sys.argv[1:])
