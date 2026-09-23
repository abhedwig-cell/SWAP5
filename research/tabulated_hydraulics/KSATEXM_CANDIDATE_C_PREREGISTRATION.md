# TAB-HYD KSATEXM candidate C preregistration

Date: 2026-09-23

Status: **PREREGISTERED RESEARCH CANDIDATE C — HYBRID GENERATED K0**

Predecessors:
- candidate A: unsplit ln(K) spline, falsified;
- candidate B: explicit spline segment at the F-SI39 threshold, falsified.

## Research hypothesis

The acceleration target is the expensive default-MvG constitutive evaluation. The admitted F-SI39 KSATEXM extension is already a very small piecewise-linear conductivity law in relative saturation.

Approximating that steep near-saturated branch with the same global raw-head table is unnecessary and, under candidates A/B, fails the existing F-TAB02 K tolerance.

Candidate C therefore uses:

- generated raw-head tables for theta, C and the default-MvG conductivity branch;
- the **exact admitted F-SI39 KSATEXM branch** when the extension condition is active.

This is a hybrid numerical representation of one admitted constitutive model, not new physics.

## Frozen branch semantics

For H_ENPR=0 and K0 only:

1. theta and C remain the generated F-TAB02 representation and wet-theta continuation.
2. If KSATEXM is disabled, K behavior must be identical to qualified F-TAB02.
3. If KSATEXM is enabled:
   - compute the exact admitted relative saturation from pressure head using the same default-MvG / wet-continuation authority;
   - if `relsat <= cofgen(11)`, evaluate K from the generated default-MvG table;
   - if `relsat > cofgen(11)`, evaluate exactly:
     `f=(relsat-cofgen(11))/(1-cofgen(11))`
     and
     `K=f*cofgen(10)+(1-f)*cofgen(12)`;
   - for saturated/nonnegative head, K = cofgen(10).
4. At the threshold equality, retain the dry/default branch exactly as F-SI39 does.
5. K0 derivative output remains zero.
6. No K1, generic external table, H_ENPR, or changed solver policy.

The exact F-SI39 expression is copied from the already admitted canonical authority; it is not recalibrated or fitted.

## Candidate C lower-layer gate

Use the exact Hupsel lower layer and the same sweep/probes as candidates A/B.

Unchanged acceptance:

- theta max abs <= 1e-4;
- C max abs <= 1e-4;
- log10(K) max abs <= 5e-4;
- exact saturated KSATEXM;
- h=-1 cm oracle within K limit;
- exact no-op behavior below threshold;
- deterministic generation;
- O0/O2 identity;
- H_ENPR fail closed;
- default non-extension route unchanged.

## Candidate C two-layer gate

Only if lower layer passes.

Use exact Hupsel top and lower layer. Historical ReadSWAP fixes the extension threshold at h=-2 cm and derives the threshold metadata from the layer MvG relation.

Exact top-layer derived authority:
- relsat threshold = 0.9962891879895563;
- K threshold = 36.025513440889625 cm/d.

The derivation must be recorded and reproducible from the authoritative ReadSWAP equations; no guessed parameters.

## Candidate C runtime gates

Only after both constitutive layers pass:

- existing F-TAB02 Reference Richards K0 harness;
- existing serialized transaction/runtime harness;
- exact M1-C3 whole-Hupsel application authority.

Correctness gates are unchanged. Performance is characterized but not used to relax fidelity.

## Stop conditions

Stop C if:
- exact branch semantics require a solver/provider ABI change;
- the constitutive limits fail;
- transaction/mass/acceptance semantics diverge;
- exact whole-Hupsel remains outside the resulting supported profile.

No tuning of tolerances or branch definitions is allowed after results.
