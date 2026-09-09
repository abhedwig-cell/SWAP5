from __future__ import annotations

import mpmath as mp

import run_ross01_gate_e3e_r2r1_endpoint_limit_oracle_repair as base


def reverse_scan_bracket(residual, y_hi: mp.mpf):
    """Same frozen 289-point log-delta scan, traversed from upper to lower q."""
    y_lo = mp.mpf(str(base.Y_MIN))
    if y_hi <= y_lo:
        raise RuntimeError(("invalid_logdelta_domain", str(y_lo), str(y_hi)))
    prev_y = y_hi
    prev_f = residual(prev_y)
    if not mp.isfinite(prev_f):
        raise RuntimeError(("nonfinite_high_scan_residual", str(prev_f)))
    for i in range(1, base.Y_SAMPLES):
        y = y_hi - (y_hi - y_lo) * mp.mpf(i) / mp.mpf(base.Y_SAMPLES - 1)
        f = residual(y)
        if not mp.isfinite(f):
            raise RuntimeError(("nonfinite_scan_residual", i, str(y), str(f)))
        if f == 0:
            return y, y, f, f
        if prev_f * f < 0:
            # Return increasing y order so the unchanged bisection code retains
            # its normal lo/hi semantics.
            return y, prev_y, f, prev_f
        prev_y, prev_f = y, f
    raise RuntimeError(("no_logdelta_sign_change", str(y_lo), str(y_hi), str(prev_f)))


base.scan_bracket = reverse_scan_bracket

if __name__ == "__main__":
    base.main()
