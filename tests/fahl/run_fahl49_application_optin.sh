#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/swap5-fahl49-app-${GITHUB_RUN_ID:-local}-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

python3 - "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
src=Path("tests/fapp/test_ppa_wu01_production_application_bootstrap.f90").read_text()
src=src.replace(
"  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c, fgc49d_capture_origins_c, &\n       fgc49d_abort_prepublication_c",
"  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c, fgc49d_capture_origins_c, &\n       fgc49d_abort_prepublication_c\n  use mod_b110_direct_retention_core, only: b110_direct_retention_pool_stats")
src=src.replace(
"  type(fmr_production_application_config_t) :: config, gw_config, bad_config, root_bad_config, drainage_bad_config, &\n       registry_bad_config",
"  type(fmr_production_application_config_t) :: config, gw_config, fast_config, bad_config, root_bad_config, drainage_bad_config, &\n       registry_bad_config")
src=src.replace(
"  type(fmr_production_application_bootstrap_t) :: app, gw_app, bad_app, root_bad_app, drainage_bad_app, registry_bad_app",
"  type(fmr_production_application_bootstrap_t) :: app, gw_app, fast_app, bad_app, root_bad_app, drainage_bad_app, registry_bad_app")
src=src.replace(
"  integer :: i, status, topology_status",
"  integer :: i, status, topology_status, direct_entries, direct_builds, direct_hits")
src=src.replace(
"  integer(c_int) :: ncell, ntile_count, c_status",
"  integer(c_int) :: ncell, ntile_count, c_status\n  integer(int64) :: direct_payload\n  logical :: direct_frozen")
needle="""  do i = 1, NTILE
    gw_config%tiles(i)%parameters%bottom_mode = 5
  end do
  call gw_app%initialize(gw_config, status)"""
insert="""  do i = 1, NTILE
    gw_config%tiles(i)%parameters%bottom_mode = 5
  end do

  fast_config = gw_config
  do i = 1, NTILE
    fast_config%tiles(i)%parameters%direct_retention_active = .true.
  end do
  call fast_app%initialize(fast_config, status)
  call require(status == FMR_APP_BOOT_OK .and. fast_app%ready(), 'direct-retention production bootstrap initialize')
  call b110_direct_retention_pool_stats(direct_entries,direct_builds,direct_hits,direct_payload,direct_frozen)
  call require(direct_entries == 1 .and. direct_builds == 1 .and. direct_hits == 1, &
       'direct-retention exact authority reuse')
  call require(direct_payload == 6240_int64 .and. direct_frozen, 'direct-retention frozen payload')
  call fast_app%run_standalone(T0, T1, results, status)
  call require(status == FMR_APP_BOOT_OK .and. allocated(results), 'direct-retention application run')
  call require(all(results%completed) .and. all(results%committed), 'direct-retention application commits')
  call require(maxval(abs(results%mass%residual)) <= HARD_MASS_GATE, 'direct-retention application mass')
  call fast_app%close(status)
  call require(status == FMR_APP_BOOT_OK, 'direct-retention application close')
  print '(a)', 'FAHL49_APPLICATION_OPTIN=PASS'

  call gw_app%initialize(gw_config, status)"""
if needle not in src: raise SystemExit("insertion seam missing")
src=src.replace(needle,insert)
Path(sys.argv[1]).write_text(src)
PY

python3 - "$BUILD/run.sh" "$BUILD/test.f90" <<'PY'
from pathlib import Path
import sys
runner=Path("tests/fapp/run_ppa_wu01_production_application_bootstrap.sh").read_text()
runner=runner.replace("tests/fapp/test_ppa_wu01_production_application_bootstrap.f90",sys.argv[2])
needle="  src/solver/mod_b110_default_mvg_provider.f90\n"
insert=needle+"  src/solver/mod_b110_direct_retention_core.f90\n  src/solver/mod_b110_direct_retention_provider.f90\n"
if "src/solver/mod_b110_direct_retention_core.f90" not in runner:
    if needle not in runner: raise SystemExit("compile seam missing")
    runner=runner.replace(needle,insert,1)
Path(sys.argv[1]).write_text(runner)
PY
chmod +x "$BUILD/run.sh"
bash "$BUILD/run.sh" | tee "$BUILD/output.txt"
grep -Fq 'FAHL49_APPLICATION_OPTIN=PASS' "$BUILD/output.txt"
echo 'FAHL49_APPLICATION_GATE=PASS'
