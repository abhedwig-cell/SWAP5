#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
PRE="integration/m1/M1_C3_B1_11_APPLICATION_TRACE_PREREGISTRATION.json"
BASE="integration/m1/M1_C3_B1_11_IDENTITY_BASELINE_ACQUIRE_PASS.json"
OUT="M1_C3_B1_11_HUPSEL_APPLICATION_TRACE.txt"
python3 - "$PRE" "$BASE" "$OUT" <<'PY'
import json, pathlib, sys
pre=json.load(open(sys.argv[1],encoding="utf-8"))
base=json.load(open(sys.argv[2],encoding="utf-8"))
dates=pre["frozen_interval_selection"]["dates"]
assert dates == base["frozen_observation_intervals"]
assert base["verdict"] == "PASS_B1_11_IDENTITY_AND_UNINSTRUMENTED_HUPSEL_BASELINE"
lines=[
 "workunit=M1-C3",
 "campaign=B1.11_HUPSEL_APPLICATION_TRACE",
 "status=BLOCKED_EXACT_EXECUTABLE_MATERIALIZATION_NOT_PERSISTED",
 "b1_11_manifest="+base["reference_authority"]["source_manifest_sha256"],
 "swap_swp_sha256="+base["official_hupsel_authority"]["swap_swp_sha256"],
 "meteo_283_sha256="+base["official_hupsel_authority"]["meteo_283_sha256"],
 "baseline_result_bal_normalized_sha256="+base["uninstrumented_b1_11_hupsel"]["result_bal_normalized_sha256"],
 "baseline_result_blc_normalized_sha256="+base["uninstrumented_b1_11_hupsel"]["result_blc_normalized_sha256"],
 "frozen_dates="+",".join(dates),
 "selection="+base["observation_selection"],
 "reason=Exact executable source/input materialization bytes are not persisted in the repository. Approximate or public substitutes are forbidden.",
 "next=Persist an immutable exact-source/input materialization asset or approved artifact handoff; then instrument only a disposable B1.11 copy at the preregistered accepted-interval boundary."
]
pathlib.Path(sys.argv[3]).write_text("\n".join(lines)+"\n",encoding="utf-8")
print("\n".join(lines))
PY
exit 2
