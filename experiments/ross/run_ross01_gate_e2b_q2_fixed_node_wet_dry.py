from __future__ import annotations

import hashlib
import json
import math
import multiprocessing as mp
import sys
import time
from pathlib import Path

import numpy as np
from scipy.stats import qmc

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_ross01_gate_c1 as c1

CONTRACT = "F-ROSS01_GATE_E2B_Q2_FIXED_NODE_WET_DRY_FACE_CHARACTERIZATION_CONTRACT.json"
CATALOG = Path("integration/f-ross/F-ROSS01_GATE_C1_MATERIAL_CATALOG.json")
MATERIALS = ("B12", "O13", "B01", "O14")
N_UNSAT = 33
N_SAT = 17
N_DRY = 241
H_WET_MIN = -1.0
H_WET_MAX = 1.0
H_DRY_MIN = -10000.0
LENGTH = 10.0
FRESH_COUNT = 512
TARGET_WET = (-1.0,-0.5,-0.1,-0.05,-0.02,-0.01,-0.005,-0.001,-1e-6,-1e-9,0.0,1e-9,1e-6,0.001,0.01,0.1,0.5,1.0)
TARGET_DRY = (-1.0,-2.0,-10.0,-100.0,-1000.0,-10000.0)
HYBRID_MAX = 0.01
HYBRID_P99 = 0.002
ABS_KSAT_MAX = 0.0005
CTX = mp.get_context("fork")
WITNESSES = {
    "B12": ((-0.07915189862251282,-3525.2238122379467),(-0.011933669447898865,-1.994237053678148)),
    "O13": ((-0.23973708227276802,-1347.627329861609),(-0.007651396095752716,-141.70309854948502)),
    "B01": ((-0.01,-2.0),),
    "O14": ((-0.0037585031241178513,-161.0527591955003),),
}


def seed_for(material: str) -> int:
    return int(hashlib.sha256(("F-ROSS01-E2B-Q2:" + material).encode()).hexdigest()[:8], 16)


def configure(row: dict) -> None:
    c1.configure_core(row)
    c1.core.H_MIN = H_DRY_MIN
    c1.core.H_MAX = H_WET_MAX


def loc_uniform(x: float, lo: float, hi: float, n: int):
    z = (n - 1) * (x - lo) / (hi - lo)
    if not (-1e-10 <= z <= n - 1 + 1e-10):
        raise ValueError(("coordinate_extrapolation", x, lo, hi, n, z))
    z = min(n - 1.0, max(0.0, z))
    i = min(n - 2, max(0, int(math.floor(z))))
    return z, i, z - i


def q2_stencil(z: float, n: int):
    center = int(math.floor(z + 0.5))
    center = min(n - 2, max(1, center))
    idx = (center - 1, center, center + 1)
    weights = []
    for a in idx:
        w = 1.0
        for b in idx:
            if a != b:
                w *= (z - b) / (a - b)
        weights.append(w)
    return idx, tuple(weights)


def asymptotic_t(h: float) -> float:
    if h >= 0.0:
        return 1.0
    return 1.0 - (-h) ** (float(c1.core.NPAR) - 1.0)


def h_from_t(t: float) -> float:
    if t >= 1.0:
        return 0.0
    return -(max(0.0, 1.0 - t) ** (1.0 / (float(c1.core.NPAR) - 1.0)))


def wet_coord(h: float):
    if h < 0.0:
        t = asymptotic_t(h)
        z, i, f = loc_uniform(t, 0.0, 1.0, N_UNSAT)
        return "UNSAT_ASYMPTOTIC", z, i, f
    z, i, f = loc_uniform(h, 0.0, H_WET_MAX, N_SAT)
    return "SAT_HEAD", z, i, f


def wet_head(branch: str, index: int) -> float:
    if branch == "UNSAT_ASYMPTOTIC":
        return h_from_t(index / (N_UNSAT - 1))
    return H_WET_MAX * index / (N_SAT - 1)


def dry_coord(h: float):
    u = math.log10(-h)
    z, i, f = loc_uniform(u, 0.0, 4.0, N_DRY)
    return z, i, f


def dry_head(index: int) -> float:
    return -(10.0 ** (4.0 * index / (N_DRY - 1)))


def build_probes(material: str):
    sob = qmc.Sobol(d=2, scramble=True, seed=seed_for(material)).random_base2(m=9)[:FRESH_COUNT]
    probes = []
    for i, (a,b) in enumerate(sob):
        probes.append({"id":f"sobol_{i:03d}","kind":"fresh_sobol","h_above":H_WET_MIN+2.0*float(a),"h_below":-(10.0**(4.0*float(b)))})
    for ha in TARGET_WET:
        for hb in TARGET_DRY:
            probes.append({"id":f"target_{ha:.12g}_{hb:.12g}","kind":"targeted","h_above":float(ha),"h_below":float(hb)})
    for j,(ha,hb) in enumerate(WITNESSES[material]):
        probes.append({"id":f"known_witness_{j}","kind":"known_witness","h_above":float(ha),"h_below":float(hb)})
    return probes


def _safe_q(pair):
    ha,hb=pair
    try:
        return pair,float(c1.core.steady_q(float(ha),float(hb))),None
    except Exception as exc:
        return pair,None,repr(exc)


def mobility(ha: float,hb: float,q: float)->float:
    driving=LENGTH+ha-hb
    if abs(driving)<=1e-14:
        raise RuntimeError(("unexpected_zero_driving",ha,hb))
    m=q/driving
    if not(math.isfinite(m) and m>0.0):
        raise RuntimeError(("invalid_mobility",ha,hb,q,driving,m))
    return m


def logm32(qmap,pair):
    ha,hb=pair
    return float(np.float32(math.log(mobility(ha,hb,qmap[pair]))))


def prepare_pairs(probes):
    pairs={(float(p["h_above"]),float(p["h_below"])) for p in probes}
    for p in probes:
        ha,hb=float(p["h_above"]),float(p["h_below"])
        branch,wz,wi,wf=wet_coord(ha)
        dz,di,df=dry_coord(hb)
        wq,_=q2_stencil(wz,N_UNSAT if branch=="UNSAT_ASYMPTOTIC" else N_SAT)
        dq,_=q2_stencil(dz,N_DRY)
        for a in wq:
            for b in dq:
                pairs.add((wet_head(branch,a),dry_head(b)))
        for a in (wi,wi+1):
            for b in (di,di+1):
                pairs.add((wet_head(branch,a),dry_head(b)))
    return sorted(pairs)


def bilinear(v00,v10,v01,v11,fw,fd):
    return (1-fw)*(1-fd)*v00+fw*(1-fd)*v10+(1-fw)*fd*v01+fw*fd*v11


def tensor_q2(values,ww,dw):
    total=0.0
    for ia,wa in enumerate(ww):
        for ib,wb in enumerate(dw):
            total += wa*wb*values[ia][ib]
    return total


def row_metric(p,q_ref,q_cand,ksat,branch,method,details):
    return {
        "probe_id":p["id"],"kind":p["kind"],"h_above":float(p["h_above"]),"h_below":float(p["h_below"]),
        "wet_branch":branch,"method":method,"q_ref":q_ref,"q_candidate":q_cand,
        "hybrid_metric":abs(q_cand-q_ref)/(abs(q_ref)+1e-4*ksat),
        "abs_error_over_ksatfit":abs(q_cand-q_ref)/ksat,
        "wrong_sign":int(abs(q_ref)>1e-8*ksat and q_ref*q_cand<0.0),
        **details,
    }


def summarize(rows):
    hy=sorted(r["hybrid_metric"] for r in rows)
    return {
        "valid_probe_count":len(rows),
        "max_hybrid_metric":max(hy),
        "p99_hybrid_metric":hy[int(0.99*(len(hy)-1))],
        "max_abs_error_over_ksatfit":max(r["abs_error_over_ksatfit"] for r in rows),
        "wrong_sign_count":sum(r["wrong_sign"] for r in rows),
        "unsaturated_wet_branch_max_hybrid":max((r["hybrid_metric"] for r in rows if r["wet_branch"]=="UNSAT_ASYMPTOTIC"),default=0.0),
        "saturated_wet_branch_max_hybrid":max((r["hybrid_metric"] for r in rows if r["wet_branch"]=="SAT_HEAD"),default=0.0),
        "transition_1e9_max_hybrid":max((r["hybrid_metric"] for r in rows if abs(abs(r["h_above"])-1e-9)<=1e-20),default=0.0),
        "known_witness_max_hybrid":max((r["hybrid_metric"] for r in rows if r["kind"]=="known_witness"),default=0.0),
        "worst_probe":max(rows,key=lambda r:r["hybrid_metric"]),
    }


def evaluate_material(row):
    configure(row)
    material=row["sfu"]
    ksat=float(c1.core.KSAT)
    probes=build_probes(material)
    pairs=prepare_pairs(probes)
    qmap={}; errors=[]; started=time.time()
    with CTX.Pool(min(8,mp.cpu_count())) as pool:
        for pair,q,error in pool.imap_unordered(_safe_q,pairs,chunksize=4):
            if error is None:qmap[pair]=q
            else:errors.append({"pair":list(pair),"error":error})
    if errors:
        return {"material":material,"runtime_pass":False,"node_evaluation_failures":len(errors),"failure_examples":errors[:8]}
    q2rows=[]; linrows=[]; lookup_failures=0; nonfinite=0
    for p in probes:
        ha,hb=float(p["h_above"]),float(p["h_below"])
        try:
            branch,wz,wi,wf=wet_coord(ha); dz,di,df=dry_coord(hb)
            widx,ww=q2_stencil(wz,N_UNSAT if branch=="UNSAT_ASYMPTOTIC" else N_SAT)
            didx,dw=q2_stencil(dz,N_DRY)
            vals=[[logm32(qmap,(wet_head(branch,a),dry_head(b))) for b in didx] for a in widx]
            logq2=tensor_q2(vals,ww,dw)
            q_ref=qmap[(ha,hb)]
            driving=LENGTH+ha-hb
            q_q2=driving*math.exp(logq2)
            v00=logm32(qmap,(wet_head(branch,wi),dry_head(di)))
            v10=logm32(qmap,(wet_head(branch,wi+1),dry_head(di)))
            v01=logm32(qmap,(wet_head(branch,wi),dry_head(di+1)))
            v11=logm32(qmap,(wet_head(branch,wi+1),dry_head(di+1)))
            q_lin=driving*math.exp(bilinear(v00,v10,v01,v11,wf,df))
        except Exception:
            lookup_failures+=1; continue
        if not all(map(math.isfinite,(q_ref,q_q2,q_lin))):
            nonfinite+=1; continue
        q2rows.append(row_metric(p,q_ref,q_q2,ksat,branch,"Q2",{
            "wet_index_coordinate":wz,"dry_index_coordinate":dz,
            "wet_stencil_indices":list(widx),"dry_stencil_indices":list(didx),
            "wet_lagrange_weights":list(ww),"dry_lagrange_weights":list(dw)}))
        linrows.append(row_metric(p,q_ref,q_lin,ksat,branch,"BILINEAR",{
            "wet_i":wi,"wet_fraction":wf,"dry_i":di,"dry_fraction":df}))
    q2=summarize(q2rows); baseline=summarize(linrows)
    q2.update({
        "lookup_failures":lookup_failures,"nan_or_inf":nonfinite,"node_evaluation_failures":0,
        "table_loads_per_lookup":9,"runtime_iteration_count":0,"lookup_complexity":"O(1)",
        "additional_shared_table_storage_bytes":0,"per_column_table_state_bytes":0,
        "conceptual_fixed_table_plus_axes_bytes":4*(N_UNSAT+N_SAT-1)*N_DRY+8*((N_UNSAT+N_SAT-1)+N_DRY),
    })
    tests={
        "max_hybrid_metric":q2["max_hybrid_metric"]<=HYBRID_MAX,
        "p99_hybrid_metric":q2["p99_hybrid_metric"]<=HYBRID_P99,
        "max_abs_error_over_ksatfit":q2["max_abs_error_over_ksatfit"]<=ABS_KSAT_MAX,
        "wrong_sign_count":q2["wrong_sign_count"]==0,
        "lookup_failures":lookup_failures==0,
        "nan_or_inf":nonfinite==0,
        "node_evaluation_failures":True,
    }
    q2["tests"]=tests; q2["pass"]=all(tests.values()); q2["failed_metrics"]=[k for k,v in tests.items() if not v]
    return {
        "material":material,"n_parameter":float(c1.core.NPAR),"seed":seed_for(material),
        "fresh_probe_count":FRESH_COUNT,"total_probe_count":len(probes),"oracle_pair_count":len(pairs),
        "q2":q2,"bilinear_baseline":baseline,"runtime_pass":True,"elapsed_seconds_descriptive":time.time()-started,
    }


def main():
    if len(sys.argv)!=2:raise SystemExit("usage: run_ross01_gate_e2b_q2_fixed_node_wet_dry.py OUTPUT.json")
    out=Path(sys.argv[1]); catalog=json.loads(CATALOG.read_text()); by={r["sfu"]:r for r in catalog["rows"]}
    results=[]; started=time.time()
    for i,m in enumerate(MATERIALS,1):
        r=evaluate_material(by[m]); results.append(r)
        print(json.dumps({"progress":f"{i}/{len(MATERIALS)}","material":m,"runtime_pass":r["runtime_pass"],"q2_pass":r.get("q2",{}).get("pass"),"q2_failed":r.get("q2",{}).get("failed_metrics")},sort_keys=True),flush=True)
    runtime_ok=all(r["runtime_pass"] for r in results)
    passed=runtime_ok and all(r["q2"]["pass"] for r in results)
    result={
        "schema_version":1,"workstream":"F-ROSS","work_unit":"F-ROSS01","gate":"E2B_Q2_FIXED_NODE_WET_DRY_FACE_CHARACTERIZATION",
        "contract":CONTRACT,"production_implementation":False,"qualification_use":False,"materials":list(MATERIALS),
        "runtime_ok":runtime_ok,"results":results,"elapsed_seconds_descriptive":time.time()-started,"pass":passed,
        "decision":"FIXED_NODE_Q2_WET_DRY_CHARACTERIZED_READY_FOR_FULL_NEAR_SATURATION_FACE_GATE" if passed else "FIXED_NODE_Q2_REJECTED_STOP_PRECOMPUTED_NEAR_SATURATION_FACE_TABLE_APPROACH",
        "hard_guard":"No new nodes or coordinates were introduced; characterization only."
    }
    out.write_text(json.dumps(result,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:v for k,v in result.items() if k!="results"},sort_keys=True),flush=True)
    raise SystemExit(0 if passed else 1)

if __name__=="__main__":main()
