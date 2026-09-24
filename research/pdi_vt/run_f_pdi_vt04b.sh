#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/research/pdi_vt/.f_pdi_vt04b_runtime.sh"
curl -fsSL "https://raw.githubusercontent.com/abhedwig-cell/SWAP5/71ae7bee45afb2b844ec81f5b38ff6cdf21d5f15/research/pdi_vt/run_f_pdi_vt04_full_swap.sh" -o "$TMP"
sed -i 's/f_pdi_vt04_make_case.py/f_pdi_vt04b_case.py/g' "$TMP"
sed -i "s/trap 'rm -rf \"\$BUILDROOT\"' EXIT/trap ':' EXIT/" "$TMP"
chmod +x "$TMP"
bash "$TMP" /tmp/f_pdi_vt04b_base.json
BUILDROOT="$(find "${RUNNER_TEMP:-/tmp}" -maxdepth 1 -type d -name 'f-pdi-vt04-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
[[ -n "$BUILDROOT" && -d "$BUILDROOT" ]]
for label in control-vap candidate-vap control-novap candidate-novap; do
  cp "$BUILDROOT/$label/result.bfo" "/tmp/${label}.bfo"
done
python3 - <<'PY'
from pathlib import Path
import json, math, re, hashlib
p={}
for name in ["control-vap","candidate-vap","control-novap","candidate-novap"]:
    b=Path("/tmp/"+name+".bfo").read_text()
    toks=re.findall(r'(?i)(?:[-+]?\d+(?:\.\d*)?(?:[Ee][-+]?\d+)?|[-+]?\.\d+(?:[Ee][-+]?\d+)?|NaN|Inf|-Inf)',b)
    nonfinite=[x for x in toks if x.lower() in {"nan","inf","-inf","+inf"}]
    p[name]={"sha256":hashlib.sha256(b.encode()).hexdigest(),"nonfinite_tokens":len(nonfinite),"finite":len(nonfinite)==0}
p["vapor_different"]=p["control-vap"]["sha256"]!=p["candidate-vap"]["sha256"]
p["novap_identical"]=p["control-novap"]["sha256"]==p["candidate-novap"]["sha256"]
p["status"]="PASS" if p["control-vap"]["finite"] and p["candidate-vap"]["finite"] and p["vapor_different"] and p["novap_identical"] else "FAIL"
Path("/tmp/f_pdi_vt04b_finite.json").write_text(json.dumps(p,indent=2)+"\n")
print(json.dumps(p,indent=2))
if p["status"]!="PASS": raise SystemExit(2)
PY
