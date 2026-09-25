#!/usr/bin/env python3
"""Materialize the 36 authoritative catalog parameter tuples for F-AHL43 admission tests.

This helper does not generate hydraulic lookup tables. It only extracts the
ordinary B1.10 parameter tuples already bound in the RossFast material catalog.
The production adaptive provider must build its own representation from them.
"""
from __future__ import annotations
import pathlib, re, sys

out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/fahl43-catalog")
out.mkdir(parents=True,exist_ok=True)
src=pathlib.Path("src/runtime/mod_rossfast_d3r_model_binding.f90").read_text()
compact=re.sub(r"&\s*\n\s*"," ",src)
pattern=re.compile(
    r"case\('([BO]\d\d)'\)\s*"
    r"material\s*=\s*rossfast_d3r_material_t\('\1'\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*,\s*"
    r"([+\-0-9.eE]+)_real64\s*\)"
)
mats={}
for m in pattern.finditer(compact):
    vals=[float(x) for x in m.groups()[1:]]
    # theta_r, theta_s, alpha, n, Ksatfit, lambda
    mats[m.group(1)]=(vals[0],vals[1],vals[2],vals[3],vals[4],vals[6])
if len(mats)!=36:
    raise SystemExit(f"expected 36 catalog materials, found {len(mats)}")
for mid,p in sorted(mats.items()):
    (out/f"{mid}.par").write_text(" ".join(f"{v:.17e}" for v in p)+"\n")
print(f"FAHL43_CATALOG_PARAMETERS={len(mats)}")
