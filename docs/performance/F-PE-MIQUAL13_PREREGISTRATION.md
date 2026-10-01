# F-PE-MIQUAL13 preregistration — fused persistent serialized-manager fast path

Date: 2026-10-01

Status: `PREREGISTERED_BEFORE_RESULTS`

Canonical authority:

`integration/f-ci-canonical@7db09b56deb99decf32f47d2deed72710a04e8b5`

Parent authorities:

- MIQUAL11: `MIQUAL11_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`;
- MIQUAL12: `QUALIFIED_MIQUAL12_DISTRIBUTED_ADAPTER_OVERHEAD`.

## Purpose

Recover net serialized-runtime speed by reducing the measured distributed composition overhead as a group, while preserving all MIQUAL06 manager semantics.

MIQUAL12 found no dominant residual non-solver hotspot. The five non-solver phases each contribute roughly 18–22% of attributed adapter CPU. Therefore MIQUAL13 is an architectural zero-waste candidate rather than another isolated micro-optimization.

## Frozen candidate scope

Candidate C may only remove redundant composition/copy/binding work that is invariant across repeated eligible manager calls.

Authorized changes:

- persist and reuse reduced-view metadata when full shape and saturated-tail identity are unchanged;
- persist reduced provider bindings across calls when parameter identity and reduced shape are unchanged;
- update only call-varying provider values such as step duration;
- avoid redundant full evaluation-context assignment followed by immediate pointer overwrite;
- reduce redundant manager finalization/result copying where the selected reduced candidate is already known valid;
- preserve persistent reduced-request and full-candidate buffers.

Not authorized:

- changing saturated-tail detection semantics;
- changing reconstruction equations;
- changing accepted-state ownership;
- changing manager eligibility;
- changing numerical tolerances;
- changing full fallback or full bypass behavior;
- changing production default;
- using fitted correction/hysteresis/mass redistribution.

## Preservation gates

Require unchanged:

- Z43F manager seam smoke;
- MIQUAL06 serialized runtime seam;
- default full route;
- explicit manager selection;
- n=16 -> n=13 reduced route on frozen fixture;
- full-shape publication;
- typed bypass;
- fallback/no-leak semantics;
- exact physical equivalence.

## Performance gate

Run the unchanged MIQUAL09 40,000-interval, 11-pair equilibrium benchmark.

Reference history:

- original adapter median wall ratio: 1.05538;
- candidate A median wall ratio: 1.04677;
- candidate B median wall ratio: 1.03087;
- deterministic work ratio throughout: 0.8125.

Classifications:

- `QUALIFIED_MIQUAL13_FUSED_RUNTIME_RECOVERY`: median wall <1.00 and median CPU <1.00 with preservation gates green;
- `MIQUAL13_OVERHEAD_REDUCED_BUT_NOT_RECOVERED`: improved versus 1.03087 but still >=1.00;
- `MIQUAL13_FUSED_FASTPATH_NO_BENEFIT`: no material improvement;
- `MIQUAL13_SEMANTIC_REGRESSION`;
- `MIQUAL13_EXECUTION_INVALID`.

## Production boundary

`LEGACY_NUMERICS` remains production default until explicit production admission after a positive benchmark.
