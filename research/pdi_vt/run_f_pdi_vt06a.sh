#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$ROOT/research/pdi_vt/.f_pdi_vt06a_runtime.sh"
curl -fsSL "https://raw.githubusercontent.com/abhedwig-cell/SWAP5/71ae7bee45afb2b844ec81f5b38ff6cdf21d5f15/research/pdi_vt/run_f_pdi_vt04_full_swap.sh" -o "$TMP"
sed -i 's/f_pdi_vt04_make_case.py/f_pdi_vt06a_cold_case.py/g' "$TMP"
sed -i "s/trap 'rm -rf \"\$BUILDROOT\"' EXIT/trap ':' EXIT/" "$TMP"
chmod +x "$TMP"
bash "$TMP" /tmp/f_pdi_vt06a_base.json
BUILDROOT="$(find "${RUNNER_TEMP:-/tmp}" -maxdepth 1 -type d -name 'f-pdi-vt04-*' -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)"
for label in control-vap candidate-vap control-novap candidate-novap; do cp "$BUILDROOT/$label/result.bfo" "/tmp/${label}.bfo"; done
python3 - <<'PY'
from pathlib import Path
import hashlib,json,re
p={}
for name in ["control-vap","candidate-vap","control-novap","candidate-novap"]:
    b=Path("/tmp/"+name+".bfo").read_text()
    bad=re.findall(r'(?i)(?<![A-Za-z])(?:NaN|[-+]?Inf)(?![A-Za-z])',b)
    p[name]={"sha256":hashlib.sha256(b.encode()).hexdigest(),"finite":not bad,"nonfinite_tokens":len(bad)}
p["vapor_different"]=p["control-vap"]["sha256"]!=p["candidate-vap"]["sha256"]
p["novap_identical"]=p["control-novap"]["sha256"]==p["candidate-novap"]["sha256"]
p["status"]="PASS" if p["control-vap"]["finite"] and p["candidate-vap"]["finite"] and p["vapor_different"] and p["novap_identical"] else "FAIL"
Path("/tmp/F-PDI-VT06A_RESULT.json").write_text(json.dumps(p,indent=2)+"\n")
print(json.dumps(p,indent=2))
if p["status"]!="PASS": raise SystemExit(2)
PY
