#!/usr/bin/env python3
"""Validate the F-TB09 integrated-column qualification catalog.

This gate qualifies the catalog/governance contract only. It never upgrades a
catalog specification into executed or scientifically qualified physics.
"""
from __future__ import annotations
import argparse, json, pathlib, re, subprocess, sys

EXPECTED_WORKUNIT="F-TB09"
EXPECTED_TARGET="QUALIFIED_INTEGRATED_COLUMN_PHYSICS_TESTBANK_CATALOG_ESTABLISHED"
EXPECTED_BASE="42544af575db522d012db491db801615577048df"
EXPECTED_POST_BASE="ca1dbf6f51e606bdd2a89aa9057ed40b2d99b868"
EXPECTED_RUNS={
 "F-TB01":("1d039292d5768496c4550a8e1b35a92c6f836504","34553040742"),
 "F-TB02":("549531e2e233cccab1416dba04edb266653a5da5","34559093286"),
 "F-TB03":("65d5e5202446212390dbdd84b06e6b2a80e7121c","34588150201"),
 "F-TB04":("85280c6c436a73c211b70996f9a22f4ad6b04f9c","34620867757"),
 "F-TB05":("81d4f0479a99bc456803f583457862387c267ec0","34621948220"),
 "F-TB06":("163ed723cc4f2277746bdd54f338c4b06e2eaaa9","34642847060"),
 "F-TB07":("4fd0e3a4cb30254135c8da086a733eb3c790b834","34643844345"),
 "F-TB08":("d240d5e90a4cb778429af7286250435cdc4f03c3","34647338808"),
}
REQUIRED_PERMANENT_IDS={
 "SWAP5-TB-DIVDRA-RUNTIME-0001-v1","SWAP5-TB-SURFEVAP-RUNTIME-0001-v1",
 "SWAP5-TB-ROOTUPTAKE-PARALLEL-0001-v1","SWAP5-TB-EFFECTIVE-FORCING-0001-v1",
 "SWAP5-TB-RELEASE-PARALLEL-ROOT-0001-v1","SWAP5-TB-RELEASE-SURFACE-EVAP-0001-v1",
 "SWAP5-TB-RST-SPLIT-0011-v1","SWAP5-TB-RST-MASS-0013-v1",
 "SWAP5-TB-THERMAL-ATOMIC-0001-v1","SWAP5-TB-THERMAL-RESTART-0004-v1",
}
ALLOWED_PROFILES={"FAST","CANONICAL","RELEASE","DEEP"}
ORACLE_ORDER={"O1_MATHEMATICAL_EXACT":1,"O2_MANUFACTURED_SOLUTION":2,"O3_INDEPENDENT_NUMERICAL_REFERENCE":3,"O4_QUALIFIED_FULL_RICHARDS_REFERENCE":4,"O5_LEGACY_SWAP431_SOURCE_BOUND":5,"O6_PROPERTY_INVARIANT":6,"O7_CROSS_SOLVER_CONSISTENCY":7}
CASE_ID=re.compile(r"^SWAP5-TB09-[A-Z0-9-]+-\d{3}-v\d+$")
ALLOWED_CHANGED_PATHS=(".github/workflows/ftb09-integrated-column-physics-catalog.yml","docs/testbank/F-TB09_","testbank/manifests/F-TB09_","testbank/runners/validate_ftb09_","integration/f-tb/F-TB09_","integration/f-tb/RUNLOG_F-TB09.md")
REQUIRED_CASE_KEYS={"stable_id","title","physics_scope","coverage","oracle","water_balance","tolerance_provenance","execution_profiles","expected_diagnostics","theory_equation_refs","architecture_invariants","owner_evidence_reused","execution_state","qualification_state","risk_selection_rationale"}

def fail(msg): raise AssertionError(msg)
def load(path): return json.loads(path.read_text(encoding="utf-8"))
def git(root,*args): return subprocess.check_output(["git","-C",str(root),*args],text=True).strip()
def allowed(path): return any(path==p or path.startswith(p) for p in ALLOWED_CHANGED_PATHS)

def validate_support_only(root,base):
 if base!=EXPECTED_BASE: fail(f"unexpected base {base}")
 subprocess.check_call(["git","-C",str(root),"merge-base","--is-ancestor",base,"HEAD"])
 changed=[p for p in git(root,"diff","--name-only",f"{base}..HEAD").splitlines() if p]
 bad=[p for p in changed if not allowed(p)]
 if bad: fail("Production/non-TB09 paths changed: "+", ".join(bad))
 if not changed: fail("No F-TB09 support changes found")
 return changed

def validate_recheck(root,manifest):
 doc=load(root/"integration/f-tb/F-TB09_AUTHORITY_RECHECK.json")
 if doc.get("workunit")!=EXPECTED_WORKUNIT: fail("wrong recheck workunit")
 if doc.get("composition_base",{}).get("commit")!=EXPECTED_BASE: fail("recheck base drift")
 rows=doc.get("predecessor_exact_head_recheck",[])
 actual={r.get("id"):(r.get("commit"),r.get("exact_head_ci_run")) for r in rows}
 if actual!=EXPECTED_RUNS: fail(f"live predecessor map mismatch: {actual!r}")
 if any(r.get("status")!="SUCCESS" for r in rows): fail("predecessor not exact-head successful")
 chain={r.get("workunit"):r.get("commit") for r in manifest.get("authority_chain",[])}
 if chain!={k:v[0] for k,v in EXPECTED_RUNS.items()}: fail("manifest predecessor commits disagree with recheck")
 cross={x.get("case_id") for x in doc.get("existing_permanent_case_crosswalk",[])}
 missing=REQUIRED_PERMANENT_IDS-cross
 if missing: fail("missing permanent case IDs: "+", ".join(sorted(missing)))
 if any(x.get("disposition")!="REUSE_NOT_DUPLICATE" for x in doc.get("existing_permanent_case_crosswalk",[])): fail("dedup disposition invalid")
 mass=doc.get("mass_notation_clarification",{})
 if "positive signed amount enters" not in mass.get("canonical_accounting_identity",""): fail("signed mass convention missing")
 if "never book both representations" not in mass.get("case_equation_Q_bottom_rule",""): fail("bottom-flux single-booking rule missing")
 if "hard" not in mass.get("tolerance_rule","").lower(): fail("hard mass rule missing")
 post=doc.get("post_base_current_canonical_recheck",{})
 if post.get("live_current_canonical")!=EXPECTED_POST_BASE: fail("post-base canonical pin mismatch")
 if post.get("classification")!="GOVERNANCE_ONLY_NO_TB09_SCOPE_DELTA": fail("post-base delta not governance-only")
 ev=post.get("evidence",{})
 for f in ("production_source_changed","reference_changed","scientific_tolerances_changed","solver_functionality_changed"):
  if ev.get(f) is not False: fail(f"post-base reconciliation changed {f}")
 if ev.get("mass_conservation")!="HARD_UNCHANGED": fail("post-base mass policy changed")
 if doc.get("production_source_changed") is not False or doc.get("mass_conservation_relaxed") is not False: fail("support-only/hard-mass boundary violated")
 return doc

def validate_manifest(doc):
 if doc.get("workunit")!=EXPECTED_WORKUNIT: fail("wrong workunit")
 if doc.get("exit_target")!=EXPECTED_TARGET: fail("wrong exit target")
 if doc.get("qualification_claim")!="CATALOG_AND_ORACLE_CONTRACT_ONLY": fail("physics overclaim")
 if doc.get("catalog_status")!="QUALIFIED_CATALOG_CONTRACT_WHEN_EXACT_HEAD_CI_GREEN": fail("catalog status not conditional")
 op=doc["oracle_policy"]
 if op.get("hierarchy")!=list(ORACLE_ORDER): fail("oracle hierarchy changed")
 if op.get("tb09_uses_legacy_o5") or op.get("corrected_golden_baseline_constructed"): fail("legacy/golden policy violation")
 mass=doc["mass_contract"]
 if not mass.get("required_for_all_water_bearing_cases") or mass.get("soft_mass_tolerance_allowed"): fail("mass gate not hard")
 dims=doc.get("coverage_dimensions",[])
 if len(dims)!=11 or len(set(dims))!=11: fail("coverage dimensions invalid")
 cases=doc.get("cases",[])
 if len(cases)!=8: fail("expected eight bounded cases")
 ids=[c.get("stable_id") for c in cases]
 if len(ids)!=len(set(ids)): fail("duplicate case IDs")
 for c in cases:
  missing=REQUIRED_CASE_KEYS-set(c)
  if missing: fail(f"{c.get('stable_id')}: missing {sorted(missing)}")
  cid=c["stable_id"]
  if not CASE_ID.fullmatch(cid): fail(f"invalid stable ID {cid}")
  if set(c["coverage"])!=set(dims): fail(f"{cid}: coverage keys mismatch")
  active=[d for d,f in c["coverage"].items() if f=="P"]
  if not active or len(active)>doc["pairwise_risk_policy"]["max_primary_interaction_dimensions_per_case"]: fail(f"{cid}: unbounded/empty interaction")
  if any(f not in {"P","-"} for f in c["coverage"].values()): fail(f"{cid}: invalid coverage flag")
  primary=c["oracle"].get("primary_class")
  if primary not in ORACLE_ORDER or primary=="O5_LEGACY_SWAP431_SOURCE_BOUND": fail(f"{cid}: invalid oracle")
  wb=c["water_balance"]
  if not wb.get("required") or wb.get("soft_tolerance_tradeoff_allowed"): fail(f"{cid}: mass not hard")
  for field in ("equation_id","equation","active_storage","inputs","outputs","closure_rule","transaction_rule"):
   if field not in wb or wb[field] in (None,"",[]): fail(f"{cid}: incomplete mass metadata {field}")
  if not any(d=="hard_mass_residual" or d.startswith("hard_mass_residual") for d in c["expected_diagnostics"]): fail(f"{cid}: hard mass diagnostic missing")
  if not c["tolerance_provenance"]: fail(f"{cid}: tolerance provenance missing")
  profiles=set(c["execution_profiles"])
  if not profiles or not profiles<=ALLOWED_PROFILES: fail(f"{cid}: invalid profile")
  if not c["theory_equation_refs"]: fail(f"{cid}: theory refs missing")
  inv=c["architecture_invariants"]
  if 13 not in inv or 30 not in inv or any(not isinstance(i,int) or not 1<=i<=30 for i in inv): fail(f"{cid}: invariant mapping invalid")
  if c["qualification_state"]!="CATALOGED_NOT_PHYSICS_QUALIFIED": fail(f"{cid}: physics overclaim")
 for d in dims:
  if not any(c["coverage"][d]=="P" for c in cases): fail(f"uncovered dimension {d}")
 for a,b in doc["pairwise_risk_policy"]["mandatory_pairs"]:
  if not any(c["coverage"][a]=="P" and c["coverage"][b]=="P" for c in cases): fail(f"missing pair {a} x {b}")
 if not any(c.get("restart_interaction") for c in cases): fail("restart-mid-interaction case missing")
 if not any(c["oracle"].get("primary_class")=="O4_QUALIFIED_FULL_RICHARDS_REFERENCE" for c in cases): fail("O4 integrated reference case missing")
 if doc.get("production_source_changed") is not False or doc.get("source_defects_fixed") is not False or doc.get("integrated_physics_results_qualified") is not False: fail("scope/qualification boundary violated")

def validate_closeout(root):
 status=load(root/"integration/f-tb/F-TB09_QUALIFICATION_STATUS.json")
 contract=load(root/"integration/f-tb/F-TB09_WORK_UNIT_CONTRACT.json")
 if status.get("decision")!=EXPECTED_TARGET: fail("closeout decision mismatch")
 if status.get("authority_recheck")!="integration/f-tb/F-TB09_AUTHORITY_RECHECK.json": fail("status lacks final recheck authority")
 if status.get("integrated_physics_results_qualified") is not False: fail("status overclaims physics")
 if contract.get("exit_target")!=EXPECTED_TARGET: fail("contract exit mismatch")
 if contract.get("qualification",{}).get("mass_conservation")!="HARD_FOR_EVERY_WATER_BEARING_CASE": fail("contract weakens mass")

def main():
 p=argparse.ArgumentParser(); p.add_argument("--manifest",required=True); p.add_argument("--base",required=True); p.add_argument("--repo-root",default="."); a=p.parse_args()
 root=pathlib.Path(a.repo_root).resolve(); mp=(root/a.manifest).resolve()
 if root not in mp.parents: fail("manifest outside repo")
 manifest=load(mp); validate_manifest(manifest); validate_recheck(root,manifest); validate_closeout(root); changed=validate_support_only(root,a.base)
 print("F-TB09 catalog contract: PASS"); print(f"cases={len(manifest['cases'])}"); print("predecessor_authorities=8 exact-head success"); print("permanent_case_crosswalk=PASS"); print("post_base_canonical_reconciliation=GOVERNANCE_ONLY_NO_SCOPE_DELTA"); print("mass_policy=HARD_UNCHANGED"); print("changed_paths="+",".join(changed)); print(EXPECTED_TARGET); return 0

if __name__=="__main__":
 try: raise SystemExit(main())
 except (AssertionError,subprocess.CalledProcessError,json.JSONDecodeError,KeyError) as exc:
  print(f"F-TB09 catalog contract: FAIL: {exc}",file=sys.stderr); raise SystemExit(1)
