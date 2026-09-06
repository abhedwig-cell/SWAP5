# SWAP-010 qualification evidence

Current B1 admission status: **PROPOSED FOR B1.7**

## Exact source identity

SWAP-010 shares `WC_K_models_04_11.f90` with already-admitted SWAP-009. Admission is therefore checked against both canonical B0 provenance and the exact ordered B1.6 preimage.

```text
canonical B0 target SHA-256
1f956cae894e83e208630e234c9b2017c945b2c522daf8277e89541f598ae4fd

ordered B1.6 target SHA-256
f728e832645ab8273e41d0d285910240565148671989de24882740e7244f15b7

stored SWAP-010 fix.patch SHA-256
f3d67771908e27a23610a650c4ad72813d882169f360a973472f86f545ee5deb

corrected B1.7 target SHA-256
7ca607b2bbf97e166a32ab8a529fc7f32af9949afb1e6eb518ddbf84e6f0169e
```

`apply_and_verify.py` fails closed if raw B0 is supplied directly, because SWAP-009 must precede SWAP-010 on this shared target.

## Source-bound capacity derivative gate

A fresh GNU Fortran gate compiled the actual B1.6 and corrected `WC_K_models_04_11.f90` model-7 route with strict runtime checks:

```text
GNU Fortran 14.2.0
-std=f2018 -ffree-line-length-none -O0 -fcheck=all
-ffpe-trap=invalid,zero,overflow -Wall -Wextra
```

The gate evaluates 50 deterministic parameter sets at 20 unsaturated pressure heads each. For every point it compares actual `functionvalue_04_11(iType=3)` capacity with a central finite-difference derivative of the same source's `functionvalue_04_11(iType=1)` water-retention function. The failure threshold is relative error `> 1e-3`.

```text
                         B1.6            corrected
points                    1000                 1000
failures > 1e-3            784                    0
failure fraction          0.784                  0.0
maximum relative error    1.6041e-1          3.3272e-8
```

The earlier audit matrix used a different sample and reported a baseline failure fraction of about 40.2% -> 0 after correction. The differing baseline percentage is expected from the different parameter/head grid; the independent conclusion is the same.

Status: **DIRECT MODEL-7 CAPACITY CONSISTENCY GATE PASS**.

## Representative full SWAP model-7 production path

A deterministic two-day bare-soil case was derived from the supplied official `2.grassgrowth` case. It uses model 7 in all five soil layers, uniform initial `h=-1000 cm`, zero bottom flux, no rain, `ETref=5 mm/d`, and a fixed hard legacy mass criterion `CRITDEVMASBAL=1e-6 cm`.

Input identities:

```text
swap.swp  d038ee57f58b100bdfaa5445b1e0ef72f06b0f26caaca5fa2f5419e4608f650e
m7.met    48c269785405464476ca49dd315e12ae67e782fb0e6d3cd0322155d0ab8fb3bc
```

Both B1.6 and the corrected candidate complete normally with legacy return code 100 and `swap.ok`.

The nonlinear routes are materially different:

```text
B1.6
4 Newton iterations: 9997 hits, 39988 backtracking cycles
5 Newton iterations:    3 hits,    15 backtracking cycles

corrected
2 Newton iterations:   57 hits,   114 backtracking cycles
```

This route difference is qualification evidence, not a performance benchmark: the host is not admitted for performance claims and no runtime speedup is inferred.

An identical output-only high-precision diagnostic transform was applied to both variants. It changes no state or physics expression. Maximum differences in the resulting existing BFO state/flux records are:

```text
                    day 1              day 2
pressure head       0.4296534490 cm    0.2364111968 cm
theta               3.82636e-5        2.02598e-5
flux record         1.67162e-5        5.55992e-6
```

Rounded `result.bal` is identical after generated timestamps are removed; higher-precision state/flux records expose the expected model-7 trajectory difference.

Status: **REPRESENTATIVE FULL MODEL-7 PRODUCTION-PATH GATE PASS**.

## Hard unrounded water balance

The same diagnostic build emits the already-computed unrounded legacy balance residuals. The criterion was fixed in the input before comparison:

```text
CRITDEVMASBAL = 1.0e-6 cm
```

Maximum absolute diagnostic residuals are:

```text
B1.6 predecessor        1.5789125609178001e-6 cm
corrected candidate     1.0036789788170353e-8 cm
```

The B1.6 predecessor consequently creates `result.dwb` for the first interval; the corrected candidate creates no `.dwb`. Profile and compartment residuals remain at approximately machine precision in both runs.

This means the candidate satisfies the predeclared full-run mass gate while the predecessor does not for this deliberately model-7-sensitive case. No tolerance is relaxed and no water-balance exception is introduced.

Status: **HARD FULL-RUN LEGACY MASS GATE PASS FOR CORRECTED CANDIDATE**.

## Qualification boundary

The evidence establishes a direct implementation defect and its minimal algebraic repair. It does not generalize to a new hydraulic model, alter model-7 retention, change other hydraulic models, or qualify any performance policy.

Prospective B1.7 source identity after ordered application is:

```text
members          63
source bytes      1,860,091
manifest SHA-256  62939097cfcdb59f8fe8c9161356fc703d7c54d6dd61ab3c31b19c2cfea6a5ba
```

Formal admission requires the repository bookkeeping and fail-closed B1.7 identity gate to pass in CI.
