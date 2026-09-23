#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib
from rom_purpose_p4_decision_policy import attribution, frontier

RUNGS={"SURF_P":("S8","S12","S16"),"GW_LB":("G8","G12","G16")}

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--prereg",required=True,type=pathlib.Path)
    ap.add_argument("--layer-result",required=True,type=pathlib.Path)
    ap.add_argument("--matched-result",required=True,type=pathlib.Path)
    ap.add_argument("--purpose-map-output",required=True,type=pathlib.Path)
    ap.add_argument("--closeout-output",required=True,type=pathlib.Path)
    ap.add_argument("--markdown-output",required=True,type=pathlib.Path)
    a=ap.parse_args()
    pre=json.loads(a.prereg.read_text()); layer=json.loads(a.layer_result.read_text()); rich=json.loads(a.matched_result.read_text())
    assert pre["phase"]=="PREREGISTERED_BEFORE_ANY_P4_REFERENCE_LAYER_ROM_OR_MATCHED_RICHARDS_RESPONSE"
    case_map={}; purposes={}; any_closure=False; any_unavailable=False; any_layer_missing=False
    any_numerical_gaps=False
    for purpose in ("SURF_P","GW_LB"):
      materials={}
      for material in ("B01","B14"):
        rung_out=[]; first_closure=None
        for member in RUNGS[purpose]:
          l=layer["cases"][purpose][material][member]
          r=rich["cases"][purpose][material][member]
          expected=pre["frozen_representations"][purpose][member]
          if l["boundaries_cm"]!=expected or r["boundaries_cm"]!=expected:
            raise ValueError(f"Same-partition contract drift: {purpose}/{material}/{member}")
          lq=l["status"]=="QUALIFIED"
          lreach=l["representation_sufficiency"]=="REPRESENTATION_COMPARATOR_REACHED"
          rq=r["numerical_qualification"]["qualified"]
          rreach=r["comparator_reached"]
          cls=attribution(lq,lreach,rq,rreach)
          if not lq or not rq: any_unavailable=True
          if cls=="CLOSURE_DEFICIT_SUPPORTED_AT_RUNG":
            any_closure=True
            if first_closure is None: first_closure=member
          rung_out.append({"member":member,"dimension":int(member[1:]),"layer_rom_reaches":lreach,
                           "layer_rom_numerically_qualified":lq,
                           "matched_richards_numerically_qualified":rq,"matched_richards_reaches":rreach,
                           "attribution":cls})
        lf=frontier([(x["member"],x["layer_rom_numerically_qualified"],x["layer_rom_reaches"]) for x in rung_out])
        rf=frontier([(x["member"],x["matched_richards_numerically_qualified"],x["matched_richards_reaches"]) for x in rung_out])
        lmin=lf["minimum_tested_state_count"]
        rmin=rf["minimum_tested_state_count"]
        if lmin!=layer["decisions"][purpose][material]["minimum_tested_state_count"]:
            raise ValueError("Layer-ROM minimum does not match qualified lower-rung evidence")
        if rmin!=rich["decisions"][purpose][material]["minimum_tested_matched_richards_state_count"]:
            raise ValueError("Richards minimum does not match qualified lower-rung evidence")
        if lf["unqualified_members"] or rf["unqualified_members"]: any_numerical_gaps=True
        if lmin is None: any_layer_missing=True
        if lmin is not None:
            state_limit=f"Comparator reached by Layer-ROM at minimum tested {lmin}-state rung."
        elif lf["first_comparator_reaching_member"] is not None:
            state_limit=("Layer-ROM reaches the comparator at "+lf["first_comparator_reaching_member"]+
                         ", but an unqualified lower rung prevents a minimum-state-count claim.")
        elif lf["unqualified_members"]:
            state_limit="Layer-ROM frontier is unresolved because numerical qualification is incomplete."
        else:
            state_limit="Layer-ROM comparator frontier not reached within the frozen 16-state P4 ladder."
        if rmin is not None:
            resolution_limit=f"Matched conventional Richards first reaches the comparator at tested {rmin}-cell rung."
        elif rf["first_comparator_reaching_member"] is not None:
            resolution_limit=("Matched Richards reaches the comparator at "+rf["first_comparator_reaching_member"]+
                              ", but an unqualified lower rung prevents a minimum-cell-count claim.")
        elif rf["unqualified_members"]:
            resolution_limit="Matched Richards frontier is unresolved because numerical qualification is incomplete."
        else:
            resolution_limit="Matched conventional Richards comparator frontier not reached within the frozen 16-cell P4 ladder."
        closure_limit=("The first tested rung supporting a propagation/closure deficit is "+first_closure+" for this tested case."
                       if first_closure else "No propagation/closure deficit is identified by the frozen P4 rung comparisons.")
        materials[material]={
          "minimum_tested_layer_rom_state_count":lmin,
          "minimum_tested_matched_richards_state_count":rmin,
          "layer_frontier_evidence":lf,
          "matched_richards_frontier_evidence":rf,
          "state_information_limit":state_limit,
          "spatial_resolution_limit":resolution_limit,
          "propagation_closure_limit":closure_limit,
          "first_closure_deficit_rung":first_closure,
          "rungs":rung_out,
          "application_authority_status":"NOT_ADJUDICATED_IN_ROM_PURPOSE_P4"
        }
        case_map[f"{purpose}/{material}"]={
          "layer_minimum":lmin,"richards_minimum":rmin,"first_closure_deficit_rung":first_closure,
          "layer_frontier_status":lf["frontier_status"],"richards_frontier_status":rf["frontier_status"],
          "terminal_attribution":rung_out[-1]["attribution"]
        }
      purposes[purpose]={"materials":materials,
                         "physical_support_region":("surface through 80 cm plus profile propagation" if purpose=="SURF_P"
                                                    else "lower-column transmission, storage memory and lower-boundary response")}
    if any_numerical_gaps:
        status="P4_CLOSED_FRONTIER_EVIDENCE_INCOMPLETE_NUMERICAL_GAPS"
    elif any_layer_missing and any_unavailable:
        status="P4_CLOSED_LAYER_FRONTIER_PARTLY_NOT_REACHED_ATTRIBUTION_PARTLY_UNAVAILABLE"
    elif any_layer_missing and any_closure:
        status="P4_CLOSED_LAYER_FRONTIER_PARTLY_NOT_REACHED_CLOSURE_DEFICIT_IDENTIFIED"
    elif any_layer_missing:
        status="P4_CLOSED_REPRESENTATION_RESOLUTION_FRONTIER_NOT_REACHED"
    elif any_closure:
        status="P4_CLOSED_LAYER_FRONTIER_IDENTIFIED_WITH_CLOSURE_DEFICIT_AT_LOWER_RUNGS"
    else:
        status="P4_CLOSED_LAYER_FRONTIER_IDENTIFIED_NO_CLOSURE_DEFICIT_SUPPORTED"
    purpose_map={
      "schema":"swap5.rom-purpose.p4.purpose-map.v1","workstream":"ROM-PURPOSE","status":"P4_RESEARCH_MAP_PERSISTED",
      "scope":"Prospectively frozen S8/S12/S16 and G8/G12/G16 frontier extension on fresh blind histories.",
      "purposes":purposes,"application_authority_status":"NOT_ADJUDICATED_IN_ROM_PURPOSE_P4",
      "scientific_firewall":{"application_acceptance_adjudicated":False,"performance_claim_authorized":False,
                             "production_rom_authorized":False,"new_closure_family_admitted":False}}
    closeout={
      "schema":"swap5.rom-purpose.p4.closeout.v1","workstream":"ROM-PURPOSE","work_unit":"ROM-PURPOSE-P4",
      "status":status,"central_question":pre["central_question"],"case_outcomes":case_map,
      "layer_result":str(a.layer_result),"matched_richards_result":str(a.matched_result),
      "purpose_map":str(a.purpose_map_output),"terminal_dimension":16,
      "closure_workstream_recommendation":("Separate prospectively governed closure research is scientifically motivated only for the exact cases/rungs classified CLOSURE_DEFICIT_SUPPORTED_AT_RUNG."
                                           if any_closure else "No separate closure workstream is supported by P4 evidence."),
      "claims_not_made":["mathematical minimum","universal minimum","all-soil minimum","application acceptance",
                         "production-ROM admission","performance or speedup","replacement of Reference Richards"],
      "scientific_firewall":{"p3_reopened":False,"boundaries_retuned_after_response":False,"closure_tuned":False,
                             "weighted_general_score_used":False,"application_acceptance_adjudicated":False,
                             "production_rom_authorized":False}
    }
    lines=["# ROM-PURPOSE P4 closeout","",f"**Status:** {status}","",
           "P4 extended the prospectively frozen purpose-aligned representation frontier from 8 to 12 and 16 states/cells and compared Layer-ROM with conventional Richards on exactly the same partitions.","",
           "| Purpose | Material | Layer-ROM minimum | Richards minimum | First closure-deficit rung | Terminal attribution |",
           "| --- | --- | ---: | ---: | --- | --- |"]
    for purpose in ("SURF_P","GW_LB"):
      for material in ("B01","B14"):
        x=case_map[f"{purpose}/{material}"]
        lines.append(f"| {purpose} | {material} | {x['layer_minimum'] if x['layer_minimum'] is not None else 'not established'} | {x['richards_minimum'] if x['richards_minimum'] is not None else 'not established'} | {x['first_closure_deficit_rung'] or 'none'} | {x['terminal_attribution']} |")
    lines += ["","This remains a research qualification result. Application acceptance belongs to ROM-ACCEPT; P4 does not admit a production ROM or a new closure family."]
    for path,obj in ((a.purpose_map_output,purpose_map),(a.closeout_output,closeout)):
      path.parent.mkdir(parents=True,exist_ok=True); path.write_text(json.dumps(obj,indent=2,sort_keys=True)+"\n")
    a.markdown_output.parent.mkdir(parents=True,exist_ok=True); a.markdown_output.write_text("\n".join(lines)+"\n")
    print(json.dumps({"status":status,"case_outcomes":case_map},sort_keys=True)); return 0

if __name__=="__main__": raise SystemExit(main())
