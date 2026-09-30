# F-PE-NLGLOB14Z32 result — stable n=13 interface-equation attribution

Date: 2026-09-30

Status:

`QUALIFIED_Z32_MIXED_INTERFACE_MECHANISM`

Qualification authority:

- workflow run: `36764856243`;
- HEAD job: `110056341910`;
- RUNOFF job: `110056341456`;
- both jobs: SUCCESS.

Canonical authority rechecked before persistence:

`integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

The canonical delta since the Z32 baseline is confined to unrelated PZG/performance-objective documentation and does not alter the Z32 scientific dependency surface.

Research postimage before result persistence:

`research/f-pe-nlglob14z32-n13-interface-attribution@76e9357b108a918463d5462f42fdfa72222d2f98`

## Coverage

Both fixtures capture all 6/6 frozen stable n=13 observation points:

1. first stable post-settlement interval;
2. 280 d;
3. 320 d;
4. 400 d;
5. 480 d;
6. 514.5 d.

Coverage therefore passes.

## Aggregate frozen classification

No single non-roundoff component satisfies a consistent >=80% material-attribution criterion across both fixtures.

Therefore the frozen fallback classification is:

`QUALIFIED_Z32_MIXED_INTERFACE_MECHANISM`.

This is a degenerate mixed result: the same-origin full/reduced differences are overwhelmingly roundoff-scale rather than evidence for multiple material physical terms.

## Roundoff significance

For O05:

- Ksat = `17.418504 cm/d`;
- double-precision machine epsilon = approximately `2.220446e-16`;
- frozen 64-epsilon flux scale using Ksat is approximately:
  `2.4753e-13 cm/d`.

Observed maximum absolute full-minus-reduced endpoint face-13/14 flux difference:

- HEAD: approximately `1.5471e-14 cm/d`;
- RUNOFF: approximately `5.6081e-14 cm/d`.

Both are below the 64-epsilon Ksat-scaled roundoff bound.

For the guard equation, the corresponding scale of `dt/dz * Ksat` is approximately `1.5471e-18`.

Observed full-minus-reduced guard-equation differences are at or below roughly `3.51e-19`, again within that roundoff scale.

## Same-origin candidate equivalence

At all 12 frozen observations:

- reduced dimension = 13;
- full and reduced theta fields are identical at reported precision;
- reconstructed tail 14:16 storage difference is exactly zero;
- full-minus-reduced nominal-interval ledger difference is zero;
- face 12/13 trapezoidal flux difference is zero;
- tail pressure-head differences are order `1e-14 cm` or smaller;
- Newton iteration counts match at every frozen point.

The reduced candidate therefore reproduces the full candidate from identical accepted origins to roundoff.

## Interface face 13/14

The full solver occasionally reports saturated-tail face fluxes of order `1e-14 cm/d`, while the analytic reduced reconstruction often returns exact zero.

Those differences are consistent with cancellation/roundoff around the hydrostatic saturated-tail condition.

Where a nonzero guard-residual difference exists, the face-13/14 term accounts for essentially all of it, but the absolute magnitude remains inside the preregistered roundoff significance envelope.

Therefore Z32 does **not** qualify a material `INTERFACE_FLUX_MISMATCH`.

## Guard node 13

Across the frozen points:

- theta13 storage increment full versus reduced is identical;
- guard storage difference is zero;
- full and reduced local guard residuals differ only by the roundoff-scale saturated-tail face-flux term.

Therefore Z32 does **not** qualify `GUARD_STORAGE_MISMATCH`.

## Reconstructed tail 14:16

Across both fixtures:

- full/reduced theta14:16 are identical;
- summed tail storage difference is zero;
- head differences are only roundoff-scale;
- reconstructed Darcy flux differences are roundoff-scale hydrostatic cancellation.

Therefore Z32 does **not** qualify `TAIL_RECONSTRUCTION_MISMATCH`.

## Relation to Z31R

Z31R demonstrated measurable long-horizon adaptive/full drift, concentrated in the stable n=13 regime.

Z32 now shows that this drift is **not reproduced as a material one-step equation discrepancy when full and reduced candidates start from the same accepted state** at representative n=13 times.

That is an important falsification.

The long-horizon difference must therefore depend on trajectory history / propagation of tiny state differences, rather than a simple persistent missing storage, interface-flux or tail-reconstruction term visible under same-origin replay.

This also explains why:

- Z29 same-origin event/control comparisons were essentially exact;
- Z31R can nevertheless develop measurable divergence after millions of independently driven intervals.

## Qualified claim boundary

Qualified:

- 6/6 observation coverage in both fixtures;
- same-origin n=13 candidate equivalence to roundoff;
- no material guard-storage discrepancy;
- no material reconstructed-tail storage discrepancy;
- no material interface-flux discrepancy under the frozen 64-epsilon rule;
- long-horizon Z31R drift is not attributable to a simple same-origin local equation defect at the frozen points.

Not qualified:

- exact nonlinear amplification mechanism of trajectory-history drift;
- broader soils/profiles;
- production admission;
- wall-clock speedup;
- any relaxation of Z30/Z31 comparison gates.

## Consequence

Do **not** introduce a correction coefficient or alter the n=13 interface equation based on Z32.

The next useful step should characterize trajectory-history amplification rather than continue static same-origin equation decomposition.

A successor should compare full and reduced independently driven states inside the stable n=13 regime and determine:

1. growth law of h/theta differences;
2. whether divergence is neutral, contracting or weakly amplifying;
3. relationship between state divergence and signed mass-difference accumulation;
4. sensitivity of the later 13:16 -> 14:16 event time to that accumulated state difference.

Given the very small absolute mass discrepancies and the established roughly 20% deterministic work reduction, this successor should also distinguish scientific-reference qualification from a practical SWAP Heritage performance envelope.

## Production boundary

Research only.

`LEGACY_NUMERICS` remains production default.
