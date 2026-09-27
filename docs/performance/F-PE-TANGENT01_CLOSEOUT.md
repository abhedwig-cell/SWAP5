# F-PE-TANGENT01 closeout — accepted-trajectory tangent authority

Date: 2026-09-26

Status: `CLOSED_NO_TANGENT_REPAIR_REQUIRED`

PR:

`#651 — F-PE-TANGENT01: accepted-trajectory tangent authority discrimination`

Parent:

`#650 — F-PE-TEMPORAL06`

## Trigger

TEMPORAL06 found that c=0.50 and c=0.65 produced materially different fresh accepted-trajectory tangents for O14 mid, while q remained close.

Against a fine N=64 Reference finite-difference derivative:

- c=0.50 differed by about 6.85%;
- c=0.65 differed by about 12.31%.

This raised the possibility that accepted-step directional composition itself was wrong.

## Discriminator

TANGENT01 preregistered a direct same-policy test.

For each difficult O14-mid point and each policy:

- tangent cache disabled;
- one fresh published tangent at h;
- independent q(h-epsilon) and q(h+epsilon) candidates from the same captured origin;
- identical temporal policy for nominal and perturbed candidates;
- path-smoothness checked through completion, solver rejection, retry count and accepted-substep count;
- central finite differences over an epsilon ladder;
- independent fixed-substep Reference derivative ladder N=1..64.

## Decisive result

All 16 policy/point combinations were smooth and complete.

### c=0.50

- one temporal retry;
- two accepted half-window substeps;
- 8/8 `DIRECTIONAL_MATCH`;
- maximum same-policy finite-difference relative error:
  `3.33516171534724854e-09`;
- published tangent also matches the independent N=2 Reference derivative to the same numerical level.

### c=0.65

- zero retries;
- one accepted full-window substep;
- 8/8 `DIRECTIONAL_MATCH`;
- maximum same-policy finite-difference relative error:
  `2.77586644025655597e-09`;
- published tangent also matches the independent N=1 Reference derivative to the same numerical level.

Thus the directional implementation is not merely within tolerance. It is numerically coincident with the derivative of the actual accepted response map.

## Temporal derivative convergence

The fixed-substep ladder shows monotone material refinement of dq/dh from N=1 toward N=64.

Representative O14-mid point:

- N=1:  -1.34490093958609097e-05 1/s;
- N=2:  -1.42866238900871908e-05 1/s;
- N=4:  -1.47910118823661351e-05 1/s;
- N=8:  -1.50718528706896601e-05 1/s;
- N=16: -1.52207432871472870e-05 1/s;
- N=32: -1.52975075508173124e-05 1/s;
- N=64: -1.53364979152549152e-05 1/s.

The TEMPORAL06 tangent discrepancy is therefore a property of temporal discretization of the response derivative.

## Contract reconciliation

The canonical fixed-interface coupling contract defines:

- the corrector value as the accepted-origin real-SWAP outward interface flux at prescribed interface head;
- the corrector tangent as accepted-trajectory `d(q_swap)/d(H_interface)`;
- MODFLOW linearization from that value and tangent.

This contract is consistent with the TANGENT01 same-policy finite-difference authority.

Historical F-GC30 qualification independently established the same oracle principle: an analytic trajectory derivative is checked against centered finite differences of the same admitted production candidate map from one immutable origin.

Therefore:

- N=64 is a valid fine-temporal reference for studying discretization error;
- N=64 is not the Jacobian of an N=1 or N=2 response map;
- substituting the fine derivative into a coarse response would be a mixed-fidelity response strategy, not a repair of the current tangent.

## Decision

No production tangent source change is authorized or required.

The accepted-step directional composition remains qualified within its current contract.

TEMPORAL06's direct c=0.50 versus c=0.65 tangent overlap failure remains an honest observation, but it must not be interpreted as evidence of tangent implementation failure.

The next production-policy question is separate:

Can c=0.65 be admitted for MODFLOW coupling when judged against the actual c=0.65 response-map tangent and end-to-end coupled behavior, rather than requiring agreement with c=0.50 or fine N=64 dq/dh?

That requires a separately preregistered admission workunit.

## Repository effect

TANGENT01 changes no production source.

It adds only:

- preregistration;
- independent qualification harness;
- result record;
- closeout record;
- CI wiring.

## Closure

F-PE-TANGENT01 is closed.

Verdict:

`NO_TANGENT_REPAIR_REQUIRED`

Scientific interpretation:

`PATH_CONSISTENT_TEMPORAL_DISCRETIZATION_DEPENDENCE`
