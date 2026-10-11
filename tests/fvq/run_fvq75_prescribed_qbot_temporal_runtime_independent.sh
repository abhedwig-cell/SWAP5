#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

BASE=e79b0272edb544ec4c8000a4d6869274f1ab3ae5
FSI38=4658b9f45c9a92f93a6a4b59c5c8aee33820ad94
FMR44R=acb63559b5246db33b1958bb0c5bc8c1ba2055c0
fail() { echo "FVQ75_FAIL $*" >&2; exit 175; }

# Independent scope/provenance review against the live canonical base from which
# both owner workunits were composed. Qualification-only files are deliberately
# ignored here; the production delta must remain exactly these three files.
changed_src="$(git diff --name-only "$BASE"...HEAD -- src | sort)"
expected=$'src/adapter/mod_b110_serialized_context_binding.f90\nsrc/runtime/mod_fmr_serialized_reference_backend.f90\nsrc/solver/mod_reference_richards_temporal_indicator.f90'
[[ "$changed_src" == "$expected" ]] || { printf '%s\n' "$changed_src" >&2; fail 'unexpected production source delta'; }
! git diff --name-only "$BASE"...HEAD -- reference | grep -q . || fail 'reference source changed'
git merge-base --is-ancestor "$FSI38" HEAD || fail 'F-SI38 authority not in ancestry'
git merge-base --is-ancestor "$FMR44R" HEAD || fail 'F-MR44R exact qualified head not in ancestry'
echo 'FVQ75_SCOPE_AND_PROVENANCE=PASS'

TMP="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fvq75-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

bash tests/fsi/run_fsi38_prescribed_qbot_temporal_certificate_gate.sh >"$TMP/fsi38.txt" 2>&1 || { cat "$TMP/fsi38.txt" >&2; fail 'F-SI38 preservation replay'; }
bash tests/fmr/run_fmr44r_serialized_prescribed_qbot_gate.sh >"$TMP/fmr44r.txt" 2>&1 || { cat "$TMP/fmr44r.txt" >&2; fail 'F-MR44R runtime replay'; }

for marker in \
  'FSI38_PRESCRIBED_QBOT_TEMPORAL_CERTIFICATE=PASS' \
  'FSI38_MODE5_O0_O2_SEMANTIC_IDENTITY=PASS' \
  'FSI38_QUALIFICATION_GATE=PASS'; do
  grep -Fq "$marker" "$TMP/fsi38.txt" || { cat "$TMP/fsi38.txt" >&2; fail "missing F-SI38 marker: $marker"; }
done
for marker in \
  'FMR44R_MODE2_EQUILIBRIUM_TRANSACTION=PASS' \
  'FMR44R_POSITIVE_QBOT_ACCEPTED_INFLOW=PASS' \
  'FMR44R_NEARBY_BOTTOM_MODE_FAIL_CLOSED=PASS' \
  'FMR44R_O0_O2_SEMANTIC_IDENTITY=PASS' \
  'FMR44R_QUALIFICATION_GATE=PASS'; do
  grep -Fq "$marker" "$TMP/fmr44r.txt" || { cat "$TMP/fmr44r.txt" >&2; fail "missing F-MR44R marker: $marker"; }
done
grep -Fq 'FMR44R_PRODUCTION_ADMISSION_PATCH_COUNT=0' "$TMP/fmr44r.txt" || fail 'runtime replay attempted to patch production source'

python3 - "$TMP/fmr44r.txt" <<'PY'
import math, re, sys
text=open(sys.argv[1], encoding='utf-8').read()
def one(pattern, name):
    m=re.search(pattern, text)
    if not m: raise SystemExit(f'FVQ75_PARSE_FAIL {name}')
    return tuple(float(x) for x in m.groups())
res,total_in,total_out=one(r'FMR44R_POSITIVE_QBOT_MASS residual=\s*([+\-0-9.Ee]+) total_in=\s*([+\-0-9.Ee]+) total_out=\s*([+\-0-9.Ee]+)', 'mass')
binf,ch=one(r'FMR44R_POSITIVE_QBOT_CERTIFICATE Binf=\s*([+\-0-9.Ee]+) Ch=\s*([+\-0-9.Ee]+)', 'certificate')
(budget,)=one(r'FMR44R_QUALIFICATION_HEAD_BUDGET_CM=\s*([+\-0-9.Ee]+)', 'budget')
vals=(res,total_in,total_out,binf,ch,budget)
if not all(math.isfinite(x) for x in vals): raise SystemExit('FVQ75_NUMERIC_FAIL nonfinite')
if abs(res) > 1.0e-12: raise SystemExit(f'FVQ75_NUMERIC_FAIL mass={res}')
if total_in <= 0.0 or total_out <= 0.0: raise SystemExit('FVQ75_NUMERIC_FAIL no-positive-transfer')
if abs(total_in-total_out) > 1.0e-12: raise SystemExit('FVQ75_NUMERIC_FAIL transfer-not-closed')
if not (0.0 < binf <= budget): raise SystemExit(f'FVQ75_NUMERIC_FAIL Binf={binf} budget={budget}')
if not (0.0 < ch <= 1.0): raise SystemExit(f'FVQ75_NUMERIC_FAIL normalized={ch}')
print(f'FVQ75_INDEPENDENT_MASS_RESIDUAL={res:.17e}')
print(f'FVQ75_INDEPENDENT_BINF_CM={binf:.17e}')
print(f'FVQ75_INDEPENDENT_HEAD_BUDGET_CM={budget:.17e}')
print(f'FVQ75_INDEPENDENT_NORMALIZED_INDICATOR={ch:.17e}')
print('FVQ75_NUMERIC_ORACLE=PASS')
PY

# Replays are observation-only on production/reference source.
git diff --quiet -- src reference || { git diff -- src reference >&2; fail 'qualification mutated production/reference source'; }

echo 'FVQ75_FSI38_PRESERVATION=PASS'
echo 'FVQ75_FMR44R_PRESERVATION=PASS'
echo 'FVQ75_INDEPENDENT_QUALIFICATION=PASS'
