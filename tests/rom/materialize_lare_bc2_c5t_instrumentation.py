#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

EDGES=[0,896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016,2048]
FACE_UP=[896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016]
FACE_DEPTH=[70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,155.0,157.5]

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
        base=td/"c5r_r2048_t16.f90"; bm=td/"c5r_manifest.json"
        subprocess.run([
          sys.executable,str(a.c5r_materializer),
          "--c5p-materializer",str(a.c5p_materializer),
          "--c5n-materializer",str(a.c5n_materializer),
          "--c5a-materializer",str(a.c5a_materializer),
          "--c4z-materializer",str(a.c4z_materializer),
          "--source",str(a.source),
          "--temporal-factor","16",
          "--output",str(base),
          "--manifest",str(bm)
        ],check=True)
        m=json.loads(bm.read_text())
        if m.get("response_based") is not False:
            raise SystemExit("C5R base materializer is not response-independent")
        text=base.read_text(encoding="utf-8")

    decl_old="""    integer :: bin,lo_node,hi_node,nodes_per_bin
    real(real64) :: bin_theta
"""
    decl_new="""    integer :: bin,lo_node,hi_node,nodes_per_bin
    integer :: c5t_layer,c5t_face
    integer, parameter :: c5t_edge(13)=[0,896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016,2048]
    integer, parameter :: c5t_up(11)=[896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016]
    real(real64), parameter :: c5t_depth(11)=[70.0_real64,80.0_real64,90.0_real64,100.0_real64,110.0_real64, &
         120.0_real64,130.0_real64,140.0_real64,150.0_real64,155.0_real64,157.5_real64]
    real(real64) :: bin_theta,c5t_storage
"""
    text=one(text,decl_old,decl_new,"C5T diagnostic declarations")

    profile_tail="""        end do
      end if
"""
    diagnostic_tail="""        end do
        do c5t_layer=1,12
          lo_node=c5t_edge(c5t_layer)+1
          hi_node=c5t_edge(c5t_layer+1)
          c5t_storage=sum(physical%water_content(lo_node:hi_node)*dz(lo_node:hi_node))
          write(*,'(*(g0))') 'LAREGW1_C5T_LAYER|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &
               '|LAYER=',c5t_layer,'|TOP_CM=',real(c5t_edge(c5t_layer),real64)*0.078125_real64, &
               '|BOTTOM_CM=',real(c5t_edge(c5t_layer+1),real64)*0.078125_real64,'|STORAGE_CM=',c5t_storage
        end do
        do c5t_face=1,11
          write(*,'(*(g0))') 'LAREGW1_C5T_FACE|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &
               '|FACE=',c5t_face,'|DEPTH_CM=',c5t_depth(c5t_face),'|UP_NODE=',c5t_up(c5t_face), &
               '|DOWN_NODE=',c5t_up(c5t_face)+1,'|H_UP=',physical%pressure_head(c5t_up(c5t_face)), &
               '|H_DOWN=',physical%pressure_head(c5t_up(c5t_face)+1), &
               '|THETA_UP=',physical%water_content(c5t_up(c5t_face)), &
               '|THETA_DOWN=',physical%water_content(c5t_up(c5t_face)+1)
        end do
      end if
"""
    # The profile output block is the only observation-window block in emit_state.
    marker="'LAREGW1_PROFILE|SPLIT='"
    pos=text.find(marker)
    if pos<0:
        raise SystemExit("C5T profile marker not found")
    tail_pos=text.find(profile_tail,pos)
    if tail_pos<0:
        raise SystemExit("C5T profile tail not found")
    text=text[:tail_pos]+diagnostic_tail+text[tail_pos+len(profile_tail):]

    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5R_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5T_INSTRUMENTATION_GENERATED=TRUE'\n  write(*,'(A)') 'LAREGW1_C5R_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "C5T marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5t.instrumentation-materialization.v1",
      "source_harness_sha256":sha256(a.source),
      "c5r_materializer_sha256":sha256(a.c5r_materializer),
      "output_sha256":sha256(a.output),
      "geometry":{"nodes":2048,"dz_cm":0.078125},
      "temporal_factor":16,
      "histories":["R01","R02","R03","R04"],
      "layer_edges_fine_indices":EDGES,
      "face_upper_nodes":FACE_UP,
      "face_depths_cm":FACE_DEPTH,
      "new_output_prefixes":["LAREGW1_C5T_LAYER","LAREGW1_C5T_FACE","LAREGW1_C5T_INSTRUMENTATION_GENERATED"],
      "preexisting_state_profile_output_changed":False,
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
