#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--profile-id",required=True,type=int)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()

    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic59.py"),
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id",str(a.profile_id),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve()),
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    old="""      '|oracle_exchange_rel=',oracle_exchange_rel,'|max_ledger_residual=',max_ledger_residual
"""
    new="""      '|oracle_exchange_rel=',oracle_exchange_rel,'|max_ledger_residual=',max_ledger_residual, &
      '|oracle_flux_final=',oracle_flux_final,'|oracle_exchange=',oracle_exchange, &
      '|full_flux=',res_full%bottom_flux,'|full_exchange=',full_exchange
"""
    if old not in s:
        raise SystemExit("F_PE_ELASTIC60_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("ELASTIC59_ORACLE|","ELASTIC60_ORACLE|")
    s=s.replace("ELASTIC59_HEADS","ELASTIC60_HEADS")
    s=s.replace("ELASTIC59_THETA","ELASTIC60_THETA")
    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC60_PROFILE_PREP=PASS")

if __name__=="__main__":
    main()
