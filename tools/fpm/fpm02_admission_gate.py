#!/usr/bin/env python3
"""Source-bound F-PM02 admission gate for structural SNOW migration."""
from __future__ import annotations
import argparse, json, subprocess
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

FCI18="7f906fcc53a4133b0e410eac7cf79fbb4eb672ab"
SOURCE="c28e7a2810b4a3678c577335a6a3086b173eb976"
TREE="a1a161e5e33fc143a7dc7f3c1b9749fc96f861f6"
ENTRY="fmr_run_serialized_physical_multiswap"
PROFILE="EXACT_FVQ14_RESTRICTED_PROFILE_ONLY"

@dataclass
class Check:
    name:str; passed:bool; observed:Any=None; expected:Any=None; detail:str|None=None

def git(*a:str)->subprocess.CompletedProcess[bytes]:
    return subprocess.run(["git",*a],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
def resolve(ref:str)->str|None:
    p=git("rev-parse","--verify",f"{ref}^{{commit}}"); return p.stdout.decode().strip() if p.returncode==0 else None
def raw(ref:str,path:str)->bytes|None:
    p=git("show",f"{ref}:{path}"); return p.stdout if p.returncode==0 else None
def doc(ref:str,path:str)->dict[str,Any]|None:
    b=raw(ref,path)
    try: v=json.loads(b) if b is not None else None
    except (UnicodeDecodeError,json.JSONDecodeError): return None
    return v if isinstance(v,dict) else None
def blob(ref:str,path:str)->str|None:
    p=git("rev-parse",f"{ref}:{path}"); return p.stdout.decode().strip() if p.returncode==0 else None
def val(d:dict[str,Any]|None,*ks:str)->Any:
    x:Any=d
    for k in ks:
        if not isinstance(x,dict) or k not in x:return None
        x=x[k]
    return x

def evaluate(candidate_ref:str,mr_ref:str,vq_ref:str,mq_ref:str)->dict[str,Any]:
    cs:list[Check]=[]
    def add(n:str,o:Any,e:Any,d:str|None=None)->None:cs.append(Check(n,o==e,o,e,d))
    c=resolve(candidate_ref); add("candidate_exact_commit",c,SOURCE)
    if c is None:return result(candidate_ref,c,mr_ref,vq_ref,mq_ref,cs)
    p=git("show","-s","--format=%T",c); add("candidate_tree",p.stdout.decode().strip(),TREE)
    add("canonical_fci18_ancestor",git("merge-base","--is-ancestor",FCI18,c).returncode==0,True)

    ms=doc(mr_ref,"integration/f-mr/F-MR05_STATUS.json"); me=doc(mr_ref,"integration/f-mr/F-MR05_QUALIFICATION_EVIDENCE.json")
    for n,o,e in [
      ("mr05_status_present",ms is not None,True),("mr05_source",val(ms,"qualified_source_commit"),c),
      ("mr05_tree",val(ms,"qualified_source_tree"),TREE),("mr05_tested",val(ms,"TESTED"),True),
      ("mr05_qualified",val(ms,"QUALIFIED"),True),("mr05_entrypoint",val(ms,"multi_column_entrypoint"),ENTRY),
      ("mr05_workflow",val(ms,"workflow","conclusion"),"success"),("mr05_evidence_source",val(me,"qualified_source_commit"),c),
      ("mr05_evidence_tree",val(me,"qualified_source_tree"),TREE)]:add(n,o,e)

    vs=doc(vq_ref,"integration/f-vq/F-VQ15_STATUS.json"); ve=doc(vq_ref,"integration/f-vq/F-VQ15_QUALIFICATION_EVIDENCE.json")
    for n,o,e in [
      ("vq15_status_present",vs is not None,True),("vq15_source",val(vs,"candidate_source_commit"),c),
      ("vq15_tree",val(vs,"candidate_source_tree"),TREE),("vq15_tested",val(vs,"TESTED"),True),
      ("vq15_qualified",val(vs,"QUALIFIED"),True),("vq15_scientific_admission",val(vs,"scientific_admission"),True),
      ("vq15_production_serial_admission",val(vs,"production_serialized_multicolumn_admission"),True),
      ("vq15_scope",val(vs,"production_physics_qualified_scope"),PROFILE),
      ("vq15_evidence_source",val(ve,"candidate_source","commit"),c),
      ("vq15_decision",val(ve,"decision"),"QUALIFIED_FMR05_RESTRICTED_SERIALIZED_MULTICOLUMN_PHYSICAL_ADMISSION")]:add(n,o,e)

    qs=doc(mq_ref,"integration/f-mq/F-MQ23_STATUS.json"); qe=doc(mq_ref,"integration/f-mq/F-MQ23_QUALIFICATION_EVIDENCE.json")
    for n,o,e in [
      ("mq23_status_present",qs is not None,True),("mq23_source",val(qs,"candidate_source_commit"),c),
      ("mq23_tree",val(qs,"candidate_source_tree"),TREE),("mq23_tested",val(qs,"TESTED"),True),
      ("mq23_qualified",val(qs,"QUALIFIED"),True),("mq23_real_physics_admitted",val(qs,"real_physics_multiswap_admitted_by_fmq23"),True),
      ("mq23_entrypoint",val(qs,"runtime_entrypoint"),ENTRY),("mq23_batches",val(qs,"verified_real_physics_matrix","batch_sizes"),[1,2,8,17,31,32]),
      ("mq23_parallel_not_admitted",val(qs,"parallel_real_physics_admitted"),False),
      ("mq23_evidence_source",val(qe,"source_under_test","commit"),c)]:add(n,o,e)

    # F-MR02 qualifies the accepted F-SI05 seam and F-KT05 boundary in one
    # source postimage. F-MR04 source-binds its qualified F-KT08 successor.
    s2=doc(c,"integration/f-mr/F-MR02_STATUS.json"); e2=doc(c,"integration/f-mr/F-MR02_QUALIFICATION_EVIDENCE.json")
    for n,o,e in [
      ("mr02_qualified",val(s2,"QUALIFIED"),True),("accepted_fsi05_lineage",val(s2,"qualified_scope","exact_f_si05_focused_production_workspace_seam"),True),
      ("fkt05_minimum",val(s2,"qualified_scope","exact_f_kt05_transaction_kernel_spine"),True),
      ("fsi05_qualification_head",val(e2,"provenance","f_si05_qualification_head"),"0227ae94edc3364b013f831f1efa6aaccac29b11"),
      ("fkt05_tested_postimage",val(e2,"provenance","f_kt05_tested_source_postimage"),"f7d2ee5e81f1d6686c96114984239e97ba6a8a8a")]:add(n,o,e)
    f5=doc(c,"integration/f-kt/F-KT05_STATUS.json");add("fkt05_status_qualified",val(f5,"qualified"),True)
    e4=doc(c,"integration/f-mr/F-MR04_QUALIFICATION_EVIDENCE.json");p4=doc(c,"integration/f-mr/F-MR04_COMPOSITION_PROVENANCE.json")
    add("fkt08_qualified_successor",val(e4,"consumed_dependencies","F-KT08"),"510d1f29d40225c68f3a8d3e789071279941e87b")
    for path,expected in (val(p4,"fkt08","production_blobs") or {}).items():add("fkt08_blob:"+path,blob(c,path),expected)
    for key in ["fkt05_forward_transaction_regression","checkpoint_trial_candidate","rollback_committed_state_unchanged","replay_candidate_identity"]:add(key,val(e4,"gates",key),"PASS")

    add("b110_snapshot_blob",blob(c,"reference/swap-4.3.1/snapshots/B1.10.yml"),"8d768f00d47224a663941f79bb2d35eacc66d16b")
    add("b110_reconstruct_blob",blob(c,"tools/vq/b1_10_reconstruct.py"),"b6d3c78c8a84a82e5c02320c83e87d250a3ad401")
    pin=doc(c,"tools/vq/cases/b1-10-reference-pin.json");add("b110_manifest_sha256",val(pin,"source_tree","member_manifest_sha256"),"2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1")
    manifest=raw(c,"reference/swap-4.3.1/b0/file-manifest.sha256")
    snow_record="02f36d30448b94dfdf386bc43424f1fe0feff9eafd24a768a8c702843a0bf9b2      5278  SWAP/snow.f90"
    add("legacy_snow_manifest_record",snow_record in manifest.decode() if manifest else False,True,
        "B1.10 leaves snow.f90 byte-identical to the canonical B0 member pinned by the source manifest.")
    return result(candidate_ref,c,mr_ref,vq_ref,mq_ref,cs)

def result(cr:str,c:str|None,mr:str,vq:str,mq:str,cs:list[Check])->dict[str,Any]:
    ok=bool(cs) and all(x.passed for x in cs)
    return {"schema_version":4,"workstream":"F-PM","work_unit":"F-PM02","candidate_ref":cr,"candidate_commit":c,
      "evidence_refs":{"F-MR05":mr,"F-VQ15":vq,"F-MQ23":mq},"decision":"ADMITTED_FOR_STRUCTURAL_SNOW_PROCESS_MIGRATION" if ok else "REJECT_FAIL_CLOSED",
      "admitted":ok,"production_migration_allowed":ok,"checks":[asdict(x) for x in cs],
      "holds_if_rejected":["Do not modify production SNOW source.","Do not weaken admission semantics."] if not ok else [],
      "holds_if_admitted":["SNOW is not scientifically admitted by F-VQ15/F-MQ23.","Parallel real physics remains NOT_ADMITTED.","Preserve legacy SNOW equations and one-call time semantics."] if ok else []}

def main()->int:
    p=argparse.ArgumentParser();p.add_argument("--candidate-ref",required=True);p.add_argument("--mr05-ref",default="origin/integration/f-mr");p.add_argument("--vq15-ref",default="origin/qualification/f-vq15-fmr05-serialized-multiswap");p.add_argument("--mq23-ref",default="origin/qualification/f-mq23-fvq14-real-physics-runtime");p.add_argument("--output",type=Path);a=p.parse_args()
    r=evaluate(a.candidate_ref,a.mr05_ref,a.vq15_ref,a.mq23_ref);s=json.dumps(r,indent=2,sort_keys=True)+"\n"
    if a.output:a.output.write_text(s,encoding="utf-8")
    print(s,end="");return 0 if r["admitted"] else 2
if __name__=="__main__":raise SystemExit(main())
