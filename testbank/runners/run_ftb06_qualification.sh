#!/usr/bin/env bash
set -euo pipefail
PROFILE="${1:-FAST}"
case "$PROFILE" in FAST|CANONICAL|RELEASE|DEEP) ;; *) echo "usage: $0 {FAST|CANONICAL|RELEASE|DEEP}" >&2; exit 2;; esac
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

python3 testbank/runners/validate_ftb06_soil_temperature_adoption.py
python3 -m json.tool testbank/manifests/F-TB06_SOIL_TEMPERATURE_RUNTIME_CASES.json >/dev/null
python3 -m json.tool integration/f-tb/F-TB06_WORK_UNIT_CONTRACT.json >/dev/null
python3 -m json.tool integration/f-tb/F-TB06_INVARIANT_AUDIT.json >/dev/null

if [[ "$PROFILE" != FAST ]]; then
  bash testbank/runners/run_ftb06_thermal_current_canonical_replay.sh
fi

case "$PROFILE" in
  FAST)
    echo 'FTB06_FAST_SCOPE=REGISTRY_PROVENANCE_IMMUTABILITY_STATIC_ARCHITECTURE'
    ;;
  CANONICAL)
    echo 'FTB06_CANONICAL_SCOPE=EIGHT_THERMAL_CASES_PLUS_FVQ58'
    ;;
  RELEASE|DEEP)
    echo 'FTB06_RELEASE_SCOPE=EIGHT_THERMAL_CASES_PLUS_FMR19_DISABLED_PATH_PLUS_EXACT_FINGERPRINT_PLUS_FVQ58'
    ;;
esac

echo "FTB06_PROFILE_${PROFILE}=PASS"
