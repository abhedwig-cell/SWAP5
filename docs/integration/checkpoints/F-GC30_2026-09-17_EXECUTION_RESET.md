# F-GC30 resumable checkpoint — 2026-09-17 execution reset

CAPABILITY: F-GC30

PHASE: RECONCILE → DESIGN RESET

BASELINE:
- `integration/f-ci-canonical`
- observed head at reset: `fc6c4e00d3b94f39dee5a30d68f4c6ef22385f9e`

WORK BRANCH:
- `work/f-gc30-modflow6-tangent-coupling-contract`
- pre-reset head: `fb534f089a3fe0803ce94bc8b49d1b7c6ec7bf4d`
- tactic-reset commit: `d2e3d9c5f64e6b246071cc4e3666e66136624b96`

## Decision

Repeated attempts to make the existing analytic trajectory tangent a prerequisite for F-GC30 caused repeated long dependency-tracing chains and timeouts without advancing the coupling implementation.

F-GC30 v0.1 therefore uses the historical centered finite-difference predictor as the canonical scientific route:

```text
q_1 = q_0 - delta_q
q_2 = q_0 + delta_q
u = ((q_2 - q_1) * delta_t) / (H_2 - H_1)
```

The analytic/trajectory tangent is no longer a blocker. It is deferred to a later optimisation/qualification surface and may replace the finite-difference route only after direct agreement with the finite-difference oracle has been demonstrated for the same origin, forcing, coupling window and active process composition.

## Reused evidence / established findings

- Predictor and corrector trials must start from one immutable accepted SWAP origin.
- `q_bot`, MODFLOW-facing `q_u`, and coupling coefficient `u` are distinct quantities.
- Generic full-profile `accepted_storage_change` is not a valid substitute for the coupling-specific response represented by `u`.
- Existing SWAP5 transaction/checkpoint semantics are suitable for repeated non-committing trials.
- Existing analytic trajectory derivative infrastructure is scientifically interesting but derivative-coverage completeness across all active state-dependent process owners is not yet established for the intended production route.
- Root-sink coverage has already exposed a fail-closed boundary; drainage response also has state-dependent derivative semantics that should not be silently treated as covered.

These derivative-coverage findings are sufficient to justify deferral. Do not reopen them inside F-GC30 v0.1.

## Mutations

- Updated `docs/integration/F-GC30_MODFLOW6_TANGENT_COUPLING_CONTRACT.md` with the execution reset and bounded next step.
- No production code changed.
- No solver code changed.
- No existing Status-A authority changed.

## Verdict

CONTINUE via finite-difference reference path.

## Next permitted action

Implement and qualify only the smallest predictor harness:

1. obtain one accepted SWAP checkpoint/origin using existing transaction seams;
2. run three non-committing prescribed-bottom-flux trials from that exact origin:
   - `q0 - delta_q`
   - `q0 + delta_q`
   - `q0`
3. expose terminal coupling-plane hydraulic heads for the two perturbation trials;
4. derive `u` with governed singularity/finite checks;
5. publish a typed, non-authoritative predictor-response object with explicit method provenance `CENTERED_FINITE_DIFFERENCE`;
6. prove the committed origin is byte/logically unchanged after the three trials;
7. persist a new checkpoint and stop.

## Explicit exclusions for next execution

Do not:
- trace F-KT21 derivative ownership further;
- redesign drainage or root uptake;
- bind MODFLOW 6 or XMI;
- implement Ribasim coupling;
- implement irrigation or pumping;
- broaden MultiSWAP coupling;
- attempt admission in the same execution chain.

If a required prescribed-`q_bot` trial seam or terminal coupling-plane head accessor is missing, fail closed and persist that exact missing seam as the next blocker instead of performing broad repository recovery.
