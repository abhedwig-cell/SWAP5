# F-PE-APPROX04 — bounded same-origin response surrogate

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH_ONLY`

Parent:
`F-PE-PROFILE06`

## Trigger

PROFILE06 established that on difficult accepted-direction workloads:

- A1 tangent reuse removes most repeated tangent work;
- A2C reduces physical Richards solve effort;
- A1 + A2C is complementary in 5/6 difficult cases;
- the remaining dominant repeated cost is the physical Reference solve on every same-origin corrector trial.

A1 already provides a bounded same-origin tangent cache, but every corrector still performs a physical solve before returning q(h).

## Research question

Can intermediate same-origin corrector responses be supplied from a bounded local response representation while retaining an exact physical solve before any commit?

The first representation to test is the local first-order response already available from the accepted origin:

`q(h) ~= q0 + dq/dh * (h - h0)`

This is a coupling approximation, not a solver replacement.

## Non-negotiable ownership rule

A surrogate response is response-only.

It must not create, mutate or masquerade as a valid SWAP candidate state.

A physical candidate becomes commit-eligible only after an exact Reference/A2C trial is executed at the final accepted coupling head.

Therefore:

- intermediate surrogate calls may return exchange and tangent information only;
- publication/commit readiness remains false for surrogate-only responses;
- final coupled convergence must be followed by an exact validation trial;
- commit uses only that exact validated candidate.

## Initial validity envelope

Start from the already-qualified A1 same-origin cache constraints:

- same captured origin lineage/revision;
- same coupling window;
- head displacement <= 0.005 m;
- maximum age <= 8 corrector uses.

These are initial research bounds only.

APPROX04 must not silently inherit A1 admission for q-response approximation.

## A4-P0 — offline response error characterization

Before implementation, measure exact mode-5 q(h) around frozen difficult PROFILE06 origins.

Use the selected difficult set:

- B01 wet;
- B01 mid;
- B12 wet;
- O05 wet;
- O14 wet;
- O14 mid.

For head offsets across the A1 window:

- 0;
- +/-0.05 cm;
- +/-0.10 cm;
- +/-0.25 cm;
- +/-0.50 cm.

At each point compare exact q(h) with:

`q_pred = q0 + tangent0 * delta_h`

Report:

- absolute exchange error;
- relative exchange error where reference q is not near zero;
- error relative to the exact q excursion from origin;
- tangent drift;
- sign/orientation preservation.

## A4-P1 — bounded response-only prototype

Only if P0 supports a useful envelope.

Prototype must live in research/test infrastructure first.

Required behavior:

1. exact origin response and tangent;
2. surrogate response for eligible intermediate same-origin correctors;
3. exact fallback outside envelope;
4. exact validation trial at converged head;
5. no surrogate candidate can be committed.

## Qualification dimensions

Any advancing candidate must be tested for:

- corrector exchange error;
- coupled convergence path;
- number of exact Richards solves avoided;
- total coupled runtime;
- final exact endpoint;
- interface ledger;
- canonical mass accounting;
- candidate-state ownership;
- rollback/abandon semantics.

## Rejection criteria

Reject if:

- q-response error is not bounded monotonically enough for a safe envelope;
- coupled iterations increase enough to erase solve savings;
- surrogate and exact-final semantics become ambiguous;
- an intermediate surrogate can leak into commit state;
- or live coupled robustness deteriorates.

## Production status

APPROX04 starts as research-only.

No new production flag or default is admitted by this preregistration.
