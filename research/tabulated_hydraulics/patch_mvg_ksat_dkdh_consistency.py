#!/usr/bin/env python3
"""Research-only consistency patch for the default MvG Ksat clamp.

The legacy/default MvG residual route clamps K to Ksat when
relsat > 1-1e-6 (for h_enpr > h_crit), but its SWKIMPL=1 derivative
continues to evaluate the unclamped MvG derivative.  This patch makes the
Jacobian derivative zero over that already-constant residual branch.

It does not alter theta(h), K(h), SWKIMPL=0, or any table interpolation.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()

old = """            if (relsat < 0.001_real64) then
               dhconduc = 0.0_real64
            else if (relsat > s_enpr) then
               dhconduc = 1.0d-12
            else
"""

new = """            if (h_enpr > -1.0d-2 .and. relsat > (1.0_real64 - 1.0d-6)) then
               dhconduc = 0.0_real64
            else if (relsat < 0.001_real64) then
               dhconduc = 0.0_real64
            else if (relsat > s_enpr) then
               dhconduc = 1.0d-12
            else
"""

if text.count(old) != 1:
    raise SystemExit(f"expected one default-MvG derivative branch in {path}, found {text.count(old)}")

path.write_text(text.replace(old, new, 1))
print(f"MVG_KSAT_DKDH_CONSISTENCY_PATCH_APPLIED {path}")
