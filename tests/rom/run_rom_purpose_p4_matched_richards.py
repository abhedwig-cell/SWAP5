#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys

def run(cmd,**kwargs): return subprocess.run(cmd,check=True,**kwargs)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--purpose",required=True,choices=("SURF_P","GW_LB"))
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--member",required=True)
    ap.add_argument("--factor",required=True,type=int,choices=(8,16,32))
    ap.add_argument("--representation-ladder",required=True,type=pathlib.Path)
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    ladder=json.loads(a.representation_ladder.read_text())
    family=ladder[a.purpose]["family"]
    if a.member not in family: raise SystemExit("member not in frozen family")
    bounds=[float(x) for x in family[a.member]["boundaries_cm"]]
    thickness=",".join(str(bounds[i+1]-bounds[i]) for i in range(len(bounds)-1))
    nodes=len(bounds)-1
    a.output_dir.mkdir(parents=True,exist_ok=True)

    generated=a.canonical_root/"tests/rom/test_p4matched.f90"
    manifest=a.output_dir/"materialization.json"
    cmd=[
      sys.executable,"tests/rom/materialize_rom_purpose_p4_matched_richards.py",
      "--purpose",a.purpose,"--material",a.material,"--member",a.member,
      "--temporal-factor",str(a.factor),
      "--representation-ladder",str(a.representation_ladder),
      "--coarse-output-adapter","tests/rom/materialize_rom_purpose_p1_coarse_output.py",
      "--output",str(generated),"--manifest",str(manifest)]
    if a.purpose=="SURF_P":
        source=("tests/rom/rom_purpose_p1_surface_b01_source.f90" if a.material=="B01"
                else "tests/rom/rom_purpose_p1_surface_b14_source.f90")
        cmd += ["--source",source,"--surface-materializer","tests/rom/materialize_rom_purpose_p4_surface_reference.py"]
        marker="LAREDYN0R_ROMPURP_P4_SURFACE_REFERENCE_GENERATED=TRUE"
        state_prefix="LAREDYN0R_STATE|"; node_prefix="ROMPURP_P1_COARSE_NODE|PURPOSE=surface|"
    else:
        cmd += ["--source","tests/rom/rom_purpose_p1_gw_source.f90",
                "--gw-materializer","tests/rom/materialize_rom_purpose_p4_gw_reference.py",
                "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
                "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py"]
        marker="LAREGW1_ROMPURP_P4_GW_REFERENCE_GENERATED=TRUE"
        state_prefix="LAREGW1_STATE|"; node_prefix="ROMPURP_P1_COARSE_NODE|PURPOSE=gw|"
    run(cmd)

    rcs={}; logs={}
    for opt in (0,2):
        stub=f"p4matched_{a.purpose}_{a.material}_{a.member}_T{a.factor}_o{opt}_stubs.f90"
        run([sys.executable,"tests/rom/rom_purpose_p1_variable_grid_stubs.py",
             "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
             "--output",str(a.canonical_root/stub),"--layer-thickness-cm",thickness])
        build=pathlib.Path(f"/tmp/p4matched_{a.purpose}_{a.material}_{a.member}_T{a.factor}_o{opt}")
        run([sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
             "--root",str(a.canonical_root),"--stub",stub,"--target","tests/rom/test_p4matched.f90",
             "--external-source","src/legacy/b1_10_port/headcalc.f90","--build",str(build),"--opt",str(opt)])
        log=a.output_dir/f"richards_{a.purpose}_{a.material}_{a.member}_T{a.factor}_o{opt}.txt"
        with log.open("w") as fh:
            cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT)
        rcs[opt]=cp.returncode; logs[opt]=log

    identity=rcs[0]==0 and rcs[2]==0 and logs[0].read_bytes()==logs[2].read_bytes()
    complete=False
    if rcs[0]==0 and rcs[2]==0:
        text=logs[0].read_text(errors="replace")
        complete=(marker in text and "EXECUTION_COMPLETE=PASS" in text
                  and text.count(state_prefix)==4*1024*a.factor
                  and text.count(node_prefix)==4*1024*nodes)
    status={
      "schema":"swap5.rom-purpose.p4.matched-richards-route-execution.v1",
      "purpose":a.purpose,"material":a.material,"member":a.member,"temporal_factor":a.factor,
      "return_code_o0":int(rcs[0]),"return_code_o2":int(rcs[2]),
      "scientific_trace_identity":bool(identity),"trace_complete":bool(complete),
      "nodes":nodes,"boundaries_cm":bounds,"scientific_change":False
    }
    (a.output_dir/f"execution_{a.purpose}_{a.material}_{a.member}_T{a.factor}.json").write_text(
      json.dumps(status,indent=2,sort_keys=True)+"\n")
    return 0

if __name__=="__main__": raise SystemExit(main())
