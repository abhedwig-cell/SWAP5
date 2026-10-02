# PPA-WU05-C3A-PERF02 pre-waterfilm bound derivation

## Exact integrand shape

The admitted MvG waterfilm integrand can be written, up to positive node constants, as

`f(x) = x^(n+1) * (1 + (alpha*x)^n)^(-(2 - 1/n))`, with `n > 1`.

Its logarithmic derivative has the sign of

`(n+1) + (2 - n) * (alpha*x)^n`.

Consequences:
- for `1 < n <= 2`, the integrand is monotone increasing on the complete positive integration interval;
- for `n > 2`, it increases until the unique maximum where
  `(alpha*x)^n = (n+1)/(n-2)`, then decreases.

This yields an equation-backed cheap upper bound on the integral `I = integral_0^H f(x) dx`:
- if `n <= 2`, `I <= H*f(H)`;
- if `n > 2`, `I <= H*f(x_peak)` when the peak lies in the interval, otherwise `I <= H*max(f(H),f(lower))`.

The actual source lower bound is `1e-10 Pa`; using zero in the interval length only enlarges the integral upper bound and is conservative.

## Direction needed for MICRO safety

Waterfilm thickness is
`w = 2*(sqrt(1/(pi*I)) - 2*sigma/H)`.

Therefore an upper bound on `I` gives a lower bound on `w`, not an upper bound. Whether that is the conservative direction for `c_micro` is not assumed: `c_micro(w)` contains competing terms through waterfilm area, diffusivity ratio and logarithms.

Admission therefore requires either:
1. proof that `c_micro(w)` is monotone over the admitted physical domain, so the appropriate integral bound can be propagated safely; or
2. a direct analytical upper bound on `c_micro` that avoids assuming monotonicity.

No skip gate is admitted from the MvG integral bound alone.


## Correct conservative direction and first falsification

A numerical monotonicity falsification over 36,150 MICRO evaluations found zero decreases in c_micro as waterfilm thickness increased across the tested admitted-like domain.

Therefore a safe no-stress proof needs an upper bound on waterfilm thickness, hence a lower bound on MvG length-density integral.

For admitted n <= 2, the positive increasing integrand gives:
`I >= (H/2) * f(H/2)`.

This yields a conservative film upper bound and therefore a conservative c_micro upper bound at max_resp_factor. Combined with the exact cheap MACRO concentration, the gate returns NO_STRESS only when `c_macro >= c_micro_upper_bound` for every rooted node.

Initial 1100-state falsification:
- full Reference no-stress: 765;
- analytical pre-waterfilm skips: 672;
- false skips: 0;
- capture of no-stress states: 87.84%;
- overall skip fraction in this synthetic sweep: 61.09%.

These fractions are not production-frequency estimates. Boundary-focused falsification remains required.


## Production-envelope check

The current typed Bartholomeus parameter contract validates `waterfilm_gen_n > 1` and does not impose an upper bound of 2. Therefore `n > 2` is part of the syntactically admitted analytical-MvG production envelope and the monotone-increasing lower-bound proof must not be extrapolated to it.

PERF02 deliberately does not add a piecewise `n > 2` optimization. The gate returns false for `n > 2`, which preserves the complete PERF01 Reference route. Boundary qualification must assert zero skips for those cases. This is a performance false negative by design, not a physics approximation.

The boundary oracle must also bypass PERF02 itself. After integration into the factor provider, calling `evaluate_bartholomeus_factors_from_state` is not an independent Reference oracle because that routine contains the gate. The qualification oracle therefore evaluates REFERENCE waterfilm explicitly and then calls `evaluate_bartholomeus_factors`, reproducing the admitted PERF01 path without the PERF02 shortcut.
