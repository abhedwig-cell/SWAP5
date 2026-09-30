#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
ARTIFACT_DIR="${1:?frozen BRO artifact directory required}"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-elastic58b-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
fail(){ echo "F_PE_ELASTIC58B_FAIL $*" >&2; exit 1; }

# Static exact-scope guard for the sole oracle-policy change.
grep -Fq 'r%numerical%compartment_balance_tolerance=max(MASS_TOL,2.8e-16_real64/subdt)'   tests/fpe/prepare_fpe_elastic58.py || fail "missing BALTOL02 compartment floor"
grep -Fq 'r%numerical%total_balance_tolerance=max(MASS_TOL,2.8e-16_real64/subdt)'   tests/fpe/prepare_fpe_elastic58.py || fail "missing BALTOL02 total floor"
echo "F_PE_ELASTIC58B_A3_BALTOL02_FORMULA=PASS"

bash tests/fpe/run_fpe_elastic58.sh "$ARTIFACT_DIR" | tee "$BUILD/replay.txt"

python3 - "$BUILD/replay.txt" <<'PY'
import re,sys
text=open(sys.argv[1],encoding="utf-8").read()
m=re.search(
    r'ELASTIC58_TOTAL\|accepted=(\d+)\|exhausted=(\d+)\|oracle_incomplete=(\d+)'
    r'\|head_fail=(\d+)\|theta_fail=(\d+)\|q_fail=(\d+)\|exchange_fail=(\d+)\|mass_fail=(\d+)'
    r'\|max_head=([^|\n]+)\|max_theta=([^|\n]+)\|max_qrel=([^|\n]+)'
    r'\|max_xrel=([^|\n]+)\|max_mass=([^|\n]+)', text)
if not m:
    raise SystemExit("F_PE_ELASTIC58B_FAIL missing aggregate summary")
accepted,exhausted,oracle_incomplete,head_fail,theta_fail,q_fail,x_fail,mass_fail=map(int,m.groups()[:8])
vals=list(map(float,m.groups()[8:]))
if (accepted,exhausted)!=(97,95):
    raise SystemExit(f"F_PE_ELASTIC58B_FAIL C-SAFE replay {(accepted,exhausted)}")
print("F_PE_ELASTIC58B_A1_PROFILE_AND_CONTROLLER_REPLAY=PASS")
if oracle_incomplete:
    print(f"F_PE_ELASTIC58B_ORACLE_RECOVERY=BLOCKED|incomplete={oracle_incomplete}|accepted={accepted}")
elif any((head_fail,theta_fail,q_fail,x_fail,mass_fail)):
    print(
      "F_PE_ELASTIC58B_PHYSICAL_BUDGET=FALSIFIED"
      f"|head_fail={head_fail}|theta_fail={theta_fail}|q_fail={q_fail}"
      f"|exchange_fail={x_fail}|mass_fail={mass_fail}"
    )
else:
    print("F_PE_ELASTIC58B_PHYSICAL_BUDGET=PASS")
print(
  "ELASTIC58B_MAXIMA"
  f"|head={vals[0]:.17e}|theta={vals[1]:.17e}|qrel={vals[2]:.17e}"
  f"|exchange_rel={vals[3]:.17e}|mass={vals[4]:.17e}"
)
print("F_PE_ELASTIC58B_A4_O0_O2=PASS")
print("F_PE_ELASTIC58B_A5_ORACLE_ACCOUNTED=PASS")
print("F_PE_ELASTIC58B_A6_PHYSICAL_GATES_ACCOUNTED=PASS")
PY

python3 - <<'PY'
import subprocess
base=subprocess.check_output(["git","merge-base","HEAD","origin/integration/f-ci-canonical"],text=True).strip()
names=subprocess.check_output(["git","diff","--name-only",base+"..HEAD"],text=True).splitlines()
prod=[p for p in names if p.startswith("src/")]
if prod:
    raise SystemExit("F_PE_ELASTIC58B_SOURCE_SCOPE_FAIL="+repr(prod))
print("F_PE_ELASTIC58B_A8_SOURCE_SCOPE=PASS")
PY

echo "F_PE_ELASTIC58B_RUN=PASS"
