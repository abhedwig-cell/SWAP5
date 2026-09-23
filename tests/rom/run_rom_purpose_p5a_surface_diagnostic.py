#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys,re

def fields(line):
    out={}
    for item in line.split("|")[1:]:
        if "=" in item:
            k,v=item.split("=",1); out[k]=v
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True,choices=("S8","S12","S16"))
    ap.add_argument("--factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()

    ladder=json.loads(a.representation_ladder.read_text())
    bounds=[float(x) for x in ladder["SURF_P"]["family"][a.member]["boundaries_cm"]]
    thickness=",".join(str(bounds[i+1]-bounds[i]) for i in range(len(bounds)-1))
    a.output_dir.mkdir(parents=True,exist_ok=True)
    generated=a.canonical_root/"tests/rom/test_p5a_surface_diag.f90"
    manifest=a.output_dir/"materialization.json"
    subprocess.run([
      sys.executable,"tests/rom/materialize_rom_purpose_p5a_surface_diagnostic.py",
      "--material",a.material,"--member",a.member,"--temporal-factor",str(a.factor),
      "--representation-ladder",str(a.representation_ladder),
      "--output",str(generated),"--manifest",str(manifest)
    ],check=True)

    runs={}
    for opt in (0,2):
        stub=f"p5a_{a.material}_{a.member}_T{a.factor}_o{opt}_stubs.f90"
        subprocess.run([
          sys.executable,"tests/rom/rom_purpose_p1_variable_grid_stubs.py",
          "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
          "--output",str(a.canonical_root/stub),"--layer-thickness-cm",thickness
        ],check=True)
        build=pathlib.Path(f"/tmp/p5a_{a.material}_{a.member}_T{a.factor}_o{opt}")
        subprocess.run([
          sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
          "--root",str(a.canonical_root),"--stub",stub,"--target","tests/rom/test_p5a_surface_diag.f90",
          "--external-source","src/legacy/b1_10_port/headcalc.f90","--build",str(build),"--opt",str(opt)
        ],check=True)
        log=a.output_dir/f"p5a_SURF_P_{a.material}_{a.member}_T{a.factor}_o{opt}.txt"
        with log.open("w") as fh:
            cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT)
        lines=log.read_text(errors="replace").splitlines()
        marks=[fields(x) for x in lines if x.startswith("ROMPURP_P5A_LOCAL_ALLOWANCE|")]
        fail_label=any("LAREDYN0R_FAIL LAREDYN0R local residual within prior integrated allowance" in x for x in lines)
        last_state=None
        for x in lines:
            if x.startswith("LAREDYN0R_STATE|"):
                last_state=fields(x)
        ratios=[float(x["RATIO"]) for x in marks if "RATIO" in x]
        runs[str(opt)]={
          "return_code":int(cp.returncode),
          "diagnostic_marker_count":len(marks),
          "max_ratio_to_allowance":max(ratios) if ratios else None,
          "terminal_marker":marks[-1] if marks else None,
          "local_allowance_failure_label_seen":bool(fail_label),
          "last_accepted_case":None if last_state is None else last_state.get("CASE"),
          "last_accepted_step":None if last_state is None else int(last_state["STEP"]),
          "execution_complete":any("LAREDYN0R_EXECUTION_COMPLETE=PASS" in x for x in lines)
        }

    marker_identity=runs["0"]["terminal_marker"]==runs["2"]["terminal_marker"]
    failure_identity=(runs["0"]["return_code"]==runs["2"]["return_code"] and
                      runs["0"]["local_allowance_failure_label_seen"]==runs["2"]["local_allowance_failure_label_seen"] and
                      marker_identity)
    out={
      "schema":"swap5.rom-purpose.p5a.surface-route-diagnostic.v1",
      "material":a.material,"member":a.member,"temporal_factor":a.factor,
      "boundaries_cm":bounds,"runs":runs,
      "o0_o2_terminal_diagnostic_identity":bool(failure_identity),
      "scientific_change":False
    }
    (a.output_dir/f"p5a_SURF_P_{a.material}_{a.member}_T{a.factor}.json").write_text(
      json.dumps(out,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__": raise SystemExit(main())
