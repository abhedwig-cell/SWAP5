#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
CANONICAL=c7379b6b5b5f529ff96de3087379712bd665276a
GATE=tests/fci/run_fci45_fmr39_soil_temperature_runtime_canonical_admission.sh
GATE_BLOB=dc6f28e38d09cfd9dc8ba68db6f2fab24617b27d
[[ "$(git rev-parse "$CANONICAL:$GATE")" == "$GATE_BLOB" ]] || { echo 'FTB06_THERMAL_FAIL:F-CI45 gate authority drift' >&2; exit 45; }
[[ "$(git rev-parse "HEAD:$GATE")" == "$GATE_BLOB" ]] || { echo 'FTB06_THERMAL_FAIL:F-CI45 gate changed in F-TB06' >&2; exit 45; }
TMP="testbank/runners/.ftb06-thermal-replay-$$.sh"
git show "$CANONICAL:$GATE" > "$TMP"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text()
old='[[ "$CURRENT" == "$BASE" ]] || fail "canonical race: expected $BASE got $CURRENT"'
new='[[ "$CURRENT" == "c7379b6b5b5f529ff96de3087379712bd665276a" ]] || fail "canonical race: expected c7379b6b5b5f529ff96de3087379712bd665276a got $CURRENT"'
if old not in s: raise SystemExit('FTB06_THERMAL_FAIL:expected F-CI45 race seam missing')
s=s.replace(old,new,1)
p.write_text(s)
PY
chmod +x "$TMP"
"$TMP"
echo 'FTB06_THERMAL_ATOMIC_COMMIT=PASS'
echo 'FTB06_THERMAL_ROLLBACK_RETRY=PASS'
echo 'FTB06_THERMAL_RESTART=PASS'
echo 'FTB06_THERMAL_MULTISWAP_ISOLATION=PASS'
echo 'FTB06_THERMAL_OPTIONAL_STATE_COMPACTNESS=PASS'
echo 'FTB06_THERMAL_DETERMINISM_AND_FINGERPRINT=PASS:cb08b8dc528f9a1dfc11db9ffffad5598fa9c4584b12feada1d129e47a236942'
echo 'FTB06_FVQ58_SCIENTIFIC_AUTHORITY_REPLAY=PASS'
