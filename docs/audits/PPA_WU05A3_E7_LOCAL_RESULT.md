# PPA-WU05-A3 E7 local groundwater/interface sweep

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / ICGWL_RULE_REFINED / NOT_YET_R1_FROZEN`

## Purpose

Stress the proposed corrected `icgwl` definition while total macropore water storage moves continuously from completely dry to completely full and the water interface crosses exact compartment boundaries.

## Important correction to E6

E6 found strong support for:

`icgwl = ICpTpWaSrDm(id)`

That statement is correct for partially filled interface compartments, but E7 found a discrete edge case at exact full-compartment boundaries.

Example:

- only the lowest compartment is exactly full;
- `ICpTpWaSrDm = bottom compartment`;
- the kinematic `icgwl` construction identifies the compartment immediately above it as the first not-fully-saturated compartment.

Therefore E6's unconditional equality was too strong.

## Refined source-bound rule

The candidate that reproduces the independent B1.11 kinematic construction is:

1. start with `icgwl = ICpTpWaSrDm(id)`;
2. if that compartment is fully wet/saturated and `icgwl > ICTopMP`, decrement `icgwl` by one;
3. otherwise retain it.

Equivalent physical interpretation:

`icgwl` is the first compartment at or above the stored-water body that is not fully saturated.

## Sweep

Synthetic four-compartment domain:

- volumes: 0.18, 0.21, 0.24, 0.27 cm;
- equal 10 cm compartment thickness;
- total storage swept over 10,001 equally spaced states from 0 to 0.90 cm.

For each state:

- the standard `MACROSTATE` bottom-connected storage construction was applied;
- water fractions and `ICpTpWaSrDm` were reconstructed;
- the original kinematic `icgwl` algorithm was evaluated independently;
- the refined corrected candidate was compared against it;
- storage closure and water-level monotonicity were checked.

## Result

Across all 10,001 states:

- candidate/kinematic index mismatches: **0**;
- storage reconstruction residual: below `2e-12 cm`;
- water level monotone throughout the sweep;
- no geometric jump at compartment boundaries beyond the finite sweep resolution;
- exact fill boundaries at 0.27, 0.51 and 0.72 cm are handled correctly by the one-compartment upward shift.

## Interpretation

The source semantics now appear clearer:

- `ICpTpWaSrDm` identifies the top compartment belonging to the stored-water body;
- `icgwl` identifies the first compartment that is not fully saturated;
- these are the same for a partially filled interface compartment;
- they differ by one exactly when the top stored-water compartment is completely full.

This resolves the E6 boundary ambiguity without introducing a new physical parameter or tolerance-driven behaviour.

## Current R1 candidate

Research-only corrected rule:

```text
icgwl = ICpTpWaSrDm(id)
if (icgwl > ICTopMP .and. FrMpWalWet(id,icgwl) >= 1 - eps) icgwl = icgwl - 1
```

The implementation should preferably avoid an arbitrary broad epsilon and use the same source-consistent saturation classification already used to construct the stored-water body.

## Mass/geometry conclusion

The refined rule preserves the bottom-connected storage identity and gives a continuous monotone macropore water-level trajectory through the interface sweep. No new whole-domain storage source or sink appears.

## Next step

E8 should now test reject/retry using the A2 seven-field state with source-active history mutations. In parallel, a small R1 `MACROSTATE` research implementation can use the refined interface rule and compare internal vertical-flux bookkeeping across compartment transitions.
