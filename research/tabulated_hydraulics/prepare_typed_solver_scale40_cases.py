#!/usr/bin/env python3
"""Generate the five typed Reference-Richards cases at 40 nodes."""
from pathlib import Path
import importlib.util
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: prepare_typed_solver_scale40_cases.py STARING_CSV OUTPUT_DIR")

here=Path(__file__).resolve().parent
p=here/"prepare_envelope_cases_loghead.py"
sp=importlib.util.spec_from_file_location("logprep",p)
mod=importlib.util.module_from_spec(sp)
assert sp.loader is not None
sp.loader.exec_module(mod)
prep=mod.prep
series=prep.read_staring(Path(sys.argv[1]))
root=Path(sys.argv[2]); root.mkdir(parents=True,exist_ok=True)

cases={
    "coarse_dry_free":("b4","o5",-180.0,0.10,2,-999999.0),
    "loam_mid_free":("b9","o9",-75.0,0.10,2,-999999.0),
    "clay_wet_free":("b12","o13",-40.0,0.10,2,-999999.0),
    "coarse_dry_pulse":("b4","o5",-180.0,0.80,2,-999999.0),
    "loam_capillary":("b9","o9",-120.0,0.10,5,-120.0),
}
nodes=40
for name,(top,sub,h0,flux_factor,bmode,bhead) in cases.items():
    mats=[top]*(nodes//2)+[sub]*(nodes//2)
    k0=prep.k_policy(h0,series[top])
    qtop=flux_factor*k0
    with (root/f"{name}.dat").open("w") as fh:
        fh.write(f"{name} {nodes} 400 4.0e-2 {h0:.17e} {qtop:.17e} 0.0 {bmode} {bhead:.17e}\n")
        for soil in mats:
            par=series[soil]
            if par["h_enpr"] != 0.0:
                raise SystemExit(f"scale40 benchmark admits only H_ENPR=0, got {soil}")
            fh.write(
                f"{soil} {par['ores']:.17e} {par['osat']:.17e} {par['alpha']:.17e} "
                f"{par['n']:.17e} {par['ksat']:.17e} {par['lexp']:.17e} {par['h_enpr']:.17e}\n"
            )
            for h,t,k in mod.loghead_rows(par,400):
                fh.write(f"{h:.17e} {t:.17e} {k:.17e}\n")
    print(f"TABHYD_SCALE40_CASE name={name} nodes={nodes} h0={h0} qtop={qtop} bottom_mode={bmode}")
