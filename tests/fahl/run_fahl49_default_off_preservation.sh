#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
TMP="tests/fapp/.run_ppa_wu01_fahl49_$$.sh"
trap 'rm -f "$TMP"' EXIT
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fapp/run_ppa_wu01_production_application_bootstrap.sh").read_text()
needle="  src/solver/mod_b110_default_mvg_provider.f90\n"
insert=needle+"  src/solver/mod_b110_direct_retention_core.f90\n  src/solver/mod_b110_direct_retention_provider.f90\n"
if "src/solver/mod_b110_direct_retention_core.f90" not in src:
    if needle not in src: raise SystemExit("default provider compile seam missing")
    src=src.replace(needle,insert,1)
Path(sys.argv[1]).write_text(src)
PY
chmod +x "$TMP"
bash "$TMP"
echo 'FAHL49_DEFAULT_OFF_PPA_WU01=PASS'
