#!/usr/bin/env python3
from __future__ import annotations
import argparse, collections, json, math, pathlib

PROBES=("HOLD","TOP_PLUS","BOTTOM_HEAD_RISE","BOTTOM_HEAD_FALL")
HORIZONS=(4,16,64)
COORDS=("Z1","Z2","Z4","Z8")

def fields(payload: str) -> dict[str,str]:
    out={}
    for part in payload.split("|"):
        if "=" in part:
            k,v=part.split("=",1)
            out[k]=v
    return out

def hist_step_key(d):
    return (d["history"], int(d["step"]))

def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input",required=True)
    ap.add_argument("--repeat",required=True)
    ap.add_argument("--discovery",required=True)
    ap.add_argument("--manifest",required=True)
    ap.add_argument("--prereg",required=True)
    ap.add_argument("--output",required=True)
    args=ap.parse_args()

    raw=pathlib.Path(args.input).read_text()
    repeat=pathlib.Path(args.repeat).read_text()
    discovery=pathlib.Path(args.discovery).read_text()
    manifest=json.loads(pathlib.Path(args.manifest).read_text())
    prereg=json.loads(pathlib.Path(args.prereg).read_text())
    repeat_identity=(raw==repeat)

    pair_scales=prereg["numerical_reference_scales"]["pairwise_response_separation_scales"]
    thresholds={
      "total":float(pair_scales["total_storage_cm"]),
      "upper":float(pair_scales["upper_0_40cm_storage_cm"]),
      "lower":float(pair_scales["lower_40_160cm_storage_cm"]),
    }

    expected_starts=set()
    for z in COORDS:
        rows=manifest["manifests"][z]
        if len(rows)!=8:
            raise SystemExit(f"{z} frozen manifest does not contain 8 pairs")
        for pair in rows:
            expected_starts.add((pair["a"]["history"],int(pair["a"]["step"])))
            expected_starts.add((pair["b"]["history"],int(pair["b"]["step"])))

    discovery_nodes={}
    for line in discovery.splitlines():
        if "ROM1AR1D3_NODE|" not in line:
            continue
        r=fields(line.split("ROM1AR1D3_NODE|",1)[1])
        key=(r["HISTORY"],int(r["STEP"]))
        if key not in expected_starts:
            continue
        discovery_nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))

    start_nodes={}
    probe_rows={}
    fallback_classes=collections.Counter()
    unique_start_marker=None
    heldout_marker=None
    b14_marker=None
    for line in raw.splitlines():
        if "ROM1B2_START_NODE|" in line:
            r=fields(line.split("ROM1B2_START_NODE|",1)[1])
            key=(r["HISTORY"],int(r["STEP"]))
            start_nodes.setdefault(key,{})[int(r["NODE"])]=(float(r["H"]),float(r["THETA"]))
        elif "ROM1B2_PROBE|" in line:
            r=fields(line.split("ROM1B2_PROBE|",1)[1])
            key=(r["HISTORY"],int(r["START_STEP"]),r["PROBE"],int(r["HORIZON_STEP"]))
            if key in probe_rows:
                raise SystemExit(f"duplicate probe row {key}")
            probe_rows[key]={
              "d_total":float(r["D_TOTAL_STORAGE"]),
              "d_upper":float(r["D_UPPER_STORAGE"]),
              "d_lower":float(r["D_LOWER_STORAGE"]),
              "cum_top":float(r["CUM_TOP_EXCHANGE"]),
              "cum_bottom":float(r["CUM_BOTTOM_OUTWARD_EXCHANGE"]),
              "terminal_bottom_flux":float(r["TERMINAL_BOTTOM_FLUX"]),
              "fallback_count":int(r["FALLBACK_COUNT"]),
              "max_abs_mass":float(r["MAX_ABS_MASS"]),
            }
        elif "ROM1B2_FALLBACK|" in line:
            r=fields(line.split("ROM1B2_FALLBACK|",1)[1])
            fallback_classes[r.get("CLASS","UNKNOWN")]+=1
        elif "ROM1B2_UNIQUE_START_COUNT=" in line:
            unique_start_marker=int(line.rsplit("=",1)[1])
        elif "ROM1B2_HELDOUT_USED=" in line:
            heldout_marker=line.rsplit("=",1)[1].strip()
        elif "ROM1B2_B14_USED=" in line:
            b14_marker=line.rsplit("=",1)[1].strip()

    start_identity=True
    identity_failures=[]
    for key in sorted(expected_starts):
        dn=discovery_nodes.get(key,{})
        sn=start_nodes.get(key,{})
        if set(dn)!=set(range(1,17)) or set(sn)!=set(range(1,17)):
            start_identity=False
            identity_failures.append({"history":key[0],"step":key[1],"reason":"missing_node_record"})
            continue
        for node in range(1,17):
            if dn[node] != sn[node]:
                start_identity=False
                identity_failures.append({
                  "history":key[0],"step":key[1],"node":node,
                  "discovery_h":dn[node][0],"probe_h":sn[node][0],
                  "discovery_theta":dn[node][1],"probe_theta":sn[node][1],
                })
                break

    expected_probe_keys={
      (h,s,p,hor)
      for h,s in expected_starts
      for p in PROBES
      for hor in HORIZONS
    }
    probe_structure=(set(probe_rows)==expected_probe_keys)
    max_mass=max((abs(v["max_abs_mass"]) for v in probe_rows.values()),default=math.inf)
    hard_mass_pass=math.isfinite(max_mass) and max_mass<=1e-12

    coordinate_results={}
    all_records=[]
    for z in COORDS:
        ambiguity_records=0
        ambiguous_pairs=set()
        max_diff={"total":0.0,"upper":0.0,"lower":0.0}
        max_ratio={"total":0.0,"upper":0.0,"lower":0.0}
        max_exchange={"top":0.0,"bottom":0.0,"terminal_bottom_flux":0.0}
        examples=[]
        for ipair,pair in enumerate(manifest["manifests"][z],start=1):
            ka=(pair["a"]["history"],int(pair["a"]["step"]))
            kb=(pair["b"]["history"],int(pair["b"]["step"]))
            pair_ambiguous=False
            for probe in PROBES:
                for hor in HORIZONS:
                    a=probe_rows.get((ka[0],ka[1],probe,hor))
                    b=probe_rows.get((kb[0],kb[1],probe,hor))
                    if a is None or b is None:
                        continue
                    dtot=abs(a["d_total"]-b["d_total"])
                    dupp=abs(a["d_upper"]-b["d_upper"])
                    dlow=abs(a["d_lower"]-b["d_lower"])
                    ratios={
                      "total":dtot/thresholds["total"] if thresholds["total"]>0 else math.inf,
                      "upper":dupp/thresholds["upper"] if thresholds["upper"]>0 else math.inf,
                      "lower":dlow/thresholds["lower"] if thresholds["lower"]>0 else math.inf,
                    }
                    ambiguous=(dtot>thresholds["total"] or dupp>thresholds["upper"] or dlow>thresholds["lower"])
                    if ambiguous:
                        ambiguity_records+=1
                        pair_ambiguous=True
                    max_diff["total"]=max(max_diff["total"],dtot)
                    max_diff["upper"]=max(max_diff["upper"],dupp)
                    max_diff["lower"]=max(max_diff["lower"],dlow)
                    for k in max_ratio:
                        max_ratio[k]=max(max_ratio[k],ratios[k])
                    etop=abs(a["cum_top"]-b["cum_top"])
                    ebot=abs(a["cum_bottom"]-b["cum_bottom"])
                    eflux=abs(a["terminal_bottom_flux"]-b["terminal_bottom_flux"])
                    max_exchange["top"]=max(max_exchange["top"],etop)
                    max_exchange["bottom"]=max(max_exchange["bottom"],ebot)
                    max_exchange["terminal_bottom_flux"]=max(max_exchange["terminal_bottom_flux"],eflux)
                    if ambiguous:
                        examples.append({
                          "pair_index":ipair,
                          "a":{"history":ka[0],"step":ka[1]},
                          "b":{"history":kb[0],"step":kb[1]},
                          "probe":probe,
                          "horizon_steps":hor,
                          "response_difference":{
                            "total_storage_cm":dtot,
                            "upper_0_40cm_storage_cm":dupp,
                            "lower_40_160cm_storage_cm":dlow,
                          },
                          "ratio_to_pairwise_reference_scale":ratios,
                          "diagnostic_exchange_difference":{
                            "cumulative_top_exchange_cm":etop,
                            "cumulative_bottom_outward_exchange_cm":ebot,
                            "terminal_bottom_flux_cm_per_day":eflux,
                          },
                          "max_storage_ratio":max(ratios.values()),
                        })
            if pair_ambiguous:
                ambiguous_pairs.add(ipair)
        examples.sort(key=lambda e:(-e["max_storage_ratio"],e["pair_index"],e["probe"],e["horizon_steps"]))
        coordinate_results[z]={
          "pair_count":8,
          "comparison_record_count":8*len(PROBES)*len(HORIZONS),
          "ambiguity_record_count":ambiguity_records,
          "ambiguous_pair_count":len(ambiguous_pairs),
          "discovery_storage_ambiguity_established":ambiguity_records>0,
          "maximum_storage_response_difference_cm":{
            "total":max_diff["total"],"upper":max_diff["upper"],"lower":max_diff["lower"]
          },
          "maximum_ratio_to_pairwise_reference_scale":max_ratio,
          "maximum_diagnostic_exchange_difference":{
            "cumulative_top_exchange_cm":max_exchange["top"],
            "cumulative_bottom_outward_exchange_cm":max_exchange["bottom"],
            "terminal_bottom_flux_cm_per_day":max_exchange["terminal_bottom_flux"],
          },
          "top_predictive_ambiguity_examples":examples[:8],
        }
        all_records.extend(examples)

    survivors=[z for z in COORDS if not coordinate_results[z]["discovery_storage_ambiguity_established"]]
    all_reduced_ambiguous=(len(survivors)==0)
    complete=(
      repeat_identity and start_identity and probe_structure and hard_mass_pass and
      unique_start_marker==len(expected_starts) and heldout_marker=="FALSE" and b14_marker=="FALSE" and
      "ROM1B2_EXECUTION_COMPLETE=PASS" in raw
    )
    decision="ROM1B2_DISCOVERY_PREDICTIVE_AMBIGUITY_COMPLETE" if complete else "ROM1B2_EVIDENCE_BLOCKED"
    result={
      "schema":"swap5.rom1b2.result.v1",
      "workstream":"F-ROM",
      "work_unit":"ROM-1B2",
      "decision":decision,
      "repeat_stdout_bitwise_identity":repeat_identity,
      "frozen_pair_manifest_source":manifest["source_result"],
      "unique_start_state_count":len(expected_starts),
      "start_state_identity_with_B1_discovery":start_identity,
      "start_identity_failures":identity_failures[:8],
      "probe_record_count":len(probe_rows),
      "expected_probe_record_count":len(expected_probe_keys),
      "probe_structure_complete":probe_structure,
      "pairwise_storage_reference_scales_cm":thresholds,
      "coordinate_results":coordinate_results,
      "reduced_coordinate_storage_survivors":survivors,
      "all_Z1_Z2_Z4_Z8_discovery_storage_ambiguous":all_reduced_ambiguous,
      "fallback_class_counts":dict(fallback_classes),
      "max_abs_committed_mass_residual_cm":max_mass,
      "hard_mass_gate_pass":hard_mass_pass,
      "heldout_used":False,
      "B14_used":False,
      "future_probe_pair_reselection":False,
      "exchange_outputs_formal_ambiguity_role":"DIAGNOSTIC_ONLY",
      "coordinate_selected_final":False,
      "production_rom_authorized":False,
    }
    pathlib.Path(args.output).write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps(result,sort_keys=True))
    return 0 if complete else 2

if __name__=="__main__":
    raise SystemExit(main())
