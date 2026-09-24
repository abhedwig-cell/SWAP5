#!/usr/bin/env python3
from __future__ import annotations
import base64,gzip,hashlib,json,re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
asset=ROOT/"reference/swap-4.3.1/b1_10_source/MOD_MvG_functions.f90.gz.b64"
raw=gzip.decompress(base64.b64decode(asset.read_bytes()))
sha=hashlib.sha256(raw).hexdigest()
expected="4bb79730b1b59653a851a9e6d8a1ff806c4d1c1668d6b341e96ecd12c7a338b1"
if sha!=expected: raise SystemExit(f"decoded SHA mismatch {sha}")
text=raw.decode("utf-8",errors="strict")
lines=text.splitlines()

hits=[]
patterns=[r"imod\s*==\s*3",r"imod\s*\.eq\.\s*3",r"iHWCKmodel",r"BiModal",r"omega_1",r"alfa_2",r"n_2",r"m_2"]
for i,line in enumerate(lines):
    if any(re.search(p,line,re.I) for p in patterns):
        a=max(0,i-8); b=min(len(lines),i+18)
        hits.append({"line":i+1,"context":"\n".join(f"{j+1}: {lines[j]}" for j in range(a,b))})

funcs=[]
for i,line in enumerate(lines):
    if re.search(r"^\s*(real\s*\([^)]*\)\s*)?(real\s*\*?\d*\s+)?function\s+",line,re.I) or re.search(r"^\s*subroutine\s+",line,re.I):
        funcs.append({"line":i+1,"signature":line.strip()})

print(json.dumps({
  "work_unit":"F-AHL25A",
  "decoded_sha256":sha,
  "line_count":len(lines),
  "function_signatures":funcs,
  "model3_contexts":hits
},indent=2))
