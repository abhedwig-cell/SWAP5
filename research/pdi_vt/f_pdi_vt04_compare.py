#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,difflib

EXTS=(".bal",".blc",".bfo")

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest() if p and p.exists() else None

def normalized_text(p):
    if p is None or not p.exists():
        return None
    s=p.read_text(errors='replace')
    return '\n'.join(
        line for line in s.splitlines()
        if 'date and time of simulation' not in line.lower() and 'generated at:' not in line.lower()
    )

def finite_file(p):
    if p is None or not p.exists():
        return None
    txt=p.read_text(errors='replace').lower()
    return not any(tok in txt for tok in ('nan','infinity','-infinity'))

def discover(directory,ext):
    matches=sorted(directory.glob('*'+ext))
    if len(matches)==0:
        return None
    if len(matches)>1:
        raise RuntimeError(f'{directory}: multiple {ext} files: {[p.name for p in matches]}')
    return matches[0]

def compare_pair(control,candidate):
    evidence={}
    produced=0
    for ext in EXTS:
        cp=discover(control,ext)
        dp=discover(candidate,ext)
        if (cp is None)!=(dp is None):
            raise RuntimeError(f'output presence mismatch for {ext}')
        if cp is None:
            evidence[ext]={"produced":False}
            continue
        produced+=1
        evidence[ext]={
            "produced":True,
            "control_name":cp.name,
            "candidate_name":dp.name,
            "control_sha":sha(cp),
            "candidate_sha":sha(dp),
            "different":cp.read_bytes()!=dp.read_bytes(),
            "candidate_finite":finite_file(dp)
        }
    return evidence,produced

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('control',type=Path)
    ap.add_argument('candidate',type=Path)
    ap.add_argument('novap_control',type=Path)
    ap.add_argument('novap_candidate',type=Path)
    a=ap.parse_args()

    vap,vap_count=compare_pair(a.control,a.candidate)
    novap,novap_count=compare_pair(a.novap_control,a.novap_candidate)

    diff_any=any(v.get("different",False) for v in vap.values())
    finite_all=all(v.get("candidate_finite",True) for v in vap.values())

    novap_same=True
    novap_detail={}
    for ext in EXTS:
        cp=discover(a.novap_control,ext)
        dp=discover(a.novap_candidate,ext)
        if cp is None and dp is None:
            novap_detail[ext]={"produced":False,"identical":True}
            continue
        if cp is None or dp is None:
            novap_detail[ext]={"produced":True,"identical":False}
            novap_same=False
            continue
        ctext=normalized_text(cp)
        dtext=normalized_text(dp)
        same=ctext==dtext
        detail={
            "produced":True,
            "control_name":cp.name,
            "candidate_name":dp.name,
            "identical":same,
            "control_sha":sha(cp),
            "candidate_sha":sha(dp)
        }
        if not same:
            detail["first_diff_lines"]=list(difflib.unified_diff(
                ctext.splitlines(), dtext.splitlines(),
                fromfile="control", tofile="candidate", n=2
            ))[:40]
        novap_detail[ext]=detail
        novap_same &= same

    evidence={
        "vapor_outputs":vap,
        "vapor_output_file_count":vap_count,
        "vapor_on_any_output_difference":diff_any,
        "vapor_candidate_outputs_finite":finite_all,
        "novap_output_file_count":novap_count,
        "novap_normalized_identical":novap_same,
        "novap_outputs":novap_detail,
        "mass_balance_gate_note":"CRITDEVMASBAL=1e-6 is enforced by the model run; all four runs must reach normal completion before this comparator is called."
    }
    evidence["status"]="PASS" if vap_count>=1 and diff_any and finite_all and novap_same else "FAIL"
    print(json.dumps(evidence,indent=2))
    raise SystemExit(0 if evidence["status"]=="PASS" else 1)

if __name__=='__main__':
    main()
