# PPA-WU05-D compensated root-water-uptake authority

Date: 2026-09-19

Status: `SOURCE_MATERIALIZATION_BLOCKED / REVIEW-ONLY OWNER BOUNDARIES FROZEN`

Original base: `integration/f-ci-canonical@e473afc2d378a2567a59cc0db1577b4c724feeb2`.  
Live reconciliation: `integration/f-ci-canonical@6c63b8d0e340669d9722bc5e3d947d42d2b467a5` via two-parent checkpoint `2bdd9fe4e285ccb07bb887a50ecc5802ef824265`; the intervening PPA-LOW02 runtime delta does not overlap compensation/root-authority files.

## Purpose

PPA-WU05-D freezes the ownership, transaction and dependency boundary for compensated root-water uptake before any production implementation.

The corrected B1.11 member identity for `SWAP/rootextraction.f90` is:

`8b7b2846618a8f82f3ed676c2c489d2d34be8c44b0a0d952f7f22ff09af78cd5`.

No admitted B1 patch changes that member. Earlier F-PM05 source-bound work already held compensated uptake outside the restricted drought-only Feddes production seam.

## Exact authority versus corroboration

The current project surface contains a later loose `rootextraction.f90` artifact. Its size differs from the pinned B1.11 member, so it is not an equation oracle.

It is useful only as corroboration. It shows a compensation section described as Jarvis/Walsum that consumes an already formed root-stress result, rescales the candidate nodewise root extraction, and then updates total uptake and stress-attribution results.

That supports an owner boundary. It does not authorize copying the equations or claiming exact B1.11 ordering, defaults or persistent-state semantics.

## Single root-water mass owner

The existing SWAP5 root-water-uptake process remains the sole accepted nodewise root sink.

Compensation is therefore a candidate-root-sink transformation inside the root-uptake composition surface. It cannot book a second water withdrawal.

The intended ownership topology is:

```text
potential transpiration + root geometry + hydraulic/stress views
                |
                v
pre-compensation root-uptake candidate
                |
                v
compensation transformation
                |
                v
final candidate nodewise root sink
                |
        outer transaction accept?
          no -> discard
          yes -> exactly one root-sink mass receipt
```

This topology does not admit compensation physics. It only prevents duplicate mass ownership.

## Retry and rollback

The later corroborating artifact rescales an existing candidate root sink. That creates an important target invariant independent of the exact formula.

A rejected trial must not become the basis for the next retry. In particular, a smaller retry may not apply a second compensation scaling to a qrot vector that was already scaled during the rejected attempt.

Every retry must rebuild the pre-compensation root result from the same committed checkpoint and current retry-span inputs, then evaluate the selected compensation method once for that trial.

No compensation reporting or stress-attribution value becomes accepted history before the enclosing root/hydraulic transaction commits.

## Persistent state and restart

PPA-WU05-D does not infer that compensation is stateless merely because the recovered later artifact looks algebraic.

Until byte-exact B1.11 source trace:

- persistent compensation state: `UNKNOWN_DO_NOT_INFER`;
- restart payload: `UNKNOWN_DO_NOT_INFER`;
- exact recomputability: `UNKNOWN_DO_NOT_INFER`.

If exact source proves that all compensation quantities are algebraic current-result values, later implementation should keep them out of persistent state. If it proves continuation state, that state must be checkpointed and restored explicitly.

## Jarvis and Walsum

The corroborating artifact distinguishes two compensation selectors and shows an additional root-depth/critical-depth dependency in the Walsum branch.

PPA-WU05-D therefore separates later Jarvis and Walsum slices.

It does not freeze their exact equations or parameters until D1 has the exact B1.11 source.

## Multiple stressors

The corroborating code uses aggregate drought, wetness/oxygen, salinity and frost reduction terms. The exact combination and selected-stressor order must remain source-bound.

Consequently:

- drought-only production does not imply compensation admission;
- WU05-C oxygen review does not imply oxygen compensation production;
- salinity compensation waits on WU05-E;
- frost compensation waits on an admitted frost route;
- no multiplication/order rule may be invented to make missing stressors composable.

## Groundwater derivative boundary

Compensation changes the accepted root sink. F-GC30 explicitly fails closed where a state-dependent root response lacks derivative coverage.

A future compensation implementation therefore cannot silently enter an analytic groundwater tangent profile. It requires explicit derivative coverage or a separately admitted fallback policy.

## Source-materialization blocker

The exact B1.11 member hash is pinned, but its complete source bytes are not materialized in current canonical. The later loose artifact is a different member and raw export of the original archive is unavailable on the current file surface.

This blocks equation-level production migration, but it does not block freezing the mass-owner, retry and dependency boundaries above.

## Frozen slices

1. **PPA-WU05-D1**: exact B1.11 source materialization, call-order and state census.
2. **PPA-WU05-D2**: typed Jarvis compensation compositor.
3. **PPA-WU05-D3**: typed Walsum compensation compositor.
4. **PPA-WU05-D4**: multi-stressor compensation after the relevant stress families are independently admitted.
5. **PPA-WU05-D5**: MICRO/Jong-van-Lier compensation after independent MICRO authority.

## Non-claims

This review does not claim:

- production compensation;
- exact B1.11 Jarvis or Walsum equations;
- zero persistent compensation state;
- salinity, oxygen or frost production;
- MICRO/Jong-van-Lier compensation;
- analytic groundwater derivative coverage;
- new solver or timestep policy.

## Verdict

`ROOT_SINK_OWNER_AND_RETRY_BOUNDARIES_FROZEN_EXACT_COMPENSATION_SCIENCE_SOURCE_HELD`

Production implementation remains forbidden until PPA-WU05-D1 supplies byte-exact B1.11 equation/order/state authority.
