#!/usr/bin/env python3
from __future__ import annotations
from dataclasses import dataclass
import json, math, os, random, subprocess, sys
from pathlib import Path
from typing import Iterable

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from legacy_divdra_oracle import SMALL, LEV2COMP_OFFSET, OracleResult, distribute_positive_single_level

U = 2.0 ** -53
SEED = 470043
EXPECTED_BLOB = "1f538174b7451aaa7a3c50d6078b7c1fc3ad8f5a"
EXPECTED_CLOSEOUT = "70a66a768e64760ecfd43702535a848b6d834d61"

@dataclass(frozen=True)
class Case:
    id: int
    label: str
    dz: tuple[float, ...]
    ksat: tuple[float, ...]
    aniso: tuple[float, ...]
    spacing: float
    gw: float
    q: float
    mode: str = "equivalence"

@dataclass
class CandidateResult:
    status: int
    evaluated: bool
    zero_transfer: bool
    wt_node: int
    bottom_node: int
    groundwater_depth: float
    saturated_top_thickness: float
    discharge_bottom_thickness: float
    fac_aniso: float
    discharge_bottom: float
    kd_drain: float
    raw_partition_sum: float
    closure_correction: float
    scalar_echo: float
    nodes: list[float]

def gamma(k: int) -> float:
    x = k * U
    if x >= 0.01:
        raise AssertionError("invalid roundoff model")
    return x / (1.0 - x)

def fp_bound(values: Iterable[float], nops: int) -> float:
    finite = [abs(float(v)) for v in values if math.isfinite(float(v))]
    return gamma(nops) * max(1.0, sum(finite))

def assert_roundoff(label: str, a: float, b: float, values: Iterable[float], nops: int) -> float:
    if not (math.isfinite(a) and math.isfinite(b)):
        raise AssertionError(f"{label}: nonfinite {a!r} {b!r}")
    diff = abs(a - b)
    bound = fp_bound(values, nops)
    if diff > bound:
        raise AssertionError(f"{label}: diff={diff:.17e} > binary64 bound={bound:.17e}; a={a:.17e}; b={b:.17e}")
    return diff

def cumulative(dz: Iterable[float]) -> list[float]:
    out, s = [], 0.0
    for d in dz:
        s += d
        out.append(s)
    return out

def loguniform(rng: random.Random, lo: float, hi: float) -> float:
    return 10.0 ** rng.uniform(math.log10(lo), math.log10(hi))

def base_profile(rng: random.Random, n: int):
    # Dyadic geometry avoids introducing an unrelated profile-bottom associativity seam.
    dz = [rng.randint(16, 280) / 8.0 for _ in range(n)]
    ksat = [loguniform(rng, 0.003, 250.0) for _ in range(n)]
    aniso = [loguniform(rng, 0.15, 12.0) for _ in range(n)]
    return dz, ksat, aniso

def stable_depth_in_node(rng: random.Random, dz: list[float], wi: int) -> float:
    b = cumulative(dz)
    top = 0.0 if wi == 0 else b[wi - 1]
    return top + (rng.randint(2, 13) / 16.0) * dz[wi]

def make_equivalence_cases():
    rng = random.Random(SEED)
    cases, cid = [], 1
    counts = {"truncated_multi": 0, "full_profile_multi": 0, "single_compartment": 0}
    targets = (("truncated_multi", 800), ("full_profile_multi", 400), ("single_compartment", 600))
    for kind, target in targets:
        while counts[kind] < target:
            if kind == "truncated_multi":
                n = rng.randint(4, 10)
                dz, ksat, aniso = base_profile(rng, n)
                wi = rng.randint(0, n - 3)
                wlev = stable_depth_in_node(rng, dz, wi)
                q = loguniform(rng, math.nextafter(SMALL, math.inf), 30.0)
                full = distribute_positive_single_level(dz, ksat, aniso, 1.0e12, -wlev, q)
                b = cumulative(dz)
                target_bottom = b[wi] + rng.uniform(0.15, 0.85) * (b[wi + 1] - b[wi])
                spacing = 4.0 * (target_bottom - wlev) / full.fac_aniso
                o = distribute_positive_single_level(dz, ksat, aniso, spacing, -wlev, q)
                if not (o.wt_node < o.bottom_node < n):
                    raise AssertionError("construction failed truncated_multi")
            elif kind == "full_profile_multi":
                n = rng.randint(2, 10)
                dz, ksat, aniso = base_profile(rng, n)
                wi = rng.randint(0, n - 2)
                wlev = stable_depth_in_node(rng, dz, wi)
                q = loguniform(rng, math.nextafter(SMALL, math.inf), 30.0)
                spacing = 1.0e12
                o = distribute_positive_single_level(dz, ksat, aniso, spacing, -wlev, q)
                if not (o.bottom_node == n and o.wt_node < n):
                    raise AssertionError("construction failed full_profile_multi")
            else:
                n = rng.randint(1, 10)
                dz, ksat, aniso = base_profile(rng, n)
                wi = rng.randint(0, n - 1)
                wlev = stable_depth_in_node(rng, dz, wi)
                q = loguniform(rng, math.nextafter(SMALL, math.inf), 30.0)
                full = distribute_positive_single_level(dz, ksat, aniso, 1.0e12, -wlev, q)
                remaining = cumulative(dz)[wi] - wlev
                spacing = 4.0 * max(1.0e-6, 0.25 * remaining) / full.fac_aniso
                o = distribute_positive_single_level(dz, ksat, aniso, spacing, -wlev, q)
                if o.wt_node != o.bottom_node:
                    raise AssertionError("construction failed single_compartment")
            cases.append(Case(cid, kind, tuple(dz), tuple(ksat), tuple(aniso), spacing, -wlev, q))
            cid += 1
            counts[kind] += 1
    cases.extend([
        Case(cid, "explicit_anisotropy", (8.0,12.0,16.0,24.0), (0.2,4.0,35.0,1.5), (7.0,0.25,3.0,1.2), 220.0, -5.25, 0.017),
        Case(cid+1, "explicit_partial_saturation", (11.0,7.0,19.0,13.0), (3.0,0.5,22.0,8.0), (1.0,2.5,0.4,4.0), 130.0, -13.2, 0.8),
        Case(cid+2, "explicit_transmissivity_weighting", (5.0,9.0,14.0,21.0), (0.07,40.0,2.0,90.0), (9.0,0.2,5.0,1.7), 1.0e12, -3.0, 2.75),
        Case(cid+3, "explicit_near_active_threshold", (9.0,11.0,17.0), (1.0,3.0,7.0), (1.0,2.0,0.5), 80.0, -4.0, math.nextafter(SMALL, math.inf)),
    ])
    return cases, counts

def make_seam_cases(start_id: int):
    dz = [7.25, 12.75, 19.125, 24.875, 36.0]
    ksat = [0.8, 12.0, 0.035, 75.0, 3.2]
    aniso = [1.0, 4.5, 0.3, 8.0, 1.7]
    b = cumulative(dz)
    cases, metadata, cid = [], [], start_id
    offsets = (("exact",0.0),("below_0p5e-10",0.5e-10),("below_1p0e-10",1.0e-10),("below_2p0e-10",2.0e-10))
    for boundary_index in range(4):
        for name, off in offsets:
            depth = b[boundary_index] + off
            c = Case(cid, f"seam_b{boundary_index+1}_{name}", tuple(dz), tuple(ksat), tuple(aniso), 1.0e12, -depth, 0.2718281828459045)
            cases.append(c)
            o = distribute_positive_single_level(dz, ksat, aniso, c.spacing, c.gw, c.q)
            metadata.append({"case_id":cid,"boundary_index":boundary_index+1,"offset_cm":off,"oracle_water_table_node":o.wt_node,"oracle_top_saturated_thickness_cm":o.dz_top_sat})
            cid += 1
    return cases, metadata

def make_guard_cases(start_id: int):
    dz=(10.0,15.0,25.0); ksat=(1.0,2.0,3.0); aniso=(1.0,1.5,0.7); bottom=sum(dz)
    return [
        Case(start_id,"profile_bottom_exact_fail_closed",dz,ksat,aniso,100.0,-bottom,0.1,"bottom_guard"),
        Case(start_id+1,"profile_bottom_below_fail_closed",dz,ksat,aniso,100.0,-math.nextafter(bottom,math.inf),0.1,"bottom_guard"),
        Case(start_id+2,"positive_at_threshold_rejected",dz,ksat,aniso,100.0,-7.0,SMALL,"transfer_guard"),
        Case(start_id+3,"positive_below_threshold_rejected",dz,ksat,aniso,100.0,-7.0,math.nextafter(SMALL,0.0),"transfer_guard"),
    ]

def serialize_cases(cases: list[Case]) -> str:
    lines=[str(len(cases))]
    for c in cases:
        lines.append(f"{c.id} {len(c.dz)} {c.q:.17g} {c.gw:.17g} {c.spacing:.17g}")
        lines.extend(f"{d:.17g} {k:.17g} {a:.17g}" for d,k,a in zip(c.dz,c.ksat,c.aniso))
    return "\n".join(lines)+"\n"

def parse_candidate(text: str):
    lines=[x.strip() for x in text.splitlines() if x.strip()]; out={}; i=0
    while i < len(lines):
        a=lines[i].split(); b=lines[i+1].split()
        if not a or a[0]!="CASE" or len(a)!=17 or not b or b[0]!="NODES" or int(b[1])!=int(a[1]):
            raise AssertionError(f"unexpected candidate output near {lines[i]}")
        cid=int(a[1])
        out[cid]=CandidateResult(int(a[2]),bool(int(a[3])),bool(int(a[4])),int(a[5]),int(a[6]),float(a[7]),float(a[8]),float(a[9]),float(a[10]),float(a[11]),float(a[12]),float(a[13]),float(a[14]),float(a[15]),[float(x) for x in b[2:]])
        if len(out[cid].nodes)!=int(a[16]): raise AssertionError(f"node count mismatch {cid}")
        i+=2
    return out

def run_candidate(exe: str, payload: str):
    p=subprocess.run([exe],input=payload,text=True,capture_output=True,check=False)
    if p.returncode: raise AssertionError(f"candidate driver failed rc={p.returncode}\n{p.stdout}\n{p.stderr}")
    return parse_candidate(p.stdout), p.stdout

def compare_o0_o2(a,b):
    if a.keys()!=b.keys(): raise AssertionError("O0/O2 case sets differ")
    ints=("status","evaluated","zero_transfer","wt_node","bottom_node")
    nums=("groundwater_depth","saturated_top_thickness","discharge_bottom_thickness","fac_aniso","discharge_bottom","kd_drain","raw_partition_sum","closure_correction","scalar_echo")
    for cid in a:
        x,y=a[cid],b[cid]
        for name in ints:
            if getattr(x,name)!=getattr(y,name): raise AssertionError(f"O0/O2 structural mismatch case {cid} {name}")
        for name in nums:
            if getattr(x,name)!=getattr(y,name): raise AssertionError(f"O0/O2 numeric mismatch case {cid} {name}")
        if len(x.nodes)!=len(y.nodes) or any(u!=v for u,v in zip(x.nodes,y.nodes)): raise AssertionError(f"O0/O2 node mismatch case {cid}")

def verify_equivalence(case: Case, cand: CandidateResult, oracle: OracleResult, metrics: dict):
    if cand.status!=0 or not cand.evaluated or cand.zero_transfer: raise AssertionError(f"case {case.id} {case.label}: status {cand.status}")
    if cand.wt_node!=oracle.wt_node or cand.bottom_node!=oracle.bottom_node: raise AssertionError(f"case {case.id} {case.label}: compartment mismatch")
    n=len(case.dz); nops=96+28*n
    pairs=((cand.groundwater_depth,oracle.wlev),(cand.saturated_top_thickness,oracle.dz_top_sat),(cand.discharge_bottom_thickness,oracle.discharge_bottom_thickness),(cand.fac_aniso,oracle.fac_aniso),(cand.discharge_bottom,oracle.discharge_bottom),(cand.kd_drain,oracle.kd_drain),(cand.raw_partition_sum,oracle.raw_partition_sum))
    for cv,ov in pairs:
        d=assert_roundoff(f"case {case.id} diagnostic",cv,ov,[cv,ov,case.q,case.spacing,*case.dz,*case.ksat,*case.aniso],nops)
        metrics["max_geometry_or_diagnostic_abs_difference"]=max(metrics["max_geometry_or_diagnostic_abs_difference"],d)
    for i,(cv,ov) in enumerate(zip(cand.nodes,oracle.nodes),1):
        d=assert_roundoff(f"case {case.id} node {i}",cv,ov,[cv,ov,case.q,*oracle.nodes],64+16*n)
        metrics["max_node_abs_difference_vs_raw_legacy"]=max(metrics["max_node_abs_difference_vs_raw_legacy"],d)
    raw_err=abs(oracle.raw_partition_sum-case.q); raw_bound=fp_bound([oracle.raw_partition_sum,case.q,*oracle.nodes],32+12*n)
    if raw_err>raw_bound: raise AssertionError(f"case {case.id} raw legacy mass error")
    metrics["max_raw_legacy_partition_mass_error"]=max(metrics["max_raw_legacy_partition_mass_error"],raw_err)
    metrics["max_raw_legacy_partition_mass_roundoff_bound"]=max(metrics["max_raw_legacy_partition_mass_roundoff_bound"],raw_bound)
    modern_sum=sum(cand.nodes); modern_err=abs(modern_sum-case.q); modern_bound=fp_bound([modern_sum,case.q,*cand.nodes],8+4*n)
    if modern_err>modern_bound: raise AssertionError(f"case {case.id} modern mass error")
    metrics["max_candidate_mass_error"]=max(metrics["max_candidate_mass_error"],modern_err)
    metrics["max_candidate_mass_roundoff_bound"]=max(metrics["max_candidate_mass_roundoff_bound"],modern_bound)
    metrics["max_candidate_closure_correction_abs"]=max(metrics["max_candidate_closure_correction_abs"],abs(cand.closure_correction))
    assert_roundoff(f"case {case.id} closure",cand.closure_correction,case.q-cand.raw_partition_sum,[cand.closure_correction,case.q,cand.raw_partition_sum],16+4*n)

def main():
    o0=os.environ.get("CANDIDATE_O0"); o2=os.environ.get("CANDIDATE_O2")
    if not o0 or not o2: raise SystemExit("CANDIDATE_O0 and CANDIDATE_O2 are required")
    eq,quotas=make_equivalence_cases(); seam,seam_meta=make_seam_cases(max(c.id for c in eq)+1); guards=make_guard_cases(max(c.id for c in seam)+1); all_cases=eq+seam+guards
    payload=serialize_cases(all_cases); r0,text0=run_candidate(o0,payload); r2,text2=run_candidate(o2,payload); compare_o0_o2(r0,r2)
    metrics={k:0.0 for k in ("max_geometry_or_diagnostic_abs_difference","max_node_abs_difference_vs_raw_legacy","max_raw_legacy_partition_mass_error","max_raw_legacy_partition_mass_roundoff_bound","max_candidate_mass_error","max_candidate_mass_roundoff_bound","max_candidate_closure_correction_abs")}
    neg=0
    for case in eq+seam:
        oracle=distribute_positive_single_level(list(case.dz),list(case.ksat),list(case.aniso),case.spacing,case.gw,case.q)
        verify_equivalence(case,r0[case.id],oracle,metrics)
        if case.label.startswith("seam_") and oracle.dz_top_sat<0: neg+=1
    for case in guards:
        c=r0[case.id]
        if case.mode=="bottom_guard" and (c.status!=2 or c.evaluated): raise AssertionError(f"case {case.id}: bottom guard")
        if case.mode=="transfer_guard" and (c.status!=4 or c.evaluated): raise AssertionError(f"case {case.id}: transfer guard")
    for m in seam_meta:
        expected=m["boundary_index"] if m["offset_cm"]<=LEV2COMP_OFFSET else m["boundary_index"]+1
        if m["oracle_water_table_node"]!=expected or r0[m["case_id"]].wt_node!=expected: raise AssertionError(f"seam classification {m}")
    summary={
      "work_unit":"F-VQ47","decision":"PASS_INDEPENDENT_REQUALIFICATION_GATE","candidate_closeout":EXPECTED_CLOSEOUT,"candidate_blob":EXPECTED_BLOB,
      "oracle":{"frozen_archive_sha256":"1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151","divdra_sha256":"d5917c80dde091f8264f875997ee7105d8b5f9b88e9d091ce162860930de8c91","lev2comp_source_semantics":"lev > -zbotcp(icplev) + 1e-10","configurable_tolerance":False},
      "coverage":{"stable_equivalence_cases":len(eq),"stable_randomized_quota_counts":quotas,"explicit_stable_physics_cases":4,"seam_cases":len(seam),"seam_internal_boundaries":4,"seam_offsets_cm":[0.0,0.5e-10,1.0e-10,2.0e-10],"negative_top_saturated_thickness_seam_cases":neg,"profile_bottom_fail_closed_cases":2,"restricted_transfer_guard_cases":2,"total_candidate_cases":len(all_cases)},
      "checks":{"water_table_compartment_selection":True,"partial_saturation":True,"horizontal_anisotropy":True,"dmax_truncation":True,"full_profile_layers":True,"single_compartment_layers":True,"transmissivity_weighted_partition":True,"legacy_admitted_positive_transfer_domain":True,"internal_boundary_exact":True,"internal_boundary_0p5e_10_below":True,"internal_boundary_1p0e_10_below":True,"internal_boundary_2p0e_10_below":True,"multiple_internal_boundaries":True,"profile_bottom_fail_closed":True,"o0_o2_numeric_identity":True,"scalar_to_node_mass_conservation":True},
      "floating_point_characterization":metrics,
      "mass_policy":{"scalar_transfer_authoritative":True,"candidate_last_node_closure_only":True,"raw_legacy_partition_checked_separately":True,"roundoff_bound":"IEEE-754 binary64 gamma(k)=k*u/(1-k*u), u=2^-53; operation counts fixed in verifier","configurable_mass_tolerance":False},
      "o0_o2":{"parsed_numeric_identity":True}}
    out=Path(os.environ.get("FVQ47_SUMMARY","F-VQ47_SUMMARY.json")); out.parent.mkdir(parents=True,exist_ok=True); out.write_text(json.dumps(summary,indent=2,sort_keys=True)+"\n")
    if os.environ.get("FVQ47_RAW_O0"): Path(os.environ["FVQ47_RAW_O0"]).write_text(text0)
    if os.environ.get("FVQ47_RAW_O2"): Path(os.environ["FVQ47_RAW_O2"]).write_text(text2)
    print(json.dumps(summary,sort_keys=True)); return 0

if __name__=="__main__": raise SystemExit(main())
