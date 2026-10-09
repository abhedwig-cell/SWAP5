# PPA-WU05-C3A PERF03 preregistration: full stress-route cost attribution

Date: 2026-10-03
Branch: research/ppa-wu05c3a-perf03-stress-profile
Baseline: integration/f-ci-canonical at branch creation

## Question

After canonical PERF01 and PERF02, where is the remaining cost of a non-skipped Bartholomeus stress evaluation spent?

This work unit is measurement-first. It does not change admitted PERF01/PERF02, equations, tolerances, state, ABI, checkpointing or application ownership.

## Motivation

E2E02 showed an accepted oxygen-enabled application around 120 us versus about 28 us oxygen OFF for its stress fixture, while E2E05 showed PERF02 eligibility is a demand/wetness-dependent niche rather than a broad shortcut. The next optimization target is therefore the full stress route.

## Cost partitions

Measure independently on the same production-constructed 3-node state:
1. REFERENCE waterfilm evaluation;
2. response-input assembly after a precomputed waterfilm;
3. profile response, including per-node MICRO/MACRO residual evaluation and scalar bisection;
4. complete PERF01 factor path with a precomputed PERF02-negative state;
5. where possible, residual evaluation count per rooted node using research-only instrumentation or an equivalent deterministic count experiment.

## Fixtures

Start from the canonical typed Bartholomeus production parameters and root carriers. Use at least the known stress state near h=-75 cm. Add dry/deeper stress states only if needed to distinguish cost dependence. Do not select states to make PERF02 eligible.

## Decision rule

Only propose an optimization after attribution.

Priority order:
- exact-preserving elimination of repeated pure calculations;
- reuse of immutable or node-local quantities within one call;
- reduced allocation/assembly overhead if material;
- no new approximation in PERF03.

A candidate is material if it plausibly removes at least about 5% of the full stress-route cost or a clearly repeated expensive operation. Smaller findings may be recorded but do not justify production complexity by themselves.

## Claim boundary

Microprofile results are not production-frequency, growing-season or MultiSWAP speed claims. E2E application timing remains the outer performance reference.
