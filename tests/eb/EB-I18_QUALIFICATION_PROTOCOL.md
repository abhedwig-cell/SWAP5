# EB-I18 Candidate-Bound Bottom Energy Publication — Qualification Protocol

## Authority

Base authority is `EB-I17R@ab74f6ded24a7d74d5f3c6f5dcafe58e28f7248f`.

EB-I18 may implement the next boundary frozen by EB-I17R: one atomic runtime seam that owns trial, local thermal capture, external donor resolution, local energy preparation, commit of the same kernel candidate object, and accepted-only energy publication.

This protocol does not itself qualify the staged implementation.

## Non-negotiable transaction rule

The implementation is qualified only if the following ordering is structurally and dynamically proven inside one transaction-owner call:

1. capture checkpoint;
2. execute exactly one physical trial through the existing backend;
3. obtain the thermal candidate produced by that same trial while the matching kernel candidate remains local;
4. clear backend thermal scratch so it cannot be reused by a later trial;
5. apply the existing hydrologic admission, mass-completeness and candidate-validity gates;
6. resolve external donor temperatures only for exact external-inflow samples of that local thermal candidate;
7. evaluate bottom sensible energy into private worker/job-local prepared data;
8. commit that same local kernel candidate through the existing F-KT commit authority;
9. construct public accepted-energy attribution only from the local prepared data and the receipt returned by that commit.

There SHALL be no public API accepting a detached prepared-energy object plus an independently supplied commit receipt.

## External provider obligations

The provider is a runtime/coupler dependency and SHALL be source-system-neutral. A provider call is a query for thermal metadata only. It SHALL NOT:

- own, replace, rescale or rebook the SWAP bottom water transfer;
- authorize SWAP candidate acceptance or commit;
- mutate SWAP committed state;
- require a second SWAP physical solve;
- introduce MODFLOW-, deep-vadose-, tile- or file-specific types into the kernel/process layer.

A request is valid only for an exact external-inflow sample and includes column identity, one-based sample ordinal, sample interval and the already-computed outward-positive water transfer. A response must match that request exactly and may be COMPLETE, UNAVAILABLE or STALE. COMPLETE requires a finite donor temperature. Missing, stale, invalid or nonfinite thermal data have no implicit temperature fallback.

The external component owns how its one scalar donor temperature for the sample is scientifically derived. SWAP does not invent external temporal interpolation.

## Hydrology versus diagnostic energy

Bottom sensible energy remains diagnostic/non-governing in EB-I18.

Therefore provider unavailability, stale thermal metadata, invalid thermal metadata or an incomplete energy total SHALL NOT retroactively reject, roll back, recommit or alter an otherwise valid mass-conserving hydrologic candidate.

After a successful hydrologic commit, accepted-energy attribution may be:

- complete, with a finite total; or
- explicitly unavailable/incomplete with diagnostics tied to that accepted transaction.

Missing external donor temperature is never encoded as zero energy.

An internal provenance/postcondition contradiction after a successful physical commit is an invariant breach, not a normal provider-unavailable case. Qualification must distinguish these cases explicitly.

## Required dynamic evidence

Final EB-I18 qualification requires, at minimum:

1. **local-only accepted path** — no provider calls; accepted energy equals the qualified EB-I15 result;
2. **external COMPLETE path** — provider called exactly once per external sample; total uses the existing I04 sensible-enthalpy primitive and accepted EB-I13 water amount;
3. **external UNAVAILABLE path** — hydrology commits; accepted energy publication exists but total is unavailable; no zero fallback;
4. **external STALE path** — same hydrologic behavior, explicit stale diagnostics, total unavailable;
5. **invalid/mismatched provider response** — hydrology remains governed only by existing physical/mass rules; energy is fail-closed and diagnosed;
6. **kernel reject** — no accepted energy publication and no stale publication leakage;
7. **mass-incomplete reject** — no accepted energy publication;
8. **candidate-invalid/commit-reject path** — no accepted energy publication;
9. **retry/repeated-call stale-scratch attack** — an earlier thermal/prepared result cannot be published for a later accepted candidate;
10. **same-origin sibling attack** — distinct candidates sharing lineage, revision and interval cannot be cross-paired through any public API;
11. **non-energy route preservation** — existing standalone/serialized/MultiSWAP transaction behavior remains semantically unchanged when the feature is not requested;
12. **restart preservation** — no new persistent continuation state or restart field;
13. **mass authority preservation** — no second bottom-water or total-mass booking;
14. **O0/O2 semantic identity** for the new deterministic qualification oracle;
15. **all 30 SWAP Core Architecture Invariants** explicitly audited.

## Accounting ownership

The accepted EB-I13 `bottom_outward_exchange_native` remains the sole water-transfer authority consumed by energy accounting. EB-I18 adds energy attribution only. It does not change the hydrologic water balance or define an independent mass ledger.

## State and scaling

Prepared energy, provider responses and binding bundles are worker/job-local scratch. They are not persistent column physical state. Inactive columns incur no persistent energy-provenance footprint. The implementation must remain compatible with batching and parallel MultiSWAP execution without a global live-candidate registry.

## Hard nonclaims

Even a fully qualified EB-I18 does not by itself claim:

- governing thermal feedback into soil-water or heat acceptance;
- persistent energy-ledger or restart-energy state;
- whole-system energy closure;
- MODFLOW-specific thermal coupling;
- a second water/mass authority;
- higher-order temporal quadrature;
- canonical admission.

## Admission rule

Compile success or staged preflight success is necessary but insufficient. Production source must be committed, the required dynamic adversarial tests must pass, the exact unchanged head must have a successful qualification workflow, and status/closure evidence must bind that exact head before EB-I18 may be called qualified.
