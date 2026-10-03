# F-PE-NLGLOB14S result — moving-interface split temporal ownership feasibility

Date: 2026-09-29

Status:

`NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`

Qualification authority:

- workflow run: `36595791223`;
- job: `109500276921`;
- conclusion: SUCCESS.

## Frozen question

At the qualified first-retreat accepted state, can the profile be decomposed conservatively into:

- upper TG ownership on nodes 1:3;
- persistent saturated ownership on nodes 4:16;
- one shared physical interface flux across the 3/4 face?

No split endpoint solve and no mode switch were performed.

## Coverage

PASS.

All 12 six-level O05 first-retreat fixtures:

- have the frozen contiguous saturated set nodes 4:16;
- retain unsaturated nodes 1:3;
- remain finite and control-mass clean;
- have finite shared interface flux;
- have finite upper and lower moisture tendencies;
- have an admissible upper-domain TG head-space predictor.

## Split mass result

All 12 fixtures classify:

`SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`.

Aggregate classification:

`NLGLOB14S_SPLIT_OWNERSHIP_MECHANICALLY_FEASIBLE`.

The same 3/4 interface flux is used with opposite sign in the two domain balances.

Observed conservation:

- max absolute interface cancellation = `0.0 cm/d`;
- max absolute split-versus-full storage-rate closure = about `3.55e-15 cm/d`.

Thus no artificial source or sink is introduced by the spatial ownership decomposition.

## Interface behavior

At these first-retreat states the 3/4 interface flux is extremely small, generally roundoff-scale to about `5.37e-12 cm/d`.

Accordingly:

- nearly all net profile drying occurs in the upper three nodes;
- lower saturated-block storage tendency is near zero at this exact handoff state;
- the lower block can remain saturated without forcing its nodes through the full-column TG head-space predictor.

This is an observational property of the frozen first-retreat states, not a claim that the interface flux remains negligible later.

## Upper TG domain

The upper-domain TG predictor is admissible in 12/12 fixtures.

Across the bank:

- upper max |h_dot| remains about `397 cm/d`;
- predicted upper heads remain negative;
- predicted upper conductivities remain finite and positive.

Therefore the specific failure identified in NLGLOB14R4, saturated-node predictor overshoot inside the lower block, is absent when TG ownership is restricted to the unsaturated upper domain.

## Scientific interpretation

The split-domain direction passes its first necessary mechanical test.

At the first-retreat state there is a unique conservative decomposition with:

- ordinary TG-compatible upper dynamics;
- persistent saturated lower-domain ownership;
- one shared physical interface flux;
- exact total storage-rate closure.

This does not yet prove that separately evolving the two domains over a finite interval is well posed or trajectory-consistent.

## Consequence

A separately preregistered successor may now test one transactional split-domain shadow interval.

That successor must use a single shared interface exchange and must not allow the two domains to invent independent interface fluxes.

It must compare the recombined shadow endpoint and mass against the persistent-KLAG control and remain fully rollback-safe.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No temporal ownership policy or numerical default changed.

`LEGACY_NUMERICS` remains production default.
