# F-PE-TIMEINT06 preregistration — fully implicit-flux BDF2 diagnostic

Date: 2026-09-28

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@bc365f8d24fb1854ee1484a4f6f9dcc5bc3944fb`

Parent:

F-PE-TIMEINT05.

## Question

Was TIMEINT05's BDF2 accuracy regression caused by combining a second-order storage derivative with the first-order lagged-conductivity SWKIMPL=0 flux treatment?

TIMEINT06 is a mechanism diagnostic, not a production qualification.

## Candidate

Reuse the exact TIMEINT05 BDF2 storage discretization:

`(1.5 theta_{n+1}-2 theta_n+0.5 theta_{n-1})/dt`.

Change only the flux treatment to the existing fully implicit conductivity route:

`SWKIMPL=1`.

For the smooth FLUX top-boundary domain:

- top flux remains prescribed by the dynamic-top provider;
- no dynamic HEAD-boundary Jacobian claim is made;
- interior conductivity and dK/dh use the existing SWKIMPL=1 HeadCalc formulation.

No new conductivity formula is introduced.

## Comparator

Within TIMEINT06, compare on identical SWKIMPL=1 physics/numerics:

1. one backward-Euler step;
2. one BDF2 step;
3. a four-times refined backward-Euler reference.

This isolates temporal order from the SWKIMPL=0 lagged-flux approximation.

TIMEINT06 does not compare SWKIMPL=1 against the admitted SWKIMPL=0 production route.

## History and domain

Use the same constant-dt two-step backward-Euler startup and the same smooth-domain material/state bank as TIMEINT05.

Exclude any point that enters:

- dynamic-top HEAD regime;
- ponding;
- runoff.

No conclusion may be generalized to the unqualified SWKIMPL=1 dynamic-head route.

## Step sizes

Unchanged:

- 0.005 d;
- 0.010 d;
- 0.020 d.

## Mass measure

Use the same discrete method-specific mass gates as TIMEINT05:

- BE endpoint-storage ledger for BE/refined BE;
- BDF2 multistep discrete mass residual for BDF2.

## Advancement / attribution gates

The fully implicit BDF2 hypothesis is supported only if:

1. at least 24 complete smooth-domain points exist;
2. no BDF2 candidate failure occurs where BE and refined BE complete;
3. all discrete mass residuals <=5e-8 cm;
4. median BDF2 max-theta error <=0.60 * median BE max-theta error;
5. median BDF2 water-L1 error <=0.60 * median BE water-L1 error;
6. median BDF2 / BE deterministic work ratio <=1.50;
7. no BDF2 theta/water error >2x BE on any complete point.

If gates 4 and 5 pass after failing in TIMEINT05, attribute the TIMEINT05 failure primarily to temporal inconsistency of the lagged SWKIMPL=0 flux treatment.

If they still fail, close BDF2 as the first higher-order migration candidate.

## Production boundary

Research-only.

No SWKIMPL=1 production expansion and no dynamic-head admission.
