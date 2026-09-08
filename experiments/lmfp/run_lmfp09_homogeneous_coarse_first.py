from __future__ import annotations

import bisect
import math
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import run_lmfp09_homogeneous_face_matrix as core

# Hierarchical qualification only: evaluate the two smallest nested runtime
# densities first. All physical equations, head/gradient envelopes, materials,
# geometry classes, probes and acceptance thresholds remain those of B1.
# If neither 17 nor 33 passes, the already-defined 65-node master remains the
# next density and no threshold is relaxed.
core.MASTER_NX = 33
core.VIEW_NX = (17, 33)


def tolerant_bracket(axis, x):
    """Bracket with endpoint tolerance restricted to floating-point roundoff.

    The first B1 run completed the expensive master-grid preparation and then
    rejected h=+100 cm because asinh(h/hscale) was one ulp above the stored
    final coordinate. This function only reconciles such machine-precision
    endpoint differences. It does not permit physical extrapolation: values
    outside a 64-ulp coordinate tolerance still fail closed.
    """
    tol = 64.0 * math.ulp(max(1.0, abs(axis[0]), abs(axis[-1])))
    if x < axis[0]:
        if axis[0] - x <= tol:
            x = axis[0]
        else:
            raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    elif x > axis[-1]:
        if x - axis[-1] <= tol:
            x = axis[-1]
        else:
            raise ValueError(("axis_out_of_range", x, axis[0], axis[-1]))
    if x == axis[-1]:
        return len(axis) - 2, len(axis) - 1
    i = bisect.bisect_right(axis, x) - 1
    return max(0, i), min(len(axis) - 1, i + 1)


core.bracket = tolerant_bracket

if __name__ == "__main__":
    core.main()
