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
