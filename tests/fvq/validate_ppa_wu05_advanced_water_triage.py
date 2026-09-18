#!/usr/bin/env python3
import argparse
import json
import subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def require(c,m):
    if not c:
        raise SystemExit("PPA_WU05_FAIL "+m)

def text(p): return (ROOT/p).read_text()
def load(p): return json.loads(text(p))

def changed(prefix):
    subprocess.run(["git","fetch","origin","integration/f-ci-canonical","--quiet"],cwd=ROOT,check=True)
    base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],cwd=ROOT,text=True).strip()
    return [x for x in subprocess.check_output(["git","diff","--name-only",base,"HEAD","--",prefix],cwd=ROOT,text=True).splitlines() if x]

def authority():
    manifest=text("reference/swap-4.3.1/b1-manifest.yml")
    p1=text("reference/swap-4.3.1/patches/SWAP-001/README.md")
    p7=text("reference/swap-4.3.1/patches/SWAP-007/README.md")
    ci31=load("integration/f-ci/F-CI31_STATUS.json")
    ci43=load("integration/f-ci/F-CI43_STATUS.json")
    graph=load("integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json")
    require('snapshot: "B1.11"' in manifest,"B1.11 authority missing")
    require("24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2" in manifest,"manifest drift")
    require("f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f" in p1,"corrected macropore authority missing")
    require("8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87" in p7,"corrected oxygen authority missing")
    nonclaims=" ".join(ci31["nonclaims"]).lower()
    for term in ("oxygen","salinity","frost","compensation","micro","macropore"):
        require(term in nonclaims,f"F-CI31 no longer holds {term}")
    holds=" ".join(ci43["hard_holds"]).lower()
    for term in ("frost","phase-change","latent-heat"):
        require(term in holds,f"F-CI43 hard hold missing {term}")
    require(graph["triage_verdict"]=="DEPENDENCY_GRAPH_FROZEN_FIRST_TARGET_MACROPORE_STATE_TRANSACTION_FOUNDATION","triage verdict drift")
    require(changed("src")==[],"production source mutation")
    require(changed("reference")==[],"reference source mutation")
    print("PPA_WU05_B111_CORRECTED_SOURCE_AUTHORITY=PASS")
    print("PPA_WU05_CURRENT_ROOT_SCOPE_HOLDS=PASS")
    print("PPA_WU05_THERMAL_FROST_NONCONFLATION=PASS")
    print("PPA_WU05_NO_PRODUCTION_OR_REFERENCE_DELTA=PASS")

def independent():
    graph=load("integration/audits/PPA_WU05_DEPENDENCY_GRAPH.json")
    doc=text("docs/audits/PPA_WU05_ADVANCED_WATER_PROCESS_TRIAGE.md")
    fam=graph["families"]
    macro=fam["macropore"]
    frost=fam["frost_hydraulic_modifier"]
    root=fam["advanced_root_stress"]
    require(len(macro["physical_state_evidence"]["committed_history_fields"])==7,"macropore state-field evidence count")
    require("worker/job scratch" in macro["scratch_evidence"]["target_rule"],"macropore scratch owner")
    require(frost["persistent_state"]==[],"legacy frost derived state must remain recomputable")
    require("not authority for explicit ice-content storage" in frost["prohibited_conflation"],"phase-change nonclaim missing")
    require(root["mass_rule"].startswith("All advanced stress/uptake routes must ultimately publish through one accepted"),"single root mass owner missing")
    subs=root["subfamilies"]
    require(subs["salinity"]["authority_maturity"]=="LOW_BLOCKED_BY_SOLUTE_OWNER","salinity dependency")
    require(subs["frost_stress"]["authority_maturity"]=="LOW_BLOCKED_BY_FROST","frost-root dependency")
    require(subs["macropore_related_uptake"]["authority_maturity"]=="BLOCKED_BY_MACROPORE","macro-root dependency")
    require(subs["micro_jong_van_lier"]["state"].startswith("F-PM05 identifies persistent state"),"MICRO state classification")
    ranked=graph["ranked_targets"]
    require(ranked[0]["id"]=="PPA-WU05-A","first target changed")
    require("Macropore committed-state and transaction foundation"==ranked[0]["target"],"first target scope changed")
    require(ranked[0]["implementation_admission"]=="NO_FULL_MACROPORE_PRODUCTION_CLAIM","production overclaim")
    for phrase in (
      "Macropore state and transaction foundation",
      "Legacy Frost Hydraulic Modifier",
      "single physical root-water mass owner",
      "It does **not** establish authority for an explicit ice-content state",
      "PPA-WU05 does not admit macropore, frost or advanced root-stress physics",
    ):
        require(phrase in doc,"narrative/graph mismatch: "+phrase)
    print("PPA_WU05_MACROPORE_STATE_SCRATCH_SEPARATION=PASS")
    print("PPA_WU05_FROST_LEGACY_MODIFIER_DECOMPOSITION=PASS")
    print("PPA_WU05_ADVANCED_ROOT_DEPENDENCY_SPLIT=PASS")
    print("PPA_WU05_SINGLE_ROOT_MASS_OWNER=PASS")
    print("PPA_WU05_FIRST_TARGET_SELECTION=PASS")

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--mode",choices=["authority","independent"],required=True)
    a=p.parse_args()
    authority() if a.mode=="authority" else independent()
    print("PPA_WU05_"+a.mode.upper()+"_TRIAGE=PASS")
if __name__=="__main__": main()
