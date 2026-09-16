# SWAP5 Status-A current status

Date: 2026-09-16

This page is the current documentation entry point for the SWAP5 Status-A baseline. It summarizes the admitted capability boundary and points readers to the underlying acceptance and preservation authorities. It does not replace capability-specific scientific contracts, qualification records, or historical migration evidence.

## Pinned current authority

- canonical branch: `integration/f-ci-canonical`
- current Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- release-readiness acceptance record: [`STATUS_A_RELEASE_READINESS_BASELINE.md`](https://github.com/abhedwig-cell/SWAP5/blob/992a5c657bfe10a10100f92e0cb77c4825ae65b6/tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md)

The Status-A authority is later than the pinned scientific production baseline but does not introduce a scientific production postimage change. Current scope claims therefore follow the Status-A acceptance record, while scientific implementation remains anchored to the production baseline and its admitted capability records.

Later canonical acceptance gates supersede earlier intermediate migration/status statements for current-state claims. Earlier records remain valid evidence for the bounded decisions they actually made.

## What Status-A means here

Status-A is the admitted current-canonical SWAP5 baseline. It is a bounded scientific and architectural acceptance boundary, not a claim that all possible SWAP functionality or future architecture has been implemented.

Within the admitted scope, SWAP5 preserves the relevant scientific behaviour and reference expectations while changing how execution, state ownership, rollback, persistence, orchestration and coupling boundaries are made explicit. The current architecture is described in [Current Status-A architecture](CURRENT_ARCHITECTURE.md).

## CANONICALLY ADMITTED NOW

The current Status-A denominator includes the following capability families within their admitted contracts:

| Capability | Current Status-A meaning |
| --- | --- |
| Reference preservation | Legacy/reference behaviour remains the scientific comparison basis for the admitted preservation scope. |
| Richards / soil-water core | The admitted soil-water core is part of the qualified scientific production baseline. Status-A does not broaden its physics beyond the accepted scope. |
| Transactional execution | Trial execution is separated from acceptance. Candidate effects can be accepted or rejected without silently mutating the authoritative committed state. |
| Trial / accept / retry / rollback | Attempts have explicit outcome semantics. Retry is an execution decision; rollback restores the accepted authority rather than treating a failed candidate as committed. |
| State ownership | Persistent committed state, tentative candidate state and disposable scratch/workspace are distinct architectural roles. |
| Solver versus execution policy | Numerical solving and the policy that accepts, retries or selects an execution outcome are separate responsibilities. |
| Restart v1 | The admitted restart capability preserves/reconstructs the bounded committed-state contract required by Restart v1. |
| Serialized MultiSWAP v1 | The admitted MultiSWAP capability is serialized orchestration of the qualified real-physics path. It is not parallel/concurrent real-physics execution. |
| Drainage | The admitted drainage capability is part of the current qualified production baseline and preservation surface. |
| Surface evaporation | The admitted surface-evaporation capability is part of the current qualified production baseline and preservation surface. |
| WOFOST runtime | WOFOST is admitted only for its bounded qualified runtime scope. This is not a claim of a broad stable public API or unrestricted WOFOST execution surface. |
| Snow | Snow is admitted only for the restricted one-call-daily path that was qualified and canonically closed. |
| Groundwater Coupling v1 | The admitted groundwater chain includes the bounded internal coupling contract and the current external gateway boundary. Coupling publication follows the accepted-state contract. |
| External groundwater gateway | Gateway v1 is the admitted structural external-coupling seam. Its existence does not itself admit a broad concrete MODFLOW backend or arbitrary external-backend semantics. |
| F-PE11 performance closure | F-PE11 closes the qualified surface-evaporation allocation/scaling performance evidence at the Status-A boundary. It does not alter scientific semantics and is not a blanket whole-model or MultiSWAP speedup claim. |
| Permanent testbank / qualification | Current-canonical preservation is protected by capability qualification plus permanent regression authority, including [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md). |

## Deliberate bounds on current claims

The following statements are part of the current documentation contract:

- restricted Snow admission does not imply subdaily, multi-day, arbitrary-duration or advanced Snow semantics;
- serialized MultiSWAP v1 does not imply parallel or concurrent real-physics admission;
- Groundwater Coupling v1 and the external gateway do not imply broad MODFLOW backend evolution;
- F-PE11 does not establish a guaranteed whole-model speedup, a general MultiSWAP speedup, automatic rebatching, execution-class switching, GPU execution or a change in physics;
- bounded WOFOST runtime admission does not create a broad stable public API;
- capabilities outside the Status-A denominator are not automatically defects. They are blockers only when an applicable acceptance authority classifies them that way.

See [Deliberate future scope](FUTURE_SCOPE.md) for the explicit non-admitted boundary.

## SWAP 4.3.1 relationship

SWAP 4.3.1 remains an important reference source for scientific preservation and historical behaviour. SWAP5 Status-A is not documented as a wholesale scientific rewrite. The architectural difference is that the admitted SWAP5 runtime makes execution state and acceptance boundaries explicit: tentative work is separated from committed state, retries and rollback are first-class execution outcomes, and restart, MultiSWAP and coupling operate through bounded ownership contracts.

A separate SWAP 4.3.1 to SWAP5 equivalence campaign may add further validation evidence. That evidence can be linked from the traceability layer after acceptance without changing this Status-A capability denominator.

## How to find authority for a claim

Use [Theory, code and evidence traceability](TRACEABILITY.md). Do not infer current status from an old migration plan, target architecture page or intermediate qualification record alone.

For current claims, use this precedence:

1. current canonical Status-A/release-readiness acceptance authority;
2. later capability-specific canonical admission/closure authority;
3. qualification evidence that remains valid for the unchanged relevant dependency surface;
4. capability scientific contract and implementation record;
5. historical migration or target-design documentation.

This precedence preserves historical evidence without allowing an earlier snapshot to override later canonical acceptance.