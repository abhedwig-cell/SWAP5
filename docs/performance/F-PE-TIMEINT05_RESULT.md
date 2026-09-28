# F-PE-TIMEINT05 result — mass-conservative BDF2 smooth-regime mechanism

Date: 2026-09-28

Status: `CLOSED_BDF2_STORAGE_ONLY_NOT_HIGHER_ORDER`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Evidence:

- preregistration: `docs/performance/F-PE-TIMEINT05_PREREGISTRATION.md`;
- successful Actions run: `36438456155`;
- job: `108982380378`;
- conclusion: SUCCESS.

## Prototype

Test-only HeadCalc materialization replaced the backward-Euler soil-storage term

`(theta_{n+1}-theta_n)/dt`

with constant-step BDF2

`(1.5 theta_{n+1}-2 theta_n+0.5 theta_{n-1})/dt`

and replaced the storage Jacobian coefficient by

`1.5 C(h_{n+1})/dt`.

All current SWKIMPL=0 flux/conductivity semantics were otherwise retained.

The mechanism bank was deliberately restricted to smooth dynamic-top FLUX cases with no ponding/runoff.

## Domain and mass result

Planned points:

`36`.

Complete smooth-domain comparison points:

`33`.

Outside smooth domain:

`3`.

BDF2 candidate failures inside domain:

`0`.

The BDF2 discrete multistep mass residual is roundoff-scale on all complete points.

Mass gate:

PASS.

Median BDF2 / BE deterministic work ratio:

`1.00`.

Thus the prototype changes temporal storage order without increasing the nonlinear work per tested step.

## Accuracy result

Against four-times refined backward Euler:

Median max-theta error:

- BE: `1.4914e-6`;
- BDF2: `2.4714e-6`;
- BDF2 / BE: `1.657`.

Median L1 water-depth error:

- BE: `3.3862e-5 cm`;
- BDF2: `5.7857e-5 cm`;
- BDF2 / BE: `1.709`.

Required for advancement:

`<=0.60`.

FAIL.

Outliers:

- max-theta BDF2 error >2x BE: 9 points;
- water-L1 BDF2 error >2x BE: 8 points.

Therefore the candidate fails both median and outlier gates.

## Interpretation

The negative result does not show that BDF2 is intrinsically unsuitable for Richards flow.

The prototype only upgraded the storage derivative.

On the admitted SWKIMPL=0 route, hydraulic conductivity in the flux operator remains frozen at the accepted time-level during the nonlinear solve. This lagged flux treatment is first-order in time.

A second-order storage derivative combined with a first-order lagged flux operator is not a consistent second-order discretization of the complete semi-discrete Richards system.

The result is therefore consistent with the hypothesis that the current SWKIMPL=0 flux treatment, rather than BDF2 itself, limits temporal order.

## Decision

Do not advance storage-only BDF2 as an AUTO_REFERENCE candidate.

Do not add dynamic-top BDF2 transition handling from this result.

Open a bounded diagnostic study of a temporally consistent flux treatment before rejecting BDF2 as an integrator family.
