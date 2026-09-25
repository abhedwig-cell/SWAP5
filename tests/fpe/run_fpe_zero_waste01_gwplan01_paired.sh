#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

PARENT_SHA="0983fce7c9981c4d192fb495e3419c1aa665f4fa"
TMP_PARENT="$(mktemp -d)"
trap 'git worktree remove --force "$TMP_PARENT" >/dev/null 2>&1 || true; rm -rf "$TMP_PARENT"' EXIT
git worktree add --detach "$TMP_PARENT" "$PARENT_SHA" >/dev/null

run_one() {
  local label="$1"
  local dir="$2"
  local rep="$3"
  local out
  out="$(cd "$dir" && bash tests/fpe/run_fpe_zero_waste01_gwplan01.sh)"
  local line
  line="$(printf '%s\n' "$out" | grep '^GWPLAN01_CURRENT,n=10000,')"
  printf 'GWPLAN01_PAIRED,label=%s,rep=%s,%s\n' "$label" "$rep" "${line#GWPLAN01_CURRENT,}"
}

: > /tmp/gwplan01_paired.txt
for rep in 1 2 3; do
  run_one parent "$TMP_PARENT" "$rep" | tee -a /tmp/gwplan01_paired.txt
  run_one candidate "$ROOT" "$rep" | tee -a /tmp/gwplan01_paired.txt
done

python3 - /tmp/gwplan01_paired.txt <<'PY'
import re, statistics, sys
vals={"parent":[],"candidate":[]}
for line in open(sys.argv[1]):
    if not line.startswith("GWPLAN01_PAIRED,"):
        continue
    label=re.search(r"label=([^,]+)",line).group(1)
    sec=float(re.search(r"seconds=\s*([^,]+)",line).group(1))
    vals[label].append(sec)
if len(vals["parent"]) != 3 or len(vals["candidate"]) != 3:
    raise SystemExit(f"incomplete paired results: {vals}")
pm=statistics.mean(vals["parent"])
cm=statistics.mean(vals["candidate"])
ratio=cm/pm
print(f"GWPLAN01_PAIRED_PARENT_MEAN_SECONDS={pm:.12g}")
print(f"GWPLAN01_PAIRED_CANDIDATE_MEAN_SECONDS={cm:.12g}")
print(f"GWPLAN01_PAIRED_RATIO={ratio:.12g}")
print(f"GWPLAN01_PAIRED_SHARED_RUNNER_REDUCTION_PERCENT={(1-ratio)*100:.6f}")
if not (ratio < 0.20):
    raise SystemExit(f"GWPLAN01 paired gate did not retain material improvement: ratio={ratio}")
print("FPE_ZERO_WASTE01_GWPLAN01_PAIRED=PASS")
PY
