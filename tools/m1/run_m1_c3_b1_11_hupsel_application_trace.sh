#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PRE="integration/m1/M1_C3_B1_11_APPLICATION_TRACE_PREREGISTRATION.json"
BASE="integration/m1/M1_C3_B1_11_IDENTITY_BASELINE_ACQUIRE_PASS.json"
ARCHIVE="${M1_C3_B0_ARCHIVE:-}"
OUT="${M1_C3_TRACE_OUT:-M1_C3_B1_11_HUPSEL_APPLICATION_TRACE.txt}"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" ]]; then
  echo "M1_C3_TRACE_BLOCKED=EXACT_B0_ARCHIVE_NOT_MOUNTED"
  echo "Set M1_C3_B0_ARCHIVE to any filename containing the exact admitted SWAP 4.3.1 distribution bytes."
  exit 2
fi
python3 - "$PRE" "$BASE" "$ARCHIVE" "$OUT" <<'PY'
import hashlib,json,pathlib,sys,zipfile
pre=json.load(open(sys.argv[1],encoding="utf-8"))
base=json.load(open(sys.argv[2],encoding="utf-8"))
archive=pathlib.Path(sys.argv[3]); out=pathlib.Path(sys.argv[4])
sha=lambda b: hashlib.sha256(b).hexdigest()
outer=archive.read_bytes()
if sha(outer) != pre["reference"]["b0_distribution_sha256"]: raise SystemExit("FAIL: B0 distribution SHA mismatch")
with zipfile.ZipFile(archive) as z:
    src=z.read("SWAP_4.3.1/tools/SWAP/source/SWAP.ZIP")
    swp=z.read("SWAP_4.3.1/cases/1.hupselbrook/swap.swp")
    met=z.read("SWAP_4.3.1/cases/1.hupselbrook/283.met")
if sha(src) != pre["reference"]["b0_source_archive_sha256"]: raise SystemExit("FAIL: nested SWAP.ZIP SHA mismatch")
if sha(swp) != pre["case"]["swap_swp_sha256"]: raise SystemExit("FAIL: Hupsel swap.swp SHA mismatch")
if sha(met) != pre["case"]["meteorology_sha256"]: raise SystemExit("FAIL: Hupsel 283.met SHA mismatch")
dates=pre["frozen_interval_selection"]["dates"]
assert dates == base["frozen_observation_intervals"]
lines=["workunit=M1-C3","campaign=B1.11_HUPSEL_APPLICATION_TRACE","materialization=PASS_EXACT_ADMITTED_DISTRIBUTION","b0_distribution_sha256="+sha(outer),"b0_source_archive_sha256="+sha(src),"swap_swp_sha256="+sha(swp),"meteo_283_sha256="+sha(met),"frozen_dates="+",".join(dates),"status=READY_FOR_B1_11_RECONSTRUCTION_AND_OBSERVATION"]
out.write_text("\n".join(lines)+"\n",encoding="utf-8"); print("\n".join(lines))
PY
echo "M1_C3_MATERIALIZATION_PASS=1"
