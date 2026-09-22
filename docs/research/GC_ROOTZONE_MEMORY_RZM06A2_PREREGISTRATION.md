# GC-RZM06A2 H2 state-pair construction preregistration

Date: 2026-09-22  
Parent state: `GC-RZM06A` qualified at `e857cc4d9ee830dfb73524d665d463797ef1649c`  
Production changes: none

## Objective

RZM06A2 addresses only the unresolved H2 attribution problem. The previous two-interval top-forcing enumeration produced many accepted real-SWAP states but no pair satisfying both the unchanged total-profile-water criterion and the unchanged vertical-distribution criterion.

The thresholds remain:

- `|ΔW_profile| <= 1e-6` in the native geometry-based storage observable;
- `|ΔM1| >= 1e-4` in the native distribution-moment observable.

They will not be relaxed after endpoint states are seen.

## State construction

RZM06A2 changes the *antecedent construction method*, not the H2 criteria.

All construction intervals use zero top forcing. The lower boundary is driven transactionally through the existing groundwater-head materializer. Every trajectory ends with the same fixed interface head

`H* = -0.7149999706136307 m`.

For each frozen head-pulse amplitude `δH`, two symmetric orderings are generated:

1. `H* + δH -> H* - δH -> H*`;
2. `H* - δH -> H* + δH -> H*`.

The first two intervals have equal duration, so their signed head anomaly about H* sums to zero. The third interval is an explicit BASE relaxation interval. This is intended to create different vertical redistribution histories without top forcing, direct state mutation, or unequal endpoint time.

The frozen amplitude order is:

`1e-3, 5e-4, 2e-4, 1e-4, 5e-5, 2e-5, 1e-5 m`.

The frozen time-group order is:

1. pulse 0.05 d, relax 0.05 d, total 0.15 d;
2. pulse 0.10 d, relax 0.05 d, total 0.25 d;
3. pulse 0.05 d, relax 0.10 d, total 0.20 d;
4. pulse 0.02 d, relax 0.05 d, total 0.09 d.

Failed trajectories remain evidence. Endpoint pairs are compared only within one time group, so a selected pair always has the same committed endpoint time.

Within a time group, all accepted endpoints are compared lexicographically in the frozen trajectory enumeration order. The first pair meeting both unchanged H2 criteria is selected. The search stops after the first time group producing such a pair.

## Response gate

No interface-response probe is opened while constructing or selecting the endpoint pair.

Only after a pair has been selected is each origin deterministically replayed from fresh initialization and subjected to the same forcing-free probe:

- `H_c = H*`;
- top forcing = 0;
- duration = `1e-4 d`;
- read-only/discarded trial.

H2 is supported only if the selected pair replays exactly, both probes are whole-window accepted and mass-complete, committed state is unchanged by the probe, and

`|ΔE_c| > 1e-18`

in the native whole-window exchange quantity.

If no endpoint pair meets the unchanged water and M1 criteria, RZM06A2 closes as `NO_MATCH` without opening an E_c probe.

## Authority boundary

This remains research-only use of the F-GC44 serialized-reference carrier. It does not modify production physics, production groundwater coupling, canonical production APIs, or the one-head physical interface contract. Antecedent head trajectories are a state-construction device here, not a production recommendation.
