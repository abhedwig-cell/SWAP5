# ROM-P Proposition Qualification

## Purpose

ROM-P is the first governed stage of the F-ROM research programme. It decides whether the reduced-order hypothesis is sufficiently well posed and potentially valuable to justify reference-trajectory experiments. It does not identify a reduced state and does not implement a solver.

## Authority baseline

ROM-P starts from canonical `0c7a76bafeab1b1e1c57f5615340178d45bec268` on `integration/f-ci-canonical`.

The governing research proposition is `docs/science/F-ROM_RESEARCH_PROPOSITION.md`.

## P1 Capability contract

The first state-identification claim is restricted to **pure one-column soil-water hydraulics**.

Initial required outputs are accepted total water storage, accepted fixed-upper-band storage, accepted fixed-lower-band storage, accepted bottom exchange, accepted top exchange and accepted water-balance diagnostics.

Pressure-head and water-content profiles are retained as full-order diagnostics for explaining counterexamples, not as primary reduced-output accuracy requirements.

Not yet in the first capability claim: dynamic crop-root uptake, oxygen stress, solute transport, MODFLOW6 coupling, regional aggregation, or broad ponding/runoff capability claims.

## P2 Domain contract

The first domain is one-dimensional vertically resolved SWAP soil water with a fixed soil profile during each experiment, accepted top forcing through an admitted boundary route, accepted lower flux or pressure-head boundary through an admitted route, both downward drainage and upward/capillary influence represented, and no regional tuning.

The first material challenge must use at least two contrasting existing qualified soil/material fixtures. Exact material IDs are frozen in the ROM-0 preregistration before trajectory generation and selected for hydraulic contrast rather than favourable ROM results.

## P3 Time/horizon contract

ROM-0 determines the stable accepted-trajectory observation cadence and Reference numerical floor before ROM-1 thresholds are set.

ROM-1 must include more than one continuation horizon. Long-horizon cumulative flux/storage drift is a separate requirement from short-horizon ambiguity.

## P4 Comparator contract

Required comparator families are Reference Richards, current admitted RossFast, spatially coarsened Richards, and literature integrated/two-layer reduced formulations where scientifically comparable.

RossFast performance is interpreted only within its measured authority. F-ROSS24 shared-host screening is proposition evidence, not a universal whole-model performance baseline.

## P5 Target workload/value contract

ROM is not justified merely because it has fewer state variables.

Before production closure work, a target workload must be named for end-to-end value evaluation. Candidate workload classes include large column populations, ensemble/uncertainty workloads and groundwater-coupled workloads.

ROM-P does not select a winning workload by assumption. It records which workload is selected and why before a production-value claim is permitted.

## Practical-state constraints

A state candidate that lowers ambiguity but cannot plausibly become a solver state is insufficient. Candidate state must remain compatible with conservation, restart/persistence, bounded validity, robust projection, inexpensive future propagation and cross-material semantic comparison.

## Error-envelope rule

ROM-P does not set an arbitrary 1%, 5% or similar ROM tolerance. ROM-0 first measures numerical/reference reproducibility. Application error envelopes are set only with that floor and the capability need visible.

## Decision

Allowed outcomes are `PROCEED_TO_ROM0`, `REFINE_CAPABILITY_CONTRACT`, `REFINE_TARGET_WORKLOAD`, or `NO_GO_PROPOSITION`.

The present authority closes ROM-P as **PROCEED_TO_ROM0** for the bounded pure-hydraulics research capability above. It does not permit ROM-1 state admission until ROM-0 closes.
