#!/usr/bin/env python3
"""Independent algebraic check for the SWAP-009 Kelvin-sign correction.

This is not a replacement for the historical Fortran hydraulic testbank. It
checks only the sign-sensitive relative-humidity factor implemented in
Kvap_func and reproduces the magnitude ratios recorded in the audit note.
"""

from __future__ import annotations

import math

MG_R = 0.018015 * 9.81 / 8.314
TEMP_C = 20.0
MG_RT = MG_R / (TEMP_C + 273.15)

CASES = {
    -1.0e5: 1.1560647951960363,
    -1.0e6: 4.264044823431949,
    -1.0e7: 1987090.3453166387,
}


def hr(head_cm: float) -> float:
    return math.exp(head_cm / 100.0 * MG_RT)


def main() -> None:
    for head_cm, expected_old_over_new in CASES.items():
        corrected = hr(head_cm)
        old = hr(abs(head_cm))
        ratio = old / corrected

        assert 0.0 < corrected < 1.0, (head_cm, corrected)
        assert old > 1.0, (head_cm, old)
        assert math.isclose(ratio, expected_old_over_new, rel_tol=1.0e-12), (
            head_cm,
            ratio,
            expected_old_over_new,
        )

        print(
            f"h={head_cm:.0e} cm: "
            f"Hr(corrected)={corrected:.12g}; "
            f"Hr(old)={old:.12g}; old/corrected={ratio:.12g}"
        )

    print("SWAP-009 Kelvin-sign theory check: PASS")


if __name__ == "__main__":
    main()
