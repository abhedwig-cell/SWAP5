#!/usr/bin/env bash
set -euo pipefail
git fetch origin archive/swap431-wofost81-qualified-donor
git checkout origin/archive/swap431-wofost81-qualified-donor -- reference/historical/swap431-wofost81
python reference/historical/swap431-wofost81/reconstruct_source.py
rm -rf /tmp/migmac02-source
mkdir -p /tmp/migmac02-source
unzip -q reference/historical/swap431-wofost81/SWAP_WOFOST81_SOURCE.zip -d /tmp/migmac02-source
SRC="$(find /tmp/migmac02-source -type f -iname macropore.f90 | head -1)"
test -n "$SRC"
echo "MIGMAC02_SOURCE_FILE=$SRC"
sha256sum "$SRC"
python - "$SRC" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
text=p.read_text(encoding="latin-1")
lines=text.splitlines()
for needle in ("SUBROUTINE SHRINKPAR","ShrRel","VlMpDyCp"):
    print(f"===== {needle} =====")
    hits=[i for i,x in enumerate(lines) if needle.lower() in x.lower()]
    for i in hits[:12]:
        a=max(0,i-18); b=min(len(lines),i+55)
        print(f"--- lines {a+1}-{b} ---")
        for n in range(a,b):
            print(f"{n+1:05d}: {lines[n]}")
PY
