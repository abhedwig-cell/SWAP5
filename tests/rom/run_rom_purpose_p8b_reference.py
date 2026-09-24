#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,pathlib,subprocess,sys

def run(cmd): subprocess.run(cmd,check=True)

def max_mass(text):
    out=0.0
    for line in text.splitlines():
        if not line.startswith("LAREGW1_STATE|"): continue
        for item in line.split("|")[1:]:
            if item.startswith("MASS="):
                out=max(out,abs(float(item.split("=",1)[1])))
    return out

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    a=ap.parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=True)
    generated=a.canonical_root/"tests/rom/test_p8b_transition_reference.f90"
    manifest=a.output_dir/"materialization.json"
    run([
      sys.executable,"tests/rom/materialize_rom_purpose_p8b_gw_reference.py",
      "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py",
      "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
      "--source","tests/rom/rom_purpose_p1_gw_source.f90",
      "--material",a.material,"--temporal-factor","8",
      "--output",str(generated),"--manifest",str(manifest)
    ])
    logs={}; masses={}
    for opt in (0,2):
        stub=f"p8b_{a.material}_o{opt}_stubs.f90"
        run([
          sys.executable,str(a.canonical_root/"tests/rom/materialize_f_rom0_headcalc_stubs.py"),
          "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
          "--output",str(a.canonical_root/stub),"--nodes","512","--dz-cm","0.3125"
        ])
        build=pathlib.Path(f"/tmp/p8b_{a.material}_o{opt}")
        run([
          sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
          "--root",str(a.canonical_root),"--stub",stub,"--target","tests/rom/test_p8b_transition_reference.f90",
          "--external-source","src/legacy/b1_10_port/headcalc.f90","--build",str(build),"--opt",str(opt)
        ])
        log=a.output_dir/f"p8b_{a.material}_o{opt}.txt"
        with log.open("w") as fh:
            cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT)
        if cp.returncode!=0: raise SystemExit(cp.returncode)
        text=log.read_text(errors="strict")
        if "LAREGW1_ROMPURP_P8B_GW_REFERENCE_GENERATED=TRUE" not in text:
            raise SystemExit("P8B marker missing")
        if text.count("LAREGW1_STATE|")!=4*1024*8:
            raise SystemExit("P8B state coverage mismatch")
        if text.count("LAREGW1_PROFILE|")!=4*1024*16:
            raise SystemExit("P8B profile coverage mismatch")
        masses[opt]=max_mass(text)
        if masses[opt]>1e-12: raise SystemExit(f"P8B mass gate {masses[opt]}")
        logs[opt]=log
    if logs[0].read_bytes()!=logs[2].read_bytes():
        raise SystemExit("P8B O0/O2 trace identity mismatch")
    out={
      "schema":"swap5.rom-purpose.p8b.reference-execution.v1",
      "material":a.material,"route":"R512_T8","histories":["G25","G26","G27","G28"],
      "optimization_modes":[0,2],"scientific_trace_identity":True,"trace_complete":True,
      "max_abs_transaction_mass_cm":max(masses.values()),"mass_gate_cm":1e-12,
      "solver_or_physics_changed":False,"numerical_policy_changed":False,
      "scientific_change":False
    }
    (a.output_dir/f"p8b_{a.material}_execution.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")

if __name__=="__main__": main()
