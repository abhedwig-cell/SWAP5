#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

DZ_FINE=0.078125

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--c5r-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5p-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5n-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c5a-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--c4z-materializer",required=True,type=pathlib.Path)
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    with tempfile.TemporaryDirectory() as td:
        td=pathlib.Path(td)
        base=td/"c5t_full.f90"; bm=td/"c5t_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5t_materializer),
          "--c5r-materializer",str(a.c5r_materializer),
          "--c5p-materializer",str(a.c5p_materializer),
          "--c5n-materializer",str(a.c5n_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False or m.get("solver_or_physics_changed") is not False:
            raise SystemExit("C5T base instrumentation is not response-independent logging-only authority")
        text=base.read_text(encoding="utf-8")

    text=one(
      text,
      "    integer :: c5t_layer,c5t_face\n",
      "    integer :: c5t_layer,c5t_face,c6d_node\n",
      "C6D integer declaration"
    )
    text=one(
      text,
      "    real(real64) :: bin_theta,c5t_storage\n",
      "    real(real64) :: bin_theta,c5t_storage,c6d_moment,c6d_zc,c6d_z\n",
      "C6D real declaration"
    )
    text=one(
      text,
      "          c5t_storage=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))\n",
      """          c5t_storage=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))
          c6d_zc=0.5_real64*real(c5t_edge(c5t_layer)+c5t_edge(c5t_layer+1),real64)*0.078125_real64
          c6d_moment=0.0_real64
          do c6d_node=lo_node,hi_node
            c6d_z=(real(c6d_node,real64)-0.5_real64)*0.078125_real64
            c6d_moment=c6d_moment+(c6d_z-c6d_zc)*physical%water_content(c6d_node)*dz(c6d_node)
          end do
""",
      "C6D centered moment calculation"
    )
    old="""               '|BOTTOM_CM=',real(c5t_edge(c5t_layer+1),real64)*0.078125_real64,'|STORAGE_CM=',c5t_storage
        end do
        do c5t_face=1,11
"""
    new="""               '|BOTTOM_CM=',real(c5t_edge(c5t_layer+1),real64)*0.078125_real64,'|STORAGE_CM=',c5t_storage
          write(*,'(*(g0))') 'LAREGW1_C6D_MOMENT|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &
               '|LAYER=',c5t_layer,'|TOP_CM=',real(c5t_edge(c5t_layer),real64)*0.078125_real64, &
               '|BOTTOM_CM=',real(c5t_edge(c5t_layer+1),real64)*0.078125_real64,'|MOMENT_CM2=',c6d_moment
        end do
        write(*,'(*(g0))') 'LAREGW1_C6D_BOUNDARY|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &
             '|TOP_FLUX_NATIVE=',forcing%top_flux,'|BOTTOM_HEAD_NATIVE=',forcing%bottom_head, &
             '|BOTTOM_MODE=',merge(5,2,is_head_symbol(symbol))
        do c5t_face=1,11
"""
    text=one(text,old,new,"C6D moment/boundary output")
    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5T_INSTRUMENTATION_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C6D_MOMENT_INSTRUMENTATION_GENERATED=TRUE'\n  write(*,'(A)') 'LAREGW1_C5T_INSTRUMENTATION_GENERATED=TRUE'",
      "C6D marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c6d.moment-instrumentation-materialization.v1",
      "c5t_materializer_sha256":sha256(a.c5t_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "geometry":{"nodes":2048,"dz_cm":DZ_FINE},
      "temporal_factor":16,
      "histories":["R01","R02","R03","R04"],
      "moment_definition":"sum((z_center-z_layer_center)*theta*dz) with z_center=(node-0.5)*0.078125 cm",
      "new_output_prefixes":["LAREGW1_C6D_MOMENT","LAREGW1_C6D_BOUNDARY","LAREGW1_C6D_MOMENT_INSTRUMENTATION_GENERATED"],
      "preexisting_state_profile_output_changed":False,
      "preexisting_c5t_layer_face_output_changed":False,
      "solver_or_physics_changed":False,
      "boundary_or_forcing_changed":False,
      "numerical_policy_changed":False,
      "candidate_feedback":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
