#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-source-$$"
rm -rf "$BUILD"; mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT

BUNDLE=integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64
test -f "$BUNDLE"
base64 -d "$BUNDLE" > "$BUILD/authority.tar.gz"
tar -xzf "$BUILD/authority.tar.gz" -C "$BUILD"
SRC="$(find "$BUILD" -type f -path '*/SWAP/irrigation.f90' -print -quit)"
test -n "$SRC"
test "$(sha256sum "$SRC" | awk '{print $1}')" = "65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1"
for token in RAWTAB TAWTAB DWATAB IRGTHRESHOLD TCRITAB DCSLIM SWCIRRTHRES F_IRR_AVAIL; do
  # Fortran identifiers are case-insensitive; the pinned source spells these in lower case.
  grep -Fiq "$token" "$SRC" || { echo "MC_IRR01_SOURCE_TOKEN_MISSING=$token" >&2; exit 1; }
done

# Pin decision operators and postselection order from the exact B1.11 authority.
grep -Fq 'if (awah < (awlh - depl)) irrigevent = 2' "$SRC"
grep -Fq 'if ((awlh-awah) > (tps4 * 0.1d0)) irrigevent = 2' "$SRC"
grep -Fq 'if (10.0d0 * cdef > irgthreshold) then' "$SRC"
grep -Fq 'if (h(nodsen) <= phcrit) irrigevent = 2' "$SRC"
grep -Fq 'if (theta(nodsen) <= tps5) irrigevent = 2' "$SRC"
grep -Fq 'if (grai > raithreshold) grai_red = grai' "$SRC"
grep -Fq 'irr_depth = max(irr_depth, irgdepmin * 0.1d0)' "$SRC"
grep -Fq 'irr_depth = min(irr_depth, irgdepmax * 0.1d0)' "$SRC"
grep -Fq 'if (cml(nodsen) > cirrthres) then' "$SRC"
grep -Fq 'gird = gird * f_irr_avail' "$SRC"
grep -Fq 'if (irr_rate > 0.0d0) dt_irr_event = dt_irr_event * f_irr_avail' "$SRC"
echo 'MC_IRR01_LITERAL_DECISION_OPERATORS=PASS'

# Exact source excerpt is persisted in the workflow log for bounded contract reconstruction.
echo 'MC_IRR01_SOURCE_BEGIN'
nl -ba "$SRC" | sed -n '240,365p'
nl -ba "$SRC" | sed -n '445,645p'
nl -ba "$SRC" | sed -n '675,745p'
echo 'MC_IRR01_SOURCE_END'
echo 'MC_IRR01_SOURCE_RECONSTRUCTION=PASS'
