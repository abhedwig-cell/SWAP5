#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, pathlib, re

VARIANTS=("GEOMETRY","CONDUCTIVITY","COMBINED")

def sha256(path:pathlib.Path)->str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def one(text:str,old:str,new:str,label:str)->str:
    n=text.count(old)
    if n!=1:
        raise SystemExit(f"{label}: expected one match, found {n}")
    return text.replace(old,new,1)

def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--source",required=True,type=pathlib.Path)
    ap.add_argument("--variant",required=True,choices=VARIANTS)
    ap.add_argument("--output",required=True,type=pathlib.Path)
    ap.add_argument("--manifest",required=True,type=pathlib.Path)
    a=ap.parse_args()

    text=a.source.read_text(encoding="utf-8")
    geometry=a.variant in ("GEOMETRY","COMBINED")
    conductivity=a.variant in ("CONDUCTIVITY","COMBINED")

    if geometry:
        text=one(
            text,
            "         grid_disnod = 0.5d0*parameter_set%dz(numnod)",
            "         grid_disnod = parameter_set%dz(numnod)",
            "explicit bottom-distance diagnostic toggle"
        )

    if conductivity:
        text=one(
            text,
            "   real(8)                          :: factor, Fmax\n",
            "   real(8)                          :: factor, Fmax\n"
            "   real(8)                          :: c5j_saved_bottom_head, c5j_boundary_k\n",
            "C5J diagnostic scalars"
        )
        marker=(
            "   state%kmean(numnod+1) = state%k(numnod)\n\n"
            "!  lower and upper diagnal elements"
        )
        replacement=(
            "   state%kmean(numnod+1) = state%k(numnod)\n"
            "   ! C5J diagnostic-only counterfactual: extend frozen swkmean=1 arithmetic\n"
            "   ! face averaging to the prescribed-head lower boundary. This file is\n"
            "   ! materialized in workflow scratch and is never production Reference.\n"
            "   if (provider_constitutive_active .and. swbotb == 5) then\n"
            "      c5j_saved_bottom_head = state%h(numnod)\n"
            "      state%h(numnod) = state%hbot\n"
            "      call evaluation_context%constitutive%evaluate(state%h(1:numnod), fsi_ws%provider_theta, &\n"
            "           fsi_ws%provider_k, fsi_ws%provider_capacity, fsi_ws%provider_dkdh)\n"
            "      c5j_boundary_k = fsi_ws%provider_k(numnod)\n"
            "      state%h(numnod) = c5j_saved_bottom_head\n"
            "      call evaluation_context%constitutive%evaluate(state%h(1:numnod), fsi_ws%provider_theta, &\n"
            "           fsi_ws%provider_k, fsi_ws%provider_capacity, fsi_ws%provider_dkdh)\n"
            "      state%kmean(numnod+1) = 0.5d0*(state%k(numnod) + c5j_boundary_k)\n"
            "   end if\n\n"
            "!  lower and upper diagnal elements"
        )
        text=one(text,marker,replacement,"prescribed-head conductivity diagnostic toggle")

    if text==a.source.read_text(encoding="utf-8"):
        raise SystemExit("C5J variant made no source change")

    a.output.write_text(text,encoding="utf-8")
    out={
      "schema":"swap5.lare.bc2.c5j.reference-boundary-variant-materialization.v1",
      "variant":a.variant,
      "source_sha256":sha256(a.source),
      "output_sha256":sha256(a.output),
      "geometry_distance_toggle":geometry,
      "conductivity_localization_toggle":conductivity,
      "boundary_distance_semantics":"dz" if geometry else "0.5*dz",
      "boundary_face_conductivity":"arithmetic(K_cell,K_boundary)" if conductivity else "K_cell",
      "swkmean_required":1,
      "swkimpl_required":0,
      "only_swbotb5_conductivity_changed":conductivity,
      "mode2_hold_changed":False,
      "fitted_parameter":False,
      "response_based":False,
      "production_reference_changed":False
    }
    a.manifest.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps(out,sort_keys=True))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
