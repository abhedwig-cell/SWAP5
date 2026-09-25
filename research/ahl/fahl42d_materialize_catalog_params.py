#!/usr/bin/env python3
from __future__ import annotations
import pathlib,re,sys
out=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else "/tmp/fahl42d-params")
out.mkdir(parents=True,exist_ok=True)
text=pathlib.Path("src/runtime/mod_rossfast_d3r_model_binding.f90").read_text()
compact=re.sub(r"&\s*\n\s*"," ",text)
pat=re.compile(
 r"case\('([BO]\d\d)'\)\s*material\s*=\s*rossfast_d3r_material_t\('\1'\s*,\s*"
 r"([+\-0-9.eE]+)_real64\s*,\s*([+\-0-9.eE]+)_real64\s*,\s*"
 r"([+\-0-9.eE]+)_real64\s*,\s*([+\-0-9.eE]+)_real64\s*,\s*"
 r"([+\-0-9.eE]+)_real64\s*,\s*([+\-0-9.eE]+)_real64\s*,\s*"
 r"([+\-0-9.eE]+)_real64\s*,\s*([+\-0-9.eE]+)_real64\s*\)"
)
count=0
for m in pat.finditer(compact):
    mid=m.group(1);v=[float(x) for x in m.groups()[1:]]
    # theta_r, theta_s, alpha, n, ksatfit, lambda
    p=(v[0],v[1],v[2],v[3],v[4],v[6])
    (out/f"{mid}.dat").write_text(" ".join(f"{x:.17e}" for x in p)+"\n")
    count+=1
if count!=36:
    raise SystemExit(f"expected 36 materials, got {count}")
print(f"FAHL42D_CATALOG_PARAMS={count}")
