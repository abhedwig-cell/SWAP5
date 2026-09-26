# F-PE-PROFILE05R1 — post-repair practical-stack rebaseline

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

Parent:
`F-PE-REPAIR01`

Predecessor:
`F-PE-PROFILE05`

## Trigger

PROFILE05 could not publish a combined A1+A2C live coupled performance result because the exact FGC44 route was process-to-process nondeterministic.

REPRO01 localized that failure to inactive-root mode-5 qbot materialization reading non-authoritative `provider_root_sink` scratch.

REPAIR01 corrected the ownership defect and qualified:

- inactive-root poisoned scratch: 40/40 PASS;
- root-active semantics: preserved;
- fixed-build exact: 20/20 PASS;
- fixed-build A2C: 20/20 PASS;
- A1 live control: PASS;
- A2C live control: 6/6 PASS.

The coupled reference is therefore available again for performance measurement on the repaired postimage.

## Purpose

Measure the combined retained practical modes on one repaired production postimage:

- exact default;
- A1 only;
- A2C only;
- A1 + A2C.

PROFILE05R1 is observation-only.

No `src/**` modification is permitted.

## Primary authority

The primary result is direct same-postimage live SWAP + MODFLOW6 timing.

Do not construct combined speedup by adding or multiplying earlier A1 and A2C percentages.

## Coupled protocol

Use the existing four-arm live FGC44 runner:

`tests/fpe/run_fpe_profile05_four_arm_modflow_e2e.sh`

Run five independent replicas.

For every arm and replica require:

- successful coupled completion;
- final head available;
- final SWAP flux available;
- ledger endpoint available;
- coupled iteration count available.

Record:

- wall-clock coupled-loop time;
- exact-relative ratio;
- speedup;
- A1 fresh/reuse counts.

## Endpoint rule

The repaired exact arm is authority.

A1, A2C and stack endpoint differences versus exact must remain zero within the already-qualified test representation for:

- final MODFLOW head;
- final SWAP exchange;
- interface ledger;
- coupled iteration count.

Any candidate-only failure reopens robustness rather than being discarded as timing noise.

## Supporting measurements

Re-run on the same postimage:

- A2C application-shaped sequence;
- current repeated Reference/directional decomposition where useful for attribution.

## Interpretation

For the five stack replicas report:

- all raw exact and stack times;
- stack speedup per replica;
- median and mean stack speedup;
- min/max observed stack speedup;
- stack versus A1 ratio;
- stack versus A2C ratio.

Sub-millisecond spread is timing variance.

Only directionally consistent replicated evidence may support a coupled speedup claim.

## Closure

PROFILE05R1 closes with either:

1. a valid post-repair A1+A2C practical-stack end-to-end rebaseline; or
2. a new specifically localized robustness/timing blocker.

No optimization work is admitted by PROFILE05R1.
