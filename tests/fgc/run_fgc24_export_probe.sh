#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
OWNER=1da854e4dd2d45fe388ee2a1ef3bd67c76d3d73f
B="${TMPDIR:-/tmp}/fgc24-probe-$$"
mkdir -p "$B"
trap 'rm -rf "$B"' EXIT
python3 - "$OWNER" "$B/fixture.f90" <<'PY'
from pathlib import Path
import subprocess, sys
text=subprocess.check_output(['git','show',f'{sys.argv[1]}:tests/fgc/test_fgc21_restricted_predictor_corrector_window.f90'],text=True)
marker='\nprogram test_fgc21_restricted_predictor_corrector_window\n'
Path(sys.argv[2]).write_text(text.split(marker,1)[0]+'\n')
PY
S=(
 src/transaction/mod_transaction_reference.f90
 src/runtime/mod_canonical_contracts.f90
 src/runtime/mod_canonical_interval_runtime.f90
 src/kernel/mod_kernel_transactions.f90
 src/kernel/mod_kernel_committed_persistence.f90
 src/runtime/mod_groundwater_coupling_contract.f90
 src/runtime/mod_groundwater_coupling_policy.f90
 src/runtime/mod_groundwater_exchange_service_contract.f90
 src/runtime/mod_groundwater_interface_mass_ledger.f90
 src/runtime/mod_groundwater_swap_forcing_adapter.f90
 src/runtime/mod_groundwater_predictor_corrector_window.f90
 src/runtime/mod_groundwater_coupled_restart.f90
)
gfortran -std=f2008 -ffree-line-length-none -O0 -J "$B" -I "$B" "${S[@]}" "$B/fixture.f90" tests/fgc/fgc24_export_probe.f90 -o "$B/probe"
"$B/probe"
