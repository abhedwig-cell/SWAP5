#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,json,re,math

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest() if p.exists() else None

def normalized_text(p):
    if not p.exists(): return ''
    s=p.read_text(errors='replace')
    # normalize timestamps / executable-identification chatter conservatively
    return '\n'.join(line for line in s.splitlines() if 'date and time of simulation' not in line.lower())

def finite_file(p):
    if not p.exists(): return False
    txt=p.read_text(errors='replace').lower()
    return not any(tok in txt for tok in ('nan','infinity','-infinity'))

def main():
    ap=argparse.ArgumentParser();ap.add_argument('control',type=Path);ap.add_argument('candidate',type=Path);ap.add_argument('novap_control',type=Path);ap.add_argument('novap_candidate',type=Path);a=ap.parse_args()
    evidence={"files":{}}
    for name in ("result.bal","result.blc","result.bfo"):
      cp=a.control/name;dp=a.candidate/name
      evidence["files"][name]={
        "control_sha":sha(cp),"candidate_sha":sha(dp),
        "different": cp.exists() and dp.exists() and cp.read_bytes()!=dp.read_bytes(),
        "candidate_finite":finite_file(dp)
      }
    diff_any=any(v["different"] for v in evidence["files"].values())
    novap_same=True
    novap={}
    for name in ("result.bal","result.blc","result.bfo"):
      x=a.novap_control/name;y=a.novap_candidate/name
      same=x.exists() and y.exists() and normalized_text(x)==normalized_text(y)
      novap[name]=same;novap_same &= same
    evidence["vapor_on_any_output_difference"]=diff_any
    evidence["novap_normalized_identical"]=novap_same
    evidence["novap_by_file"]=novap
    evidence["status"]="PASS" if diff_any and novap_same and all(v["candidate_finite"] for v in evidence["files"].values()) else "FAIL"
    print(json.dumps(evidence,indent=2))
    raise SystemExit(0 if evidence["status"]=="PASS" else 1)
if __name__=='__main__':main()
