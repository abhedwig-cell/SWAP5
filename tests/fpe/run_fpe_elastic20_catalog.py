#!/usr/bin/env python3
"""F-PE-ELASTIC20 qualification of deterministic BOFEK/BRO horizon catalog."""
from __future__ import annotations
import csv, json, math, subprocess, sys
from collections import Counter
from pathlib import Path

catalog=Path(sys.argv[1])
meta_path=Path(sys.argv[2])
verifier=Path(sys.argv[3])

rows=list(csv.DictReader(catalog.open(newline="",encoding="utf-8")))
meta=json.loads(meta_path.read_text(encoding="utf-8"))

expected_regimes={"MINERAL":1356,"ORGANIC_RICH_NONPEAT":8,"PEAT":204,"UNKNOWN":0}
regime_codes={"MINERAL":1,"ORGANIC_RICH_NONPEAT":2,"PEAT":3,"UNKNOWN":4}

if meta.get("schema")!="swap5.elastic20.bofek_horizon_catalog.v1":
    raise SystemExit("F_PE_ELASTIC20_FAIL schema")
if meta.get("profiles")!=368 or meta.get("horizons")!=1568:
    raise SystemExit("F_PE_ELASTIC20_FAIL source counts")
if len(rows)!=1568:
    raise SystemExit("F_PE_ELASTIC20_FAIL csv rows")
print("F_PE_ELASTIC20_A1_SOURCE_IDENTITY=PASS")

codes={f"B{i:02d}" for i in range(1,19)}|{f"O{i:02d}" for i in range(1,19)}
if any(r["staring_code"] not in codes for r in rows):
    raise SystemExit("F_PE_ELASTIC20_FAIL staring code")
print("F_PE_ELASTIC20_A2_STARING_LOOKUP=PASS")

for r in rows:
    for k in ("profile_id","bofek_unit","soilunit","layer_number","top_depth_m","bottom_depth_m",
              "staring_code","rho_dry_g_cm3","wcr","wcs","alpha_cm_inv","npar",
              "theta_ref_h_minus100","regime"):
        if r[k]=="":
            raise SystemExit(f"F_PE_ELASTIC20_FAIL missing {k}")
    if r["organic_matter_available"] not in ("0","1") or r["peat_type_present"] not in ("0","1"):
        raise SystemExit("F_PE_ELASTIC20_FAIL availability flag")
    if r["organic_matter_available"]=="1" and r["organic_matter_pct"]=="":
        raise SystemExit("F_PE_ELASTIC20_FAIL missing available organic matter")
print("F_PE_ELASTIC20_A3_SOURCE_COMPLETENESS=PASS")

for r in rows:
    wcr=float(r["wcr"]); wcs=float(r["wcs"]); theta=float(r["theta_ref_h_minus100"])
    if not all(math.isfinite(x) for x in (wcr,wcs,theta)) or theta<wcr or theta>wcs:
        raise SystemExit("F_PE_ELASTIC20_FAIL theta")
print("F_PE_ELASTIC20_A4_THETA=PASS")

counts=Counter(r["regime"] for r in rows)
obs={k:counts.get(k,0) for k in expected_regimes}
if obs!=expected_regimes or meta.get("regime_counts")!=expected_regimes:
    raise SystemExit(f"F_PE_ELASTIC20_FAIL regimes={obs}")
print("F_PE_ELASTIC20_A5_REGIMES=PASS")

keys=[(int(r["profile_id"]),int(r["layer_number"])) for r in rows]
if keys!=sorted(keys) or len(keys)!=len(set(keys)):
    raise SystemExit("F_PE_ELASTIC20_FAIL ordering")
print("F_PE_ELASTIC20_A6_ORDERING=PASS")

# Deterministic sample: first, middle, last, plus first row of every represented regime.
idx={0,len(rows)//2,len(rows)-1}
for reg in ("MINERAL","ORGANIC_RICH_NONPEAT","PEAT"):
    idx.add(next(i for i,r in enumerate(rows) if r["regime"]==reg))

for i in sorted(idx):
    r=rows[i]
    om_avail=int(r["organic_matter_available"])
    om=r["organic_matter_pct"] if om_avail else "0"
    args=[
        str(verifier),
        r["top_depth_m"],r["bottom_depth_m"],r["rho_dry_g_cm3"],
        str(om_avail),om,r["peat_type_present"],
        r["wcr"],r["wcs"],r["alpha_cm_inv"],r["npar"],
        r["theta_ref_h_minus100"],str(regime_codes[r["regime"]]),
    ]
    cp=subprocess.run(args,text=True,capture_output=True)
    if cp.returncode or "F_PE_ELASTIC20_ROW=PASS" not in cp.stdout:
        raise SystemExit("F_PE_ELASTIC20_FAIL row crosscheck\n"+cp.stdout+"\n"+cp.stderr)
print("F_PE_ELASTIC20_A7_ELASTIC19_CROSSCHECK=PASS")

if len({int(r["bofek_unit"]) for r in rows})!=79 or meta.get("bofek_units")!=79:
    raise SystemExit("F_PE_ELASTIC20_FAIL BOFEK unit coverage")
print("F_PE_ELASTIC20_A8_BOFEK_UNITS=PASS")

print("F_PE_ELASTIC20_CATALOG_QUALIFICATION=PASS")
