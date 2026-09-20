#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, subprocess, sys, tempfile

LAYER_LO=[1,897,1025,1153,1281,1409,1537,1665,1793,1921,1985,2017]
LAYER_HI=[896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016,2048]
FACE_UP=[896,1024,1152,1280,1408,1536,1664,1792,1920,1984,2016]
FACE_DEPTH=[70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,155.0,157.5]

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def ints(values):
    return ",".join(str(x) for x in values)

def reals(values):
    return ",".join(f"{x:g}_real64" for x in values)

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
        base=td/"c5r_t16.f90"; bm=td/"c5r_manifest.json"
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

    params=(
      "  integer, parameter :: OUTPUT_FACTOR=16\n"
      "  integer, parameter :: C5T_NLAYER=12,C5T_NFACE=11\n"
      f"  integer, parameter :: C5T_LAYER_LO(C5T_NLAYER)=[{ints(LAYER_LO)}]\n"
      f"  integer, parameter :: C5T_LAYER_HI(C5T_NLAYER)=[{ints(LAYER_HI)}]\n"
      f"  integer, parameter :: C5T_FACE_UP(C5T_NFACE)=[{ints(FACE_UP)}]\n"
      f"  real(real64), parameter :: C5T_FACE_DEPTH(C5T_NFACE)=[{reals(FACE_DEPTH)}]\n"
    )
    text=one(text,"  integer, parameter :: OUTPUT_FACTOR=16\n",params,"C5T diagnostic constants")

    text=one(
      text,
      "    integer :: bin,lo_node,hi_node,nodes_per_bin\n    real(real64) :: bin_theta\n",
      "    integer :: bin,lo_node,hi_node,nodes_per_bin,c5t_layer,c5t_face\n    real(real64) :: bin_theta,c5t_storage\n",
      "C5T emit declarations"
    )

    anchor=(
      "        end do\n"
      "      end if\n"
      "    class default\n"
    )
    diag=(
      "        end do\n"
      "        do c5t_layer=1,C5T_NLAYER\n"
      "          c5t_storage=sum(physical%water_content(C5T_LAYER_LO(c5t_layer):C5T_LAYER_HI(c5t_layer))* &\n"
      "               dz(C5T_LAYER_LO(c5t_layer):C5T_LAYER_HI(c5t_layer)))\n"
      "          write(*,'(*(g0))') 'LAREGW1_C5T_LAYER|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &\n"
      "               '|SYMBOL=',trim(symbol_label(symbol)),'|LAYER=',c5t_layer,'|STORAGE=',c5t_storage\n"
      "        end do\n"
      "        do c5t_face=1,C5T_NFACE\n"
      "          write(*,'(*(g0))') 'LAREGW1_C5T_FACE|HISTORY=',trim(history_label(ih)),'|OBS_STEP=',step/OUTPUT_FACTOR, &\n"
      "               '|SYMBOL=',trim(symbol_label(symbol)),'|FACE=',c5t_face,'|DEPTH=',C5T_FACE_DEPTH(c5t_face), &\n"
      "               '|H_UP=',physical%pressure_head(C5T_FACE_UP(c5t_face)), &\n"
      "               '|H_DN=',physical%pressure_head(C5T_FACE_UP(c5t_face)+1), &\n"
      "               '|THETA_UP=',physical%water_content(C5T_FACE_UP(c5t_face)), &\n"
      "               '|THETA_DN=',physical%water_content(C5T_FACE_UP(c5t_face)+1)\n"
      "        end do\n"
      "      end if\n"
      "    class default\n"
    )
    text=one(text,anchor,diag,"C5T observation diagnostics")

    text=one(
      text,
      "write(*,'(A)') 'LAREGW1_C5R_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'",
      "write(*,'(A)') 'LAREGW1_C5R_FRESH_B14_DYNAMIC_REFERENCE_GENERATED=TRUE'\n"
      "  write(*,'(A)') 'LAREGW1_C5T_LOGGING_ONLY_INSTRUMENTED=TRUE'",
      "C5T completion marker"
    )

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5t.instrumented-reference-materialization.v1",
      "c5r_materializer_sha256":sha256(a.c5r_materializer),
      "source_harness_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "geometry":{"id":"R2048","nodes":2048,"dz_cm":0.078125},
      "temporal_factor":16,
      "transaction_dt_day":0.00005,
      "observation_factor":16,
      "retained_boundaries_cm":[0,70,80,90,100,110,120,130,140,150,155,157.5,160],
      "layer_lo_nodes":LAYER_LO,
      "layer_hi_nodes":LAYER_HI,
      "face_up_nodes":FACE_UP,
      "face_depths_cm":FACE_DEPTH,
      "diagnostic_lines_per_history":{"layer":12288,"face":11264},
      "logging_only":True,
      "candidate_feedback":False,
      "solver_or_physics_changed":False,
      "history_or_forcing_changed":False,
      "numerical_policy_changed":False,
      "response_based":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
