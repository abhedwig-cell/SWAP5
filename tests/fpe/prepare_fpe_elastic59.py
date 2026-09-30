#!/usr/bin/env python3
from __future__ import annotations
import argparse, subprocess
from pathlib import Path

PROFILE_ID=8016

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--repo-root",required=True)
    ap.add_argument("--artifact-dir",required=True)
    ap.add_argument("--work-dir",required=True)
    ap.add_argument("--fixture",required=True)
    ap.add_argument("--geometry-json",required=True)
    a=ap.parse_args()
    root=Path(a.repo_root).resolve()
    fixture=Path(a.fixture).resolve()
    cp=subprocess.run([
        "python3",str(root/"tests/fpe/prepare_fpe_elastic55.py"),"profile",
        "--repo-root",str(root),
        "--artifact-dir",str(Path(a.artifact_dir).resolve()),
        "--work-dir",str(Path(a.work_dir).resolve()),
        "--profile-id",str(PROFILE_ID),
        "--fixture",str(fixture),
        "--geometry-json",str(Path(a.geometry_json).resolve())
    ],text=True,capture_output=True)
    if cp.returncode!=0:
        raise SystemExit(cp.stdout+"\n"+cp.stderr)
    print(cp.stdout,end="")
    s=fixture.read_text(encoding="utf-8")

    s=s.replace(
        "  integer::ih,itheta,i\n",
        "  integer::ih,itheta,i,oracle_maxit\n",1
    )
    s=s.replace(
        "  if(command_argument_count()<4) error stop 'F_PE_ELASTIC50_FAIL args'\n",
        "  if(command_argument_count()<5) error stop 'F_PE_ELASTIC59_FAIL args'\n",1
    )
    anchor="  call get_command_argument(4,arg);read(arg,*)dt\n"
    repl=anchor+"  call get_command_argument(5,arg);read(arg,*)oracle_maxit\n  call req(oracle_maxit>=16,'oracle maxit')\n"
    if anchor not in s: raise SystemExit("F_PE_ELASTIC59_FAIL arg anchor")
    s=s.replace(anchor,repl,1)

    anchor="  call make_request(req_half1,soil,constitutive_half,source_sink,top,heads,water,h0,qeq+delta,qeq,0.5_real64*dt)\n"
    repl=anchor+"  req_half1%numerical%max_iterations=oracle_maxit\n"
    if anchor not in s: raise SystemExit("F_PE_ELASTIC59_FAIL half1 anchor")
    s=s.replace(anchor,repl,1)

    anchor="""    call make_request_from_state(req_half2,soil,constitutive_half,source_sink,top,res_half1%candidate_state, &
         h0,qeq+delta,qeq,0.5_real64*dt)
"""
    repl=anchor+"    req_half2%numerical%max_iterations=oracle_maxit\n"
    if anchor not in s: raise SystemExit("F_PE_ELASTIC59_FAIL half2 anchor")
    s=s.replace(anchor,repl,1)

    s=s.replace(
        "'ELASTIC55_BANK|profile=8016|regime='",
        "'ELASTIC59_CASE|profile=8016|regime='",1
    )
    old="'|storage_half=',storage_half,'|exact_identity=',exact_identity, &"
    new="'|storage_half=',storage_half,'|oracle_maxit=',oracle_maxit,'|exact_identity=',exact_identity, &"
    if old not in s: raise SystemExit("F_PE_ELASTIC59_FAIL output anchor")
    s=s.replace(old,new,1)
    s=s.replace("'F_PE_ELASTIC55_EXEC=PASS'","'F_PE_ELASTIC59_EXEC=PASS'",1)

    fixture.write_text(s,encoding="utf-8")
    print("F_PE_ELASTIC59_PREP=PASS")

if __name__=="__main__":
    main()
