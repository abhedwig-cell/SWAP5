# TAB-HYD KSATEXM candidate B preregistration

Date: 2026-09-23

Status: **PREREGISTERED RESEARCH CANDIDATE B**

Predecessor: candidate A is falsified by run `35854220809`.

## Falsification that motivates B

Candidate A used one TSPACK ln(K) spline across the admitted F-SI39 KSATEXM transition. On the exact Hupsel lower layer it produced:

- theta max abs = 2.0754e-6;
- C max abs = 6.3570e-6;
- log10(K) max abs = 3.9321e-2 at h=-1.93865 cm.

The K failure occurs immediately wetward of the historical transition at h=-2 cm and exceeds the preregistered 5e-4 limit by almost two orders of magnitude.

## Candidate B hypothesis

The error is caused by imposing one smooth interpolant across a physical/numerical branch with a genuine derivative discontinuity.

Candidate B therefore treats the F-SI39 transition as an explicit **interpolation-segment boundary** while preserving all other generated-provider choices.

## Frozen representation

- exactly 400 pressure-head rows per node;
- same dry and wet generation bounds as F-TAB02;
- same raw physical pressure-head runtime coordinate;
- same log(K) ordinate;
- same TSPACK interpolation family;
- same theta/C table and wet-theta branch;
- same constant dry extension;
- same K0-only derivative-slot semantics;
- no generic external table input.

For a KSATEXM-enabled node:

1. determine the threshold pressure head from the admitted analytical theta authority by solving
   `(theta(h)-theta_r)/(theta_s-theta_r) = cofgen(11)`;
2. force that pressure head to be an exact table knot;
3. sample theta and K only through the admitted analytical provider;
4. preprocess ln(K) separately on:
   - dry/default branch through the threshold knot;
   - threshold knot through the near-saturated KSATEXM branch;
5. retain the explicit saturated KSATEXM plateau above the qualified final K branch head.

The threshold knot is shared by both segments, but the left and right spline slopes are stored separately. No derivative continuity across the F-SI39 transition is assumed or imposed.

For a non-KSATEXM node, behavior must remain identical to qualified F-TAB02.

## Phase B-A acceptance

First gate: exact Hupsel lower layer used by F-SI39.

Unchanged limits:

- theta max abs <= 1e-4;
- capacity max abs <= 1e-4;
- log10(K) max abs <= 5e-4;
- saturated K equals KSATEXM;
- h=-1 cm F-SI39 oracle remains within the log10(K) limit;
- h=-5 cm extension remains exact analytical no-op;
- deterministic duplicate generation;
- O0/O2 output identity;
- K0 derivative slot exactly zero;
- H_ENPR fail closed;
- disabled-extension generated route preserves the F-TAB02 default behavior.

If the lower layer fails, stop candidate B.

## Phase B-B acceptance

Only if B-A passes.

Run both exact Hupsel layers. The top-layer threshold metadata is derived from the same historical ReadSWAP authority:

- ReadSWAP fixes `hthr=-2 cm`;
- relsat threshold is the MvG saturation at that head;
- K threshold is the default MvG K at that same head.

For the exact Hupsel top parameters this gives:

- relsat threshold = `0.9962891879895563`;
- K threshold = `36.025513440889625 cm/d`.

Apply the same constitutive limits independently and jointly over both layers.

## Later phases

Only after B-A and B-B pass:

- Reference-Richards + serialized K0 transaction/runtime qualification;
- exact M1-C3 whole-Hupsel gate;
- separate production-extension handoff if all gates close.

## Stop conditions

Do not tune knot count, tolerances, branch location or interpolation family after seeing B results.

If B fails, persist the falsification and redesign under a new candidate identifier.
