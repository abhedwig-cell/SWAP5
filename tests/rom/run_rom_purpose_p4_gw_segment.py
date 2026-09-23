#!/usr/bin/env python3
from __future__ import annotations
import argparse,json,os,pathlib,subprocess,sys

ROUTES={
 "R512_T32":(512,0.3125,32,4),
 "R1024_T32":(1024,0.15625,32,4),
 "R2048_T16":(2048,0.078125,16,2),
 "R2048_T8":(2048,0.078125,8,1),
}
SEGMENT_STEPS=8192

def run(cmd): subprocess.run(cmd,check=True)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--material",required=True,choices=("B01","B14"))
    ap.add_argument("--route",required=True,choices=tuple(ROUTES))
    ap.add_argument("--opt",required=True,type=int,choices=(0,2))
    ap.add_argument("--history",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--segment",required=True,type=int,choices=(1,2,3,4))
    ap.add_argument("--canonical-root",required=True,type=pathlib.Path)
    ap.add_argument("--output-dir",required=True,type=pathlib.Path)
    ap.add_argument("--checkpoint-in",type=pathlib.Path)
    a=ap.parse_args()
    nodes,dz,factor,nseg=ROUTES[a.route]
    if a.segment>nseg: raise SystemExit("segment outside route topology")
    if a.segment>1 and a.checkpoint_in is None: raise SystemExit("--checkpoint-in required")
    start=(a.segment-1)*SEGMENT_STEPS+1; end=a.segment*SEGMENT_STEPS
    a.output_dir.mkdir(parents=True,exist_ok=True)
    target=a.canonical_root/"tests/rom/test_p4gw_segment.f90"; manifest=a.output_dir/"manifest.json"
    run([sys.executable,"tests/rom/materialize_rom_purpose_p1_gw_reference_segment.py",
         "--slice-materializer","tests/rom/materialize_rom_purpose_p1_gw_reference_slice.py",
         "--base-materializer","tests/rom/materialize_rom_purpose_p4_gw_reference.py",
         "--c5a-materializer","tests/rom/rom_purpose_p1_base_b14_materializer.py",
         "--c4z-materializer","tests/rom/rom_purpose_p1_base_c4z_materializer.py",
         "--source","tests/rom/rom_purpose_p1_gw_source.f90",
         "--material",a.material,"--temporal-factor",str(factor),"--history-index",str(a.history),
         "--segment-start",str(start),"--segment-end",str(end),
         "--output",str(target),"--manifest",str(manifest)])
    stub=f"p4gwseg_{a.material}_{a.route}_o{a.opt}_h{a.history}_s{a.segment}_stubs.f90"
    run([sys.executable,str(a.canonical_root/"tests/rom/materialize_f_rom0_headcalc_stubs.py"),
         "--source",str(a.canonical_root/"tests/fsi/fsi04_real_headcalc_stubs.f90"),
         "--output",str(a.canonical_root/stub),"--nodes",str(nodes),"--dz-cm",str(dz)])
    build=pathlib.Path(f"/tmp/p4gwseg_{a.material}_{a.route}_o{a.opt}_h{a.history}_s{a.segment}")
    run([sys.executable,str(a.canonical_root/"tests/rom/compile_f_rom0_fortran_closure.py"),
         "--root",str(a.canonical_root),"--stub",stub,"--target","tests/rom/test_p4gw_segment.f90",
         "--external-source","src/legacy/b1_10_port/headcalc.f90","--build",str(build),"--opt",str(a.opt)])
    checkpoint=a.output_dir/"checkpoint.bin"; env=os.environ.copy()
    env["ROMPURP_P1_CHECKPOINT_OUT"]=str(checkpoint)
    if a.checkpoint_in is not None: env["ROMPURP_P1_CHECKPOINT_IN"]=str(a.checkpoint_in)
    log=a.output_dir/f"segment{a.segment}.txt"
    with log.open("w") as fh:
        cp=subprocess.run([str(build/"rom0_test")],stdout=fh,stderr=subprocess.STDOUT,env=env)
    if cp.returncode!=0: raise SystemExit(cp.returncode)
    text=log.read_text(errors="replace")
    expected_states=end-start+1
    expected_profiles=(expected_states//factor)*16
    if text.count("LAREGW1_STATE|")!=expected_states: raise SystemExit("state coverage mismatch")
    if text.count("LAREGW1_PROFILE|")!=expected_profiles: raise SystemExit("profile coverage mismatch")
    if "LAREGW1_ROMPURP_P4_GW_REFERENCE_GENERATED=TRUE" not in text: raise SystemExit("P4 GW marker missing")
    if "LAREGW1_ROMPURP_P1_SEGMENTED_GW_REFERENCE_GENERATED=TRUE" not in text: raise SystemExit("segmented marker missing")
    if not checkpoint.exists() or checkpoint.stat().st_size==0: raise SystemExit("checkpoint missing")
    out={"schema":"swap5.rom-purpose.p4.gw-segment-execution.v1","material":a.material,"route":a.route,
         "optimization":a.opt,"history_index":a.history,"segment":a.segment,"segment_start":start,"segment_end":end,
         "temporal_factor":factor,"nodes":nodes,"dz_cm":dz,"segment_steps":SEGMENT_STEPS,
         "segments_per_history":nseg,"checkpoint_continuation":a.segment>1,
         "scientific_change":False,"forcing_changed":False,"numerical_policy_changed":False,
         "solver_or_physics_changed":False,"response_based":False}
    (a.output_dir/"execution.json").write_text(json.dumps(out,indent=2,sort_keys=True)+"\n"); return 0

if __name__=="__main__": raise SystemExit(main())
